// Agent dashboard client: polls the local server (tools/dashboard/server.py) and renders each tab.
"use strict";

const AGENTS = ["main", "test-writer", "ui-test-writer", "physics-tester", "ui-tester", "multiplayer-tester",
  "world-tester", "physics-tuner", "track-designer"];
const STATUS_COLS = [["doing", "Doing"], ["next", "Up next"], ["backlog", "Backlog"], ["done", "Done"]];

const $ = (id) => document.getElementById(id);
const state = { session: "", agent: null, tab: "agents", canWrite: true, last: {}, open: new Set() };

function esc(s) {
  return String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c]));
}
function colorVar(type) {
  return AGENTS.includes(type) ? `var(--a-${type})` : "var(--a-other)";
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
  $("who").textContent = `${m.developer}${m.canWrite ? "" : " · read-only"}`;
  $("todo-form").hidden = !m.canWrite;
  if (!state.session) state.session = m.session;
  if (changed("sessions", m.sessions)) {
    $("session").innerHTML = m.sessions.map((s) =>
      `<option value="${esc(s.id)}">${esc(s.title || s.id.slice(0, 8))} · ${s.agents} agents · ${ago(s.updated * 1000)}</option>`).join("");
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
      <div class="desc">${esc(a.description)}</div>
      <div class="row small muted"><span>${when(a.start)}</span><span>${duration(a.start, a.end)} · ${a.steps} steps</span></div>
      ${a.status === "running" ? `<div class="last">${esc(a.lastTool)}</div>` : ""}
    </div>`).join("") : `<p class="muted">No subagents in this session yet. Pick an earlier session in the Session menu to see past runs.</p>`;
  $("agents").querySelectorAll(".agent").forEach((el) => el.addEventListener("click", () => selectAgent(el.dataset.id)));
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
      <span class="badge">${esc(label[c.status] || c.status)}</span><span class="path">${esc(c.path)}</span>
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
  if (!changed("history", h.commits)) return;
  $("history").innerHTML = h.commits.map((c) => {
    const add = c.files.reduce((n, f) => n + (+f.add || 0), 0);
    const del = c.files.reduce((n, f) => n + (+f.del || 0), 0);
    return `<div class="commit" data-sha="${esc(c.sha)}">
      <span class="sha">${esc(c.short)}</span><span class="subj">${esc(c.subject)}</span>
      <span class="when">${esc(new Date(c.date).toLocaleString())}</span>
      <div class="sub"><span class="who" style="--c:var(--a-other)">${esc(c.author)}</span>
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
    await api("/api/todo", body);
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
        ${i.detail ? `<div class="detail">${esc(i.detail)}</div>` : ""}
        <div class="foot"><span>${esc(i.by || "")}${i.done ? ` · done ${when(i.done)}` : ""}</span><span class="sp"></span>
          ${state.canWrite ? moves(i) + `<button data-del="${esc(i.id)}" title="Delete">✕</button>` : ""}</div>
      </div>`).join("")}</div>`;
  }).join("");
  $("board").querySelectorAll(".card .title").forEach((el) => el.addEventListener("click", () => el.parentElement.classList.toggle("open")));
  $("board").querySelectorAll("[data-move]").forEach((b) => b.addEventListener("click", () => todo({ action: "move", id: b.dataset.id, status: b.dataset.move })));
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

// ------------------------------------------------------------------------------------------------ wiring + polling

const LOADERS = {
  agents: [loadAgents, loadTimeline, loadNeedToKnow],
  changes: [loadChanges, loadHistory],
  todo: [loadTodo, loadSuggestions],
  tests: [loadTests],
};

async function refresh() {
  try {
    await loadMeta();
    await Promise.all([loadGate(), ...LOADERS[state.tab].map((f) => f())]);
  } catch (e) {
    toast(`Dashboard server: ${e.message}`);
  }
}

$("tabs").addEventListener("click", (e) => {
  const tab = e.target.dataset.tab;
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
$("f-author").addEventListener("change", loadHistory);
$("f-branch").addEventListener("change", loadHistory);
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
// #changes, #todo, #tests open that tab (shareable links); otherwise the last tab this browser used
let startTab = location.hash.slice(1);
try { if (!LOADERS[startTab]) startTab = localStorage.getItem("dash-tab"); } catch (_) { /* storage blocked: fine */ }
if (LOADERS[startTab]) document.querySelector(`.tabs [data-tab="${startTab}"]`).click();
refresh();
setInterval(() => { if (!document.hidden) refresh(); }, 2500);
