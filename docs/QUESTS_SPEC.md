# Quests

Status: BUILT starter system. Quests are server-authoritative and use UTC periods.

Daily quests reset at UTC midnight. Weekly quests reset at the UTC week boundary. The initial content tracks races,
rolls, new car discoveries, and potion use. Completion rewards are existing potion items only; quests do not create a
new currency or bypass the game's money rules.

The client receives progress through player attributes and may request a claim by quest ID and period. The server
validates the period, progress, and one-claim rule, then grants the configured potion through `BoostService`.
