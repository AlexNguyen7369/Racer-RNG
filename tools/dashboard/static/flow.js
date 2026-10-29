// Orchestration flow: draws /api/flow (the orchestrator's .agents/orchestrator.json + live subagents + bus messages)
// as a live graph. Nodes glide to new places, edges follow them, and every new message or event flies along its edge.
// ?demo shows a simulated orchestrator so the page can be seen without one running.
"use strict";

const $ = (id) => document.getElementById(id);
const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" })[c]);
const SVG = "http://www.w3.org/2000/svg";
const DEMO = new URLSearchParams(location.search).has("demo");
const REDUCED = matchMedia("(prefers-reduced-motion: reduce)").matches;
const POLL_MS = 2500;
const COL = { people: 10, orch: 220, lanes: 520, studio: 900, int: 1130, main: 1420 };
const WID = { people: 170, orch: 250, lanes: 340, studio: 190, int: 250, main: 130 };
const VIEW_W = 1560;
const TOP = 20, GAP = 14;
const OPEN = ["queued", "running", "verifying", "green"];

const graph = $("graph");
const edgeLayer = document.createElementNS(SVG, "g");
const nodeLayer = document.createElementNS(SVG, "g");
const particleLayer = document.createElementNS(SVG, "g");
graph.append(edgeLayer, nodeLayer, particleLayer);

const nodes = new Map(); // id -> {g, fo, div, html, x, y, tx, ty, w, h}
const edges = new Map(); // key -> {path, from, to, hotUntil}
const particles = [];
let seen = null; // keys of messages/events already shown; null until the first load (nothing animates on load)
const feed = [];

// ---------------------------------------------------------------------------------------------------------------
// layout: data -> node and edge specs

function ago(iso) {
  if (!iso) return "";
  const s = Math.max(0, (Date.now() - new Date(iso).getTime()) / 1000);
  return s < 60 ? `${Math.round(s)}s ago` : s < 3600 ? `${Math.round(s / 60)}m ago` : `${Math.round(s / 3600)}h ago`;
}

const base = (p) => String(p || "").split("/").filter(Boolean).pop() || "";

function laneHtml(t, shared) {
  const files = t.changed && t.changed.length ? t.changed : t.files || [];
  const chips = files.slice(0, 5).map((f) => `<span class="chip${shared.has(f) ? " shared" : ""}" title="${esc(f)}">${esc(base(f))}</span>`).join("")
    + (files.length > 5 ? `<span class="muted">+${files.length - 5}</span>` : "");
  const studio = t.resource === "isolated" ? `Studio: own${t.port ? ` :${t.port}` : ""}`
    : t.resource === "queued" ? "Studio: queued" : "";
  const merge = t.merge === "conflict" ? `<span class="pill st-failed" title="${esc((t.conflicts || []).join(", "))}">conflict</span>`
    : t.merge === "clean" ? `<span class="muted">merges clean</span>` : "";
  return `<div class="row"><span class="k">${esc(t.agent_type || "agent")}</span><span class="pill st-${esc(t.status)}">${esc(t.status)}</span></div>
    <b title="${esc(t.title)}">${esc(t.title || t.id)}</b>
    <div class="mono" title="${esc(t.branch)}">⑂ ${esc(t.branch || "no branch")}</div>
    <div class="mono muted" title="${esc(t.worktree)}">▣ ${esc(t.worktree ? base(t.worktree) : "no worktree")}${t.worktree && t.worktreeExists === false ? " (gone)" : ""}</div>
    <div class="chips">${chips || '<span class="muted">no files yet</span>'}</div>
    <div class="row muted"><span>${esc(studio)}</span><span>${esc(t.tests || "")}${t.audit ? ` · audit ${esc(t.audit)}` : ""}</span>${merge}</div>`;
}

function layout(d) {
  const specs = [], links = [];
  const o = d.orchestrator || {};
  const tasks = d.tasks || []; // state-file order: lanes stay put while their status changes
  const overlapIds = new Map();
  for (const ov of d.overlaps || []) for (const id of [ov.a, ov.b]) {
    if (!overlapIds.has(id)) overlapIds.set(id, new Set());
    ov.files.forEach((f) => overlapIds.get(id).add(f));
  }

  // lanes column
  let y = TOP;
  const lanes = [];
  for (const t of tasks) {
    const shared = overlapIds.get(t.id) || new Set();
    lanes.push({ id: `task:${t.id}`, col: "lanes", y, h: 128, cls: `lane st-${t.status}${shared.size ? " overlap" : ""}`, html: laneHtml(t, shared), task: t });
    y += 128 + GAP;
  }
  for (const a of d.outside || []) {
    lanes.push({ id: `out:${a.id}`, col: "lanes", y, h: 74, cls: "outside",
      html: `<div class="row"><span class="k">${esc(a.type)} · outside orchestrator</span><span class="pill st-${a.status === "running" ? "running" : "merged"}">${esc(a.status)}</span></div>
        <b title="${esc(a.description)}">${esc(a.description)}</b><div class="mono muted" title="${esc(a.lastTool)}">${esc(a.lastTool || "")}</div>` });
    y += 74 + GAP;
  }
  const laneBottom = Math.max(y - GAP, TOP + 160);
  const mid = (TOP + laneBottom) / 2;
  specs.push(...lanes);

  // orchestrator
  const queue = (d.studioQueue || []).map((id, i) => `${i + 1}. ${esc(id)}`).join("<br>") || '<span class="muted">empty</span>';
  const orchH = 170;
  specs.push({ id: "orch", col: "orch", y: Math.max(TOP, mid - orchH / 2), h: orchH, cls: `orch${o.active ? " active" : ""}`,
    html: `<div class="k">${o.active ? "Orchestrator" : "Claude (no orchestrator state)"}</div><b>${esc(o.phase)}</b>
      <div class="muted">${o.tick != null ? `tick ${esc(o.tick)} · ` : ""}${esc(ago(o.updated))}</div>
      ${o.context ? `<div class="ctx${o.context.pct >= 0.75 ? " hi" : o.context.pct >= 0.6 ? " mid" : ""}" title="${esc(o.context.tokens)} of ${esc(o.context.window)} tokens, ${esc(ago(o.context.at))}"><span style="width:${Math.min(100, Math.round(o.context.pct * 100))}%"></span><em>context ${Math.round(o.context.pct * 100)}%</em></div>` : ""}
      <div class="k" style="margin-top:6px">Shared Studio queue</div><div class="mono">${queue}</div>` });

  // people / other sessions
  const people = [{ id: "user", h: 58, cls: "user", html: `<div class="k">Owner</div><b>You</b><div class="muted">goals · decisions</div>` }];
  const st = (d.bus && d.bus.status) || {};
  people.push({ id: "codex", h: 70, cls: "codex", html: `<div class="k">Codex</div><b title="${esc(st.codex && st.codex.task)}">${esc((st.codex && st.codex.task) || "idle")}</b><div class="mono muted">${esc(((st.codex && st.codex.files) || []).map(base).join(", "))}</div>` });
  if (o.active && (d.outside || []).length) people.push({ id: "others", h: 58, cls: "outside", html: `<div class="k">Other Claude sessions</div><b>${d.outside.length} subagent(s)</b>` });
  let py = Math.max(TOP, mid - (people.reduce((s, p) => s + p.h + GAP, 0) - GAP) / 2);
  for (const p of people) { specs.push({ ...p, col: "people", y: py }); py += p.h + GAP; }

  // Studios
  const studios = [{ id: "studio:shared", h: 62, cls: `studio${(d.studioQueue || []).length || tasks.some((t) => t.resource === "queued" && OPEN.includes(t.status)) ? " live" : ""}`,
    html: `<div class="k">Shared Studio</div><b>Rojo :34872 (main tree)</b><div class="muted">${(d.studioQueue || []).length} waiting</div>` }];
  for (const t of tasks) if (t.resource === "isolated" && OPEN.includes(t.status)) {
    studios.push({ id: `studio:${t.id}`, h: 62, cls: "studio live", html: `<div class="k">Studio · ${esc(t.id)}</div><b>Rojo :${esc(t.port || "?")}</b><div class="mono muted">${esc(t.instance || "")}</div>` });
  }
  let sy = Math.max(TOP, mid - (studios.reduce((s, p) => s + p.h + GAP, 0) - GAP) / 2);
  for (const s of studios) { specs.push({ ...s, col: "studio", y: sy }); sy += s.h + GAP; }

  // integration branches (one per goal; else the current branch)
  const goals = (d.goals || []).filter((g) => g.status !== "done" || tasks.some((t) => t.goal === g.id));
  const ints = goals.length ? goals.map((g) => {
    const mine = tasks.filter((t) => t.goal === g.id);
    const merged = mine.filter((t) => t.status === "merged").length;
    return { id: `int:${g.id}`, h: 84, cls: "integration",
      html: `<div class="k">Integration · ${esc(g.id)}</div><b title="${esc(g.branch)}">⑂ ${esc(g.branch || "not started")}</b>
        <div class="muted">${merged}/${mine.length} tasks merged</div><div class="muted">${esc(g.title || "")}</div>` };
  }) : [{ id: "int:_current", h: 70, cls: "integration", html: `<div class="k">Current branch</div><b title="${esc(d.branch)}">⑂ ${esc(d.branch || "?")}</b><div class="muted">no goal set</div>` }];
  let iy = Math.max(TOP, mid - (ints.reduce((s, p) => s + p.h + GAP, 0) - GAP) / 2);
  for (const s of ints) { specs.push({ ...s, col: "int", y: iy }); iy += s.h + GAP; }
  specs.push({ id: "main", col: "main", y: mid - 30, h: 60, cls: "main", html: `<div class="k">Protected</div><b>main</b><div class="muted">owner merges</div>` });

  // edges
  links.push({ key: "user|orch", from: "user", to: "orch", cls: "" });
  links.push({ key: "codex|orch", from: "codex", to: "orch", cls: "" });
  for (const L of lanes) {
    if (L.task) {
      const t = L.task, intId = goals.some((g) => g.id === t.goal) ? `int:${t.goal}` : ints[0].id;
      const ov = overlapIds.has(t.id) ? " overlap" : "";
      links.push({ key: `orch|${L.id}`, from: "orch", to: L.id, cls: `st-${t.status}${ov}` });
      const mcls = t.merge === "conflict" ? "conflict" : t.status === "merged" ? "st-merged" : t.status === "green" ? "st-green" : `st-${t.status} uncommitted`;
      links.push({ key: `${L.id}|${intId}`, from: L.id, to: intId, cls: mcls });
      if (t.resource && t.resource !== "none" && OPEN.includes(t.status)) {
        const sid = t.resource === "isolated" ? `studio:${t.id}` : "studio:shared";
        links.push({ key: `${L.id}|${sid}`, from: L.id, to: sid, cls: "studio" });
      }
    } else {
      links.push({ key: `${o.active ? "others" : "orch"}|${L.id}`, from: o.active ? "others" : "orch", to: L.id, cls: "outside" });
    }
  }
  for (const s of ints) links.push({ key: `${s.id}|main`, from: s.id, to: "main", cls: "owner" });

  const height = Math.max(laneBottom, py, sy, iy) + TOP;
  return { specs, links, height };
}

// ---------------------------------------------------------------------------------------------------------------
// rendering: create / update / remove, then the animation frame moves everything

function apply(d) {
  const { specs, links, height } = layout(d);
  graph.setAttribute("viewBox", `0 0 ${VIEW_W} ${height}`);
  const want = new Set();
  for (const s of specs) {
    want.add(s.id);
    const x = COL[s.col], w = WID[s.col];
    let n = nodes.get(s.id);
    if (!n) {
      const g = document.createElementNS(SVG, "g");
      g.classList.add("node-g");
      const fo = document.createElementNS(SVG, "foreignObject");
      const div = document.createElement("div");
      fo.append(div);
      g.append(fo);
      nodeLayer.append(g);
      n = { g, fo, div, html: "", x, y: s.y, w, h: s.h };
      nodes.set(s.id, n);
    }
    n.g.classList.remove("leaving");
    n.leaving = false;
    n.tx = x; n.ty = s.y; n.w = w; n.h = s.h;
    n.fo.setAttribute("width", w);
    n.fo.setAttribute("height", s.h);
    const cls = `node ${s.cls}`;
    if (n.div.className.replace(" flash", "") !== cls) n.div.className = cls;
    if (n.html !== s.html) { n.div.innerHTML = s.html; n.html = s.html; }
  }
  for (const [id, n] of nodes) if (!want.has(id) && !n.leaving) {
    n.leaving = true;
    n.g.classList.add("leaving");
    setTimeout(() => { if (n.leaving) { n.g.remove(); nodes.delete(id); } }, 600);
  }
  const wantE = new Set();
  for (const L of links) {
    wantE.add(L.key);
    let e = edges.get(L.key);
    if (!e) {
      const path = document.createElementNS(SVG, "path");
      edgeLayer.append(path);
      e = { path, hotUntil: 0 };
      edges.set(L.key, e);
    }
    e.from = L.from; e.to = L.to; e.cls = L.cls;
    e.path.setAttribute("class", `edge ${L.cls}`);
  }
  for (const [k, e] of edges) if (!wantE.has(k)) { e.path.remove(); edges.delete(k); }
}

function ends(a, b) {
  const ac = a.x + a.w / 2, bc = b.x + b.w / 2;
  const p0 = bc >= ac ? [a.x + a.w, a.y + a.h / 2] : [a.x, a.y + a.h / 2];
  const p3 = bc >= ac ? [b.x, b.y + b.h / 2] : [b.x + b.w, b.y + b.h / 2];
  const dx = Math.max(40, Math.abs(p3[0] - p0[0]) / 2) * (bc >= ac ? 1 : -1);
  return [p0, [p0[0] + dx, p0[1]], [p3[0] - dx, p3[1]], p3];
}

function bez(P, t) {
  const u = 1 - t;
  return [0, 1].map((i) => u * u * u * P[0][i] + 3 * u * u * t * P[1][i] + 3 * u * t * t * P[2][i] + t * t * t * P[3][i]);
}

function frame(now) {
  const k = REDUCED ? 1 : 0.14;
  for (const n of nodes.values()) {
    n.x += (n.tx - n.x) * k;
    n.y += (n.ty - n.y) * k;
    n.g.setAttribute("transform", `translate(${n.x.toFixed(1)},${n.y.toFixed(1)})`);
  }
  for (const e of edges.values()) {
    const a = nodes.get(e.from), b = nodes.get(e.to);
    if (!a || !b) continue;
    const P = ends(a, b);
    e.path.setAttribute("d", `M${P[0]} C${P[1]} ${P[2]} ${P[3]}`);
    e.path.classList.toggle("hot", now < e.hotUntil);
  }
  for (let i = particles.length - 1; i >= 0; i--) {
    const p = particles[i], a = nodes.get(p.from), b = nodes.get(p.to);
    const t = (now - p.start) / p.dur;
    if (t >= 1 || !a || !b) {
      p.el.remove();
      particles.splice(i, 1);
      if (b && t >= 1) flash(p.to);
      continue;
    }
    if (t < 0) continue;
    const [x, y] = bez(ends(a, b), t * t * (3 - 2 * t));
    p.el.setAttribute("cx", x.toFixed(1));
    p.el.setAttribute("cy", y.toFixed(1));
  }
  requestAnimationFrame(frame);
}

function flash(id) {
  const n = nodes.get(id);
  if (!n || REDUCED) return;
  n.div.classList.remove("flash");
  void n.div.offsetWidth; // restart the animation
  n.div.classList.add("flash");
}

function edgeBetween(a, b) {
  return edges.get(`${a}|${b}`) || edges.get(`${b}|${a}`);
}

function send(from, to, tone, delay) {
  if (!nodes.has(from) || !nodes.has(to) || from === to) return flash(from);
  const e = edgeBetween(from, to);
  if (e) e.hotUntil = performance.now() + 2500;
  if (REDUCED) return flash(to);
  const el = document.createElementNS(SVG, "circle");
  el.setAttribute("r", 6);
  el.setAttribute("class", `particle ${tone || ""}`);
  el.setAttribute("cx", -20);
  particleLayer.append(el);
  particles.push({ el, from, to, start: performance.now() + (delay || 0), dur: 1400 });
}

// ---------------------------------------------------------------------------------------------------------------
// communication: bus messages + orchestrator events -> feed rows and particles

const BUS_NODE = { claude: "orch", codex: "codex", user: "user" };

function routeOf(item, d) {
  if (item.src === "bus") {
    const from = BUS_NODE[item.from] || "orch";
    const to = item.to === "all" ? ["user", "codex", "orch"].filter((x) => x !== from) : [BUS_NODE[item.to] || "orch"];
    return to.map((t) => [from, t]);
  }
  const taskNode = item.task ? `task:${item.task}` : null;
  const t = (d.tasks || []).find((x) => x.id === item.task);
  const goals = (d.goals || []).map((g) => g.id);
  const intNode = t && goals.includes(t.goal) ? `int:${t.goal}` : goals.length ? `int:${goals[0]}` : "int:_current";
  const studio = t && t.resource === "isolated" ? `studio:${t.id}` : "studio:shared";
  const named = { orchestrator: "orch", orch: "orch", user: "user", owner: "user", codex: "codex", studio, integration: intNode, main: "main" };
  const pick = (v) => (v == null ? null : named[v] || (nodes.has(`task:${v}`) ? `task:${v}` : v));
  if (item.from || item.to) return [[pick(item.from) || taskNode || "orch", pick(item.to) || taskNode || "orch"]];
  const kind = String(item.kind || "").toLowerCase();
  if (/deleg|start|brief|assign|spawn/.test(kind)) return [["orch", taskNode]];
  if (/report|done|result|fail|block|red|green|pass/.test(kind)) return [[taskNode, "orch"]];
  if (/test|studio|harness/.test(kind)) return [[taskNode, studio]];
  if (/merge|land|commit/.test(kind)) return [[taskNode, intNode]];
  if (/ask|question|owner|escalat|conflict/.test(kind)) return [["orch", "user"]];
  if (/answer|confirm|goal/.test(kind)) return [["user", "orch"]];
  if (/push/.test(kind)) return [[intNode, intNode]];
  return [[taskNode || "orch", "orch"]];
}

function items(d) {
  const out = [];
  for (const m of (d.bus && d.bus.messages) || []) {
    out.push({ key: `m${m.id || m.n}`, src: "bus", at: m.at || m.time || m.ts, from: m.from, to: m.to, kind: "message", text: m.text });
  }
  for (const e of d.events || []) {
    out.push({ key: `e${e.at}|${e.kind}|${e.task}|${e.text}`, src: "event", at: e.at, from: e.from, to: e.to, kind: e.kind, task: e.task, text: e.text });
  }
  return out.sort((a, b) => String(a.at || "").localeCompare(String(b.at || "")));
}

function label(id) {
  if (!id) return "?";
  if (id.startsWith("task:")) return id.slice(5);
  if (id.startsWith("int:")) return "integration";
  if (id.startsWith("studio:")) return id === "studio:shared" ? "shared Studio" : "Studio";
  return { orch: orchActive ? "orchestrator" : "Claude" }[id] || id;
}

function communicate(d) {
  const all = items(d);
  const fresh = seen ? all.filter((it) => !seen.has(it.key)) : [];
  if (!seen) feed.push(...all.slice(-60).map((it) => ({ it, routes: routeOf(it, d), isNew: false })));
  seen = new Set(all.map((it) => it.key));
  fresh.forEach((it, i) => {
    const routes = routeOf(it, d);
    const tone = it.src === "bus" ? (it.from === "user" ? "user" : it.from === "codex" ? "codex" : "") : /fail|block|conflict|red/i.test(it.kind || "") ? "bad" : "";
    routes.forEach(([a, b]) => send(a, b, tone, i * 220));
    feed.push({ it, routes, isNew: true });
  });
  while (feed.length > 120) feed.shift();
  renderFeed();
}

function renderFeed() {
  const ol = $("feed");
  ol.innerHTML = "";
  for (const f of [...feed].reverse()) {
    const li = document.createElement("li");
    if (f.isNew) li.className = "new";
    f.isNew = false;
    const r = f.routes[0] || [];
    li.innerHTML = `<span class="when">${esc(ago(f.it.at))}</span><span class="route">${esc(label(r[0]))} → ${esc(f.routes.map((x) => label(x[1])).join(", "))}</span>
      <span class="kind">${esc(f.it.kind)}</span><div class="text">${esc(String(f.it.text || "").slice(0, 280))}</div>`;
    li.addEventListener("mouseenter", () => f.routes.forEach(([a, b]) => edgeBetween(a, b)?.path.classList.add("focus")));
    li.addEventListener("mouseleave", () => f.routes.forEach(([a, b]) => edgeBetween(a, b)?.path.classList.remove("focus")));
    ol.append(li);
  }
  $("feed-count").textContent = feed.length ? `(${feed.length})` : "";
}

// ---------------------------------------------------------------------------------------------------------------
// header

let orchActive = false;

function header(d) {
  const o = d.orchestrator || {};
  orchActive = !!o.active;
  $("phase").textContent = o.phase || "?";
  $("phase").classList.toggle("on", !!o.active && o.phase !== "idle");
  $("updated").textContent = o.updated ? `state ${ago(o.updated)}` : DEMO ? "demo" : "no .agents/orchestrator.json yet";
  $("stale").hidden = !o.stale;
  const open = (d.tasks || []).filter((t) => OPEN.includes(t.status)).length;
  const ov = d.overlaps || [];
  const sep = $("separation");
  sep.className = `sep ${ov.length ? "bad" : "ok"}`;
  sep.textContent = ov.length
    ? `${ov.length} overlap(s): ${ov.map((x) => `${x.a} × ${x.b} (${x.files.map(base).join(", ")})`).join("; ")}`
    : `${open} open lane(s), 0 shared files ✓`;
  $("goals").innerHTML = (d.goals || []).map((g) => `<div class="goal"><b>${esc(g.title || g.id)}</b><span class="muted">${esc(g.status || "")}</span><div>${(g.deliverables || [])
    .map((x) => `<span class="chip ${x.status === "done" ? "done" : ""}" title="${esc(x.done_when)}">${esc(x.output || x.id)}</span>`).join("")}</div></div>`).join("");
  $("demo-link").textContent = DEMO ? "Show live data" : "Demo";
  $("demo-link").href = DEMO ? "/static/flow.html" : "/static/flow.html?demo";
}

// ---------------------------------------------------------------------------------------------------------------
// board: the TODO board's Doing / Up next cards and the orchestrator's queued tasks, refreshed every poll

let boardSeen = null; // card keys already shown; new ones flash

function board(d) {
  const b = d.board || {};
  const queued = (d.tasks || []).filter((t) => t.status === "queued");
  const keys = new Set();
  const row = (key, title, tip, pill) => {
    keys.add(key);
    const fresh = boardSeen && !boardSeen.has(key);
    return `<li class="${fresh ? "new" : ""}" title="${esc(tip)}"><span class="t">${esc(title)}</span>${pill}</li>`;
  };
  const card = (sec) => (i) => row(`${sec}:${i.id}`, i.title || i.id, [i.owner, i.branch, i.updated && `updated ${ago(i.updated)}`].filter(Boolean).join(" · "),
    i.taskStatus ? `<span class="pill st-${esc(i.taskStatus)}">${esc(i.taskStatus)}</span>` : i.owner ? `<span class="muted">${esc(i.owner)}</span>` : "");
  // <details> keep their open/closed state across polls (only the lists inside are replaced)
  const list = (key, name, items) => {
    let el = $("board").querySelector(`details[data-k="${key}"]`);
    if (!el) {
      el = document.createElement("details");
      el.dataset.k = key;
      el.open = true;
      el.innerHTML = "<summary></summary><ul></ul>";
      $("board").append(el);
    }
    el.querySelector("summary").innerHTML = `${name} <span class="muted">(${items.length})</span>`;
    el.querySelector("ul").innerHTML = items.join("") || '<li class="muted">none</li>';
  };
  list("queue", "Orchestrator queue", queued.map((t) => row(`q:${t.id}`, t.title || t.id, t.branch || "", `<span class="pill st-queued">queued</span>`)));
  list("doing", "Doing", (b.doing || []).map(card("doing")));
  list("next", "Up next", (b.next || []).map(card("next")));
  boardSeen = keys;
}

// ---------------------------------------------------------------------------------------------------------------
// demo: a simulated orchestrator moving four tasks through the loop

const demo = (() => {
  const now = () => new Date().toISOString();
  const s = {
    tick: 1, phase: "delegate", events: [], messages: [], n: 0, queue: ["track-7"],
    goals: [{ id: "juice", title: "Race feels juicy", status: "active", branch: "feature/alex/juice",
      deliverables: [{ id: "d1", output: "Boost VFX", status: "open", done_when: "vehicle_effects green" },
        { id: "d2", output: "Engine SFX", status: "open", done_when: "sfx scenario green" },
        { id: "d3", output: "Shop polish", status: "open", done_when: "ui_shop green" },
        { id: "d4", output: "Track 7", status: "open", done_when: "track:Track7 green" }] }],
    tasks: [
      { id: "boost-vfx", goal: "juice", deliverable: "d1", title: "Boost trail VFX", agent_type: "roblox-vfx", files: ["src/client/BoostVfx.luau", "src/shared/VfxConfig.luau"], resource: "isolated", port: 34873, instance: "studio-2" },
      { id: "engine-sfx", goal: "juice", deliverable: "d2", title: "Engine pitch SFX", agent_type: "general-purpose", files: ["src/client/EngineAudio.luau"], resource: "isolated", port: 34874, instance: "studio-3" },
      { id: "shop-ui", goal: "juice", deliverable: "d3", title: "Shop panel polish", agent_type: "ui-test-writer", files: ["ui/specs/Shop.ui.json", "src/client/ShopUi.luau"], resource: "queued" },
      { id: "track-7", goal: "juice", deliverable: "d4", title: "Track 7 (Volcano)", agent_type: "track-designer", files: ["src/shared/Tracks/Track7.luau"], resource: "queued" },
    ].map((t) => ({ ...t, branch: `orch/juice/${t.id}`, worktree: `/Users/you/RobloxGames-orch/${t.id}`, status: "queued", worktreeExists: true })),
  };
  const ev = (kind, task, text, extra) => s.events.push({ at: now(), kind, task, text, ...extra });
  const NEXT = { queued: "running", running: "verifying", verifying: "green", green: "merged" };
  return () => {
    s.tick++;
    const t = s.tasks[s.tick % s.tasks.length];
    const was = t.status;
    if (was === "merged") { t.status = "queued"; t.tests = ""; t.audit = ""; ev("delegate", t.id, `restart ${t.title}`); }
    else {
      t.status = NEXT[was];
      if (t.status === "running") { s.phase = "delegate"; ev("delegate", t.id, `brief: ${t.title}; rules: design doc + spec; done = tests green`); }
      if (t.status === "verifying") { s.phase = "verify"; ev("test", t.id, t.resource === "isolated" ? `harness in own Studio :${t.port}` : "waiting for the shared Studio"); ev("report", t.id, "implementation done, verifying"); }
      if (t.status === "green") { t.tests = "[CARTEST] pass=52 fail=0"; t.audit = "PASS"; ev("report", t.id, "RULES AUDIT: PASS"); }
      if (t.status === "merged") { s.phase = "land"; ev("merge", t.id, `merged ${t.branch} --no-ff`); s.goals[0].deliverables.find((x) => x.id === t.deliverable).status = "done"; }
    }
    t.changed = t.status === "queued" ? [] : t.files;
    t.merge = OPEN.includes(t.status) && t.status !== "queued" ? "clean" : undefined;
    s.queue = s.tasks.filter((x) => x.resource === "queued" && x.status === "verifying").map((x) => x.id);
    const ui = s.tasks.find((x) => x.id === "shop-ui");
    const overlapping = s.tick % 24 > 18 && ui.status === "running";
    if (overlapping) { ui.changed = [...ui.files, "src/client/EngineAudio.luau"]; }
    if (s.tick % 7 === 0) s.messages.push({ id: `d${s.n++}`, at: now(), from: "codex", to: "claude", text: "I'm on the loser screen; leaving RacerUiController to you." });
    if (s.tick % 11 === 0) { ev("ask", null, "Track 7 lap time is not in the design doc. What target?"); s.phase = "blocked"; }
    if (s.tick % 11 === 2) s.messages.push({ id: `d${s.n++}`, at: now(), from: "user", to: "claude", text: "Target 45 s, add it to TRACKS spec." });
    const tasks = s.tasks.map((x) => ({ ...x }));
    const overlaps = overlapping && OPEN.includes(s.tasks[1].status) ? [{ a: "shop-ui", b: "engine-sfx", files: ["src/client/EngineAudio.luau"] }] : [];
    return { orchestrator: { active: true, phase: s.phase, tick: s.tick, updated: now(), age: 0, context: { pct: (s.tick % 30) / 36, tokens: 0, window: 200000, at: now() } }, goals: s.goals, tasks, overlaps,
      studioQueue: s.queue, board: { doing: [{ id: "boost-vfx", title: "Boost trail VFX", taskStatus: tasks[0].status }, { id: "loser", title: "Loser screen recap", owner: "Codex" }],
        next: [{ id: "quests", title: "Daily Quest System" }, ...(s.tick % 10 > 4 ? [{ id: "pets", title: "Pet companions" }] : [])] },
      events: s.events.slice(-200), outside: [], branch: "feature/alex/juice",
      bus: { messages: s.messages.slice(-80), status: { codex: { task: "Loser screen recap", files: ["src/client/NpcRacerView.luau"] } } } };
  };
})();

// ---------------------------------------------------------------------------------------------------------------

async function tick() {
  if (document.hidden) return;
  try {
    const d = DEMO ? demo() : await (await fetch("/api/flow", { cache: "no-store" })).json();
    header(d);
    board(d);
    apply(d);
    communicate(d);
  } catch (e) {
    $("updated").textContent = `dashboard server: ${e.message}`;
  }
}

requestAnimationFrame(frame);
tick();
setInterval(tick, DEMO ? 1800 : POLL_MS);
document.addEventListener("visibilitychange", tick);
