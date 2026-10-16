# Duels: player vs player (contract for tests and implementation)

Owner brief (2026-10-12): a separate multiplayer feature. A player requests a duel against another player; the other
player accepts or declines. The challenger is asked at once which track to race, and both players must have unlocked
that track. No stake. Design rule: `docs/GAME_DESIGN_REQUIREMENTS.md`, "Duels (player vs player)".

Status: BUILT 2026-10-13 (server and client source present; full CarTest duel scenario 191/191 passed).
Live UI and multiplayer flow validation remain pending. This file remains the implementation contract.

## 1. Rules

1. **Request.** Every on-foot character carries a server-made `ProximityPrompt` named `DuelPrompt` ("Duel"). Player A
   triggering the prompt on player B's character is a request from A to B. The server accepts the request only when,
   for BOTH players: the save is loaded (`DataLoaded`, not `DataFailed`), the character is alive and on foot
   (`AutoRacing` false, `RaceEvent == "Off"`), and the player is in no duel and no pending request. A also needs
   `DuelConfig.REQUEST_COOLDOWN` seconds since their last request. A refused request changes nothing and tells A why.
2. **Track pick.** A is asked at once which track to race. The choices are the tracks both players unlocked:
   `1 .. min(Unlocked(A), Unlocked(B))`, where `Unlocked(p) = min(BestTrack(p) + 1, number of tracks)` (Track 1 is
   always unlocked). The server computes the list, sends it, and validates A's pick against a freshly computed list.
   No pick within `DuelConfig.PICK_TIMEOUT` cancels the request.
3. **Accept / decline.** B sees who challenges and on which track, with Accept and Decline. No answer within
   `DuelConfig.INVITE_TIMEOUT` is a decline. A is told the result. The conditions of rule 1 are checked again on accept.
4. **Race.** Both players get a car at the start of the picked track, through the normal start event
   (`docs/SPAWN_AND_ROLLS_SPEC.md` section 2: anchored car, seated, then released). After a
   `DuelConfig.COUNTDOWN` both cars are released in the same server step and auto-race that ONE track. The first
   car whose path index reaches the track's `FinishIndex` wins; equal step = the lower finish time, then a draw.
   The server decides it. Player cars are in the `Cars` collision group and pass through each other.
5. **No stake, no Money.** A duel run has no NPC, pays no pad, has no bank (`Unbanked` stays 0) and changes no
   `leaderstats.Money`. Speed gain continues as in any race. The stability rules of every run apply (no flip, on
   the path).
6. **End.** Both cars are removed and both players stand at the walk spawn. The winner's `DuelWins` (player
   attribute, saved) goes up by one; a draw changes nothing. Stop Auto, death or leaving during the countdown or
   the race is a forfeit: the other player wins. A duel that neither car finishes within `DuelConfig.RACE_TIMEOUT`
   is a draw.

## 2. Numbers (`src/shared/DuelConfig.luau`)

| Constant | Value |
|---|---|
| `REQUEST_COOLDOWN` | 10 s |
| `PICK_TIMEOUT` | 15 s |
| `INVITE_TIMEOUT` | 15 s |
| `COUNTDOWN` | 3 s |
| `RACE_TIMEOUT` | 180 s |
| `PROMPT_DISTANCE` | 10 studs |

## 3. Modules

- `Server/DuelService`: `Start()`, `Request(a, b) -> ok, reason`, `Pick(a, trackNumber) -> ok, reason`,
  `Respond(b, accept) -> ok, reason`, `StateOf(player) -> "None" | "Picking" | "Invited" | "Countdown" | "Racing"`,
  `Unlocked(player) -> number`, `Choices(a, b) -> { number, ... }`. One state table per pair; cleaned on leave.
- `RaceService.NewRun(car, route, player, options)`: `options.Duel = { Track = n, OnFinish = fn(run, time) }` is a
  non-NPC run that starts on track n, pays no pad and ends at that track's `FinishIndex`.
- `Remotes.Duel` (RemoteEvent). Server -> one client: `{ Type = "PickTrack", Opponent, Tracks }`,
  `{ Type = "Invite", Opponent, Track }`, `{ Type = "Countdown", Track, ServerStart }`,
  `{ Type = "Result", Result = "Win" | "Lose" | "Draw", Track, Time, OpponentTime }`,
  `{ Type = "Cancelled", Reason }`. Client -> server: `("Pick", trackNumber)`, `("Respond", boolean)`; any other
  payload is ignored. Rate limit: one message per 0.25 s per player.
- `Client/DuelUi.client.luau`: ScreenGui `DuelUi` with the track-pick modal, the invite modal, the countdown and
  the result toast. It joins `Client/PanelSwitch` (opening it closes the Index / Stats / Settings / Rebirth panels).
- Save (`PlayerData` VERSION 8): `DuelWins` (integer >= 0).

## 4. Tests

- `duel` harness scenario: every refusal of rule 1, the unlock list of rule 2 and a rejected out-of-list pick, both
  timeouts, decline, forfeit by stop and by leaving, winner by finish order, Money and `Unbanked` unchanged for both
  players, `DuelWins` saved and loaded, stability rules on both cars.
- UI tests (`ui-test-writer`): the two modals follow the overlap, hitbox and "does what it shows" rules.
- `multiplayer-tester`: the real two-player flow in Studio.
