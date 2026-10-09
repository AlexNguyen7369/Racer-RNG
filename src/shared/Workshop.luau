--!nonstrict
-- Mechanical Workshop rules: pure functions (no Instances created) shared by the server (truth), the builder and the
-- tests. Numbers: Shared/WorkshopConfig. Spec: docs/WORKSHOP_SPEC.md. Plot rects are local (x, z) of Track 1's
-- flattened Start (SpawnArea.Base), floor top at SpawnArea.TOP_Y.

local RaceConfig = require(script.Parent.RaceConfig)
local SpawnArea = require(script.Parent.SpawnArea)
local WorkshopConfig = require(script.Parent.WorkshopConfig)

local Workshop = {}

Workshop.Config = WorkshopConfig

local function plot(index)
	return type(index) == "number" and WorkshopConfig.Plots[index] or nil
end

local function finite(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

-- Local (x, z) centre of plot `index`, or nil.
function Workshop.PlotCentre(index)
	local p = plot(index)
	return p and (p.Min + p.Max) / 2 or nil
end

-- World CFrame of plot `index`'s centre at floor-top height, facing its open front (LookVector = Front). nil for a
-- bad index. `startCFrame` = Track 1's Start part CFrame (flattened like SpawnArea).
function Workshop.PlotCFrame(startCFrame, index)
	local p = plot(index)
	if not p or typeof(startCFrame) ~= "CFrame" then
		return nil
	end
	local base = SpawnArea.Base(startCFrame)
	local c = (p.Min + p.Max) / 2
	local pos = base:PointToWorldSpace(Vector3.new(c.X, 0, c.Y))
	pos = Vector3.new(pos.X, SpawnArea.TOP_Y, pos.Z)
	local front = base:VectorToWorldSpace(Vector3.new(p.Front.X, 0, p.Front.Y))
	return CFrame.lookAt(pos, pos + front)
end

-- Local zone rect of a plot: { Min, Max } (Vector2, x/z), ZONE_SIZE.X by ZONE_SIZE.Z centred in the plot.
local function zoneRect(p)
	local c = (p.Min + p.Max) / 2
	local half = Vector2.new(WorkshopConfig.ZONE_SIZE.X, WorkshopConfig.ZONE_SIZE.Z) / 2
	return c - half, c + half
end

-- World { Min, Max } (Vector3) of plot `index`'s zone: x/z of the zone rect, Y from the floor top to ZONE_SIZE.Y above
-- it. nil for a bad index.
function Workshop.ZoneBounds(startCFrame, index)
	local p = plot(index)
	if not p or typeof(startCFrame) ~= "CFrame" then
		return nil
	end
	local base = SpawnArea.Base(startCFrame)
	local lo, hi = zoneRect(p)
	local a = base:PointToWorldSpace(Vector3.new(lo.X, 0, lo.Y))
	local b = base:PointToWorldSpace(Vector3.new(hi.X, 0, hi.Y))
	local top = SpawnArea.TOP_Y
	return {
		Min = Vector3.new(math.min(a.X, b.X), top, math.min(a.Z, b.Z)),
		Max = Vector3.new(math.max(a.X, b.X), top + WorkshopConfig.ZONE_SIZE.Y, math.max(a.Z, b.Z)),
	}
end

-- true if a world position is inside plot `index`'s zone (checked in the plot's local space).
function Workshop.InZone(startCFrame, index, position)
	local p = plot(index)
	if not p or typeof(startCFrame) ~= "CFrame" or typeof(position) ~= "Vector3" then
		return false
	end
	local l = SpawnArea.Base(startCFrame):PointToObjectSpace(position)
	local lo, hi = zoneRect(p)
	local top = SpawnArea.TOP_Y
	return l.X >= lo.X
		and l.X <= hi.X
		and l.Z >= lo.Y
		and l.Z <= hi.Y
		and position.Y >= top
		and position.Y <= top + WorkshopConfig.ZONE_SIZE.Y
end

-- Lowest free plot index given a set { [index] = true } of taken plots, or 0 when all PLOT_COUNT are taken.
function Workshop.FreePlot(taken)
	taken = type(taken) == "table" and taken or {}
	for i = 1, WorkshopConfig.PLOT_COUNT do
		if not taken[i] then
			return i
		end
	end
	return 0
end

-- A saved / attribute level as a whole number in 1 .. MAX_LEVEL (anything that is not a number = 1).
function Workshop.CleanLevel(level)
	if not finite(level) then
		return 1
	end
	return math.clamp(math.floor(level), 1, WorkshopConfig.MAX_LEVEL)
end

-- W of a workshop level (level 1 = 1). Bad or out-of-range levels are clamped to 1 .. MAX_LEVEL.
function Workshop.LevelMulti(level)
	return WorkshopConfig.Levels[Workshop.CleanLevel(level)].Multi
end

-- Speed per second in the zone: BASE_RATE * speedMulti * LevelMulti(level) * workshopMulti / (1 + stat / GAIN_SOFT).
-- Bad inputs give 0.
function Workshop.Rate(stat, speedMulti, level, workshopMulti)
	if not finite(stat) or stat < 0 or not finite(speedMulti) or speedMulti < 0 then
		return 0
	end
	if not finite(workshopMulti) or workshopMulti < 0 then
		return 0
	end
	if level ~= nil and not finite(level) then
		return 0
	end
	stat = math.min(stat, RaceConfig.MAX_STAT)
	return WorkshopConfig.BASE_RATE
		* speedMulti
		* Workshop.LevelMulti(level)
		* workshopMulti
		/ (1 + stat / RaceConfig.GAIN_SOFT)
end

-- Integrate ds/dt = A/(1+s/H), rather than multiplying a frozen rate by hours.
-- The rationalized expression retains precision for small gains at high stats.
function Workshop.OfflineGain(stat, speedMulti, level, workshopMulti, seconds)
	if
		not finite(stat)
		or stat < 0
		or not finite(speedMulti)
		or speedMulti < 0
		or not finite(workshopMulti)
		or workshopMulti < 0
		or not finite(seconds)
		or (level ~= nil and not finite(level))
	then
		return 0
	end
	stat = math.min(stat, RaceConfig.MAX_STAT)
	local duration = math.clamp(seconds, 0, WorkshopConfig.OFFLINE_CAP)
	local a = WorkshopConfig.BASE_RATE
		* speedMulti
		* Workshop.LevelMulti(level)
		* workshopMulti
		* WorkshopConfig.OFFLINE_FRACTION
	local h = RaceConfig.GAIN_SOFT
	local q = 2 * h * a * duration
	local gain = q / (math.sqrt((stat + h) ^ 2 + q) + stat + h)
	return math.min(gain, RaceConfig.MAX_STAT - stat)
end

-- Offline Money is a deterministic companion credit based on the same capped Speed interval.
function Workshop.OfflineMoney(stat, speedMulti, level, workshopMulti, seconds)
	local speedGain = Workshop.OfflineGain(stat, speedMulti, level, workshopMulti, seconds)
	return math.floor(speedGain * WorkshopConfig.OFFLINE_MONEY_FRACTION)
end

return Workshop
