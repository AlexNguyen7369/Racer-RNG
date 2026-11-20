--!nonstrict
-- Game audio (docs/AUDIO_SPEC.md; design doc "Playtest follow-ups", Sound). Everything plays on this client only,
-- so nobody else hears it. Ids, volumes and pitches live in Shared/SoundConfig.
--   Engine loop  on the local player's own car while auto racing (3D, on the car's chassis); pitch follows the
--                car's actual speed (AssemblyLinearVelocity magnitude). Other players' cars stay silent.
--   Nitro        whoosh when a boost starts (player attribute NitroUntil moves into the future), a chime on a
--                Perfect press and a soft tick on a Miss (NitroGrade, read when NitroPresses changes; Server/NitroService).
--   Race result  win / lose stinger on Remotes.NpcRace { Type = "Result", Result = "Win" | "Lose" } (Server/RaceService).
--   Roll reveal  when a new or emphasized roll (Remotes.RollResult) lands in the roll animation: the
--                RollToast/Toast card's Phase attribute turns "Land" with that RollId (docs/ROLL_ANIMATION_CONTRACT.md).
--   Music        one calm looping track.
-- Every sound goes through SoundService.GameAudio (SoundGroup, children Music / Sfx / Engine), so one volume governs
-- all of it. Muting: player attribute SoundMuted = true sets GameAudio to 0. The Settings Sound toggle
-- (Client/RollToast/RacerUiController) also zeroes every Sound's Volume itself; this script never writes a Sound's
-- Volume after creating it, so that restore keeps working.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local SoundConfig = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("SoundConfig"))
local RollAnimConfig = require(ReplicatedStorage.Shared:WaitForChild("RollAnimConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local S = SoundConfig.Sounds

-- Sound groups ----------------------------------------------------------------------------------------------------

local function soundGroup(name, volume, parent)
	local g = parent:FindFirstChild(name)
	if not (g and g:IsA("SoundGroup")) then
		g = Instance.new("SoundGroup")
		g.Name = name
		g.Parent = parent
	end
	g.Volume = volume
	return g
end

local master = soundGroup("GameAudio", SoundConfig.MASTER_VOLUME, SoundService)
local musicGroup = soundGroup("Music", SoundConfig.MUSIC_VOLUME, master)
local sfxGroup = soundGroup("Sfx", SoundConfig.SFX_VOLUME, master)
local engineGroup = soundGroup("Engine", 0, master) -- faded in / out by the engine loop, up to ENGINE_VOLUME

local function applyMute()
	master.Volume = player:GetAttribute("SoundMuted") == true and 0 or SoundConfig.MASTER_VOLUME
end
player:GetAttributeChangedSignal("SoundMuted"):Connect(applyMute)
applyMute()

-- Every property is set before Parent, so the Settings toggle (which caches a Sound's Volume when it first sees
-- it) records the configured volume.
local function makeSound(name, spec, group, parent)
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.Id
	sound.Volume = spec.Volume
	sound.PlaybackSpeed = spec.Pitch or 1
	sound.Looped = spec.Looped == true
	sound.SoundGroup = group
	sound.Parent = parent
	return sound
end

-- One-shots (2D: parented under SoundService) -----------------------------------------------------------------------

local oneShots = {}
for _, name in { "NitroWhoosh", "PerfectChime", "MissTick", "Win", "Lose", "RollReveal" } do
	oneShots[name] = makeSound(name, S[name], sfxGroup, sfxGroup)
end

local lastPlayed = {}
local function play(name)
	local sound = oneShots[name]
	local now = os.clock()
	if not sound or now - (lastPlayed[name] or -math.huge) < SoundConfig.MIN_REPEAT_SECONDS then
		return
	end
	lastPlayed[name] = now
	sound:Stop()
	sound:Play()
	-- MaxSeconds (optional): long stingers are cut short so a win on every track does not drag on
	local maxSeconds = S[name] and S[name].MaxSeconds
	if type(maxSeconds) == "number" and maxSeconds > 0 then
		task.delay(maxSeconds, function()
			if lastPlayed[name] == now then
				sound:Stop()
			end
		end)
	end
end

-- Music -------------------------------------------------------------------------------------------------------------

local music = makeSound("Music", S.Music, musicGroup, musicGroup)
music:Play()

-- Nitro -------------------------------------------------------------------------------------------------------------

player:GetAttributeChangedSignal("NitroUntil"):Connect(function()
	local untilTime = player:GetAttribute("NitroUntil")
	if type(untilTime) == "number" and untilTime > Workspace:GetServerTimeNow() then
		play("NitroWhoosh")
	end
end)

-- NitroPresses counts every graded press, so two equal grades in a row still play twice. The server sets
-- NitroGrade before NitroPresses, so the grade read here is the one for this press.
player:GetAttributeChangedSignal("NitroPresses"):Connect(function()
	local grade = player:GetAttribute("NitroGrade")
	if grade == "Perfect" then
		play("PerfectChime")
	elseif grade == "Miss" then
		play("MissTick")
	end
end)

-- Race result stingers ------------------------------------------------------------------------------------------------

remotes:WaitForChild("NpcRace").OnClientEvent:Connect(function(event)
	if type(event) ~= "table" or event.Type ~= "Result" then
		return
	end
	if event.Result == "Win" then
		oneShots.Lose:Stop()
		play("Win")
	elseif event.Result == "Lose" then
		oneShots.Win:Stop()
		play("Lose")
	end
end)

-- Roll reveal ---------------------------------------------------------------------------------------------------------

local MAX_PENDING_ROLLS = 50
local pendingRolls = {} -- { Id, Good } per RollResult received, in order; consumed when that roll lands
local fallbackReveal = false -- no RollToast card to watch: play when the roll would land by RollAnimConfig timing

remotes:WaitForChild("RollResult").OnClientEvent:Connect(function(id, isNew, _turboMulti, emphasized)
	local good = isNew == true or emphasized == true
	if fallbackReveal then
		if good then
			task.delay(RollAnimConfig.POP + RollAnimConfig.SPIN, play, "RollReveal")
		end
		return
	end
	table.insert(pendingRolls, { Id = id, Good = good })
	if #pendingRolls > MAX_PENDING_ROLLS then
		table.remove(pendingRolls, 1)
	end
end)

local function onRollLanded(rollId)
	for i, entry in pendingRolls do
		if entry.Id == rollId then
			-- Rolls land in the order they arrived: anything older than this one will never land now.
			for _ = 1, i do
				table.remove(pendingRolls, 1)
			end
			if entry.Good then
				play("RollReveal")
			end
			return
		end
	end
end

task.spawn(function()
	local gui = player:WaitForChild("PlayerGui"):WaitForChild("RollToast", 30)
	local toast = gui and gui:WaitForChild("Toast", 10)
	if not toast then
		fallbackReveal = true
		table.clear(pendingRolls)
		return
	end
	toast:GetAttributeChangedSignal("Phase"):Connect(function()
		if toast:GetAttribute("Phase") == "Land" then
			onRollLanded(toast:GetAttribute("RollId"))
		end
	end)
end)

-- Engine loop ---------------------------------------------------------------------------------------------------------

-- The car the local player sits in while auto racing (or held for a duel): never the MountedCar cosmetic, which
-- has no IsCar attribute.
local function ownCar()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local car = seat and seat.Parent
	if not (car and car:IsA("Model") and car:GetAttribute("IsCar")) then
		return nil
	end
	if player:GetAttribute("AutoRacing") ~= true and car:GetAttribute("AutoRace") ~= true then
		return nil
	end
	return car.PrimaryPart
end

local engine = nil -- the Sound on the current chassis (destroyed with the car)
local enginePart = nil
local lastPos = nil
local pitch = SoundConfig.ENGINE_PITCH_MIN
local fadeRate = SoundConfig.ENGINE_VOLUME / math.max(SoundConfig.ENGINE_FADE_SECONDS, 0.01)

local function dropEngine()
	if engine then
		engine:Destroy()
	end
	engine, enginePart, lastPos = nil, nil, nil
end

local function speedOf(chassis, dt)
	local speed = chassis.AssemblyLinearVelocity.Magnitude
	local pos = chassis.Position
	-- Fallback when the car is moved without physics velocity: speed from the position change, ignoring teleports.
	if speed < 0.5 and lastPos and dt > 0 then
		local moved = (pos - lastPos).Magnitude / dt
		if moved < SoundConfig.ENGINE_TELEPORT_SPEED then
			speed = moved
		end
	end
	lastPos = pos
	return speed
end

RunService.Heartbeat:Connect(function(dt)
	if engine and engine.Parent == nil then
		engineGroup.Volume = 0 -- the car was destroyed and took its Sound with it
		dropEngine()
	end

	local chassis = ownCar()
	if chassis and chassis ~= enginePart then
		dropEngine()
		engineGroup.Volume = 0
		pitch = SoundConfig.ENGINE_PITCH_MIN
		engine = Instance.new("Sound")
		engine.Name = "GameAudioEngine"
		engine.SoundId = S.Engine.Id
		engine.Volume = S.Engine.Volume
		engine.Looped = true
		engine.PlaybackSpeed = pitch
		engine.RollOffMode = Enum.RollOffMode.InverseTapered
		engine.RollOffMinDistance = SoundConfig.ENGINE_ROLLOFF_MIN
		engine.RollOffMaxDistance = SoundConfig.ENGINE_ROLLOFF_MAX
		engine.SoundGroup = engineGroup
		engine.Parent = chassis
		engine:Play()
		enginePart = chassis
		lastPos = chassis.Position
	end
	if not engine then
		return
	end

	local target = chassis and SoundConfig.ENGINE_VOLUME or 0
	local volume = engineGroup.Volume
	if volume < target then
		engineGroup.Volume = math.min(target, volume + fadeRate * dt)
	elseif volume > target then
		engineGroup.Volume = math.max(target, volume - fadeRate * dt)
	end
	if not chassis then
		if engineGroup.Volume <= 0 then
			dropEngine() -- out of the car (Stop Auto) and faded out
		end
		return
	end

	local span = math.max(SoundConfig.ENGINE_SPEED_MAX - SoundConfig.ENGINE_SPEED_MIN, 1)
	local alpha = math.clamp((speedOf(chassis, dt) - SoundConfig.ENGINE_SPEED_MIN) / span, 0, 1)
	local goal = SoundConfig.ENGINE_PITCH_MIN + (SoundConfig.ENGINE_PITCH_MAX - SoundConfig.ENGINE_PITCH_MIN) * alpha
	pitch += (goal - pitch) * math.min(1, dt * SoundConfig.ENGINE_PITCH_SMOOTHING)
	engine.PlaybackSpeed = pitch
end)
