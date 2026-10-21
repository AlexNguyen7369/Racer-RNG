# Race progress map and personal bests

## Contract

During an NPC auto-race, the HUD shows a non-interactive, current-track-only card in
the top-right. It contains a stylized top-down route, a `YOU` dot using the player's
avatar headshot (with a colored fallback), an `NPC` dot, an `AHEAD`, `BEHIND`, or
`EVEN` status, the current track title, `TIME mm:ss.cc`, and `PB mm:ss.cc` (or
`PB --`). The card is hidden when no NPC track is active, on reset, stop, result
completion, and while the roll showcase is visible. It does not apply to duels.

The route is normalized from the current track's ordered path using X/Z for display.
Progress is still ordered 3D path distance, so hills and overlapping top-down
sections remain unambiguous. A difference below 1% of the track is `EVEN`.

## Timing and authority

`NpcRace.Start` includes `ServerStart` and the player's saved `BestTime` for that
track. The client displays elapsed time from `Workspace:GetServerTimeNow()` and
never sends per-frame progress. The server decides every result. A personal best is
recorded only after an authoritative NPC-race win; losses, stops, resets, duels and
incomplete races never write one. A faster positive finite time replaces the old
record.

## Saved data

VERSION 11 adds `RaceBestTimes`, a table keyed by string track number. Values are
positive finite seconds. Missing, malformed, infinite, or non-positive values are
discarded; VERSION 10 and older saves default to an empty table. The data is private
to each player and is never broadcast to other players.

## Layout

The desktop card is approximately 252x174 px below the Daily/Quests/Market pills;
the phone card is approximately 190x128 px and uses the HUD's responsive layout.
The card is presentation-only and must not overlap existing controls or panels.
