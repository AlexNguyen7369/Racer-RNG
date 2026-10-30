# Quests

Status: BUILT starter system. Quests are server-authoritative and use UTC periods.

Daily quests reset at UTC midnight. Weekly quests reset at the UTC week boundary. The initial content tracks races,
rolls, new car discoveries, and potion use. Completion rewards are existing potion items only; quests do not create a
new currency or bypass the game's money rules.

The client receives progress through player attributes and may request a claim by quest ID and period. The server
validates the period, progress, and one-claim rule, then grants the configured potion through `BoostService`.

## Rotation (owner 2026-10-30)

Design doc: `GAME_DESIGN_REQUIREMENTS.md`, "Progression". Every pool entry, target, reward and count below is a
*placeholder* (tunable); the rotation rule itself is fixed.

- Each period (UTC day for daily, UTC week for weekly, `QuestConfig.PeriodKey`) the server picks **3** quests
  (`QuestConfig.PICK`, placeholder) from that period's pool. The pick is seeded only by the period key (weekly
  seed = key + 1,000,000, an implementation detail), using `Random.new(seed)` to shuffle the pool and take the first 3, so every player and
  every server gets the same 3 for the same period. Function: `QuestConfig.Active(weekly, now) -> { quest, ... }`.
- Progress and claims count only for the 3 active quests; a claim for a quest not active this period is rejected.
- Metrics stay the existing four: `Races`, `Rolls`, `Discoveries`, `Potions`. Rewards stay existing potion items
  only (never Money). Quest `Id`s are permanent save keys: never rename or reuse one.

Daily pool (placeholders):

| Id | Metric | Target | Reward |
|---|---|---|---|
| `daily_races` | Races | 3 | LuckI x1 |
| `daily_rolls` | Rolls | 5 | MoneyI x1 |
| `daily_discover` | Discoveries | 1 | SpeedI x1 |
| `daily_races_long` | Races | 8 | SpeedI x1 |
| `daily_rolls_long` | Rolls | 25 | LuckI x1 |
| `daily_potions` | Potions | 1 | MoneyI x1 |

Weekly pool (placeholders):

| Id | Metric | Target | Reward |
|---|---|---|---|
| `weekly_races` | Races | 20 | MoneyI x2 |
| `weekly_discover` | Discoveries | 5 | LuckI x2 |
| `weekly_potions` | Potions | 3 | SpeedI x2 |
| `weekly_races_long` | Races | 50 | LuckI x2 |
| `weekly_rolls` | Rolls | 150 | MoneyI x2 |
| `weekly_discover_long` | Discoveries | 10 | SpeedI x2 |
