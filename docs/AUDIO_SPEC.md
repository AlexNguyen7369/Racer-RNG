# Audio spec

Rule source: `docs/GAME_DESIGN_REQUIREMENTS.md`, "Playtest follow-ups" (Sound), proposed by Vic2CS 2026-11-20,
not yet reviewed by the owner. Every id, volume and pitch is a placeholder.

## Files

- `src/shared/SoundConfig.luau`: every sound id, volume, pitch and the engine speed-to-pitch range. Each id has a
  comment naming the asset and its creator. Change sounds here only.
- `src/client/GameAudio.client.luau`: all playback. Nothing plays on the server, so each player hears only their own
  game.

## What plays when

| Sound | When | Where |
|---|---|---|
| Engine loop | The local player sits in their own car (`IsCar`) while auto racing (`AutoRacing`, or the car's `AutoRace` for a duel). Fades in and out over `ENGINE_FADE_SECONDS`. Pitch goes from `ENGINE_PITCH_MIN` to `ENGINE_PITCH_MAX` as the car's actual speed (`AssemblyLinearVelocity` magnitude) goes from `ENGINE_SPEED_MIN` to `ENGINE_SPEED_MAX`. | 3D, on the car's chassis, this client only. Other players' cars are silent. |
| Nitro whoosh | The player attribute `NitroUntil` changes to a time in the future (a boost started, `Server/NitroService`). | 2D |
| Perfect chime | `NitroPresses` changes and `NitroGrade` is `"Perfect"`. | 2D |
| Miss tick | `NitroPresses` changes and `NitroGrade` is `"Miss"`. Soft. | 2D |
| Win stinger | `Remotes.NpcRace` event `{ Type = "Result", Result = "Win" }`. Stops a playing lose stinger. | 2D |
| Lose stinger | `Remotes.NpcRace` event `{ Type = "Result", Result = "Lose" }`. Stops a playing win stinger. | 2D |
| Roll reveal | A `Remotes.RollResult` with `isNew` or `emphasized` lands in the roll animation: `RollToast/Toast` attribute `Phase` becomes `"Land"` with that `RollId`. Without the card it plays `RollAnimConfig.POP + SPIN` seconds after the result. | 2D |
| Music | One calm track, looped, low volume, from join. | 2D |

The same one-shot never restarts within `MIN_REPEAT_SECONDS`.

## Volume and the Settings Sound toggle

- Every sound goes through the SoundGroup `SoundService.GameAudio` (`MASTER_VOLUME`), with child groups `Music`,
  `Sfx` and `Engine`. The engine fade uses the `Engine` group volume.
- The Settings Sound row (`docs/HUD_LAYOUT_SPEC.md` section 4) is session-local. `Client/RollToast/RacerUiController`
  sets the Volume of every `Sound` in the game to 0 when it is OFF and puts back the volume it first saw when it is
  ON again. That covers these sounds too. `GameAudio` sets a Sound's Volume once, before parenting it, and never
  writes it again, so the restore keeps working.
- `GameAudio` also mutes `GameAudio` (volume 0) while the player attribute `SoundMuted` is `true`. The toggle
  should set that attribute (one line in `RacerUiController`'s toggle handler) so one volume governs all game audio.

## Licensing

Only audio Roblox provides or has licensed for every experience is used:

- **Roblox Resources** (Roblox's own template-asset group),
- **ProSoundEffects** and **APMOfficial** (the Pro Sound Effects and APM Music libraries Roblox licensed for the
  Creator Store),
- `rbxasset://` sound files that ship with the Roblox client.

Each id was checked to load in the dev place (Edit mode, `ContentProvider:PreloadAsync`, `TimeLength > 0`). A new id
must pass the same check: private audio from other creators does not play in this experience.
