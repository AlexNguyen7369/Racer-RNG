// Agent dashboard client: polls the local server (tools/dashboard/server.py) and renders each tab.
"use strict";

const AGENTS = ["main", "claude", "codex", "test-writer", "ui-test-writer", "physics-tester", "ui-tester", "multiplayer-tester",
  "world-tester", "regression-tester", "physics-tuner", "track-designer"];
const STATUS_COLS = [["doing", "Doing"], ["next", "Up next"], ["backlog", "Backlog"], ["done", "Done"]];

const $ = (id) => document.getElementById(id);
const state = { session: "", agent: null, tab: "agents", canWrite: true, local: true, last: {}, open: new Set() };

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function colorVar(type) {
  return AGENTS.includes(type) ? `var(--a-${type})` : "var(--a-other)";
}
const AGENT_NAME = { claude: "Claude", codex: "Codex", user: "You", all: "both" };
// "Claude · Opus 5.5 · physics-tuner": which agent, which model, which role (subagent) made a change
function agentChip(a) {
  const role = a.role && !["main", a.agent].includes(a.role) ? ` · ${a.role}` : "";
  return `<span class="achip" style="--c:${colorVar(a.agent)}" title="${esc(a.ts ? `last edit ${when(a.ts)}` : "")}">${esc(AGENT_NAME[a.agent] || a.agent)}${a.model ? ` · ${esc(a.model)}` : ""}${esc(role)}</span>`;
}
function agentChips(list, none = "") {
  return `<span class="achips">${(list || []).length ? list.map(agentChip).join("") : none ? `<span class="achip none" title="No agent log touched it: a person, or an agent edit made through a shell command">${none}</span>` : ""}</span>`;
}
function when(ts) {
  if (!ts) return "";
  const d = new Date(ts);
  return d.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}
function ago(ts) {
  if (!ts) return "";
  const s = Math.max(0, (Date.now() - new Date(ts).getTime()) / 1000);
  if (s < 60) return `${Math.round(s)}s ago`;
  if (s < 3600) return `${Math.round(s / 60)}m ago`;
  if (s < 86400) return `${Math.round(s / 3600)}h ago`;
  return `${Math.round(s / 86400)}d ago`;
}
function duration(a, b) {
  if (!a || !b) return "";
  const s = (new Date(b) - new Date(a)) / 1000;
  return s < 60 ? `${Math.round(s)}s` : `${Math.floor(s / 60)}m ${Math.round(s % 60)}s`;
}
function toast(msg) {
  const t = $("toast");
  t.textContent = msg;
  t.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (t.hidden = true), 2500);
}
function statusBadge(status, verdict) {
  if (status === "running") return `<span class="badge running">running</span>`;
  if (verdict === "pass") return `<span class="badge pass">passed</span>`;
  if (verdict === "fail") return `<span class="badge fail">failed</span>`;
  if (status === "stopped") return `<span class="badge stale">stopped</span>`;
  return `<span class="badge">done</span>`;
}

async function api(path, body) {
  const sep = path.includes("?") ? "&" : "?";
  const url = body || !state.session ? path : `${path}${sep}session=${state.session}`;
  const r = await fetch(url, body ? { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(body) } : {});
  const j = await r.json();
  if (!r.ok) throw new Error(j.error || r.statusText);
  return j;
}
// Re-render only when the data changed, so open dropdowns and scroll positions survive the polling.
function changed(key, data) {
  const s = JSON.stringify(data);
  if (state.last[key] === s) return false;
  state.last[key] = s;
  return true;
}
function keepOpen(root) {
  root.querySelectorAll("details[data-key]").forEach((d) => {
    if (state.open.has(d.dataset.key)) d.open = true;
    d.addEventListener("toggle", () => (d.open ? state.open.add(d.dataset.key) : state.open.delete(d.dataset.key)));
  });
}
function fail(el, e) {
  el.innerHTML = `<p class="err">${esc(e.message || e)}</p>`;
}

// ------------------------------------------------------------------------------------------------ header + gate

async function loadMeta() {
  const m = await api("/api/meta");
  state.canWrite = m.canWrite;
  state.local = m.local;
  $("team-actions").hidden = $("feature-form").hidden = !m.local;
  $("who").textContent = `${m.developer}${m.canWrite ? "" : " · read-only"}`;
  $("todo-form").hidden = !m.canWrite;
  $("bus-form").hidden = !m.canWrite;
  if (!state.session) state.session = m.session;
  if (changed("sessions", m.sessions)) {
    $("session").innerHTML = m.sessions.map((s) =>
      `<option value="${esc(s.id)}">${esc(s.source === "codex" ? "Codex" : "Claude")}${s.model ? ` (${esc(s.model)})` : ""} · ${esc(s.title || s.id.slice(0, 8))} · ${s.agents} agents · ${ago(s.updated * 1000)}</option>`).join("");
    $("session").value = state.session;
  }
}

async function loadGate() {
  const g = await api("/api/gate");
  if (!changed("gate", g)) return;
  $("gate").className = `gate ${g.verdict}`;
  $("gate-text").textContent = g.text;
  $("gate").title = `branch ${g.branch} · ${g.aheadOfMain} commits ahead of origin/main · last green ${g.stampAt || "never"} (${g.stampHead})`;
  $("suites").innerHTML = g.suites.map((s) =>
    `<span class="badge ${s.pass === true ? "pass" : s.pass === false ? "fail" : ""}" title="${esc(s.summary)}">${esc(s.name)}</span>`).join("") +
    `<span class="badge">${esc(g.branch)} · ${esc(g.aheadOfMain)} ahead of main</span>`;
}

// The handoff is Markdown kept in the repository. Render the small, deliberately
// limited format used by handoff.md without adding a client-side dependency.
async function loadHandoff() {
  const d = await api("/api/handoff");
  if (!changed("handoff", d)) return;
  $("handoff-updated").textContent = d.updated ? `updated ${when(d.updated)}` : "not found";
  const lines = d.content.split(/\r?\n/), out = [];
  let list = false;
  const closeList = () => { if (list) { out.push("</ul>"); list = false; } };
  for (const line of lines) {
    if (/^### /.test(line)) { closeList(); out.push(`<h4>${esc(line.slice(4))}</h4>`); }
    else if (/^## /.test(line)) { closeList(); out.push(`<h3>${esc(line.slice(3))}</h3>`); }
    else if (/^# /.test(line)) { closeList(); out.push(`<h2>${esc(line.slice(2))}</h2>`); }
    else if (/^- /.test(line)) { if (!list) { out.push("<ul>"); list = true; } out.push(`<li>${esc(line.slice(2))}</li>`); }
    else if (!line.trim()) { closeList(); }
    else { closeList(); out.push(`<p>${esc(line)}</p>`); }
  }
  closeList();
  $("handoff").innerHTML = out.join("");
}

// ------------------------------------------------------------------------------------------------ agents tab

function renderLegend() {
  $("legend").innerHTML = AGENTS.map((a) => `<span style="--c:${colorVar(a)}">${a}</span>`).join("") +
    `<span style="--c:var(--a-other)">other</span>`;
}

async function loadAgents() {
  const list = await api("/api/agents");
  $("agent-count").textContent = `${list.filter((a) => a.status === "running").length} running · ${list.length} total`;
  if (!changed("agents", list)) return;
  $("agents").innerHTML = list.length ? list.map((a) => `
    <div class="agent ${state.agent === a.id ? "sel" : ""}" data-id="${esc(a.id)}" style="--c:${colorVar(a.type)}">
      <div class="row"><span class="type">${esc(a.type)}</span>${statusBadge(a.status, a.verdict)}</div>
      <div class="small">${agentChip({ agent: a.source || "claude", model: a.model, role: "main" })}</div>
      <div class="desc">${esc(a.description)}</div>
      <div class="row small muted"><span>${when(a.start)}</span><span>${duration(a.start, a.end)} · ${a.steps} steps</span></div>
      ${a.status === "running" ? `<div class="last">${esc(a.lastTool)}</div>` : ""}
    </div>`).join("") : `<p class="muted">No subagents in this session yet. Pick an earlier session in the Session menu to see past runs.</p>`;
  $("agents").querySelectorAll(".agent").forEach((el) => el.addEventListener("click", () => selectAgent(el.dataset.id)));
}

// ------------------------------------------------------------------------------------------------ Claude <-> Codex bus

function presenceHtml(name, p, st) {
  const c = colorVar(name);
  const said = st && st.task ? `<p class="said small"><b>Says:</b> ${esc(st.task)}${st.files && st.files.length ? ` · <span class="muted">${st.files.map(esc).join(", ")}</span>` : ""}${st.note ? `<br>${esc(st.note)}` : ""} <span class="muted">${ago(st.updated)}</span></p>` : "";
  if (!p) return `<div class="presence" style="--c:${c}"><div class="row"><span class="name">${AGENT_NAME[name]}</span><span class="badge">no sessions here</span></div>${said}</div>`;
  return `<div class="presence" style="--c:${c}">
    <div class="row"><span class="name">${AGENT_NAME[name]}${p.model ? ` · ${esc(p.model)}` : ""}</span>${statusBadge(p.status)}</div>
    <div class="small muted">${esc(p.title || p.session.slice(0, 14))} · active ${ago(p.updated * 1000)}${p.subagents ? ` · ${p.subagents} subagents running` : ""}</div>
    ${said}
    ${p.prompt ? `<p class="small clamp" title="${esc(p.prompt)}"><b>Task:</b> ${esc(p.prompt)}</p>` : ""}
    ${p.status === "running" && p.lastTool ? `<p class="small muted clamp">⚙ ${esc(p.lastTool)}</p>` : p.report ? `<p class="small muted clamp" title="${esc(p.report)}"><b>Latest:</b> ${esc(p.report)}</p>` : ""}
    <p class="small"><b>Uncommitted files it changed:</b> ${p.files.length ? p.files.map((f) => `<code>${esc(f)}</code>`).join(" ") : `<span class="muted">none</span>`}</p>
  </div>`;
}

function busMsgHtml(m, byId) {
  const parent = m.re && byId[m.re];
  return `<div class="msg" style="--c:${colorVar(m.from === "user" ? "other" : m.from)}">
    <div class="meta"><b>${esc(AGENT_NAME[m.from] || m.from)}${m.model ? ` · ${esc(m.model)}` : ""}</b><span class="arrow">→</span>
      <span class="to" style="--t:${colorVar(m.to)}">${esc(AGENT_NAME[m.to] || m.to)}</span>
      ${parent ? `<span class="small" title="${esc(parent.text)}">re ${esc(AGENT_NAME[parent.from] || parent.from)}: ${esc(parent.text.slice(0, 50))}</span>` : ""}
      <span>${when(m.ts)}</span><span class="muted">#${esc(m.id)}</span></div>
    <div class="body">${esc(m.text)}</div></div>`;
}

async function loadBus() {
  const b = await api("/api/bus");
  if (!changed("bus", b)) return;
  $("presence").innerHTML = ["claude", "codex"].map((a) => presenceHtml(a, b.presence[a], b.status[a])).join("");
  $("bus-unread").textContent = `unread: Claude ${b.unread.claude} · Codex ${b.unread.codex}`;
  const el = $("thread");
  const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 40;
  const byId = Object.fromEntries(b.messages.map((m) => [m.id, m]));
  el.innerHTML = b.messages.length ? b.messages.map((m) => busMsgHtml(m, byId)).join("")
    : `<p class="muted small">No messages yet. Agents send with <code>python3 tools/dashboard/agent_bus.py send --from claude --to codex "…"</code>; Claude gets new ones automatically at its next prompt, Codex when it runs <code>agent_bus.py context --agent codex</code>.</p>`;
  if (atBottom || state.busJump) el.scrollTop = el.scrollHeight;
  state.busJump = false;
}

function msgHtml(m) {
  const kind = m.kind;
  const from = m.from || "main";
  if (kind === "tool") {
    return `<div class="msg tool" style="--c:${colorVar(from)}"><div class="body">⚙ <b>${esc(m.name)}</b> ${esc(m.text)}</div></div>`;
  }
  if (kind === "result") {
    return `<details class="msg result ${m.error ? "err" : ""}" style="--c:${colorVar(from)}"><summary class="muted">result${m.error ? " (error)" : ""}</summary><div class="body">${esc(m.text)}</div></details>`;
  }
  const label = { spawn: "started", send: "message", reply: "reply", report: "report", prompt: "task", say: "" }[kind] ?? kind;
  const to = m.to ? `<span class="arrow">→</span><span class="to" style="--t:${colorVar(m.to)}">${esc(m.to)}</span>` : "";
  const verdict = m.verdict ? `<span class="badge ${m.verdict}">${m.verdict === "pass" ? "passed" : "failed"}</span>` : "";
  const long = (m.text || "").length > 400 && kind !== "report";
  return `<div class="msg ${long ? "collapsed" : ""}" style="--c:${colorVar(from)}">
    <div class="meta"><b>${esc(from)}</b>${to}<span class="badge">${esc(label)}</span>${verdict}
      ${m.title ? `<span>${esc(m.title)}</span>` : ""}<span>${when(m.ts)}</span></div>
    <div class="body">${esc(m.text)}</div></div>`;
}

async function loadTimeline() {
  const el = $("timeline");
  const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 40;
  let items, title;
  if (state.agent) {
    const t = await api(`/api/agent/${state.agent}`);
    items = t.items;
    title = `${t.type}: ${t.description || ""}`;
  } else {
    items = await api("/api/messages");
    title = "Messages between agents";
  }
  $("timeline-title").textContent = title;
  $("show-all").hidden = !state.agent;
  if (!changed("timeline", [state.agent, items])) return;
  el.innerHTML = items.length ? items.map(msgHtml).join("") : `<p class="muted">Nothing yet.</p>`;
  el.querySelectorAll(".msg.collapsed").forEach((m) => m.addEventListener("click", () => m.classList.toggle("collapsed")));
  if (atBottom || state.jump) el.scrollTop = el.scrollHeight;
  state.jump = false;
}

function selectAgent(id) {
  state.agent = id;
  state.jump = true;
  document.querySelectorAll(".agent").forEach((a) => a.classList.toggle("sel", a.dataset.id === id));
  loadTimeline().catch((e) => fail($("timeline"), e));
}

async function loadNeedToKnow() {
  const n = await api("/api/needtoknow");
  if (!changed("ntk", n)) return;
  const sect = (h, body, cls = "") => (body ? `<div class="${cls}"><h3>${h}</h3><pre>${esc(body)}</pre></div>` : "");
  $("ntk").className = "ntk";
  $("ntk").innerHTML =
    sect("Urgent", n.urgent, "urgent") +
    sect("What's next", n.next.replace(/^## What's next\s*/, "")) +
    sect("Known issues / not verified", n.known.replace(/^KNOWN ISSUES.*\n/, "")) +
    (n.completed.length ? `<h3>Recently completed</h3><pre>${esc(n.completed.slice(0, 5).join("\n\n"))}</pre>` : "") +
    `<p class="small muted">From context/ProjectContext.luau (updated ${esc(n.updated)}) and current_progress.md</p>`;
}

// ------------------------------------------------------------------------------------------------ changes + history

function diffHtml(text) {
  return text.split("\n").map((l) => {
    const c = l.startsWith("+") && !l.startsWith("+++") ? "a" : l.startsWith("-") && !l.startsWith("---") ? "d" : l.startsWith("@@") ? "h" : "";
    return c ? `<span class="${c}">${esc(l)}</span>` : esc(l) + "\n";
  }).join("");
}

async function loadChanges() {
  const list = await api("/api/changes");
  $("change-count").textContent = `${list.length} files`;
  if (!changed("changes", list)) return;
  const label = { M: "modified", A: "added", D: "deleted", R: "renamed", "??": "new" };
  $("changes").innerHTML = list.length ? list.map((c) => `
    <div class="file" data-path="${esc(c.path)}" title="${esc(c.path)}">
      <span class="badge">${esc(label[c.status] || c.status)}</span><span class="path">${esc(c.path)}</span>${agentChips(c.agents, "no agent")}
      <span class="plus">+${c.add}</span><span class="minus">-${c.del}</span></div>`).join("") : `<p class="muted">Working tree is clean.</p>`;
  $("changes").querySelectorAll(".file").forEach((el) => el.addEventListener("click", async () => {
    document.querySelectorAll(".file").forEach((f) => f.classList.toggle("sel", f === el));
    $("diff-title").textContent = el.dataset.path;
    try {
      const d = await api(`/api/diff?path=${encodeURIComponent(el.dataset.path)}`);
      $("diff").className = "diff";
      $("diff").innerHTML = diffHtml(d.diff || "(no textual diff)");
    } catch (e) { fail($("diff"), e); }
  }));
}

async function loadHistory() {
  const q = new URLSearchParams({ limit: "80" });
  if ($("f-author").value) q.set("author", $("f-author").value);
  if ($("f-branch").value) q.set("branch", $("f-branch").value);
  const h = await api(`/api/history?${q}`);
  if (changed("filters", [h.authors, h.branches])) {
    const fill = (sel, first, opts) => {
      const v = sel.value;
      sel.innerHTML = `<option value="">${first}</option>` + opts.map((o) => `<option>${esc(o)}</option>`).join("");
      sel.value = v;
    };
    fill($("f-author"), "All developers", h.authors);
    fill($("f-branch"), "All branches", h.branches);
  }
  const fa = $("f-agent").value;
  const commits = h.commits.filter((c) => !fa || (fa === "none" ? !c.agents.length : c.agents.some((a) => a.agent === fa)));
  if (!changed("history", commits)) return;
  $("history").innerHTML = commits.map((c) => {
    const add = c.files.reduce((n, f) => n + (+f.add || 0), 0);
    const del = c.files.reduce((n, f) => n + (+f.del || 0), 0);
    return `<div class="commit" data-sha="${esc(c.sha)}">
      <span class="sha">${esc(c.short)}</span><span class="subj">${esc(c.subject)}</span>
      <span class="when">${esc(new Date(c.date).toLocaleString())}</span>
      <div class="sub"><span class="who" style="--c:var(--a-other)">${esc(c.author)}</span>${agentChips(c.agents)}
        ${c.green ? `<span class="badge pass">green</span>` : ""}${c.pushed ? "" : `<span class="badge">local</span>`}
        ${c.refs ? `<span class="badge">${esc(c.refs)}</span>` : ""}
        <span>${c.files.length} files</span><span class="plus">+${add}</span><span class="minus">-${del}</span></div></div>`;
  }).join("") || `<p class="muted">No commits match.</p>`;
  $("history").querySelectorAll(".commit").forEach((el) => el.addEventListener("click", async () => {
    $("diff-title").textContent = `commit ${el.dataset.sha.slice(0, 10)}`;
    try {
      const d = await api(`/api/commit/${el.dataset.sha}`);
      $("diff").className = "diff";
      $("diff").innerHTML = diffHtml(d.diff);
      $("diff").scrollIntoView({ behavior: "smooth", block: "nearest" });
    } catch (e) { fail($("diff"), e); }
  }));
}

// ------------------------------------------------------------------------------------------------ TODO + suggestions

async function todo(body) {
  try {
    const r = await api("/api/todo", body);
    if (r.started) toast(`Started ${r.started.branch}${r.started.pushed ? " on GitHub" : " (local only: " + (r.started.pushError || "not pushed") + ")"}`);
    else if (r.branchError) toast(`No branch: ${r.branchError}`);
    await loadTodo();
  } catch (e) { toast(e.message); }
}

async function loadTodo() {
  const t = await api("/api/todo");
  if (!changed("todo", t)) return;
  const moves = (i) => STATUS_COLS.filter(([s]) => s !== i.status)
    .map(([s, l]) => `<button data-move="${s}" data-id="${esc(i.id)}">${l}</button>`).join("");
  $("board").innerHTML = STATUS_COLS.map(([s, label]) => {
    const items = t.items.filter((i) => i.status === s);
    return `<div class="col ${s}"><h3>${label}<span class="muted">${items.length}</span></h3>${items.map((i) => `
      <div class="card" data-id="${esc(i.id)}">
        <div class="title">${esc(i.title)}</div>
        ${i.branch ? `<div class="tags"><span class="badge owner" title="Initiated by">${esc(i.owner || i.by || "")}${i.ownerGithub ? ` · @${esc(i.ownerGithub)}` : ""}</span><span class="badge branch" title="Feature branch">${esc(i.branch)}</span></div>` : ""}
        ${i.detail ? `<div class="detail">${esc(i.detail)}</div>` : ""}
        <div class="foot"><span>${esc(i.by || "")}${i.done ? ` · done ${when(i.done)}` : ""}</span><span class="sp"></span>
          ${state.local && !i.branch && i.status !== "done" ? `<button data-branch="${esc(i.id)}" title="Start a labelled feature branch for this task">Branch</button>` : ""}
          ${state.canWrite ? moves(i) + `<button data-del="${esc(i.id)}" title="Delete">✕</button>` : ""}</div>
      </div>`).join("")}</div>`;
  }).join("");
  $("board").querySelectorAll(".card .title").forEach((el) => el.addEventListener("click", () => el.parentElement.classList.toggle("open")));
  $("board").querySelectorAll("[data-move]").forEach((b) => b.addEventListener("click", () => todo({ action: "move", id: b.dataset.id, status: b.dataset.move })));
  $("board").querySelectorAll("[data-branch]").forEach((b) => b.addEventListener("click", () => teamAction("start", { todo: b.dataset.branch })));
  $("board").querySelectorAll("[data-del]").forEach((b) => b.addEventListener("click", () => {
    if (confirm("Delete this task?")) todo({ action: "delete", id: b.dataset.del });
  }));
}

function suggestionHtml(s) {
  const decided = s.status !== "open";
  const actions = !state.canWrite ? "" : decided
    ? `<button data-s="${esc(s.id)}" data-a="reopen">Reopen</button>`
    : `<button class="primary" data-s="${esc(s.id)}" data-a="add">Add to TODO</button><button data-s="${esc(s.id)}" data-a="dismiss">Not now</button>`;
  return `<details class="sugg" data-key="s-${esc(s.id)}">
    <summary><span class="t">${esc(s.title)}</span><span class="badge">effort ${esc(s.effort || "?")}</span>
      ${s.status === "added" ? `<span class="badge pass">added</span>` : s.status === "dismissed" ? `<span class="badge">dismissed</span>` : ""}</summary>
    <div class="inner"><dl>
      <dt>What</dt><dd>${esc(s.description)}</dd>
      <dt>Why it fits</dt><dd>${esc(s.fit)}</dd>
      <dt>Inspired by</dt><dd>${esc(s.inspiredBy)}</dd>
      ${s.dependsOn ? `<dt>Depends on</dt><dd>${esc(s.dependsOn)}</dd>` : ""}
      ${s.decidedBy ? `<dt>Decided</dt><dd>${esc(s.decidedBy)} · ${when(s.decidedAt)}</dd>` : ""}
    </dl><div class="actions">${actions}</div></div></details>`;
}

async function loadSuggestions() {
  const d = await api("/api/suggestions");
  if (!changed("sugg", d)) return;
  $("sugg-note").textContent = d.researched ? `trend research ${d.researched} · /refresh-suggestions to update` : "";
  $("suggestions").innerHTML = d.items.filter((s) => s.status === "open").map(suggestionHtml).join("") || `<p class="muted">No open suggestions.</p>`;
  $("suggestions-closed").innerHTML = d.items.filter((s) => s.status !== "open").map(suggestionHtml).join("") || `<p class="muted small">None.</p>`;
  document.querySelectorAll("#tab-todo [data-a]").forEach((b) => b.addEventListener("click", async () => {
    try {
      await api(`/api/suggestions/${b.dataset.s}`, { action: b.dataset.a });
      toast(b.dataset.a === "add" ? "Added to the TODO backlog" : b.dataset.a === "dismiss" ? "Dismissed" : "Reopened");
      await Promise.all([loadSuggestions(), loadTodo()]);
    } catch (e) { toast(e.message); }
  }));
  keepOpen($("tab-todo"));
}

// ------------------------------------------------------------------------------------------------ team + branches

async function teamAction(action, body = {}) {
  const labels = { sync: "Fetching from GitHub…", push: "Pushing…", start: "Creating the branch…", switch: "Switching…" };
  toast(labels[action]);
  try {
    const r = await api(`/api/team/${action}`, body);
    if (action === "start") {
      const s = r.started;
      toast(`${s.branch} started by ${s.initiatedBy.name}${s.pushed ? ", pushed to GitHub" : " (local only: " + (s.pushError || "not pushed") + ")"}`);
    } else if (action === "push") toast(`Pushed ${r.branch}`);
    else if (action === "switch") toast(`Now on ${r.branch}: Rojo syncs it into Studio`);
    else toast("Up to date with GitHub");
    state.last.team = state.last.todo = null;
    await Promise.all([loadTeam(), state.tab === "todo" ? loadTodo() : null]);
  } catch (e) { toast(e.message); }
}

function person(p) {
  return `<div class="person"><div class="pname">${esc(p.name)}${p.github ? ` <span class="muted">@${esc(p.github)}</span>` : ""}</div>
    ${p.role ? `<div class="small muted">${esc(p.role)}</div>` : ""}
    <div class="small">started ${p.started.length} · committing on ${p.working.length} · active ${ago(p.last)}</div></div>`;
}

function fileList(files) {
  const st = { A: "new", M: "mod", D: "del", R: "ren" };
  return files.map((f) => `<div class="bfile"><span class="badge">${st[f.status] || f.status}</span><span class="path">${esc(f.path)}</span>
    <span class="small muted">${esc(f.area)}</span><span class="plus">+${esc(f.add)}</span><span class="minus">-${esc(f.del)}</span></div>`).join("");
}

function branchHtml(b) {
  const who = b.initiator;
  const imp = b.implementers.map((i) => `${esc(i.name)} (${i.commits})`).join(", ") || "no commits yet";
  const conflicts = (list, whom) => list && list.length
    ? `<div class="warn fail">Merge conflicts with ${whom}: ${list.map(esc).join(", ")}</div>` : "";
  const badges = [
    b.current ? `<span class="badge running">you are here</span>` : "",
    b.merged ? `<span class="badge pass">merged</span>` : "",
    b.onRemote ? "" : `<span class="badge stale">not pushed</span>`,
    b.green ? `<span class="badge pass">compat green</span>` : b.touchesGame && !b.merged ? `<span class="badge">not compat-checked</span>` : "",
  ].join("");
  const actions = !state.local ? "" : `${b.current ? "" : `<button data-switch="${esc(b.name)}">Switch to it</button>`}`;
  return `<details class="branch" data-key="b-${esc(b.name)}">
    <summary>
      <div class="bhead"><span class="btitle">${esc(b.title)}</span>${badges}</div>
      <div class="bmeta"><span class="who" style="--c:var(--a-other)">Started by <b>${esc(who.name)}</b>${who.github ? ` @${esc(who.github)}` : ""}</span>
        <code>${esc(b.name)}</code><span>${b.ahead} ahead · ${b.behind} behind main</span><span>last ${ago(b.lastDate)}</span></div>
      <div class="chips">${b.areas.map((a) => `<span class="chip" title="+${a.add} -${a.del}">${esc(a.name)} <b>${a.files}</b></span>`).join("")}</div>
      ${b.overlapWithMe.length ? `<div class="warn stale">Also changed in your work: ${b.overlapWithMe.map(esc).join(", ")}</div>` : ""}
      ${conflicts(b.conflictsWithMe, "your branch")}${conflicts(b.conflictsWithMain, "main")}
      ${b.studio.map((s) => `<div class="warn">${esc(s)}</div>`).join("")}
    </summary>
    <div class="inner">
      <p><b>Started by:</b> ${esc(who.name)}${who.role ? ` (${esc(who.role)})` : ""} <span class="muted small">from the ${esc(who.how)}</span><br>
        <b>Commits by:</b> ${imp}</p>
      <div class="actions">${actions}${b.compare ? `<a class="btn" href="${esc(b.compare)}" target="_blank" rel="noopener">Compare / open PR on GitHub</a>` : ""}</div>
      ${b.notes.map((n) => `<h4>${esc(n.path)}</h4><pre class="note">${esc(n.text)}</pre>`).join("")}
      <h4>Commits (${b.commitCount})</h4>
      ${b.commits.map((c) => `<div class="bcommit"><span class="sha">${esc(c.short)}</span><span>${esc(c.subject)}</span><span class="small muted">${esc(c.author)} · ${when(c.date)}</span></div>`).join("")}
      <h4>Files (${b.files.length})</h4>${fileList(b.files)}
    </div></details>`;
}

async function loadTeam() {
  const t = await api("/api/team");
  const open = t.branches.filter((b) => !b.merged);
  const others = open.filter((b) => !b.current && b.initiator.name !== t.me.name).length;
  $("team-count").hidden = others === 0;
  $("team-count").textContent = others;
  if (!changed("team", t)) return;
  $("team-note").innerHTML = `${esc(t.me.name)} on <code>${esc(t.current)}</code> · ${t.fetch.error ? `<span class="minus">fetch failed: ${esc(t.fetch.error)}</span>` : t.fetch.at ? `synced ${ago(t.fetch.at)}` : "not synced yet"}` +
    (t.repo ? ` · <a href="${esc(t.repo)}" target="_blank" rel="noopener">GitHub repo</a>` : "");
  $("people").innerHTML = t.people.map(person).join("");
  $("branches").innerHTML = open.map(branchHtml).join("") || `<p class="muted">Every branch is merged into main.</p>`;
  $("branches-merged").innerHTML = t.branches.filter((b) => b.merged).map(branchHtml).join("") || `<p class="muted small">None.</p>`;
  $("tab-team").querySelectorAll("[data-switch]").forEach((b) => b.addEventListener("click", (e) => {
    e.preventDefault();
    if (confirm(`Switch your working tree to ${b.dataset.switch}? Rojo will sync that branch into Studio.`)) teamAction("switch", { branch: b.dataset.switch });
  }));
  keepOpen($("tab-team"));
}

// ------------------------------------------------------------------------------------------------ needs you

// `code` spans in a task's text become <code> (click copies it).
function richText(t) {
  return esc(t).replace(/`([^`]+)`/g, "<code title=\"Click to copy\">$1</code>");
}

function taskHtml(m) {
  const done = m.status === "done";
  const action = m.persistent ? `<span class="muted">Reference setup · keep this checklist available</span>` : !state.canWrite ? "" : done
    ? `<button data-m="${esc(m.id)}" data-ma="reopen">Reopen</button>`
    : `<button class="primary" data-m="${esc(m.id)}" data-ma="done">Mark done</button>`;
  return `<div class="task ${esc(m.priority || "")} ${m.persistent ? "manual-reference" : ""}">
    <div class="head"><span class="t">${esc(m.title)}</span><span class="badge">${esc(m.priority || "")} priority</span></div>
    <p><b>Why:</b> ${richText(m.why)}</p>
    ${m.blocks ? `<p><b>Unblocks:</b> ${richText(m.blocks)}</p>` : ""}
    ${m.when ? `<p><b>When:</b> ${richText(m.when)}</p>` : ""}
    <ol>${(m.steps || []).map((st) => `<li>${richText(st)}</li>`).join("")}</ol>
    <div class="actions">${action}<span>${done ? `done by ${esc(m.doneBy || "")} ${when(m.doneAt)}` : `added by ${esc(m.by || "")} ${when(m.added)}`}</span></div>
  </div>`;
}

const PRIORITY = { high: 0, medium: 1, low: 2 };

async function loadManualCount() {
  const d = await api("/api/manual");
  const open = d.items.filter((m) => m.status !== "done" && !m.persistent);
  $("manual-count").hidden = open.length === 0;
  $("manual-count").textContent = open.length;
  $("needs").hidden = open.length === 0;
  $("needs").textContent = `${open.length} task${open.length === 1 ? "" : "s"} need${open.length === 1 ? "s" : ""} you`;
  return d;
}

async function loadManual() {
  const d = await loadManualCount();
  if (!changed("manual", d)) return;
  const byPriority = (a, b) => (PRIORITY[a.priority] ?? 3) - (PRIORITY[b.priority] ?? 3);
  const configs = d.items.filter((m) => m.category === "config").sort(byPriority);
  const open = d.items.filter((m) => m.status !== "done" && m.category !== "config").sort(byPriority);
  $("manual").innerHTML = (configs.length ? `<div class="manual-section"><h3 class="manual-section-title">Configs &amp; setup</h3><p class="muted small">Persistent onboarding guidance for a new developer or LLM. Check the commands on the current machine before starting work.</p>${configs.map(taskHtml).join("")}</div>` : "") +
    (open.length ? `<div class="manual-section"><h3 class="manual-section-title">Manual tasks</h3>${open.map(taskHtml).join("")}</div>` : `<p class="muted">Nothing needs you right now.</p>`);
  $("manual-done").innerHTML = d.items.filter((m) => m.status === "done" && m.category !== "config").map(taskHtml).join("") || `<p class="muted small">None yet.</p>`;
  document.querySelectorAll("#tab-manual [data-ma]").forEach((b) => b.addEventListener("click", async () => {
    try {
      await api(`/api/manual/${b.dataset.m}`, { action: b.dataset.ma });
      toast(b.dataset.ma === "done" ? "Marked done: tell your agent so it can pick it up" : "Reopened");
      state.last.manual = null;
      await loadManual();
    } catch (e) { toast(e.message); }
  }));
  document.querySelectorAll("#tab-manual code").forEach((c) => c.addEventListener("click", () => {
    navigator.clipboard?.writeText(c.textContent).then(() => toast("Copied"), () => {});
  }));
}

// ------------------------------------------------------------------------------------------------ tests

async function loadTests() {
  const t = await api("/api/tests");
  if (!changed("tests", t)) return;
  $("guide").innerHTML = t.guide.map((g) => `<li>${esc(g)}</li>`).join("");
  $("latest").innerHTML = Object.entries(t.latest).map(([k, v]) => `
    <div class="suite ${v.verdict || ""}"><b>${esc(k)}</b> ${v.end ? `<code>${esc(v.end)}</code>` : ""}
      <div class="s">${when(v.at)} · ${esc(v.summary)}</div></div>`).join("") || `<p class="muted">No tester reports found.</p>`;
  $("compat").innerHTML = t.compat.map((s) => `
    <div class="suite ${s.pass === true ? "pass" : s.pass === false ? "fail" : ""}"><b>${esc(s.name)}</b>
      ${s.pass === true ? `<span class="badge pass">green</span>` : s.pass === false ? `<span class="badge fail">red</span>` : `<span class="badge">not run</span>`}
      <div class="s">${esc(s.summary)}</div></div>`).join("") +
    `<p class="small muted">These are from the last /compat-check. The gate light at the top says whether they still apply to the current code.</p>`;
  $("tests").innerHTML = t.groups.map((g) => `<div class="tgroup"><h3>${esc(g.name)}</h3>${g.rows.map((r) => `
    <details class="trow" data-key="t-${esc(r.name)}"><summary><span class="n">${esc(r.name)}</span>
      ${r.status ? `<span class="badge ${r.status}">${r.status === "pass" ? "pass" : "fail"}</span>` : `<span class="badge">no result</span>`}
      <span class="small muted">${r.from ? when(r.from) : ""}</span></summary>
      <div class="inner">
        ${r.checks ? `<p><b>Checks:</b> ${esc(r.checks)}</p>` : `<p class="muted">No explanation yet: add it to tools/dashboard/data/tests_explained.json.</p>`}
        ${r.why ? `<p><b>Why it matters:</b> ${esc(r.why)}</p>` : ""}
        ${r.limits ? `<p><b>Limits:</b> ${esc(r.limits)}</p>` : ""}
        ${r.files ? `<p><b>Code under test:</b> ${esc(r.files)}</p>` : ""}
      </div></details>`).join("")}</div>`).join("");
  keepOpen($("tab-tests"));
}

// ------------------------------------------------------------------------------------------------ bugs

const KIND_TEXT = {
  fault: "Fault: the defect in the code itself (the cause)",
  failure: "Failure: the wrong behaviour seen when the game runs (the effect)",
};
const CODE_NOW = {
  same: "",
  changed: "The code at these lines has changed since the bug was logged; this is the code as it was.",
  missing: "This file no longer exists; this is the code as it was.",
};

function bugSource(b) {
  if (!b.file) return `<p class="muted small">No source location recorded.</p>`;
  const loc = `${b.file}${b.line ? `:${b.line}${b.endLine && b.endLine !== b.line ? `-${b.endLine}` : ""}` : ""}`;
  const head = `<p class="small"><b>Source:</b> <code title="Click to copy">${esc(loc)}</code></p>`;
  if (!b.snippet) return head;
  const rows = b.snippet.lines.map((l, i) => {
    const n = b.snippet.from + i;
    const hit = n >= b.line && n <= (b.endLine || b.line);
    return `<span class="ln ${hit ? `hit ${esc(b.kind)}` : ""}"><span class="no">${n}</span>${esc(l) || " "}</span>`;
  }).join("");
  return `${head}<pre class="bug-code">${rows}</pre>${CODE_NOW[b.codeNow] ? `<p class="muted small">${CODE_NOW[b.codeNow]}</p>` : ""}`;
}

function bugHtml(b) {
  const fixed = b.status === "fixed";
  const action = !state.canWrite ? "" : fixed
    ? `<button data-b="${esc(b.id)}" data-ba="reopen">Reopen</button>`
    : `<button class="primary" data-b="${esc(b.id)}" data-ba="fixed">Mark fixed</button>`;
  return `<div class="bug ${esc(b.kind)} ${fixed ? "fixed" : ""}">
    <div class="head">
      <span class="t">${esc(b.name)}</span>
      <span class="badge kind-${esc(b.kind)}" title="${esc(KIND_TEXT[b.kind] || "")}">${esc(b.kind)}</span>
      <span class="badge ${fixed ? "pass" : "fail"}">${fixed ? "fixed" : "open"}</span>
    </div>
    <div class="meta small">
      <span>Found by <span class="achip" style="--c:${colorVar(b.foundBy)}">${esc(b.foundBy)}</span></span>
      <span title="${esc(b.foundAt)}">${esc(new Date(b.foundAt).toLocaleString(undefined, { year: "numeric", month: "short", day: "numeric", hour: "2-digit", minute: "2-digit", second: "2-digit" }))}</span>
      ${b.loggedBy ? `<span class="muted">logged on ${esc(b.loggedBy)}'s machine</span>` : ""}
    </div>
    <p><b>What fails and how it affects the game:</b> ${richText(b.summary)}</p>
    ${b.error ? `<p class="small"><b>Error:</b></p><pre class="bug-error">${esc(b.error)}</pre>` : ""}
    ${bugSource(b)}
    <div class="actions">${action}${fixed ? `<span>fixed by ${esc(b.fixedBy || "")} ${when(b.fixedAt)}${b.fixNote ? ` · ${esc(b.fixNote)}` : ""}</span>` : ""}</div>
  </div>`;
}

async function loadBugsCount() {
  const d = await api("/api/bugs");
  const open = d.items.filter((b) => b.status !== "fixed").length;
  $("bugs-count").hidden = open === 0;
  $("bugs-count").textContent = open;
  return d;
}

async function loadBugs() {
  const d = await loadBugsCount();
  const filters = [$("bug-status").value, $("bug-kind").value, $("bug-agent").value];
  if (!changed("bugs", [d, filters])) return;
  const agents = [...new Set(d.items.map((b) => b.foundBy))].sort();
  const pick = $("bug-agent").value;
  $("bug-agent").innerHTML = `<option value="">Found by anyone</option>` + agents.map((a) => `<option>${esc(a)}</option>`).join("");
  $("bug-agent").value = agents.includes(pick) ? pick : "";
  const [status, kind] = filters;
  const rows = d.items
    .filter((b) => (!status || b.status === status) && (!kind || b.kind === kind) && (!$("bug-agent").value || b.foundBy === $("bug-agent").value))
    .sort((a, b) => new Date(b.foundAt) - new Date(a.foundAt));
  $("bugs").innerHTML = rows.map(bugHtml).join("") ||
    `<p class="muted">${d.items.length ? "No bugs match these filters." : "No bugs logged yet. Subagents log them with tools/dashboard/bugs.py."}</p>`;
  document.querySelectorAll("#tab-bugs [data-ba]").forEach((btn) => btn.addEventListener("click", async () => {
    try {
      await api(`/api/bugs/${btn.dataset.b}`, { action: btn.dataset.ba });
      toast(btn.dataset.ba === "fixed" ? "Marked fixed" : "Reopened");
      state.last.bugs = null;
      await loadBugs();
    } catch (e) { toast(e.message); }
  }));
  document.querySelectorAll("#tab-bugs .bug code").forEach((c) => c.addEventListener("click", () => {
    navigator.clipboard?.writeText(c.textContent).then(() => toast("Copied"), () => {});
  }));
}

// ------------------------------------------------------------------------------------------------ model analytics

function num(n) { return Number(n || 0).toLocaleString(); }
function compact(n) {
  n = Number(n || 0);
  return n >= 1000000 ? `${(n / 1000000).toFixed(1)}M` : n >= 1000 ? `${(n / 1000).toFixed(1)}k` : String(Math.round(n));
}
function analyticsTrend(points) {
  const max = Math.max(1, ...points.map((p) => (p.claude.output || 0) + (p.codex.output || 0)));
  return points.map((p) => {
    const c = p.claude.output || 0, x = p.codex.output || 0;
    return `<div class="trend-column" title="${esc(p.date)} · Claude ${compact(c)} · Codex ${compact(x)}">
      <div class="trend-stack"><span class="trend-bar claude" style="height:${Math.max(c ? 3 : 0, c / max * 100)}%"></span><span class="trend-bar codex" style="height:${Math.max(x ? 3 : 0, x / max * 100)}%"></span></div>
      <span>${esc(p.date.slice(5))}</span></div>`;
  }).join("");
}
function analyticsState(cards) {
  return cards.map((c) => {
    const s = c.stats, total = Math.max(1, s.completed + s.running + s.paused);
    return `<div class="state-row"><div class="row"><b style="color:${colorVar(c.provider)}">${esc(c.label)}</b><span class="small muted">${num(total)} sessions</span></div>
      <div class="state-track"><span class="state-segment completed" style="width:${s.completed / total * 100}%"></span><span class="state-segment running" style="width:${s.running / total * 100}%"></span><span class="state-segment paused" style="width:${s.paused / total * 100}%"></span></div>
      <div class="small muted">${num(s.completed)} completed · ${num(s.running)} live · ${num(s.paused)} paused</div></div>`;
  }).join("") + `<div class="chart-legend state-legend"><span class="completed-dot">completed</span><span class="running-dot">live</span><span class="paused-dot">paused</span></div>`;
}
function analyticsModelMix(cards) {
  const models = cards.flatMap((c) => c.models.map((m) => ({ ...m, provider: c.provider })));
  const max = Math.max(1, ...models.map((m) => m.tasks));
  return models.length ? models.map((m) => `<div class="mix-row"><div class="row"><b>${esc(m.model)}</b><span class="badge" style="color:${colorVar(m.provider)}">${esc(m.provider)}</span></div><div class="mix-track"><span style="width:${m.tasks / max * 100}%;background:${colorVar(m.provider)}"></span></div><div class="small muted">${num(m.tasks)} tasks · ${num(m.output)} output tokens</div></div>`).join("") : `<p class="muted small">No model telemetry yet.</p>`;
}
function statLine(s) {
  return `<span class="analytics-stat"><b>${num(s)}</b></span>`;
}
function taskRows(rows, empty, completed = false) {
  return rows.length ? rows.map((r) => `<div class="analytics-task">
    <div><span class="task-text">${esc(r.task)}</span>${r.model ? ` <span class="badge">${esc(r.model)}</span>` : ""}</div>
    <span class="small muted">${when(r.updated * 1000)}${r.tools != null ? ` · ${num(r.tools)} tool calls` : ""}</span>
    ${completed && r.report ? `<div class="small muted clamp">${esc(r.report)}</div>` : ""}
  </div>`).join("") : `<p class="muted small">${empty}</p>`;
}
function analyticsCard(c) {
  const s = c.stats;
  const models = c.models.map((m) => `<div class="analytics-model"><b>${esc(m.model)}</b>
    <span>${num(m.tasks)} tasks · ${num(m.completed)} completed · ${num(m.tools)} tools</span>
    <span class="small muted">${num(m.input)} in · ${num(m.output)} out · ${num(m.cached)} cached${m.reasoning ? ` · ${num(m.reasoning)} reasoning` : ""}</span>
  </div>`).join("");
  return `<div class="panel analytics-card" style="--c:${colorVar(c.provider)}">
    <div class="panel-head"><h2>${esc(c.label)}</h2><span class="badge ${s.running ? "running" : ""}">${s.running ? `${s.running} live` : "idle"}</span></div>
    <div class="analytics-metrics">
      <div><b>${num(s.tasks)}</b><span>tasks</span></div><div><b>${num(s.completed)}</b><span>completed</span></div>
      <div><b>${num(s.paused)}</b><span>paused</span></div><div><b>${num(s.sessions)}</b><span>sessions</span></div>
    </div>
    <h3>Models used</h3>${models || `<p class="muted small">No model telemetry yet.</p>`}
    <div class="analytics-columns">
      <div><h3>Working live <span class="muted">(${num(s.running)})</span></h3>${taskRows(c.current, "No live tasks.")}</div>
      <div><h3>Paused / stopped <span class="muted">(${num(s.paused)})</span></h3>${taskRows(c.paused, "No paused tasks.")}</div>
    </div>
    <h3>Previously completed</h3>${taskRows(c.completedRecent, "No completed tasks recorded.", true)}
  </div>`;
}
function quotaTime(q) {
  if (q.reset) return q.reset;
  if (q.resetAt) return new Date(q.resetAt * 1000).toLocaleString(undefined, { month: "short", day: "numeric", hour: "numeric", minute: "2-digit" });
  return "reset unavailable";
}
function analyticsQuotas(quotas) {
  return ["claude", "codex"].map((provider) => {
    const q = quotas[provider], label = provider === "claude" ? "Claude" : "Codex";
    if (!q || !q.available) return `<div class="quota-card"><div class="row"><b>${label}</b><span class="badge">quota unavailable</span></div><p class="small muted">Provider limits were not returned. Local token totals remain below.</p></div>`;
    return `<div class="quota-card" style="--c:${colorVar(provider)}"><div class="row"><b>${label}</b>${q.plan ? `<span class="badge">${esc(q.plan)}</span>` : ""}</div>${q.windows.map((w) => `<div class="quota-window"><div class="row"><span>${esc(w.label)}</span><b>${num(w.usedPercent)}%</b></div><div class="quota-track"><span style="width:${Math.min(100, Math.max(0, w.usedPercent))}%"></span></div><div class="small muted">resets ${esc(quotaTime(w))}</div></div>`).join("")}<div class="small muted quota-source">${esc(q.note || "Provider rate-limit data")}</div></div>`;
  }).join("");
}
async function loadAnalytics() {
  const a = await api("/api/analytics");
  if (!changed("analytics", a)) return;
  $("analytics-updated").textContent = `updated ${when(a.generated)}`;
  $("analytics-scope").textContent = `Local view for ${a.scope.developer} · ${a.scope.workspace}. Task state is inferred from provider logs; paused means stopped without a completion event. Token totals can include cached input.`;
  const t = a.totals;
  $("analytics-summary").innerHTML = [
    ["Tasks", t.tasks], ["Completed", t.completed], ["Live", t.running], ["Paused", t.paused],
    ["Input tokens", t.input], ["Output tokens", t.output], ["Tool calls", t.tools],
  ].map(([label, value]) => `<div class="summary-metric"><b>${num(value)}</b><span>${label}</span></div>`).join("");
  $("analytics-trend").innerHTML = analyticsTrend(a.trend);
  $("analytics-quotas").innerHTML = analyticsQuotas(a.quotas || {});
  $("analytics-state").innerHTML = analyticsState(a.cards);
  $("analytics-model-mix").innerHTML = analyticsModelMix(a.cards);
  $("analytics-cards").innerHTML = a.cards.map(analyticsCard).join("");
}

// ------------------------------------------------------------------------------------------------ wiring + polling

const LOADERS = {
  manual: [loadManual],
  team: [loadTeam],
  agents: [loadBus, loadAgents, loadTimeline, loadNeedToKnow],
  handoff: [loadHandoff],
  analytics: [loadAnalytics],
  changes: [loadChanges, loadHistory],
  todo: [loadTodo, loadSuggestions],
  tests: [loadTests],
  bugs: [loadBugs],
};

async function refresh() {
  try {
    await loadMeta();
    await Promise.all([loadGate(), ...(state.tab === "manual" ? [] : [loadManualCount()]), ...(state.tab === "bugs" ? [] : [loadBugsCount()]), ...LOADERS[state.tab].map((f) => f())]);
  } catch (e) {
    toast(`Dashboard server: ${e.message}`);
  }
}

$("needs").addEventListener("click", () => document.querySelector('.tabs [data-tab="manual"]').click());
$("tabs").addEventListener("click", (e) => {
  const tab = e.target.closest("button")?.dataset.tab;
  if (!tab) return;
  state.tab = tab;
  document.querySelectorAll(".tabs button").forEach((b) => b.classList.toggle("on", b.dataset.tab === tab));
  document.querySelectorAll(".tab").forEach((s) => s.classList.toggle("on", s.id === `tab-${tab}`));
  history.replaceState(null, "", `#${tab}`);
  try { localStorage.setItem("dash-tab", tab); } catch (_) { /* storage blocked: fine */ }
  refresh();
});
$("session").addEventListener("change", () => {
  state.session = $("session").value;
  state.agent = null;
  state.last = {};
  refresh();
});
$("show-all").addEventListener("click", () => {
  state.agent = null;
  state.jump = true;
  document.querySelectorAll(".agent").forEach((a) => a.classList.remove("sel"));
  loadTimeline();
});
$("team-sync").addEventListener("click", () => teamAction("sync"));
$("team-push").addEventListener("click", () => teamAction("push"));
$("feature-form").addEventListener("submit", (e) => {
  e.preventDefault();
  teamAction("start", { title: $("feature-title").value, detail: $("feature-detail").value });
  $("feature-title").value = $("feature-detail").value = "";
});
$("f-author").addEventListener("change", loadHistory);
$("f-agent").addEventListener("change", loadHistory);
$("bus-form").addEventListener("submit", async (e) => {
  e.preventDefault();
  try {
    await api("/api/bus", { action: "send", from: "user", to: $("bus-to").value, text: $("bus-text").value });
    $("bus-text").value = "";
    state.busJump = true;
    await loadBus();
  } catch (err) { toast(err.message); }
});
$("f-branch").addEventListener("change", loadHistory);
["bug-status", "bug-kind", "bug-agent"].forEach((id) => $(id).addEventListener("change", loadBugs));
$("todo-form").addEventListener("submit", (e) => {
  e.preventDefault();
  todo({ action: "add", title: $("todo-title").value, status: $("todo-status").value });
  $("todo-title").value = "";
});

function setTheme(t) {
  if (t === "light" || t === "dark") document.documentElement.dataset.theme = t;
  else delete document.documentElement.dataset.theme;
  document.querySelectorAll("#theme button").forEach((b) => b.classList.toggle("on", b.dataset.theme === (t || "system")));
  try { localStorage.setItem("dash-theme", t); } catch (_) { /* storage blocked: fine */ }
}
$("theme").addEventListener("click", (e) => { if (e.target.dataset.theme) setTheme(e.target.dataset.theme); });
setTheme(document.documentElement.dataset.theme || "system");

renderLegend();
// #changes, #todo, #tests, #bugs open that tab (shareable links); otherwise the last tab this browser used
let startTab = location.hash.slice(1);
try { if (!LOADERS[startTab]) startTab = localStorage.getItem("dash-tab"); } catch (_) { /* storage blocked: fine */ }
if (LOADERS[startTab]) document.querySelector(`.tabs [data-tab="${startTab}"]`).click();
refresh();
setInterval(() => { if (!document.hidden) refresh(); }, 2500);
