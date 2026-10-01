#!/usr/bin/env python3
"""Compatibility gate for Claude Code (see tools/compat.py and .claude/commands/compat-check.md).

PreToolUse (Bash): blocks `git push` to main/master (explicit, or a bare push while on main) and `gh pr merge`
unless the current code has an ALL GREEN /compat-check stamp. The git pre-push hook (.githooks/pre-push) checks
the exact commit again.

Stop: when shipped code (src/, default.project.json) differs from the last green stamp, the turn may not end
silently: Claude is told once per stop to run /compat-check (or to say why it cannot, e.g. Studio is closed).
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.environ.get("CLAUDE_PROJECT_DIR") or os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def compat_green():
    r = subprocess.run(
        [sys.executable, os.path.join(ROOT, "tools", "compat.py"), "status"], cwd=ROOT, capture_output=True, text=True
    )
    return r.returncode == 0, (r.stdout or r.stderr).strip()


def current_branch():
    r = subprocess.run(["git", "branch", "--show-current"], cwd=ROOT, capture_output=True, text=True)
    return r.stdout.strip()


def strip_data(cmd):
    """Drop heredoc bodies and quoted strings: text that merely mentions `git push` is not a push."""
    kept = []
    for line in cmd.splitlines():
        kept.append(line)
        if "<<" in line:
            break
    text = "\n".join(kept)
    text = re.sub(r"'[^']*'", "''", text)
    return re.sub(r'"(?:\\.|[^"\\])*"', '""', text)


def targets_main(cmd):
    cmd = strip_data(cmd)
    if re.search(r"\bgh\s+pr\s+merge\b", cmd):
        return True
    for m in re.finditer(r"\bgit\s+(?:-C\s+\S+\s+)?push\b([^;&|]*)", cmd):
        args = m.group(1)
        if re.search(r"(?:^|[\s:/+])(?:refs/heads/)?(main|master)\b", args) or "--all" in args or "--mirror" in args:
            return True
        positional = [a for a in args.split() if not a.startswith("-")]
        if len(positional) <= 1 and current_branch() in ("main", "master"):
            return True
    return False


def main():
    try:
        data = json.load(sys.stdin)
    except Exception:
        return 0
    event = data.get("hook_event_name")

    if event == "PreToolUse":
        cmd = (data.get("tool_input") or {}).get("command", "")
        if not targets_main(cmd):
            return 0
        ok, msg = compat_green()
        if ok:
            return 0
        print(
            json.dumps(
                {
                    "hookSpecificOutput": {
                        "hookEventName": "PreToolUse",
                        "permissionDecision": "deny",
                        "permissionDecisionReason": msg
                        + ". Pushing/merging to main requires an ALL GREEN /compat-check for exactly this code "
                        "(harness, ui, multiplayer, world). Run /compat-check first.",
                    }
                }
            )
        )
        return 0

    if event == "Stop":
        if data.get("stop_hook_active"):
            return 0  # already reminded this stop: never loop
        ok, _ = compat_green()
        if ok:
            return 0
        r = subprocess.run(
            ["git", "status", "--porcelain", "--", "src", "default.project.json"], cwd=ROOT, capture_output=True, text=True
        )
        if not r.stdout.strip():
            return 0  # shipped code unchanged since the last commit: nothing new to check this turn
        # Remind once per distinct state of src/: a turn that did not change it is not nagged again
        fp = subprocess.run(
            [sys.executable, os.path.join(ROOT, "tools", "compat.py"), "fingerprint"], cwd=ROOT, capture_output=True, text=True
        ).stdout.strip()
        seen = os.path.join(ROOT, ".compat", "last_reminded")
        try:
            with open(seen) as f:
                if f.read().strip() == fp:
                    return 0
        except OSError:
            pass
        os.makedirs(os.path.dirname(seen), exist_ok=True)
        with open(seen, "w") as f:
            f.write(fp)
        print(
            json.dumps(
                {
                    "decision": "block",
                    "reason": "Shipped code (src/) changed and has no ALL GREEN compatibility run. Run /compat-check "
                    "(harness + ui-tester + multiplayer-tester + world-tester) until it is green, or tell the user "
                    "why it cannot run now (e.g. Studio closed) and that the code is NOT cleared for main.",
                }
            )
        )
    return 0


if __name__ == "__main__":
    sys.exit(main())
