---
description: Start a new feature on its own labelled branch (feature/<you>/<name> from origin/main, pushed to GitHub, linked to a TODO card).
argument-hint: "<title> [-- detail]"
---

Start a feature branch for: $ARGUMENTS

1. Split the arguments at ` -- ` into a title and an optional detail. If a TODO item in `tools/dashboard/data/todo.json` already describes this feature and has no `branch`, use its id (`--todo ID`).
2. Run `python3 tools/collab.py start "<title>" [--detail "<detail>"] [--todo ID]`. It fetches origin, creates `feature/<handle>/<slug>` from `origin/main` without touching the working tree, records who started it in the start commit's trailers, pushes it, and links the TODO card.
3. Report the branch name, whether it reached GitHub, and who it is labelled with. Do NOT switch branches yourself: if the user wants to work on it now, check `git status` first, and if tracked files are modified ask whether to commit or stash before `git switch <branch>` (Rojo would sync a mix of two branches into Studio).
4. If the person is not in `tools/dashboard/data/team.json`, tell them to add themselves (name, emails, github, handle).
