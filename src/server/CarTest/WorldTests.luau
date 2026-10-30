--!nonstrict
-- BRIEF: docs/WORLDS_SPEC.md section 2 (owner 2026-10-27), task w2a (WorldConfig + per-world TrackRegistry only).
-- World 1 tracks = Shared/Tracks/World1/* (today's 10), World 2 = Shared/Tracks/World2/* (empty until built).
-- Shared/WorldConfig.Current() returns 1 or 2 from game.PlaceId via WorldConfig.PLACE_IDS; the ReplicatedStorage
-- attribute WorldOverride (1 or 2) wins, for Studio and the harness. docs/CHECKPOINT_SPEC.md: each place lists
-- only its own world's tracks. CLAUDE.md "Tracks" rules 1-3: numbered ladder, chained in Number order.
-- Not covered here (later tasks): save VERSION 13, WorldService portal / teleport, the rebirth cap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local H = require(script.Parent.AcceptanceSupport)
local Shared = ReplicatedStorage.Shared
local Tests = {}

local ATTR = "WorldOverride"
-- Today's World 1 ladder (src/shared/Tracks at the start of w2a): name of track Number = index.
local WORLD1 = { "Oval", "Hill", "DragRace", "Circuit", "Serpentine", "City", "Desert", "Snow", "Volcano", "Space" }

local function chainNames(chain)
	local out = {}
	for i, spec in chain or {} do
		out[i] = spec.Name
	end
	return out
end

local function isLadder(chain, expected)
	if type(chain) ~= "table" or #chain ~= #expected then
		return false
	end
	for i, name in expected do
		local spec = chain[i]
		if type(spec) ~= "table" or spec.Name ~= name or spec.Number ~= i then
			return false
		end
	end
	return true
end

local function sameSpecs(a, b)
	if type(a) ~= "table" or type(b) ~= "table" or #a ~= #b then
		return false
	end
	for i = 1, #a do
		if a[i] ~= b[i] then
			return false
		end
	end
	return true
end

function Tests.worlds()
	local r, flag = H.report("worlds")
	local World = H.module(Shared, "WorldConfig")
	flag("world_config_exists", World ~= nil)
	local Registry = require(Shared.TrackRegistry)
	local saved = ReplicatedStorage:GetAttribute(ATTR)
	r.metrics.place_id = game.PlaceId
	r.metrics.saved_override = saved

	local ok, err = pcall(function()
		-- Folder layout: every track module lives in Tracks/World1, none directly in Tracks.
		local tracks = Shared:FindFirstChild("Tracks")
		local w1 = tracks and tracks:FindFirstChild("World1")
		local w2 = tracks and tracks:FindFirstChild("World2")
		flag("tracks_world1_folder", w1 ~= nil and w1:IsA("Folder"))
		flag("tracks_world2_folder", w2 ~= nil and w2:IsA("Folder"))
		local loose = {}
		for _, child in tracks and tracks:GetChildren() or {} do
			if child:IsA("ModuleScript") then
				table.insert(loose, child.Name)
			end
		end
		r.metrics.loose_track_modules = loose
		flag("no_track_module_in_tracks_root", #loose == 0, #loose, 0)
		local w1Modules = {}
		for _, child in w1 and w1:GetChildren() or {} do
			if child:IsA("ModuleScript") then
				table.insert(w1Modules, child.Name)
			end
		end
		table.sort(w1Modules)
		r.metrics.world1_modules = w1Modules
		local wanted = table.clone(WORLD1)
		table.sort(wanted)
		flag("world1_folder_holds_10_tracks", H.same(w1Modules, wanted), #w1Modules, #WORLD1)

		-- Registry per world (World 1 ladder unchanged, World 2 empty until its tracks exist).
		local okChain1, chain1 = pcall(Registry.Chain, 1)
		r.metrics.chain1 = okChain1 and chainNames(chain1) or tostring(chain1)
		flag("chain_world1_is_ladder_1_to_10", okChain1 and isLadder(chain1, WORLD1))
		local okChain2, chain2 = pcall(Registry.Chain, 2)
		r.metrics.chain2 = okChain2 and chainNames(chain2) or tostring(chain2)
		flag("chain_world2_no_error", okChain2)
		-- Update to the World 2 ladder when Shared/Tracks/World2 gets its tracks.
		flag("chain_world2_empty", okChain2 and type(chain2) == "table" and #chain2 == 0, okChain2 and #chain2 or -1, 0)

		local okNames1, names1 = pcall(Registry.Names, 1)
		flag("names_world1", okNames1 and H.same(names1, wanted))
		local okNames2, names2 = pcall(Registry.Names, 2)
		flag("names_world2_empty", okNames2 and type(names2) == "table" and #names2 == 0)

		local okGet, oval1 = pcall(Registry.Get, "Oval", 1)
		flag("get_oval_world1", okGet and type(oval1) == "table" and oval1.Number == 1)
		local okGet2, oval2 = pcall(Registry.Get, "Oval", 2)
		flag("get_oval_world2_nil", okGet2 and oval2 == nil)
		local okSpace, space1 = pcall(Registry.Get, "Space", 1)
		flag("get_space_world1", okSpace and type(space1) == "table" and space1.Number == 10)

		if not World then
			return
		end
		flag("place_ids_table", type(World.PLACE_IDS) == "table")
		local ids = type(World.PLACE_IDS) == "table" and World.PLACE_IDS or {}
		flag("place_ids_numbers", type(ids[1]) == "number" and type(ids[2]) == "number")
		flag("place_ids_distinct", ids[1] ~= ids[2])

		-- Current(): override wins when it is 1 or 2, anything else is ignored (Studio place -> 1).
		ReplicatedStorage:SetAttribute(ATTR, nil)
		local base = World.Current()
		r.metrics.current_no_override = base
		flag("current_no_override_is_1", base == 1, base, 1)
		ReplicatedStorage:SetAttribute(ATTR, 2)
		flag("override_2", World.Current() == 2, World.Current(), 2)
		ReplicatedStorage:SetAttribute(ATTR, 1)
		flag("override_1", World.Current() == 1, World.Current(), 1)
		for _, bad in { 0, 3, -1, 1.5, 0 / 0, math.huge, "2", true } do
			ReplicatedStorage:SetAttribute(ATTR, bad)
			local got = World.Current()
			flag("override_ignored_" .. tostring(bad), got == base, got, base)
		end

		-- Chain() / Get() / Names() default to Current() and follow the override live.
		ReplicatedStorage:SetAttribute(ATTR, nil)
		flag("chain_default_is_current", sameSpecs(Registry.Chain(), Registry.Chain(World.Current())))
		flag("chain_default_world1_ladder", isLadder(Registry.Chain(), WORLD1))
		ReplicatedStorage:SetAttribute(ATTR, 2)
		local okDef2, def2 = pcall(Registry.Chain)
		flag("chain_default_follows_override_2", okDef2 and type(def2) == "table" and #def2 == 0)
		local okGetDef2, ovalDef2 = pcall(Registry.Get, "Oval")
		flag("get_default_follows_override_2", okGetDef2 and ovalDef2 == nil)
		ReplicatedStorage:SetAttribute(ATTR, 1)
		flag("chain_default_follows_override_1", isLadder(Registry.Chain(), WORLD1))
		flag("get_default_world1", type(Registry.Get("Oval")) == "table")
	end)
	ReplicatedStorage:SetAttribute(ATTR, saved)
	flag("ran_without_error", ok, ok and 1 or tostring(err))
	flag("override_restored", ReplicatedStorage:GetAttribute(ATTR) == saved)
	return r
end

return Tests
