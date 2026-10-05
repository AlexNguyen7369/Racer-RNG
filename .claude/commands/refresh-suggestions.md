---
description: Re-research trending Roblox games and refresh the dashboard's feature suggestions (tools/dashboard/data/suggestions.json).
argument-hint: "[focus, optional, e.g. 'monetisation' or 'social']"
---

Refresh the suggested features shown in the agent dashboard. Focus (optional): $ARGUMENTS

1. Read `tools/dashboard/data/suggestions.json`, `tools/dashboard/data/todo.json`, CLAUDE.md and `docs/*_SPEC.md` so you know the game and what is already planned.
2. WebSearch for the Roblox games trending right now (top concurrent players, new breakout games, RNG / idle / racing / tycoon / simulator games) and the mechanics driving them. Use the current month in the queries.
3. Write 10-15 ideas that fit THIS game (auto-racing idle game with a Speed stat, NPC races, banked money, car gacha + index, stat points). Each item: `id` (kebab-case, never reuse one that exists), `title`, `inspiredBy` (the real game(s)), `description`, `fit` (why it fits here, which existing systems it plugs into), `effort` (S/M/L), `dependsOn`, `status: "open"`.
4. Keep every item whose `status` is `added` or `dismissed` exactly as it is (a person decided it). Replace only `open` items, and do not re-suggest a dismissed idea.
5. Set `researched` to today's date and `note` to the games the trend snapshot came from. Validate the JSON (`python3 -m json.tool`).
6. Tell the user what is new, with the sources you used.
