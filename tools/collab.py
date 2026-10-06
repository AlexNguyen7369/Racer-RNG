#!/usr/bin/env python3
"""Team work over GitHub: every feature gets its own branch labelled with who started it, the repo stays in sync with
origin, and every collaborator's unmerged work is compared with main and with your own work.

  python3 tools/collab.py start "Title" [--detail TEXT] [--todo ID] [--no-push]
        new branch feature/<handle>/<slug> from origin/main (no checkout, your working tree is untouched), with an
        empty "Start feature" commit whose trailers record the title and who initiated it, pushed to origin, and the
        TODO item (given, or a new one in Doing) linked to it
  python3 tools/collab.py sync          git fetch --prune origin
  python3 tools/collab.py push          push the current branch to origin (main still goes through the pre-push gate)
  python3 tools/collab.py overview      every unmerged branch: who, what, which systems, overlap and conflicts with you

Who is who: tools/dashboard/data/team.json (git email -> name, GitHub login, branch handle, role).
Branches are labelled by git itself (branch name + commit trailers), so nothing has to be kept in sync by hand and a
collaborator who never runs this tool still shows up (their first commit on the branch counts as the initiator).
Stdlib only; used by tools/dashboard/server.py.
"""
import argparse
import json
import os
import re
import subprocess
import sys
import uuid

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA = os.path.join(ROOT, "tools", "dashboard", "data")
TEAM_FILE = os.path.join(DATA, "team.json")
TODO_FILE = os.path.join(DATA, "todo.json")
REMOTE = "origin"
MAIN = "main"
BASE = f"{REMOTE}/{MAIN}"
MAIN_NAMES = {"main", "master", "HEAD"}

sys.path.insert(0, os.path.join(ROOT, "tools"))
import compat  # noqa: E402
import readme_sync  # noqa: E402

# Which part of the game a path belongs to (first match wins). Shown as "systems touched".
AREAS = [
    (r"^places/|\.rbxlx?$", "Studio place files"),
    (r"^default\.project\.json$|\.meta\.json$", "Rojo project (what syncs into Studio)"),
    (r"^src/server/CarTest/|^src/client/UiTest/", "Tests"),
    (r"^src/client/(?!CarController)|^ui/|StarterGui", "UI (client)"),
    (r"^src/shared/Tracks/|Track(Builder|Validator|Registry)", "Tracks"),
    (r"Workshop", "Workshop"),
    (r"Upgrade", "Upgrade tree"),
    (r"Gacha|CarCatalog|^src/shared/Cars/|Roll|Index", "Car gacha / rolls / index"),
    (r"Npc", "NPC racers"),
    (r"Race(Service|Config)|PathDriver|Money", "Auto race / economy"),
    (r"Car(Service|Factory|Physics|Config|Controller|Appearance)|PhysicsTargets", "Car system"),
    (r"PlayerData", "Save data"),
    (r"Admin", "Admin commands"),
    (r"SpawnArea", "Spawn area"),
    (r"^src/", "Other game code"),
    (r"^assets/|^blender/|^drafts/|^references/", "Art (Blender / meshes)"),
    (r"^context/|current_progress\.md$|^README\.md$|^CLAUDE\.md$", "Project notes"),
    (r"^docs/", "Design docs"),
    (r"^tools/dashboard/data/", "Dashboard board (TODO etc.)"),
    (r"^tools/|^\.claude/|^\.githooks/|^\.gitignore$", "Tooling"),
]


class GitError(RuntimeError):
    pass


def git(*args, check=True, env=None):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True,
        env={**os.environ, **env} if env else None)
    if check and r.returncode != 0:
        raise GitError(r.stderr.strip() or f"git {args[0]} failed")
    return r.stdout


def git_rc(*args):
    r = subprocess.run(["git", *args], cwd=ROOT, capture_output=True, text=True)
    return r.returncode, r.stdout, r.stderr


def read_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(path, data):
    tmp = f"{path}.{uuid.uuid4().hex}.tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)
        f.write("\n")
    os.replace(tmp, path)


def slugify(text, n=40):
    s = re.sub(r"[^a-z0-9]+", "-", text.lower()).strip("-")
    return s[:n].rstrip("-") or "feature"


# ---------------------------------------------------------------------------------------------------------------
# people


def team():
    return read_json(TEAM_FILE, {"members": []}).get("members", [])


def member_for(name="", email=""):
    """The team.json entry for a git identity (matched by email, then name), or a stand-in built from it."""
    email, name = (email or "").lower(), name or ""
    for m in team():
        if email and email in [e.lower() for e in m.get("emails", [])]:
            return m
    for m in team():
        if name and name.lower() in [m.get("name", "").lower(), m.get("github", "").lower()]:
            return m
    return {"name": name or email or "unknown", "handle": slugify(name or email.split("@")[0] or "someone", 20),
        "github": "", "role": "", "unknown": True}


def me():
    name = git("config", "user.name", check=False).strip()
    email = git("config", "user.email", check=False).strip()
    return {**member_for(name, email), "gitName": name, "gitEmail": email}


def label(m):
    return {"name": m.get("name"), "github": m.get("github", ""), "handle": m.get("handle"), "role": m.get("role", "")}


# ---------------------------------------------------------------------------------------------------------------
# GitHub sync


def remote_web_url():
    url = git("remote", "get-url", REMOTE, check=False).strip()
    m = re.match(r"(?:https://|git@)github\.com[/:](.+?)(?:\.git)?$", url)
    return f"https://github.com/{m.group(1)}" if m else ""


def fetch():
    git("fetch", "--prune", "--quiet", REMOTE)


def current_branch():
    return git("rev-parse", "--abbrev-ref", "HEAD", check=False).strip()


def push_current():
    """Push the checked-out branch and set its upstream. Pushing main is left to the pre-push gate."""
    br = current_branch()
    if br in ("", "HEAD"):
        raise GitError("not on a branch")
    rc, out, err = git_rc("push", "-u", REMOTE, f"HEAD:refs/heads/{br}")
    if rc != 0:
        raise GitError(err.strip() or out.strip() or "push failed")
    return {"branch": br, "output": (err or out).strip()}


def tracked_changes():
    """Uncommitted edits to tracked files (untracked files are carried by a switch without risk)."""
    return [l[3:] for l in git("status", "--porcelain=v1", "--untracked-files=no").splitlines()]


def switch(branch):
    if not re.fullmatch(r"[A-Za-z0-9._/-]+", branch) or branch.startswith("-"):
        raise GitError("bad branch name")
    dirty = tracked_changes()
    if dirty:
        raise GitError(f"you have {len(dirty)} uncommitted change(s) to tracked files: commit or stash them first, "
            "so Rojo never syncs a mix of two branches into Studio")
    rc, _out, err = git_rc("switch", branch)
    if rc != 0:
        raise GitError(err.strip())
    return {"branch": current_branch()}


# ---------------------------------------------------------------------------------------------------------------
# feature branches


def branch_exists(name):
    for ref in (f"refs/heads/{name}", f"refs/remotes/{REMOTE}/{name}"):
        if git_rc("rev-parse", "--verify", "--quiet", ref)[0] == 0:
            return True
    return False


def start_feature(title, detail="", todo_id=None, push=True, do_fetch=True):
    """Create feature/<handle>/<slug> from origin/main without touching the working tree, labelled with who started it."""
    title = (title or "").strip()
    if not title:
        raise GitError("title required")
    if do_fetch:
        try:
            fetch()
        except GitError:
            pass  # offline: branch from the last fetched main
    who = me()
    base = BASE if git_rc("rev-parse", "--verify", "--quiet", BASE)[0] == 0 else "HEAD"
    stem = f"feature/{who['handle']}/{slugify(title)}"
    name, n = stem, 2
    while branch_exists(name):
        name, n = f"{stem}-{n}", n + 1
    fid = uuid.uuid4().hex[:8]
    msg = f"Start feature: {title}\n\n" + (f"{detail.strip()}\n\n" if detail.strip() else "")
    msg += f"Feature-Id: {fid}\nFeature-Title: {title}\nInitiated-By: {who['gitName']} <{who['gitEmail']}>\n"
    if who.get("github"):
        msg += f"Initiated-By-GitHub: {who['github']}\n"
    if todo_id:
        msg += f"Todo-Id: {todo_id}\n"
    # an empty commit on top of main: same tree, so it changes nothing, but it carries the label to GitHub
    sha = git("commit-tree", f"{base}^{{tree}}", "-p", base, "-m", msg).strip()
    git("branch", name, sha)
    pushed, push_error = False, ""
    if push:
        rc, _out, err = git_rc("push", "-u", REMOTE, f"{name}:refs/heads/{name}")
        pushed, push_error = rc == 0, ("" if rc == 0 else err.strip())
    if pushed:
        git("branch", f"--set-upstream-to={REMOTE}/{name}", name, check=False)
    return {"branch": name, "featureId": fid, "title": title, "base": base, "sha": sha, "pushed": pushed,
        "pushError": push_error, "initiatedBy": label(who), "compare": compare_url(name)}


def link_todo(info, todo_id=None, detail=""):
    """Record the branch on its TODO item (or add one in Doing), so the board shows who started what and where."""
    data = read_json(TODO_FILE, {"items": []})
    who = info["initiatedBy"]["name"]
    at = __import__("datetime").datetime.now().astimezone().isoformat(timespec="seconds")
    item = next((i for i in data["items"] if i["id"] == todo_id), None) if todo_id else None
    if not item:
        item = {"id": uuid.uuid4().hex[:8], "title": info["title"][:200], "detail": detail[:4000], "status": "doing",
            "source": "feature branch", "by": who, "added": at}
        data["items"].append(item)
    item.update({"branch": info["branch"], "featureId": info["featureId"], "owner": who,
        "ownerGithub": info["initiatedBy"].get("github", ""), "updated": at, "updatedBy": who})
    if item.get("status") in ("backlog", "next"):
        item["status"] = "doing"
    write_json(TODO_FILE, data)
    readme_sync.sync()
    return item


def compare_url(branch):
    web = remote_web_url()
    return f"{web}/compare/{MAIN}...{branch}?expand=1" if web else ""


# ---------------------------------------------------------------------------------------------------------------
# overview of everyone's branches


def area_of(path):
    for pat, name in AREAS:
        if re.search(pat, path):
            return name
    return "Other"


def all_branches():
    """Every branch on origin plus local branches never pushed: {name: (ref, onRemote)}."""
    out = {}
    for line in git("for-each-ref", "--format=%(refname)", f"refs/remotes/{REMOTE}").splitlines():
        name = line[len(f"refs/remotes/{REMOTE}/"):]
        if name not in MAIN_NAMES:
            out[name] = (f"{REMOTE}/{name}", True)
    for name in git("for-each-ref", "--format=%(refname:short)", "refs/heads").split():
        if name not in MAIN_NAMES and name not in out:
            out[name] = (name, False)
    return out


def my_files():
    """Files your work changes compared with main: commits on your branch + everything uncommitted."""
    files = set()
    if git_rc("rev-parse", "--verify", "--quiet", BASE)[0] == 0:
        files |= set(git("diff", "--name-only", f"{BASE}...HEAD", check=False).split("\n"))
    for line in git("status", "--porcelain=v1", "-uall").splitlines():
        p = line[3:].split(" -> ")[-1].strip('"')
        files.add(p)
    files.discard("")
    return files


def merge_conflicts(a, b):
    rc, out, _err = git_rc("merge-tree", "--write-tree", "--name-only", "--no-messages", a, b)
    if rc == 0:
        return []
    if rc == 1:
        return [l for l in out.splitlines()[1:] if l.strip()]
    return None  # unknown (unrelated histories, old git)


def handoff_notes(ref, files):
    """Notes the collaborator left for others: handoff / readme docs added or changed on the branch."""
    notes = []
    for f in files:
        p = f["path"]
        if re.search(r"(HANDOFF|NOTES|CHANGES)[^/]*\.md$", p, re.I) and f["status"] != "D":
            notes.append({"path": p, "text": git("show", f"{ref}:{p}", check=False)[:6000]})
    return notes


_cache = {}


def overview():
    head = git("rev-parse", "HEAD", check=False).strip()
    base_ok = git_rc("rev-parse", "--verify", "--quiet", BASE)[0] == 0
    main_sha = git("rev-parse", BASE, check=False).strip() if base_ok else ""
    mine = my_files()
    branches = all_branches()
    tips = {n: git("rev-parse", r, check=False).strip() for n, (r, _) in branches.items()}
    key = (head, main_sha, tuple(sorted(tips.items())), tuple(sorted(mine)))
    if _cache.get("key") == key:
        return _cache["value"]
    stamp_fp = (compat.load_stamp() or {}).get("fingerprint")
    cur = current_branch()
    me_ = me()
    rows = []
    for name, (ref, on_remote) in sorted(branches.items()):
        tip = tips[name]
        merged = base_ok and git_rc("merge-base", "--is-ancestor", tip, BASE)[0] == 0
        behind, ahead = (git("rev-list", "--left-right", "--count", f"{BASE}...{ref}").split() if base_ok else ("?", "?"))
        fmt = "%H%x1f%an%x1f%ae%x1f%aI%x1f%s%x1f%(trailers:key=Initiated-By,valueonly,separator=)%x1f" \
            "%(trailers:key=Feature-Title,valueonly,separator=)%x1f%(trailers:key=Feature-Id,valueonly,separator=)%x1e"
        span = f"{BASE}..{ref}" if base_ok else ref
        commits = []
        for rec in git("log", f"--format={fmt}", span, check=False).split("\x1e"):
            parts = rec.strip("\n").split("\x1f")
            if len(parts) == 8:
                sha, an, ae, date, subj, init, ftitle, fid = parts
                commits.append({"sha": sha, "short": sha[:7], "author": an, "email": ae, "date": date,
                    "subject": subj, "initiatedBy": init.strip(), "featureTitle": ftitle.strip(), "featureId": fid.strip()})
        start = next((c for c in reversed(commits) if c["initiatedBy"]), None)
        if start:
            m = re.match(r"(.*?)\s*<(.*)>", start["initiatedBy"])
            initiator, how = member_for(*(m.groups() if m else (start["initiatedBy"], ""))), "start commit"
        elif commits:
            initiator, how = member_for(commits[-1]["author"], commits[-1]["email"]), "first commit"
        else:
            last = git("log", "-1", "--format=%an%x1f%ae", ref, check=False).strip().split("\x1f")
            initiator, how = member_for(*(last + [""])[:2]), "last commit"
        by_author = {}
        for c in commits:
            if c["subject"].startswith("Start feature:"):
                continue
            mm = member_for(c["author"], c["email"])
            by_author.setdefault(mm["name"], {**label(mm), "commits": 0})["commits"] += 1
        files = []
        if base_ok:
            stats = {}
            for l in git("diff", "--numstat", f"{BASE}...{ref}", check=False).splitlines():
                a, d, p = l.split("\t", 2)
                stats[p] = (a, d)
            for l in git("diff", "--name-status", f"{BASE}...{ref}", check=False).splitlines():
                st, p = l.split("\t", 1)
                p = p.split("\t")[-1]
                a, d = stats.get(p, ("0", "0"))
                files.append({"path": p, "status": st[0], "add": a, "del": d, "area": area_of(p)})
        areas = {}
        for f in files:
            ar = areas.setdefault(f["area"], {"name": f["area"], "files": 0, "add": 0, "del": 0})
            ar["files"] += 1
            ar["add"] += int(f["add"]) if f["add"].isdigit() else 0
            ar["del"] += int(f["del"]) if f["del"].isdigit() else 0
        is_current = name == cur
        overlap = [] if is_current else sorted(mine & {f["path"] for f in files})
        studio = []
        if any(f["area"] == "Rojo project (what syncs into Studio)" for f in files):
            studio.append("Changes what Rojo syncs into Studio (default.project.json / .meta.json): reconnect Rojo after switching.")
        if any(f["area"] == "Studio place files" for f in files):
            studio.append("Carries saved Studio place files (.rbxl): open them only as a reference; code comes from Rojo.")
        if any(f["path"].endswith(".rbxm") for f in files):
            studio.append("Carries Studio model files (.rbxm) that Rojo inserts into the game.")
        rows.append({
            "name": name, "ref": ref, "onRemote": on_remote, "current": is_current, "tip": tip[:10],
            "lastDate": commits[0]["date"] if commits else git("log", "-1", "--format=%aI", ref, check=False).strip(),
            "merged": merged, "ahead": int(ahead) if str(ahead).isdigit() else ahead,
            "behind": int(behind) if str(behind).isdigit() else behind,
            "title": (start or {}).get("featureTitle") or name, "featureId": (start or {}).get("featureId", ""),
            "initiator": {**label(initiator), "how": how}, "implementers": sorted(by_author.values(), key=lambda x: -x["commits"]),
            "commits": commits[:40], "commitCount": len(commits), "files": files, "areas": sorted(areas.values(), key=lambda x: -x["files"]),
            "overlapWithMe": overlap,
            "conflictsWithMe": None if is_current else merge_conflicts("HEAD", ref),
            "conflictsWithMain": merge_conflicts(BASE, ref) if base_ok and not merged else [],
            "green": bool(stamp_fp) and compat.fingerprint_rev(tip) == stamp_fp,
            "touchesGame": any(f["path"].startswith("src/") or f["path"] == "default.project.json" for f in files),
            "studio": studio, "notes": handoff_notes(ref, files), "compare": compare_url(name) if on_remote else "",
        })
    rows.sort(key=lambda r: (r["merged"], r["lastDate"] and -_ts(r["lastDate"])))
    people = {}
    for r in rows:
        if r["merged"]:
            continue
        for who in [r["initiator"]] + r["implementers"]:
            p = people.setdefault(who["name"], {**{k: who.get(k, "") for k in ("name", "github", "handle", "role")},
                "started": [], "working": [], "last": ""})
        people[r["initiator"]["name"]]["started"].append(r["name"])
        for imp in r["implementers"]:
            people[imp["name"]]["working"].append(r["name"])
        for who in [r["initiator"]] + r["implementers"]:
            people[who["name"]]["last"] = max(people[who["name"]]["last"], r["lastDate"] or "")
    value = {
        "me": label(me_), "current": cur, "base": BASE, "mainTip": main_sha[:10], "myFiles": len(mine),
        "repo": remote_web_url(), "branches": rows, "people": sorted(people.values(), key=lambda p: p["last"], reverse=True),
        "team": [label(m) for m in team()],
    }
    _cache.update(key=key, value=value)
    return value


def _ts(iso):
    import datetime
    try:
        return datetime.datetime.fromisoformat(iso).timestamp()
    except ValueError:
        return 0


# ---------------------------------------------------------------------------------------------------------------
# CLI


def print_overview(o):
    print(f"You: {o['me']['name']} on {o['current']}  ·  main = {o['base']} {o['mainTip']}  ·  {o['myFiles']} files in your work")
    for r in o["branches"]:
        if r["merged"]:
            continue
        who = r["initiator"]
        imp = ", ".join(f"{i['name']} ({i['commits']})" for i in r["implementers"]) or "none yet"
        print(f"\n{r['name']}{'  (you are here)' if r['current'] else ''}{'' if r['onRemote'] else '  [not pushed]'}")
        print(f"  {r['title']}")
        print(f"  initiated by {who['name']}{' @' + who['github'] if who['github'] else ''} ({who['how']}); commits by {imp}")
        print(f"  {r['ahead']} ahead / {r['behind']} behind main · last {r['lastDate'][:16]} · {'GREEN' if r['green'] else 'not compat-checked'}")
        print("  systems: " + ", ".join(f"{a['name']} ({a['files']})" for a in r["areas"]))
        if r["overlapWithMe"]:
            print("  overlaps your work: " + ", ".join(r["overlapWithMe"]))
        if r["conflictsWithMe"]:
            print("  CONFLICTS with your HEAD: " + ", ".join(r["conflictsWithMe"]))
        if r["conflictsWithMain"]:
            print("  CONFLICTS with main: " + ", ".join(r["conflictsWithMain"]))
        for s in r["studio"]:
            print("  studio: " + s)


def main(argv):
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("start")
    s.add_argument("title")
    s.add_argument("--detail", default="")
    s.add_argument("--todo", default=None, help="TODO item id to link (default: add one in Doing)")
    s.add_argument("--no-push", action="store_true")
    sub.add_parser("sync")
    sub.add_parser("push")
    o = sub.add_parser("overview")
    o.add_argument("--json", action="store_true")
    a = ap.parse_args(argv)
    try:
        if a.cmd == "start":
            info = start_feature(a.title, a.detail, a.todo, push=not a.no_push)
            link_todo(info, a.todo, a.detail)
            print(f"Branch {info['branch']} from {info['base']}, initiated by {info['initiatedBy']['name']}")
            print("Pushed to GitHub." if info["pushed"] else f"NOT pushed: {info['pushError'] or 'local only (--no-push)'}")
            print(f"Work on it: git switch {info['branch']}")
        elif a.cmd == "sync":
            fetch()
            print("Fetched origin.")
        elif a.cmd == "push":
            print(push_current()["output"])
        else:
            fetch_err = None
            try:
                fetch()
            except GitError as e:
                fetch_err = str(e)
            ov = overview()
            print(json.dumps(ov, indent=2)) if a.json else print_overview(ov)
            if fetch_err:
                print(f"\n(fetch failed, showing the last fetched state: {fetch_err})", file=sys.stderr)
    except GitError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
