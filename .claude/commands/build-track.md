---
description: Build a race track through the full test-first subagent loop. Runs until every test is green.
argument-hint: "<track name> <brief>, e.g. 'Hairpin sprint with three tight-ish corners'"
---

Build this track using the loop below: $ARGUMENTS

This is mandatory for every track that is created or changed. The loop ends only when the FULL suite is green.

Every track must satisfy the **Track rules** and **Auto race and saved stats** in `CLAUDE.md`: numbered; separate start and finish; finish is the connector to the next track; WIDE checkpoint area; the yellow neon winnings pad sits on the LEFT apron beside the racing line and pays `$` (Number x CASH_PER_TRACK) into the player's saved Money stat when the car passes it; proximity `$` text; and the car AUTO-RACES the track along `RacePath` (right-hand lane) at the speed from the player's Speed stat, which grows passively while it drives, without ever flipping and staying on its path (see the stability rules in `CLAUDE.md`). Give `Number` and the previous track (whose finish this one starts from) in the brief. Tell `test-writer` to test all of it (track geometry, checkpoint, `race` scenario across the chain, stat gain), and `track-designer` to end the previous track's finish and this track's start in a compatible straight-into-straight joint (last straight >= 40 studs, clear of walls and turns) that does not overlap earlier tracks.

Agents (`.claude/agents/`): `test-writer`, `track-designer`, `physics-tuner`, `physics-tester`. Race/stat/money/checkpoint code (`TrackBuilder`, `PathDriver`, `RaceService`, `PlayerData`, `MoneyService`) has no agent of its own: the caller implements it AFTER the red run, then `test-writer` audits it like any other implementation round.
Only one `physics-tester` may run at a time because there is one Studio. Confirm Studio is open and the Rojo plugin is connected first (`mcp__Roblox_Studio__list_roblox_studios` must list a Studio). If not, stop and tell the user.

## Phase 1: Red
1. Launch `test-writer` in WRITE mode with the brief. It creates `src/server/CarTest/TrackTests/<Track>.luau`.
2. Launch `physics-tester` for the whole suite. The new `track:<Track>` test MUST fail (`track_exists`). If it passes, the test is wrong: send it back to `test-writer`.

## Phase 2: Green loop (repeat)
Each round:
1. Launch `track-designer` with the brief and the latest failing checks (round 1: create the track). If the report includes car-side failures, launch `physics-tuner` in parallel: they own different files.
2. Launch `test-writer` in AUDIT mode. If it finds a weakened test, restore it and re-run the round.
3. Launch `physics-tester` on the FULL suite (every scenario, not just the new one, so a fix cannot silently break another test).
4. Read the report:
   - `[CARTEST] END fail=0` and every scenario listed as pass: go to Phase 3.
   - Track failures (`track_valid`, length, radius, off-track, lap time): next round goes to `track-designer`.
   - Car failures (`static_settle`, `accel`, `brake`, `skidpad`, flips or stuck on several tracks): next round goes to `physics-tuner`.
   - Race failures (`race` scenario: speed not held, missed pad, off-track, flipped at the joint): a track shape problem goes to `track-designer`; a driver problem (`PathDriver`, `RaceService`) is fixed by the caller and audited next round.
   - A failure that appears only in the first scenarios of a cold-start run and disappears on warm re-runs is a start-up transient: check the harness `WARMUP` line and `max_dt` before touching the car.
   - Harness/environment failure (Studio closed, Rojo disconnected, script error): stop and tell the user.
5. Log one line per round: round number, what changed (old -> new), which checks are still red.

There is no round limit. Progress guard: if the set of failing checks AND their values are identical three rounds in a row, tell the agent to change strategy (bigger change, different knob, redesign the segment). If it is still identical three rounds after that, stop and report to the user with the evidence instead of grinding forever.

## Phase 3: Exit
Exit only when the last full run ended `fail=0`. Then update `context/ProjectContext.luau` (change log, dated test results, known issues) and show the user the list of changes and where the context is held (`ServerScriptService > ProjectContext`). Then:
- Ask `test-writer` for a final AUDIT (suite intact).
- Report: track name, `Number`, length, lap time, where its Start joins the previous finish, every scenario PASS, and the list of rounds with what changed.
- Do not exit on "almost", on a partial run, or on a run that skipped a scenario.

Rules:
- Never edit test files or `PhysicsTargets.luau` to make a run pass. Only `test-writer` edits tests, and only to add or tighten.
- Pass each agent only what it needs: the brief, the exact failing check names and values, and the files it owns.
