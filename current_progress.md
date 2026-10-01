# Current Progress

## Completed
1. 2026-10-01 — Alex Nguyen — Shared the Claude Code tooling with collaborators: test/compat subagents, slash commands, hooks and the main-branch compatibility gate (/compat-check, tools/compat.py, .githooks/pre-push).

## What's next
**Get the uncommitted NPC racer and gacha work to an ALL GREEN /compat-check (one session in Studio at a time), then commit it.**

**Why this is next:** nothing can be pushed to main until /compat-check is green for that exact code, and the NPC and gacha features (plus the race, flip_recovery and auto_toggle fixes) are still unverified in src/.
