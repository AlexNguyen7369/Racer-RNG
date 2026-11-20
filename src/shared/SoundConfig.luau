--!nonstrict
-- Every game sound in one place (docs/AUDIO_SPEC.md). Client/GameAudio plays them; nothing else reads this.
-- All values are placeholders (design doc "Playtest follow-ups", Sound): tune freely.
--
-- Licensing: only Roblox-provided or Roblox-licensed audio from the Creator Store audio library.
--   Roblox Resources  = Roblox's own template-asset group (group 412659284).
--   ProSoundEffects   = Roblox-licensed Pro Sound Effects library (user 7462895450).
--   APMOfficial       = Roblox-licensed APM Music library (user 7462718749).
--   rbxasset://       = sound files that ship with the Roblox client.
-- Every id below was checked to load in the dev place (2026-11-20, Edit mode PreloadAsync, TimeLength > 0).
-- A swapped id must be checked the same way: private audio from other creators does not play in this experience.

export type SoundSpec = {
	Id: string,
	Volume: number,
	Pitch: number?, -- PlaybackSpeed (1 = as recorded)
	Looped: boolean?,
	MaxSeconds: number?, -- one-shots: stop after this many seconds (long stingers)
}

local SoundConfig = {}

-- Master volume of SoundService.GameAudio (the SoundGroup every game sound goes through)
SoundConfig.MASTER_VOLUME = 1
-- Sub-group volumes (children of GameAudio)
SoundConfig.MUSIC_VOLUME = 1
SoundConfig.SFX_VOLUME = 1
SoundConfig.ENGINE_VOLUME = 1

SoundConfig.Sounds = {
	-- Engine loop on the local player's own car. "Car-Engine-Loop" by Roblox Resources, 9.2 s, loopable.
	Engine = { Id = "rbxassetid://80317022777602", Volume = 0.18, Looped = true } :: SoundSpec,
	-- Nitro boost starts. "Whoosh By Fast Airy Swooshing Whipping Thuds (SFX)" by ProSoundEffects, 1.0 s.
	NitroWhoosh = { Id = "rbxassetid://9126229255", Volume = 0.45, Pitch = 1 } :: SoundSpec,
	-- A Perfect nitro press. "Early Bird - Hit1" by APMOfficial (APM Music), 2.6 s mallet hit.
	PerfectChime = { Id = "rbxassetid://9040476898", Volume = 0.4, Pitch = 1.05 } :: SoundSpec,
	-- A missed nitro press (soft tick). Client sound file volume_slider.ogg (ships with Roblox).
	MissTick = { Id = "rbxasset://sounds/volume_slider.ogg", Volume = 0.2, Pitch = 0.7 } :: SoundSpec,
	-- Won a track race. "LaserTagTemplate_Victory_01" by Roblox Resources, 7.6 s.
	Win = { Id = "rbxassetid://18961389529", Volume = 0.35, MaxSeconds = 2.5 } :: SoundSpec,
	-- Lost a track race. "LaserTagTemplate_Defeat_01" by Roblox Resources, 6.0 s.
	Lose = { Id = "rbxassetid://18961391664", Volume = 0.35, MaxSeconds = 3 } :: SoundSpec,
	-- Good roll lands (new car or emphasized roll). "Spinning Around (b)" by APMOfficial (APM Music), 5.4 s.
	RollReveal = { Id = "rbxassetid://1839881844", Volume = 0.35, MaxSeconds = 2.5 } :: SoundSpec,
	-- Background music, looped. "Piano Circles--Underscore" by APMOfficial (APM Music), 121.8 s.
	Music = { Id = "rbxassetid://9048006016", Volume = 0.12, Looped = true } :: SoundSpec,
}

-- Engine pitch follows the car's actual speed (studs/s, AssemblyLinearVelocity magnitude). Cruise speed runs from
-- RaceConfig.BASE_SPEED (14) to about 123 at HALF_STAT and keeps rising slowly, plus nitro.
SoundConfig.ENGINE_SPEED_MIN = 0 -- at or below: ENGINE_PITCH_MIN
SoundConfig.ENGINE_SPEED_MAX = 160 -- at or above: ENGINE_PITCH_MAX
SoundConfig.ENGINE_PITCH_MIN = 0.75
SoundConfig.ENGINE_PITCH_MAX = 1.6
SoundConfig.ENGINE_PITCH_SMOOTHING = 6 -- per second; higher follows speed changes faster
SoundConfig.ENGINE_FADE_SECONDS = 0.4 -- fade in when the race starts, out when it stops
-- A per-frame jump faster than this (studs/s) is a teleport (track reset, checkpoint), not speed
SoundConfig.ENGINE_TELEPORT_SPEED = 600
SoundConfig.ENGINE_ROLLOFF_MIN = 12 -- studs: full volume within this distance of the camera
SoundConfig.ENGINE_ROLLOFF_MAX = 150

-- Minimum seconds between two plays of the same one-shot (stops stacking on rapid events)
SoundConfig.MIN_REPEAT_SECONDS = 0.08

return SoundConfig
