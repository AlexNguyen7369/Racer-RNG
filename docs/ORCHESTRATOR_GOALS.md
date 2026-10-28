# Orchestrator goals

The owner's end goals for `/orchestrate` (skill `~/.claude/skills/orchestrator`, config `.claude/orchestrator.md`).
Only the owner adds, changes or closes a goal. The orchestrator asks, writes the answers here and dates them.
Game rules stay in `docs/GAME_DESIGN_REQUIREMENTS.md` and the specs; this file only says what to deliver and in what order.

Owner answers 2026-10-28:
- Goals: all four, plus suggested improvements in parallel.
- Priority: test debt first.
- Done: full green.
- Deadline: none.

## Global

- **Definition of done (every deliverable):**
  - the feature's scenarios are green;
  - the full harness gives `[CARTEST] END fail=0`;
  - the full UI suite gives `[UITEST] END fail=0`;
  - `rules-auditor` says `RULES AUDIT: PASS`.
  - A goal is done when `/compat-check` is green on its integration branch.
- **Order:** the goals below, top to bottom. A later goal's task may run in parallel only when its files do not overlap any open task.
- **Out of scope:**
  - nothing beyond the hard rules: no edits to `PhysicsTargets`, no rule changes without the owner, no pushes or merges to `main`;
  - merging an integration branch into `main` is the owner's call.

## test-debt: Test suites trustworthy
Status: active
Priority: 1
Owner-confirmed: pending
Branch: feature/alex/test-debt (created on the first task)
Deliverables:
- td1 | UI tests match Isaac's inventory / upgrade-tree UI (todo `isaac-ui-tests-reconcile`) | UiSpec/UiScenarios updated by ui-test-writer; [UITEST] END fail=0
- td2 | Checkpoint tests (todo `checkpoint-tests`) | `checkpoint` harness scenario green; CheckpointUi in UiSpec; [UITEST] END fail=0
- td3 | roll_odds fixtures close open panels first (todo `roll-odds-fixture-panels`) | every roll_odds_* green
- td4 | DailyBoosts Status does not overlap on phones (todo `daily-status-phone-overlap`, bug 3a6d9cb3) | ui overlap checks green at 844x390 and 667x375; bug marked fixed
- td5 | Shop/Market panels no longer cover the compact roll (todo `band-vs-compact-roll`) | ui_hitboxes button_topmost_at_centre_shop_open / market_open green
- td6 | Never-run UI suites pass: ui_upgrades, ui_reduced_motion, ui_safe_insets, ui_panel_focus, ui_speed_float (todo `best-roll-ui-suite`, handoff) | each green in a live run; manual ones (ui_safe_insets_notch, ui_gamepad_focus) checked by ui-tester
- td7 | NPC client view and LoserScreen checked live (todo `npc-loser-live`) | ui-tester + multiplayer-tester PASS
Out of scope: changing what a test checks to make it pass (only test-writer / ui-test-writer write tests, and never looser)

## world1-ship: Ship-ready World 1
Status: active
Priority: 2
Owner-confirmed: pending
Branch: feature/alex/world1-ship (created on the first task)
Deliverables:
- w1a | Payout + price curves, Speed float landed (todo `f65d9146`) | economy + ui_speed_float green; pad billboard short-format question answered by owner
- w1b | Speed gain rebalance + rebirth rev 3 landed (todos `speed-gain-rebalance`, handoff rebirth rev 2/3) | rebirth, gacha, economy scenarios green
- w1c | Cruise cap from the speed probe (todo `cruise-cap`, WORLDS_SPEC 1) | speed_probe finds the cap; RaceConfig.MAX_CRUISE set; high_multi / max_speed green; NPC ladder under the cap
- w1d | Giant scenery in every biome (todo `giant-biome-scenery`, bugs ab037b16, b99e2c0b) | environment scenario green; both bugs fixed
- w1e | UI visual pass + HUD redesign verified on phone (todos `5eb5d552`, `hud-redesign`, `ui-world-dim-only`, `checkpoint-quest-panel-style`) | [UITEST] END fail=0 at desktop and phone viewports
- w1f | Shop redesign + gifting finished (todos `shop-redesign`, `shop-gifting`) | shop_purchases, gifting, gift_mailbox green; gift-picker UI pass
Out of scope: World 2 content

## world2: World 2 split
Status: active
Priority: 3
Owner-confirmed: pending
Branch: feature/alex/world2 (created on the first task)
Deliverables:
- w2a | World 1 / World 2 split per docs/WORLDS_SPEC.md (todo `worlds-split`) | WorldConfig, per-world TrackRegistry, PlayerData VERSION 13, WorldService portal + teleport; data, rebirth and new world scenarios green
- w2b | Balance sim: World 1 ~30 h, World 2 ~35 h (todo `balance-sim`) | tools/balance_sim.py output; owner approves the hour table
Out of scope: anything WORLDS_SPEC does not state (asked, not guessed)

## new-features: New player features
Status: active
Priority: 4
Owner-confirmed: pending
Branch: feature/alex/new-features (created on the first task)
Deliverables (each one is blocked until the owner writes its rule into the design doc and a spec):
- nf1 | Daily quest system (todo `9c8021bf`) | spec written by owner; quest scenarios + UI tests green
- nf2 | Redeem codes in the Shop (todo `6f721034`; may overlap with the codes in `shop-redesign`) | spec written by owner; codes scenario green
- nf3 | Friends-in-server boost, +10% luck and Money per friend up to +40% (todo `ee591f0e`) | spec written by owner; gacha / economy scenarios green
Out of scope: monetization changes not in a spec

## improvements: Suggested features, optimizations and fixes (in parallel)
Status: active
Priority: parallel (files never overlap a higher-priority open task)
Owner-confirmed: pending
Branch: feature/alex/improvements (created on the first approved item)
Deliverables:
- The orchestrator proposes items from `tools/dashboard/data/suggestions.json`, open bugs in `bugs.json`, and performance / code-quality audits, through the owner channel.
- An item becomes a deliverable here only after the owner approves it. The orchestrator never adds one itself.
Out of scope: anything not approved
