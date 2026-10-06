# Admin commands: design spec (contract for tests and implementation)

User brief (2026-10-01): chat admin commands so the owner can set stats while testing instead of using the
Studio command bar. Server-only; non-admins can never change anything.

## Modules and API

### `src/server/AdminConfig.luau` (editable)
- `UserIds = { }`: extra admin Roblox UserIds (the owner adds theirs here).
- `GROUP_MIN_RANK = 255`: for a group-owned place, members at or above this rank are admins.
- `ALLOW_IN_STUDIO = true`: every player is an admin while running in Studio.
- `MAX_ROLLS = 100`: most `/roll` may do at once.

### `src/server/AdminService.luau`
- `AdminService.AllowStudio` (boolean, starts as `AdminConfig.ALLOW_IN_STUDIO`; tests may set it to `false`
  and restore it).
- `AdminService.IsAdmin(player) -> boolean`. True when any of:
  - the player's UserId is in `AdminConfig.UserIds`;
  - `game.CreatorType` is User and the UserId equals `game.CreatorId` (and `CreatorId ~= 0`);
  - `game.CreatorType` is Group and `player:GetRankInGroup(game.CreatorId) >= GROUP_MIN_RANK` (pcall, cached);
  - `AdminService.AllowStudio` and `RunService:IsStudio()`.
  UserId of a non-Player test stand-in (a Folder) is its `UserId` attribute. No UserId -> only the Studio rule.
  `nil` or a destroyed instance -> false.
- `AdminService.RunOf(player)`: the player's race run, defaults to `CarService.GetRun(player)`. Tests may
  replace the function and restore it.
- `AdminService.Parse(text) -> name, args` (lower-case command name without "/", array of string args), or
  nil when `text` is not a string starting with "/".
- `AdminService.ParseNumber(s) -> number | nil`: accepts `"1500"`, `"1,500"`, `"1.5k"`, `"2m"`, `"3b"`, `"1t"`,
  `"1e6"` (suffixes case-insensitive: k 1e3, m 1e6, b 1e9, t 1e12). NaN, inf, empty and junk -> nil.
- `AdminService.Run(sender, text) -> ok: boolean, message: string`. Runs one command for `sender`.
  - Not an admin: returns `false` and changes NOTHING (no stat, attribute, car or run touched).
  - Not a command / unknown command / bad arguments: `false`, a message with the usage. Nothing changes.
  - Success: `true`, a short human message. Also `print("[ADMIN] " .. senderName .. ": " .. text)`.
  - Never errors (internally pcall'd); a failure inside returns `false`.
- `AdminService.Commands`: table `name -> { Usage = string, Help = string, ... }` (used by `/help`).
- `AdminService.Start()`: creates `Remotes.AdminMessage` (RemoteEvent, server -> sender only) and binds chat:
  with `TextChatService.ChatVersion == TextChatService` it creates one `TextChatCommand` per command in a
  folder `TextChatService.AdminCommands` (`PrimaryAlias = "/<name>"`, `AutocompleteVisible = false`) and runs
  `Run` from `Triggered` (sender = `Players:GetPlayerByUserId(source.UserId)`); with legacy chat it uses
  `player.Chatted`. The reply goes back with `AdminMessage:FireClient(sender, message)`, never to anyone else.
  Called from `Main` after the other services.

### Targets
The last argument may name a target: `me` (default, the sender), `all` (every player in `Players`), or the
start of a player's Name or DisplayName (case-insensitive; exactly one match required, otherwise `false`).
A command with no target argument acts on the sender. The sender may be a test stand-in; `me` works for it.

### Commands
| Command | Effect on each target |
|---|---|
| `/help` | Lists every command's usage. `true`. |
| `/money <n> [target]` | `leaderstats.Money.Value = floor(n)`, n in [0, 1e15]; negative / junk -> `false`. |
| `/addmoney <n> [target]` | Money += floor(n) (n may be negative; result clamped at 0). |
| `/speed <n> [target]` | `leaderstats.Speed.Value` = n clamped to [0, `RaceConfig.MAX_STAT`], 3 decimals. |
| `/addspeed <n> [target]` | Speed += n, same clamp. |
| `/give <carId\|all> [target]` | `GachaService.Grant` the car (or every rollable car). Unknown / starter id -> `false`. StatPoints update as usual. |
| `/equip <carId> [target]` | `GachaService.Equip`; not owned / unknown -> `false`. |
| `/roll [count] [target]` | `GachaService.Roll` count times (default 1, 1..`MAX_ROLLS`). |
| `/wipe [target]` | Money 0, Speed 0, `GachaService.Apply(player, {})` (no cars, no allocations, Rolls 0, starter equipped), `UpgradeService.Apply(player, {})` (no upgrade tiles, BestTrack 0, TurboCount 0). |
| `/tp <trackNumber> [target]` | `RunOf(target):JumpToTrack(n)`; no run or bad number -> `false`. |

### `RaceService` run: `run:JumpToTrack(number) -> boolean`
- `number` must be the `Number` of a track in the run's route (`route.Tracks`), else returns false, nothing changes.
- Puts the car at that track's start (`route.Tracks[i].StartIndex`, `START_AHEAD` studs in, lane, upright,
  facing along the path) and sets the driver index there. Not finished, not held.
- Pads of tracks BEFORE it count as already paid for this pass (jumping never pays anything); the target track's
  pad and later ones pay as normal.
- NPC mode: any race in progress is dropped (no Result, no payout) and a new `Start` for that track follows.
- Stability rules unchanged (no flip, stays on the path after the jump).

### Client: `src/client/AdminChat.client.luau`
Shows each `Remotes.AdminMessage` text as a system message in the chat
(`TextChatService.TextChannels.RBXSystem:DisplaySystemMessage`), or in the output with legacy chat.

### Security
- Every decision is server-side. The only remote is server -> client feedback.
- Non-admins (including in a live server) can run nothing; their `/money` etc. are swallowed by the
  TextChatCommand and answered with "not an admin".
