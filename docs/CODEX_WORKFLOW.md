# Codex Workspace Workflow

This is the project-local, portable subset of the workflows installed in the
shared Claude environment. It is intentionally adapted to this repository and
Codex's available tools; it is not a copy of Claude-only commands, hooks,
credentials, or MCP names.

## Session and collaboration

At the start of game work:

1. Read `AGENTS.md`, `CLAUDE.md`, `handoff.md`, and
   `context/ProjectContext.luau`.
2. Run `python3 tools/dashboard/agent_bus.py context --agent codex`.
3. Inspect the dashboard metadata and current TODO/test state before changing
   shared files.
4. Announce the task with `agent_bus.py status`; clear it when finished.
5. Check the collaborator's active files before editing. Re-read any overlapping
   file immediately before patching it.

Keep `handoff.md` factual: goal, active files, edits, failed attempts or
blockers, and exact resume steps. Do not claim a live test from another agent's
completion message. Before the final response, run the agent-bus context check
again so unread coordination messages are not left hidden.

## Lifecycle and scope gates

Treat the project as moving through these gates:

1. core loop and player goal;
2. prototype or focused feature slice;
3. representative vertical slice;
4. production implementation;
5. internal QA and security;
6. polish, balance, release, and live maintenance.

Do not scale content while the current slice lacks a clear first action,
server-authoritative value flow, save/security coverage, and a credible Studio
playtest. For broad planning requests, report the current gate, evidence,
missing exit criteria, next milestone, acceptance checks, and risks.

For a new feature, use the repository's design-doc-first rule: write or update
the design requirement and feature spec before implementation. For an existing
feature, treat the design document and feature spec as contracts; stop on a
conflict instead of silently choosing a value.

## Implementation ladder

After understanding the real code path, choose the smallest sound rung:

1. existing project helper or canonical layer;
2. Roblox/native platform behavior;
3. standard library or a small pure helper;
4. the minimum new module or instance hierarchy;
5. a focused test for logic with branches, loops, parsers, money, security, or
   other meaningful risk.

Do not add an abstraction, dependency, generated shell, or generalized mode
until the existing architecture and platform primitives are ruled out. This is
not code golf: retain validation, error handling, security, accessibility, and
the tests needed to prove behavior. Mark deliberate shortcuts with a brief
`shortcut:` comment only when the project owner has accepted the debt.

## Roblox architecture and security

- ServerScriptService owns game state, economy, persistence, and authority.
- ReplicatedStorage contains only shared code and assets that both sides need.
- StarterPlayer/StarterGui contain client controllers and presentation.
- Every client request is attacker-controlled: validate type, range, ownership,
  cooldown, and current state on the server.
- The client may request an action or display a result; it never grants money,
  items, progression, race outcomes, or save data.
- Disconnect connections and cancel/replace tweens when a UI or effect is
  destroyed or reopened.
- Preserve session locking and safe shutdown save behavior. Never introduce a
  raw overwrite path for player data.

Use the actual project tools: edit disk sources, sync with Rojo, use the Roblox
Studio MCP or CUA for live Studio work, and do not edit Rojo-synced scripts in
Studio. Detect the available live-control surface before promising a Studio
operation; if it is unavailable, report offline verification honestly.

## UI workflow

Before a non-trivial UI change, read the approved project UI spec and inspect
the existing visual language: fonts, palette, spacing, corners, strokes,
display order, safe-inset policy, and reusable components. Preserve the
authored hierarchy and make repeated content data-driven only where repetition
is real.

Design for narrow screens first, then verify desktop, phone landscape, portrait,
tablet-like, and controller focus where the feature supports them. Prefer
`Activated`, explicit selected/disabled/loading states, deliberate anchors and
layouts, bounded constraints, `AutomaticCanvasSize`, safe insets, and a clear
focus entry/exit path. Honor reduced motion and clean up lifecycle-owned
connections.

Verify the real UI in Studio: screenshots are evidence for visual claims,
console output is evidence for runtime claims, and UI harness output is evidence
for contract claims. A static compile or offline layout check does not replace a
live viewport check.

## VFX and asset workflow

For a new effect, define where it is seen, its intensity/timing curve, palette,
and layer budget before building. Prefer layered ParticleEmitters, Beams,
Trails, and authored mesh shapes over clusters of physical Parts. Keep effects
client-side for presentation; the server sends a small validated effect name
and transform, never damage or economy decisions through the effect path.

Preview and inspect at several moments and camera distances before uploading
assets. Upload only the settled batch, record its size and IDs, and keep the
source texture/mesh recipe and asset map in the project so it can be rebuilt.
Project-specific VFX lessons win over generic guidance and belong in the
project's VFX lessons file when one exists.

## Verification and review

Match verification to risk:

- source-only change: formatter/linter, compile/build, and focused tests;
- gameplay/economy/save change: focused harness plus relevant full scenario;
- UI change: tooling checks plus live viewport/device checks;
- track/car/physics change: required test-first loop and full stability suite;
- broad or cross-system change: compatibility gate, with exact suite output and
  fingerprint recorded.

Report what ran, what passed, what was not run, and why. Never turn a blocked
Studio session, stale screenshot, or another agent's report into a green result.

For a demanding maintainability review, inspect the whole changed flow rather
than only the diff. Prioritize structural regressions, duplicated helpers,
feature logic in the wrong layer, ad-hoc branches, unclear type boundaries,
partial updates, and files pushed past a healthy size. Look for a simpler
reframing that removes concepts; do not approve merely because the code works.

## Portable plugin practices

The shared installation currently includes these relevant ideas:

- VibeWise: separate user decisions from implementation details; use short
  design/build/implementation checkpoints when the user wants to learn or the
  architecture is materially ambiguous.
- Ponytail: inspect the existing code and platform primitives before adding
  dependencies or abstractions; keep the smallest solution that retains tests,
  security, accessibility, and error handling.
- Caveman: keep progress updates and command output concise, but preserve exact
  errors, paths, and verification evidence.
- Brag: treat launch/demo capture as a separate deliverable; do not mix it into
  ordinary implementation or claim a polished showcase without inspecting it.
- `rederive`: optional learning mode only. It writes under `.rederive/`, never
  edits product code, and should not be forced into ordinary bug fixes.
- `thermo-nuclear-code-quality-review`: optional strict review mode for explicit
  maintainability audits; it is not an automatic blocker for routine work.

Claude-only browser, computer-use, document, spreadsheet, and plugin-runtime
instructions are not imported here. Use Codex's native browser, CUA, filesystem,
and artifact skills when those tasks are explicitly requested.
