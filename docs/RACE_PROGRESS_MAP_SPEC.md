# Race progress map and personal bests

## Contract

During an NPC auto-race, the HUD shows a non-interactive, current-track-only
transparent route icon in the top-right. It contains a stylized top-down route, a `YOU` dot using the player's
avatar headshot (with a colored fallback), an `NPC` dot, an `AHEAD`, `BEHIND`, or
`EVEN` status, the current track title, `TIME mm:ss.cc`, and `PB mm:ss.cc` (or
`PB --`). The icon is hidden when no NPC track is active, on reset, stop, result
completion, and while the roll showcase is visible. It does not apply to duels.

The route is normalized from the current track's ordered path using X/Z for display.
Progress is still ordered 3D path distance, so hills and overlapping top-down
sections remain unambiguous. A difference below 1% of the track is `EVEN`.
The route preserves its aspect ratio and leaves a margin for the markers. Each
racer is projected onto its own lane in 3D; a forward distance window and previous
progress disambiguate a loop's repeated positions. Both dots use the same displayed
route, and the NPC pose comes from `NpcRacer.PoseAt` at the server-clock elapsed time.
The displayed route is a heading-up tactical view that follows the player's car,
keeps `YOU` at the centre, and zooms to a bounded local world span. Route segments
outside the viewport are clipped. An NPC outside the view remains visible as an
edge-clamped marker along the direction it lies from the player.

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
Keys must be canonical strings for a numbered track in `TrackRegistry`; unknown
tracks, leading zeros, numeric keys and non-integer keys are discarded on load.

## Layout

The desktop route icon is approximately 360x260 px below the Daily/Quests/Market
pills; the phone icon is approximately 250x184 px and uses the HUD's responsive
layout. The route itself has no card, fill, shadow, or border; the title, status,
timer, and PB are transparent text overlays around the enlarged route. The icon is
presentation-only and must not overlap existing controls or panels.
The panel band reserves room for the visible map. On short screens the map shifts
left of the Shop tile if necessary. A roll showcase temporarily suppresses the
icon; closing it restores the active track with its continuing server-clock timer.
