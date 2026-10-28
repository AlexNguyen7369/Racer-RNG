--!nonstrict
-- BRIEF (owner, 2026-10-13; design doc "Monetization" -> "Gamepass cars", contract docs/GAMEPASS_CARS_SPEC.md, and
-- docs/LEADERBOARD_SPEC.md 3a note of 2026-10-13): "two smaller pedestals stand left and right of the Best Roll Ever
-- pedestal. Each shows a car that is locked behind a gamepass. Walking up to one offers the purchase for Robux."
-- Spec section 7: "`pass_cars` harness scenario: catalog rules of section 2; never rolled in many rolls; equip refused
-- without the pass and accepted with it; `Apply` keeps a saved gamepass car and the check resets it when not owned;
-- id 0 never prompts and is never owned; a fake purchase sets the attribute and equips; a failing market raises no
-- error; the pedestals, labels, prompt and `Car` models exist and the footprints overlap nothing in the list of
-- section 5."
-- Written before CarCatalog.Passes, Shared/PassCarConfig, Server/PassCarService and the pedestals exist: red by design.
-- The test sets spec.GamepassId to made-up ids while it runs and always puts the original values back.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

-- Spec section 1: the cars (Name, Rarity and RobuxPrice are fixed; SpeedMulti is proposed, so only checked positive).
-- Owner 2026-10-16: rarities swapped (Ember Wyvern Secret, Singularity Mythic) and RobuxPrice added to each car file.
local CARS = {
	{ Id = "ember_wyvern", Name = "Ember Wyvern", Rarity = "Secret", RobuxPrice = 1999 },
	{ Id = "singularity", Name = "Singularity", Rarity = "Mythic", RobuxPrice = 999 },
}
local TAG_TEXT = "GAMEPASS"
local ACTION_SOON = "Coming soon"
local ACTION_UNLOCK = "Unlock"
-- docs/SPAWN_AND_ROLLS_SPEC.md: the hub, local (x, z) of Track 1's Start (same literals as the spawn_area scenario)
local HUB_MIN = Vector2.new(24, -100)
local HUB_MAX = Vector2.new(184, 44)
local GEOM_TOL = 0.05 -- studs of footprint overlap ignored (parts that only touch)
local SCALE_TOL = 1e-3
local ID_BASE = 990074300 -- fake user ids
local PASS_IDS = { ember_wyvern = 990074901, singularity = 990074902 } -- made-up gamepass ids, never real
local UNKNOWN_PASS = 990074999
local ROLLS_PER_CASE = 1000
local ROLL_SEED = 74300
local WAIT_LIMIT = 2 -- seconds Check may take to set PassChecked with an instant fake market

local function module(parent, name)
	local source = parent:FindFirstChild(name)
	if not source then
		return nil
	end
	local ok, value = pcall(require, source)
	return ok and type(value) == "table" and value or nil
end

local function report(name)
	local r = { scenario = name, pass = true, checks = {}, metrics = {} }
	local function flag(label, ok, value, limit)
		table.insert(
			r.checks,
			{ name = label, pass = ok == true, value = value or (ok and 1 or 0), limit = limit or 1 }
		)
		r.pass = r.pass and ok == true
	end
	return r, flag
end

local function finite(v)
	return type(v) == "number" and v == v and math.abs(v) ~= math.huge
end

-- Horizontal footprint of a part: its 8 corners on XZ and the projected axes (as in the spawn_area scenario).
local function partPoly(part)
	local cf, s = part.CFrame, part.Size / 2
	local pts, dirs = {}, {}
	for _, x in { -1, 1 } do
		for _, y in { -1, 1 } do
			for _, z in { -1, 1 } do
				local w = cf:PointToWorldSpace(Vector3.new(x * s.X, y * s.Y, z * s.Z))
				table.insert(pts, Vector2.new(w.X, w.Z))
			end
		end
	end
	for _, v in { cf.RightVector, cf.UpVector, cf.LookVector } do
		local d = Vector2.new(v.X, v.Z)
		if d.Magnitude > 1e-3 then
			table.insert(dirs, d.Unit)
		end
	end
	return { Points = pts, Dirs = dirs }
end

-- A local (x, z) rectangle in the space of `base`, as a world footprint.
local function rectPoly(base, minV, maxV)
	local pts = {}
	for _, x in { minV.X, maxV.X } do
		for _, z in { minV.Y, maxV.Y } do
			local w = base:PointToWorldSpace(Vector3.new(x, 0, z))
			table.insert(pts, Vector2.new(w.X, w.Z))
		end
	end
	local r = base.RightVector
	return { Points = pts, Dirs = { Vector2.new(r.X, r.Z).Unit } }
end

-- A round footprint of `radius` around local (x, z), as a 32-gon around the circle (never smaller than the circle).
local SIDES = 32
local function circlePoly(base, x, z, radius)
	local pts, dirs = {}, {}
	local outer = radius / math.cos(math.pi / SIDES)
	for k = 0, SIDES - 1 do
		local a = 2 * math.pi * k / SIDES
		local w = base:PointToWorldSpace(Vector3.new(x + outer * math.cos(a), 0, z + outer * math.sin(a)))
		table.insert(pts, Vector2.new(w.X, w.Z))
		local n = base:VectorToWorldSpace(Vector3.new(math.cos(a + math.pi / SIDES), 0, math.sin(a + math.pi / SIDES)))
		table.insert(dirs, Vector2.new(n.X, n.Z).Unit)
	end
	return { Points = pts, Dirs = dirs }
end

-- Separating-axis test of two convex footprints: > 0 is the gap, <= 0 means they overlap by -value.
local function separation(a, b)
	local best = -math.huge
	for _, poly in { a, b } do
		for _, d in poly.Dirs do
			for _, ax in { d, Vector2.new(-d.Y, d.X) } do
				local aMin, aMax, bMin, bMax = math.huge, -math.huge, math.huge, -math.huge
				for _, p in a.Points do
					local v = p:Dot(ax)
					aMin, aMax = math.min(aMin, v), math.max(aMax, v)
				end
				for _, p in b.Points do
					local v = p:Dot(ax)
					bMin, bMax = math.min(bMin, v), math.max(bMax, v)
				end
				best = math.max(best, math.max(bMin - aMax, aMin - bMax))
			end
		end
	end
	return best
end

local function partsOf(root)
	local list = {}
	if root and root:IsA("BasePart") then
		table.insert(list, root)
	end
	for _, d in root and root:GetDescendants() or {} do
		if d:IsA("BasePart") then
			table.insert(list, d)
		end
	end
	return list
end

local function waitFor(test)
	local t0 = os.clock()
	while not test() and os.clock() - t0 < WAIT_LIMIT do
		task.wait(0.05)
	end
	return test()
end

function Tests.pass_cars()
	local r, flag = report("pass_cars")
	local catalog = module(Shared, "CarCatalog")
	local gachaConfig = module(Shared, "GachaConfig")
	local config = module(Shared, "PassCarConfig")
	local lbConfig = module(Shared, "LeaderboardConfig")
	local workshopConfig = module(Shared, "WorkshopConfig")
	local registry = module(Shared, "TrackRegistry")
	local service = module(Server, "PassCarService")
	local gacha = module(Server, "GachaService")
	local data = module(Server, "PlayerData")
	local leaderboard = module(Server, "LeaderboardService")

	-- Catalog rules (spec section 2)
	local C = catalog or {}
	local hasPasses = type(C.Passes) == "function"
	flag("pass_cars_catalog_passes_exists", hasPasses)
	local okPasses, passes = false, nil
	if hasPasses then
		okPasses, passes = pcall(C.Passes)
	end
	passes = okPasses and type(passes) == "table" and passes or {}
	flag("pass_cars_passes_count", #passes == #CARS, #passes, #CARS)
	local sorted = #passes > 0
	for i = 2, #passes do
		sorted = sorted and type(passes[i].Order) == "number" and passes[i - 1].Order <= passes[i].Order
	end
	flag("pass_cars_passes_sorted_by_order", sorted)
	local all = type(C.All) == "function" and C.All() or {}
	local rollable = type(C.Rollable) == "function" and C.Rollable() or {}
	local function member(list, id)
		for _, spec in list do
			if spec.Id == id then
				return true
			end
		end
		return false
	end
	local specs = {} -- car id -> spec from CarCatalog.Get
	for _, car in CARS do
		local spec = type(C.Get) == "function" and C.Get(car.Id) or nil
		specs[car.Id] = spec
		local s = spec or {}
		flag("pass_cars_get_returns_" .. car.Id, spec ~= nil)
		flag("pass_cars_in_passes_" .. car.Id, spec ~= nil and member(passes, car.Id))
		local samePassEntry = false
		for _, p in passes do
			samePassEntry = samePassEntry or (p.Id == car.Id and p == spec)
		end
		flag("pass_cars_passes_entry_is_get_spec_" .. car.Id, samePassEntry)
		flag("pass_cars_name_" .. car.Id, s.Name == car.Name, tostring(s.Name), car.Name)
		flag("pass_cars_rarity_" .. car.Id, s.Rarity == car.Rarity, tostring(s.Rarity), car.Rarity)
		flag("pass_cars_robux_price_" .. car.Id, s.RobuxPrice == car.RobuxPrice, tostring(s.RobuxPrice), car.RobuxPrice)
		local gid = s.GamepassId
		flag(
			"pass_cars_gamepass_id_whole_number_" .. car.Id,
			finite(gid) and gid >= 0 and math.floor(gid) == gid,
			tostring(gid),
			">= 0"
		)
		flag("pass_cars_not_rollable_flag_" .. car.Id, spec ~= nil and s.Rollable == false)
		flag("pass_cars_no_chance_" .. car.Id, spec ~= nil and s.Chance == nil)
		flag("pass_cars_speed_multi_positive_" .. car.Id, finite(s.SpeedMulti) and s.SpeedMulti > 0)
		flag("pass_cars_model_named_" .. car.Id, type(s.Model) == "string" and s.Model ~= "")
		-- guards: hold before and after the feature
		flag("pass_cars_not_in_all_" .. car.Id, not member(all, car.Id))
		flag("pass_cars_not_in_rollable_" .. car.Id, not member(rollable, car.Id))
	end
	local strayGamepass = 0
	for _, list in { all, rollable } do
		for _, spec in list do
			if spec.GamepassId ~= nil then
				strayGamepass += 1
			end
		end
	end
	flag("pass_cars_no_gamepass_car_in_all_or_rollable", strayGamepass == 0, strayGamepass, 0)
	local strayPass = 0
	for _, spec in passes do
		if spec.GamepassId == nil or member(all, spec.Id) or member(rollable, spec.Id) then
			strayPass += 1
		end
	end
	flag("pass_cars_passes_only_gamepass_cars", strayPass == 0, strayPass, 0)

	-- Never rolled (guard): the pure roll at low and very high luck, with and without a weather event
	local rolledPass, rollErrors = 0, 0
	if gachaConfig and type(gachaConfig.Roll) == "function" then
		local isPass = {}
		for _, car in CARS do
			isPass[car.Id] = true
		end
		local case = 0
		for _, event in { false, "rain", "night", "gold" } do -- false: no weather event (passed as nil)
			for _, luck in { 1, 1e3, 1e6, 1e12 } do
				case += 1
				local ok = pcall(function()
					local rng = Random.new(ROLL_SEED + case)
					for _ = 1, ROLLS_PER_CASE do
						if isPass[gachaConfig.Roll(rng, luck, event or nil)] then
							rolledPass += 1
						end
					end
				end)
				rollErrors += ok and 0 or 1
			end
		end
	else
		rollErrors = 1
	end
	r.metrics.pass_rolls = 16 * ROLLS_PER_CASE
	flag("pass_cars_roll_runs", rollErrors == 0, rollErrors, 0)
	flag("pass_cars_never_rolled", rollErrors == 0 and rolledPass == 0, rolledPass, 0)

	-- Config (spec section 5)
	local P = config or {}
	local B = lbConfig and type(lbConfig.BEST_ROLL) == "table" and lbConfig.BEST_ROLL or {}
	flag("pass_cars_config_exists", config ~= nil)
	local numbersOk = true
	for _, key in { "RADIUS", "CAR_SCALE", "TEXT_DISTANCE", "PROMPT_DISTANCE" } do
		numbersOk = numbersOk and finite(P[key]) and P[key] > 0
	end
	flag("pass_cars_config_numbers", numbersOk)
	local bestOk = finite(B.X) and finite(B.Z) and finite(B.RADIUS) and B.RADIUS > 0
	-- "two smaller pedestals"
	flag(
		"pass_cars_pedestals_smaller_than_best_roll",
		numbersOk and bestOk and P.RADIUS < B.RADIUS,
		tonumber(P.RADIUS) or -1,
		tonumber(B.RADIUS) or -1
	)
	local entries = type(P.Pedestals) == "table" and P.Pedestals or {}
	local entryFor = {}
	for _, e in entries do
		if type(e) == "table" and type(e.CarId) == "string" and finite(e.X) and finite(e.Z) then
			entryFor[e.CarId] = e
		end
	end
	flag("pass_cars_config_pedestal_count", #entries == #CARS, #entries, #CARS)
	for _, car in CARS do
		flag("pass_cars_config_pedestal_for_" .. car.Id, entryFor[car.Id] ~= nil)
	end
	-- "left and right of the Best Roll Ever pedestal", "the centre of a row of three": the Best Roll centre lies
	-- between the two along the line joining them, and that line crosses its platform.
	local a, b = entryFor[CARS[1].Id], entryFor[CARS[2].Id]
	local between = false
	if a and b and bestOk then
		local pa, pb, pc = Vector2.new(a.X, a.Z), Vector2.new(b.X, b.Z), Vector2.new(B.X, B.Z)
		local ab = pb - pa
		if ab.Magnitude > 1e-3 then
			local t = (pc - pa):Dot(ab) / ab:Dot(ab)
			local offLine = (pa + ab * t - pc).Magnitude
			r.metrics.row_t = math.round(t * 1000) / 1000
			r.metrics.row_off_line = math.round(offLine * 1000) / 1000
			between = t > 0 and t < 1 and offLine < B.RADIUS
		end
	end
	flag("pass_cars_best_roll_between_pedestals", between)

	-- World (spec section 5)
	local area = Workspace:FindFirstChild("SpawnArea")
	local trackFolder = Workspace:FindFirstChild("Track")
	local chain = registry and type(registry.Chain) == "function" and registry.Chain() or {}
	local track1 = trackFolder and chain[1] and trackFolder:FindFirstChild(chain[1].Name)
	local startPart = track1 and track1:FindFirstChild("Start")
	local worldOk = area ~= nil and startPart ~= nil and startPart:IsA("BasePart")
	flag("pass_cars_spawn_area_and_chain_present", worldOk)
	local root = area and area:FindFirstChild("PassCars")
	flag("pass_cars_model_exists", root ~= nil and root:IsA("Model"))
	local carModels = ReplicatedStorage:FindFirstChild("CarModels")
	local geomOk = worldOk and numbersOk
	local function localXZ(p)
		local l = startPart.CFrame:PointToObjectSpace(Vector3.new(p.X, 0, p.Y))
		return Vector2.new(l.X, l.Z)
	end
	for _, car in CARS do
		local id = car.Id
		local spec = specs[id] or {}
		local e = entryFor[id]
		local holder = root and root:FindFirstChild("Pass_" .. id)
		if holder and not holder:IsA("Model") then
			holder = nil
		end
		flag("pass_cars_holder_exists_" .. id, holder ~= nil)
		local pedestal = holder and holder:FindFirstChild("Pedestal")
		local pedOk = pedestal ~= nil and pedestal:IsA("BasePart")
		flag("pass_cars_pedestal_exists_" .. id, pedOk)
		flag("pass_cars_pedestal_anchored_" .. id, pedOk and pedestal.Anchored == true)
		flag("pass_cars_pedestal_can_collide_" .. id, pedOk and pedestal.CanCollide == true)
		local here = geomOk and pedOk and e ~= nil
		local function reachOf(part)
			local reach = 0
			for _, p in partPoly(part).Points do
				reach = math.max(reach, (localXZ(p) - Vector2.new(e.X, e.Z)).Magnitude)
			end
			return reach
		end
		local off = -1
		if here then
			local l = startPart.CFrame:PointToObjectSpace(pedestal.Position)
			off = Vector2.new(l.X - e.X, l.Z - e.Z).Magnitude
		end
		flag("pass_cars_pedestal_at_config_centre_" .. id, here and off <= GEOM_TOL, off, GEOM_TOL)
		-- A round part's own bounding box may be turned about the vertical, so its corners may reach RADIUS * sqrt(2)
		local cornerLimit = here and P.RADIUS * math.sqrt(2) + GEOM_TOL or -1
		local own = here and reachOf(pedestal) or -1
		flag(
			"pass_cars_pedestal_radius_" .. id,
			here and own >= P.RADIUS - GEOM_TOL and own <= cornerLimit,
			own,
			cornerLimit
		)
		local shown = holder and holder:FindFirstChild("Car")
		local worst = 0
		for _, part in here and partsOf(holder) or {} do
			if not (shown and part:IsDescendantOf(shown)) then
				worst = math.max(worst, reachOf(part))
			end
		end
		flag("pass_cars_parts_inside_footprint_" .. id, here and worst <= cornerLimit, worst, cornerLimit)
		local R = numbersOk and P.RADIUS or 0
		flag(
			"pass_cars_inside_hub_" .. id,
			numbersOk
				and e ~= nil
				and e.X - R >= HUB_MIN.X - GEOM_TOL
				and e.X + R <= HUB_MAX.X + GEOM_TOL
				and e.Z - R >= HUB_MIN.Y - GEOM_TOL
				and e.Z + R <= HUB_MAX.Y + GEOM_TOL
		)

		-- Labels
		local stats = pedOk and pedestal:FindFirstChild("Stats")
		local statsOk = stats ~= nil and stats ~= false and stats:IsA("BillboardGui")
		flag("pass_cars_stats_billboard_exists_" .. id, statsOk)
		local dist = statsOk and stats.MaxDistance or -1
		flag(
			"pass_cars_text_distance_" .. id,
			statsOk and numbersOk and dist < math.huge and math.abs(dist - P.TEXT_DISTANCE) < 1e-3,
			dist,
			tonumber(P.TEXT_DISTANCE) or -1
		)
		local title = statsOk and stats:FindFirstChild("Title", true)
		local titleText = title and title:IsA("TextLabel") and title.Text or "<missing>"
		flag("pass_cars_title_is_car_name_" .. id, titleText == car.Name, titleText, car.Name)
		local tag = statsOk and stats:FindFirstChild("Tag", true)
		local tagText = tag and tag:IsA("TextLabel") and tag.Text or "<missing>"
		flag("pass_cars_tag_text_" .. id, tagText == TAG_TEXT, tagText, TAG_TEXT)

		-- Prompt (read before the test changes any GamepassId)
		local buy = pedOk and pedestal:FindFirstChild("Buy")
		local buyOk = buy ~= nil and buy ~= false and buy:IsA("ProximityPrompt")
		flag("pass_cars_prompt_exists_" .. id, buyOk)
		flag("pass_cars_prompt_key_e_" .. id, buyOk and buy.KeyboardKeyCode == Enum.KeyCode.E)
		flag("pass_cars_prompt_instant_" .. id, buyOk and buy.HoldDuration == 0, buyOk and buy.HoldDuration or -1, 0)
		local reach = buyOk and buy.MaxActivationDistance or -1
		flag(
			"pass_cars_prompt_distance_" .. id,
			buyOk and numbersOk and math.abs(reach - P.PROMPT_DISTANCE) < 1e-3,
			reach,
			tonumber(P.PROMPT_DISTANCE) or -1
		)
		local objectText = buyOk and buy.ObjectText or "<missing>"
		flag("pass_cars_prompt_object_text_" .. id, objectText == car.Name, objectText, car.Name)
		local wantAction = spec.GamepassId == 0 and ACTION_SOON or ACTION_UNLOCK
		local actionText = buyOk and buy.ActionText or "<missing>"
		flag(
			"pass_cars_prompt_action_text_" .. id,
			specs[id] ~= nil and actionText == wantAction,
			actionText,
			wantAction
		)

		-- The shown car: a clone of CarModels[spec.Model] at CAR_SCALE, static, standing on the platform
		local template = type(spec.Model) == "string" and carModels and carModels:FindFirstChild(spec.Model) or nil
		flag("pass_cars_template_in_car_models_" .. id, template ~= nil and template:IsA("Model"))
		local carOk = shown ~= nil and shown:IsA("Model")
		flag("pass_cars_car_model_exists_" .. id, carOk)
		local parts, loose = partsOf(carOk and shown or nil), 0
		for _, part in parts do
			if not part.Anchored or part.CanCollide or part.CanTouch or part.CanQuery then
				loose += 1
			end
		end
		flag("pass_cars_car_parts_static_" .. id, carOk and #parts > 0 and loose == 0, loose, 0)
		local scale = carOk and template and template:IsA("Model") and shown:GetScale() / template:GetScale() or -1
		-- GAMEPASS_CARS_SPEC section 5 (owner 2026-10-27): CAR_SCALE times the car's SkinScale when it has one, at most
		-- CarAppearance.DISPLAY_SKIN_MAX; a car with SkinScale fails when that constant is missing (no fallback)
		local skinScale = tonumber(spec.SkinScale)
		local appearance = module(Shared, "CarAppearance")
		local cap = appearance and appearance.DISPLAY_SKIN_MAX
		local capOk = skinScale == nil or (type(cap) == "number" and cap > 0)
		local wantScale = numbersOk and capOk and P.CAR_SCALE * (skinScale and math.min(skinScale, cap) or 1) or -1
		flag("pass_cars_car_scale_" .. id, numbersOk and math.abs(scale - wantScale) < SCALE_TOL, scale, wantScale)
		local onPedestal = false
		if carOk and pedOk and numbersOk then
			local offset = shown:GetBoundingBox().Position - pedestal.Position
			onPedestal = Vector2.new(offset.X, offset.Z).Magnitude <= P.RADIUS and offset.Y > 0
		end
		flag("pass_cars_car_on_pedestal_" .. id, onPedestal)
	end

	-- Footprints overlap none of: plot, pad, Spawn, marketplace footprint, race platform, track part, leaderboard sign,
	-- the Best Roll pedestal, the other pass pedestal
	local function polys(parts)
		local list = {}
		for _, p in parts do
			table.insert(list, partPoly(p))
		end
		return list
	end
	local sets = {}
	local plots = {}
	for _, plot in worldOk and workshopConfig and workshopConfig.Plots or {} do
		table.insert(plots, rectPoly(startPart.CFrame, plot.Min, plot.Max))
	end
	table.insert(sets, { Label = "plots", Polys = plots })
	local pads = {}
	for _, d in area and area:GetChildren() or {} do
		if d:IsA("BasePart") and string.sub(d.Name, -3) == "Pad" then -- StartPad, UpgradePad, MarketPad
			table.insert(pads, d)
		end
	end
	table.insert(sets, { Label = "pads", Polys = polys(pads) })
	table.insert(sets, { Label = "spawn", Polys = polys(partsOf(area and area:FindFirstChild("Spawn"))) })
	local marketplace = area and area:FindFirstChild("Marketplace")
	local footprint = marketplace and marketplace:IsA("Model") and marketplace.PrimaryPart
	table.insert(sets, { Label = "marketplace", Polys = polys(partsOf(footprint or nil)) })
	local platform = partsOf(area and area:FindFirstChild("RaceBoundaries"))
	local startPad = area and area:FindFirstChild("StartPad")
	if startPad and startPad:IsA("BasePart") then
		table.insert(platform, startPad)
	end
	table.insert(sets, { Label = "race_platform", Polys = polys(platform) })
	local trackParts = {}
	for _, d in partsOf(trackFolder) do
		if d.Name ~= "Ground" and d.Name ~= "Start" then -- as in spawn_area: neither is road
			table.insert(trackParts, d)
		end
	end
	table.insert(sets, { Label = "track_parts", Polys = polys(trackParts) })
	local signs = {}
	for _, d in partsOf(area and area:FindFirstChild("Leaderboards")) do
		if string.sub(d.Name, 1, 6) == "Board_" then
			table.insert(signs, d)
		end
	end
	table.insert(sets, { Label = "signs", Polys = polys(signs) })
	table.insert(sets, {
		Label = "best_roll",
		Polys = worldOk and bestOk and { circlePoly(startPart.CFrame, B.X, B.Z, B.RADIUS) } or {},
	})
	for i, car in CARS do
		local e = entryFor[car.Id]
		local circle = geomOk and e and circlePoly(startPart.CFrame, e.X, e.Z, P.RADIUS)
		local other = entryFor[CARS[3 - i].Id]
		local otherSet = {
			Label = "other_pass",
			Polys = geomOk and other and { circlePoly(startPart.CFrame, other.X, other.Z, P.RADIUS) } or {},
		}
		for _, set in { sets[1], sets[2], sets[3], sets[4], sets[5], sets[6], sets[7], sets[8], otherSet } do
			local overlaps, gap = 0, math.huge
			for _, poly in circle and set.Polys or {} do
				local sep = separation(circle, poly)
				gap = math.min(gap, sep)
				if sep < -GEOM_TOL then
					overlaps += 1
				end
			end
			r.metrics[car.Id .. "_" .. set.Label .. "_gap"] = gap == math.huge and -1 or math.round(gap * 1000) / 1000
			flag(
				"pass_cars_clear_of_" .. set.Label .. "_" .. car.Id,
				circle ~= nil and circle ~= false and #set.Polys > 0 and overlaps == 0,
				overlaps,
				0
			)
		end
	end

	-- Service API (spec section 3)
	local api = service ~= nil
		and gacha ~= nil
		and data ~= nil
		and type(service.SetMarket) == "function"
		and type(service.Check) == "function"
		and type(service.Trigger) == "function"
		and type(service.Purchased) == "function"
		and specs[CARS[1].Id] ~= nil
		and specs[CARS[2].Id] ~= nil
	flag("pass_cars_api_exists", api == true)
	if not api then
		return r
	end

	local EMBER, SING = CARS[1].Id, CARS[2].Id
	local STARTER = catalog.STARTER_ID
	local original = { [EMBER] = specs[EMBER].GamepassId, [SING] = specs[SING].GamepassId }
	local players = {}
	local ok, err = pcall(function()
		-- The fake market: records every call; `owned[userId .. ":" .. passId]` decides Owns
		local market = { Owned = {}, Asked = {}, Prompts = {}, Throw = false }
		service.SetMarket({
			Owns = function(userId, passId)
				table.insert(market.Asked, { UserId = userId, PassId = passId })
				if market.Throw then
					error("fake market down")
				end
				return market.Owned[tostring(userId) .. ":" .. tostring(passId)] == true
			end,
			Prompt = function(player, passId)
				table.insert(market.Prompts, { Player = player, PassId = passId })
			end,
		})
		local function setIds(ember, sing)
			specs[EMBER].GamepassId = ember
			specs[SING].GamepassId = sing
		end
		local function player(index)
			local p = Instance.new("Folder")
			p.Name = "CarTestPassCar" .. index
			p:SetAttribute("UserId", ID_BASE + index)
			p.Parent = Workspace
			table.insert(players, p)
			data.Setup(p)
			gacha.Setup(p)
			p:SetAttribute("DataLoaded", true)
			return p, ID_BASE + index
		end
		local function check(p)
			local okCheck = pcall(service.Check, p)
			local done = waitFor(function()
				return p:GetAttribute("PassChecked") == true
			end)
			return okCheck, done
		end
		local function askedFor(userId, passId)
			local n = 0
			for _, q in market.Asked do
				if q.UserId == userId and q.PassId == passId then
					n += 1
				end
			end
			return n
		end
		local function equipped(p)
			return p:GetAttribute("EquippedCar")
		end

		-- GamepassId = 0 (as shipped until the owner creates the passes): never asked, never owned, never prompts.
		-- The fake market says "owned" for everything, so only the id-0 rule can keep the attributes nil.
		setIds(0, 0)
		local p1, u1 = player(1)
		market.Owned[tostring(u1) .. ":0"] = true
		flag("pass_cars_equip_refused_without_pass_id0", gacha.Equip(p1, EMBER) == false and equipped(p1) == STARTER)
		local okCheck, done = check(p1)
		flag("pass_cars_check_no_error_id0", okCheck)
		flag("pass_cars_check_sets_pass_checked_id0", done)
		flag("pass_cars_id0_never_asked", #market.Asked == 0, #market.Asked, 0)
		flag(
			"pass_cars_id0_never_owned",
			p1:GetAttribute("Pass_" .. EMBER) == nil and p1:GetAttribute("Pass_" .. SING) == nil
		)
		local okTrigger = pcall(service.Trigger, p1, EMBER)
		flag("pass_cars_trigger_no_error_id0", okTrigger)
		flag("pass_cars_id0_trigger_never_prompts", #market.Prompts == 0, #market.Prompts, 0)
		flag("pass_cars_id0_trigger_equips_nothing", equipped(p1) == STARTER, tostring(equipped(p1)), STARTER)
		local okBuy0 = pcall(service.Purchased, p1, 0)
		flag(
			"pass_cars_id0_purchase_grants_nothing",
			okBuy0
				and p1:GetAttribute("Pass_" .. EMBER) == nil
				and p1:GetAttribute("Pass_" .. SING) == nil
				and equipped(p1) == STARTER
		)
		-- Apply keeps a saved gamepass car; the check (id 0: never owned) puts the starter back
		local p2 = player(2)
		gacha.Apply(p2, { Equipped = EMBER })
		flag("pass_cars_apply_keeps_saved_pass_car", equipped(p2) == EMBER, tostring(equipped(p2)), EMBER)
		check(p2)
		flag("pass_cars_check_resets_unowned_id0", equipped(p2) == STARTER, tostring(equipped(p2)), STARTER)

		-- Real (made-up) pass ids from here on
		setIds(PASS_IDS[EMBER], PASS_IDS[SING])
		local p3, u3 = player(3)
		-- three index cars: one stat point, a rarest-car score
		local rarest, granted = 0, 0
		for _, spec in catalog.All() do
			if granted < 3 and type(spec.Chance) == "number" and gacha.Grant(p3, spec.Id) == true then
				granted += 1
				rarest = math.max(rarest, spec.Chance)
			end
		end
		local before = {
			Unique = gacha.UniqueCount(p3),
			Points = p3:GetAttribute("StatPoints"),
			Earned = gacha.EarnedPoints(p3),
			Entries = #p3.GachaData:GetChildren(),
		}
		market.Asked = {}
		okCheck, done = check(p3)
		flag("pass_cars_check_no_error", okCheck)
		flag("pass_cars_check_sets_pass_checked", done)
		flag(
			"pass_cars_check_asks_every_pass_once",
			askedFor(u3, PASS_IDS[EMBER]) == 1 and askedFor(u3, PASS_IDS[SING]) == 1 and #market.Asked == 2,
			#market.Asked,
			2
		)
		flag(
			"pass_cars_not_owned_attribute_nil",
			p3:GetAttribute("Pass_" .. EMBER) == nil and p3:GetAttribute("Pass_" .. SING) == nil
		)
		flag("pass_cars_equip_refused_without_pass", gacha.Equip(p3, EMBER) == false and equipped(p3) == STARTER)
		okTrigger = pcall(service.Trigger, p3, EMBER)
		local prompt = market.Prompts[1]
		flag("pass_cars_trigger_no_error", okTrigger)
		flag(
			"pass_cars_trigger_prompts_purchase",
			#market.Prompts == 1 and prompt.Player == p3 and prompt.PassId == PASS_IDS[EMBER],
			#market.Prompts,
			1
		)
		flag("pass_cars_trigger_unowned_equips_nothing", equipped(p3) == STARTER, tostring(equipped(p3)), STARTER)
		local strayOk = true
		for _, bad in { "wooden_car", STARTER, "car_test_no_such_car", 42 } do
			strayOk = strayOk and pcall(service.Trigger, p3, bad)
		end
		flag("pass_cars_trigger_other_ids_no_error", strayOk)
		flag(
			"pass_cars_trigger_other_ids_no_prompt",
			#market.Prompts == 1 and equipped(p3) == STARTER,
			#market.Prompts,
			1
		)
		-- An unknown pass id buys nothing
		local okUnknown = pcall(service.Purchased, p3, UNKNOWN_PASS)
		flag(
			"pass_cars_unknown_pass_purchase_grants_nothing",
			okUnknown
				and p3:GetAttribute("Pass_" .. EMBER) == nil
				and p3:GetAttribute("Pass_" .. SING) == nil
				and equipped(p3) == STARTER
		)
		-- A fake purchase sets the attribute and equips
		local okBuy = pcall(service.Purchased, p3, PASS_IDS[EMBER])
		flag("pass_cars_purchase_no_error", okBuy)
		flag("pass_cars_purchase_sets_attribute", p3:GetAttribute("Pass_" .. EMBER) == true)
		flag("pass_cars_purchase_only_that_pass", p3:GetAttribute("Pass_" .. SING) == nil)
		flag("pass_cars_purchase_equips", equipped(p3) == EMBER, tostring(equipped(p3)), EMBER)
		-- Owned: the prompt equips, never asks to buy again
		gacha.Equip(p3, STARTER)
		pcall(service.Trigger, p3, EMBER)
		flag("pass_cars_trigger_owned_equips", equipped(p3) == EMBER, tostring(equipped(p3)), EMBER)
		flag("pass_cars_trigger_owned_no_prompt", #market.Prompts == 1, #market.Prompts, 1)
		-- Equip accepted with the pass, refused for the other one
		flag(
			"pass_cars_equip_accepted_with_pass",
			gacha.Equip(p3, STARTER) == true and gacha.Equip(p3, EMBER) == true and equipped(p3) == EMBER
		)
		flag("pass_cars_equip_other_pass_refused", gacha.Equip(p3, SING) == false and equipped(p3) == EMBER)
		-- Effects of any car: its SpeedMulti
		local multi = type(gacha.CarSpeedMulti) == "function" and gacha.CarSpeedMulti(p3) or -1
		flag("pass_cars_equipped_speed_multi", multi == specs[EMBER].SpeedMulti, multi, specs[EMBER].SpeedMulti)
		-- No stat points, never in GachaData, never saved in Cars, never on the Rarest Car board
		flag("pass_cars_grant_returns_nil", gacha.Grant(p3, EMBER) == nil and gacha.Grant(p3, SING) == nil)
		flag(
			"pass_cars_not_in_gacha_data",
			p3.GachaData:FindFirstChild(EMBER) == nil
				and p3.GachaData:FindFirstChild(SING) == nil
				and #p3.GachaData:GetChildren() == before.Entries,
			#p3.GachaData:GetChildren(),
			before.Entries
		)
		flag(
			"pass_cars_unique_count_unchanged",
			gacha.UniqueCount(p3) == before.Unique,
			gacha.UniqueCount(p3),
			before.Unique
		)
		flag(
			"pass_cars_stat_points_unchanged",
			p3:GetAttribute("StatPoints") == before.Points and gacha.EarnedPoints(p3) == before.Earned,
			tonumber(p3:GetAttribute("StatPoints")) or -1,
			tonumber(before.Points) or -1
		)
		local snap = gacha.Snapshot(p3)
		local savedPass = false
		for _, savedId in snap.Cars do
			savedPass = savedPass or savedId == EMBER or savedId == SING
		end
		flag("pass_cars_never_saved_in_cars", not savedPass)
		flag("pass_cars_snapshot_saves_equipped", snap.Equipped == EMBER, tostring(snap.Equipped), EMBER)
		if leaderboard and type(leaderboard.Scores) == "function" then
			local scores = leaderboard.Scores(p3)
			local score = type(scores) == "table" and scores.RarestCar or -1
			flag("pass_cars_not_on_rarest_car_board", score == rarest, tonumber(score) or -1, rarest)
		else
			flag("pass_cars_not_on_rarest_car_board", false, -1, rarest)
		end
		-- A saved Cars list naming a pass car adds nothing to GachaData
		local p6 = player(6)
		gacha.Apply(p6, { Cars = { EMBER, SING, "wooden_car" }, Equipped = STARTER })
		flag(
			"pass_cars_apply_drops_pass_ids_from_cars",
			p6.GachaData:FindFirstChild(EMBER) == nil and p6.GachaData:FindFirstChild(SING) == nil
		)
		flag("pass_cars_apply_pass_ids_count_nothing", gacha.UniqueCount(p6) == 1, gacha.UniqueCount(p6), 1)

		-- The check on a saved car: owned keeps it, not owned resets to the starter
		local p4, u4 = player(4)
		market.Owned[tostring(u4) .. ":" .. tostring(PASS_IDS[SING])] = true
		gacha.Apply(p4, { Equipped = SING })
		flag("pass_cars_apply_keeps_saved_pass_car_owned", equipped(p4) == SING, tostring(equipped(p4)), SING)
		check(p4)
		flag("pass_cars_check_sets_owned_attribute", p4:GetAttribute("Pass_" .. SING) == true)
		flag("pass_cars_check_only_owned_pass", p4:GetAttribute("Pass_" .. EMBER) == nil)
		flag("pass_cars_check_keeps_owned_equipped", equipped(p4) == SING, tostring(equipped(p4)), SING)
		local p5 = player(5)
		gacha.Apply(p5, { Equipped = EMBER })
		check(p5)
		flag("pass_cars_check_resets_unowned", equipped(p5) == STARTER, tostring(equipped(p5)), STARTER)

		-- A failing market raises no error and counts as not owned
		market.Throw = true
		local p7, u7 = player(7)
		market.Owned[tostring(u7) .. ":" .. tostring(PASS_IDS[EMBER])] = true
		gacha.Apply(p7, { Equipped = EMBER })
		okCheck, done = check(p7)
		flag("pass_cars_failing_market_no_error", okCheck)
		flag("pass_cars_failing_market_pass_checked", done)
		flag(
			"pass_cars_failing_market_not_owned",
			p7:GetAttribute("Pass_" .. EMBER) == nil and p7:GetAttribute("Pass_" .. SING) == nil
		)
		flag("pass_cars_failing_market_resets_equipped", equipped(p7) == STARTER, tostring(equipped(p7)), STARTER)
		market.Throw = false

		-- One pass created, the other still 0: only the created one is asked
		setIds(PASS_IDS[EMBER], 0)
		local p8, u8 = player(8)
		market.Owned[tostring(u8) .. ":0"] = true
		market.Asked = {}
		check(p8)
		flag(
			"pass_cars_check_skips_id0_pass",
			askedFor(u8, PASS_IDS[EMBER]) == 1 and #market.Asked == 1,
			#market.Asked,
			1
		)
		flag("pass_cars_mixed_id0_never_owned", p8:GetAttribute("Pass_" .. SING) == nil)
		market.Prompts = {}
		pcall(service.Trigger, p8, SING)
		flag("pass_cars_mixed_id0_never_prompts", #market.Prompts == 0, #market.Prompts, 0)
	end)
	-- Restore the shipped pass ids and the real market
	specs[EMBER].GamepassId = original[EMBER]
	specs[SING].GamepassId = original[SING]
	pcall(service.SetMarket, nil)
	for _, p in players do
		p:Destroy()
	end
	flag(
		"pass_cars_ids_restored",
		specs[EMBER].GamepassId == original[EMBER] and specs[SING].GamepassId == original[SING]
	)
	flag("pass_cars_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

return Tests
