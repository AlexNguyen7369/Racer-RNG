--!nonstrict
-- BRIEF (owner, 2026-10-12, dashboard card 487b1922; docs/GAME_DESIGN_REQUIREMENTS.md "Global leaderboards",
-- contract docs/LEADERBOARD_SPEC.md): "OrderedDataStore boards for Speed, Money earned, rolls and rarest car, shown
-- on signs in the spawn area. Server-only." Spec section 4: "`leaderboard` harness scenario with a fake store:
-- descending order and the `TOP_N` cap, integer scores, the Speed max rule (a lower Speed never overwrites), nothing
-- written for a failed or unloaded save, zero not written, the signs exist and overlap nothing in the list above,
-- the rows match `Top(id)`, a throwing store raises no error."
-- Written before Shared/LeaderboardConfig, Server/LeaderboardService and the signs exist: red by design.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Server = script.Parent.Parent
local Tests = {}

-- Spec section 1. Titles are read off the signs and store names off the injected store lookup, so the test does not
-- depend on how LeaderboardConfig lays the table out.
local TOP_N = 10
local REFRESH = 60
local WRITE_INTERVAL = 300
local BOARDS = {
	{ Id = "Speed", Title = "TOP SPEED", Store = "LB_Speed_v1" },
	{ Id = "MoneyEarned", Title = "MONEY EARNED", Store = "LB_MoneyEarned_v1" },
	{ Id = "Rolls", Title = "MOST ROLLS", Store = "LB_Rolls_v1" },
	{ Id = "RarestCar", Title = "RAREST CAR", Store = "LB_RarestCar_v1" },
}
local NO_DATA = "No data yet"
-- docs/SPAWN_AND_ROLLS_SPEC.md: the hub, local (x, z) of Track 1's Start (same literals as the spawn_area scenario)
local HUB_MIN = Vector2.new(24, -100)
local HUB_MAX = Vector2.new(184, 44)
local GEOM_TOL = 0.05 -- studs of footprint overlap ignored (parts that only touch)
local ID_BASE = 990074100 -- fake user ids; names come from the injected lookup, never from the web

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

local function isInt(n)
	return type(n) == "number" and n == n and math.floor(n) == n
end

-- Fake OrderedDataStores, one per store name. `state.Throw` makes every method error.
local function newStores()
	local state = { Data = {}, Asked = {}, Sets = {}, Updates = {}, Sorted = {}, Throw = false }
	local objects = {}
	local function count(list, name)
		list[name] = (list[name] or 0) + 1
	end
	function state.Get(name)
		table.insert(state.Asked, name)
		if objects[name] then
			return objects[name]
		end
		local data = {}
		state.Data[name] = data
		local store = {}
		function store:SetAsync(key, value)
			if state.Throw then
				error("fake store down")
			end
			count(state.Sets, name)
			data[key] = value
		end
		function store:UpdateAsync(key, transform)
			if state.Throw then
				error("fake store down")
			end
			count(state.Updates, name)
			local new = transform(data[key])
			if new ~= nil then
				data[key] = new
			end
			return new
		end
		function store:GetSortedAsync(ascending, pageSize)
			if state.Throw then
				error("fake store down")
			end
			state.Sorted[name] = { Ascending = ascending, PageSize = pageSize }
			local rows = {}
			for key, value in data do
				table.insert(rows, { key = key, value = value })
			end
			table.sort(rows, function(a, b)
				if a.value ~= b.value then
					if ascending then
						return a.value < b.value
					end
					return a.value > b.value
				end
				return a.key < b.key
			end)
			local page = table.move(rows, 1, math.min(#rows, tonumber(pageSize) or #rows), 1, {})
			return {
				GetCurrentPage = function()
					return page
				end,
			}
		end
		objects[name] = store
		return store
	end
	function state.Keys(name)
		local n = 0
		for _ in state.Data[name] or {} do
			n += 1
		end
		return n
	end
	function state.Value(name, userId)
		return (state.Data[name] or {})[tostring(userId)]
	end
	return state
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

-- The sign's Title and Row1..Row10 labels, or nil when the sign is not built as the spec says.
local function labelsOf(board)
	local gui = board and board:FindFirstChild("Board")
	if not (gui and gui:IsA("SurfaceGui")) then
		return nil
	end
	local labels = { Title = gui:FindFirstChild("Title", true), Rows = {} }
	if not (labels.Title and labels.Title:IsA("TextLabel")) then
		return nil
	end
	for i = 1, TOP_N do
		local row = gui:FindFirstChild("Row" .. i, true)
		if not (row and row:IsA("TextLabel")) then
			return nil
		end
		labels.Rows[i] = row
	end
	return labels
end

local function rowTexts(labels)
	local texts = {}
	for i = 1, TOP_N do
		texts[i] = labels and labels.Rows[i].Text or "<missing>"
	end
	return table.concat(texts, "|")
end

function Tests.leaderboard()
	local r, flag = report("leaderboard")
	local config = module(Shared, "LeaderboardConfig")
	local service = module(Server, "LeaderboardService")
	local hud = module(Shared, "HudFormat")
	local catalog = module(Shared, "CarCatalog")
	local workshopConfig = module(Shared, "WorkshopConfig")
	local registry = module(Shared, "TrackRegistry")
	local data = module(Server, "PlayerData")
	local gacha = module(Server, "GachaService")

	-- Config (spec section 1)
	flag("leaderboard_config_exists", config ~= nil)
	local C = config or {}
	flag("leaderboard_config_top_n", C.TOP_N == TOP_N, tonumber(C.TOP_N) or -1, TOP_N)
	flag("leaderboard_config_refresh", C.REFRESH == REFRESH, tonumber(C.REFRESH) or -1, REFRESH)
	flag(
		"leaderboard_config_write_interval",
		C.WRITE_INTERVAL == WRITE_INTERVAL,
		tonumber(C.WRITE_INTERVAL) or -1,
		WRITE_INTERVAL
	)

	-- No remote (spec section 2): clients can not write a score or ask for a refresh
	local remotes = 0
	for _, d in ReplicatedStorage:GetDescendants() do
		if
			(d:IsA("BaseRemoteEvent") or d:IsA("RemoteFunction"))
			and string.find(string.lower(d.Name), "leaderboard", 1, true)
		then
			remotes += 1
		end
	end
	flag("leaderboard_no_remote", remotes == 0, remotes, 0)

	-- Signs (spec section 3)
	local area = Workspace:FindFirstChild("SpawnArea")
	local trackFolder = Workspace:FindFirstChild("Track")
	local specs = registry and type(registry.Chain) == "function" and registry.Chain() or {}
	local track1 = trackFolder and specs[1] and trackFolder:FindFirstChild(specs[1].Name)
	local startPart = track1 and track1:FindFirstChild("Start")
	local worldOk = area ~= nil and startPart ~= nil and startPart:IsA("BasePart")
	flag("leaderboard_spawn_area_and_chain_present", worldOk)
	local signs = area and area:FindFirstChild("Leaderboards")
	flag("leaderboard_signs_model_exists", signs ~= nil and signs:IsA("Model"))
	local boardCount = 0
	for _, d in signs and signs:GetChildren() or {} do
		if string.sub(d.Name, 1, 6) == "Board_" then
			boardCount += 1
		end
	end
	flag("leaderboard_one_sign_per_board", boardCount == #BOARDS, boardCount, #BOARDS)
	local labels, signPolys = {}, {}
	for _, b in BOARDS do
		local part = signs and signs:FindFirstChild("Board_" .. b.Id)
		local partOk = part ~= nil and part:IsA("BasePart")
		flag("leaderboard_sign_exists_" .. b.Id, partOk)
		flag("leaderboard_sign_anchored_" .. b.Id, partOk and part.Anchored == true)
		flag("leaderboard_sign_can_collide_" .. b.Id, partOk and part.CanCollide == true)
		if partOk then
			labels[b.Id] = labelsOf(part)
			table.insert(signPolys, { Id = b.Id, Poly = partPoly(part) })
		end
		flag("leaderboard_sign_gui_title_and_rows_" .. b.Id, labels[b.Id] ~= nil)
		local title = labels[b.Id] and labels[b.Id].Title.Text or "<missing>"
		flag("leaderboard_sign_title_" .. b.Id, title == b.Title, title, b.Title)
		local inside = false
		if partOk and worldOk then
			inside = true
			for _, p in signPolys[#signPolys].Poly.Points do
				local l = startPart.CFrame:PointToObjectSpace(Vector3.new(p.X, 0, p.Y))
				inside = inside
					and l.X >= HUB_MIN.X - GEOM_TOL
					and l.X <= HUB_MAX.X + GEOM_TOL
					and l.Z >= HUB_MIN.Y - GEOM_TOL
					and l.Z <= HUB_MAX.Y + GEOM_TOL
			end
		end
		flag("leaderboard_sign_inside_hub_" .. b.Id, inside)
	end
	-- The signs overlap none of: plot, pad, Spawn, marketplace footprint, race platform, track part
	local allSigns = #signPolys == #BOARDS
	local function clear(label, obstacles)
		local overlaps, worst = 0, math.huge
		for _, sign in signPolys do
			for _, poly in obstacles do
				local sep = separation(sign.Poly, poly)
				worst = math.min(worst, sep)
				if sep < -GEOM_TOL then
					overlaps += 1
				end
			end
		end
		r.metrics[label .. "_gap"] = worst == math.huge and -1 or math.round(worst * 1000) / 1000
		flag("leaderboard_signs_clear_of_" .. label, allSigns and #obstacles > 0 and overlaps == 0, overlaps, 0)
	end
	local function polys(parts)
		local list = {}
		for _, p in parts do
			table.insert(list, partPoly(p))
		end
		return list
	end
	local plots = {}
	for _, plot in worldOk and workshopConfig and workshopConfig.Plots or {} do
		table.insert(plots, rectPoly(startPart.CFrame, plot.Min, plot.Max))
	end
	clear("plots", plots)
	local pads = {}
	for _, d in area and area:GetChildren() or {} do
		if d:IsA("BasePart") and string.sub(d.Name, -3) == "Pad" then -- StartPad, UpgradePad, MarketPad
			table.insert(pads, d)
		end
	end
	clear("pads", polys(pads))
	clear("spawn", polys(partsOf(area and area:FindFirstChild("Spawn"))))
	local marketplace = area and area:FindFirstChild("Marketplace")
	local footprint = marketplace and marketplace:IsA("Model") and marketplace.PrimaryPart
	clear("marketplace", polys(partsOf(footprint or nil)))
	local platform = partsOf(area and area:FindFirstChild("RaceBoundaries"))
	local startPad = area and area:FindFirstChild("StartPad")
	if startPad and startPad:IsA("BasePart") then
		table.insert(platform, startPad)
	end
	clear("race_platform", polys(platform))
	local trackParts = {}
	for _, d in partsOf(trackFolder) do
		if d.Name ~= "Ground" and d.Name ~= "Start" then -- as in spawn_area: neither is road
			table.insert(trackParts, d)
		end
	end
	clear("track_parts", polys(trackParts))

	-- Service API (spec section 2 + the agreed test seams SetStore / SetNameLookup)
	local api = service ~= nil
		and config ~= nil
		and hud ~= nil
		and catalog ~= nil
		and data ~= nil
		and gacha ~= nil
		and type(service.Start) == "function"
		and type(service.Scores) == "function"
		and type(service.Write) == "function"
		and type(service.Refresh) == "function"
		and type(service.Top) == "function"
		and type(service.SetStore) == "function"
		and type(service.SetNameLookup) == "function"
	flag("leaderboard_api_exists", api == true)
	if not api then
		return r
	end

	local players = {}
	local stores = newStores()
	local lookups = {}
	local THROWING_NAME_ID = ID_BASE + 12 -- the top Speed row: its name lookup fails
	local function nameOf(userId)
		return "Racer" .. tostring(userId)
	end
	local ok, err = pcall(function()
		service.SetStore(stores.Get)
		service.SetNameLookup(function(userId)
			lookups[userId] = (lookups[userId] or 0) + 1
			if userId == THROWING_NAME_ID then
				error("name lookup down")
			end
			return nameOf(userId)
		end)
		local function player(index, loaded)
			local p = Instance.new("Folder")
			p.Name = "CarTestLeaderboard" .. index
			p:SetAttribute("UserId", ID_BASE + 50 + index)
			p.Parent = Workspace
			table.insert(players, p)
			data.Setup(p)
			gacha.Setup(p)
			if loaded then
				p:SetAttribute("DataLoaded", true)
			end
			return p, ID_BASE + 50 + index
		end
		local function storedNowhere(userId)
			for _, b in BOARDS do
				if stores.Value(b.Store, userId) ~= nil then
					return false
				end
			end
			return true
		end

		-- Scores(player): four integer scores
		local p, id = player(1, true)
		p.leaderstats.Speed.Value = 321.9
		p:SetAttribute("MoneyEarned", 9000.7)
		p:SetAttribute("Rolls", 40)
		gacha.Grant(p, "wooden_car")
		gacha.Grant(p, "go_kart")
		local unknown = Instance.new("StringValue") -- saves keep unknown ids; only catalog cars count
		unknown.Name = "car_test_not_in_catalog"
		unknown.Parent = p.GachaData
		local rarest = math.max(catalog.Get("wooden_car").Chance, catalog.Get("go_kart").Chance)
		local scores = service.Scores(p)
		local isTable = type(scores) == "table"
		local S = isTable and scores or {}
		local keys = 0
		for _ in S do
			keys += 1
		end
		flag("leaderboard_scores_has_four_boards", isTable and keys == #BOARDS, keys, #BOARDS)
		flag("leaderboard_scores_speed_floored", S.Speed == 321, tonumber(S.Speed) or -1, 321)
		flag("leaderboard_scores_money_earned_floored", S.MoneyEarned == 9000, tonumber(S.MoneyEarned) or -1, 9000)
		flag("leaderboard_scores_rolls", S.Rolls == 40, tonumber(S.Rolls) or -1, 40)
		flag("leaderboard_scores_rarest_car", S.RarestCar == rarest, tonumber(S.RarestCar) or -1, rarest)
		local bare = player(2, true)
		local bareScores = service.Scores(bare)
		local bareRarest = type(bareScores) == "table" and bareScores.RarestCar
		flag("leaderboard_scores_rarest_car_zero_without_cars", bareRarest == 0, tonumber(bareRarest) or -1, 0)

		-- Write(player): integers, keyed by tostring(userId), into the four spec stores
		local wrote = service.Write(p)
		flag("leaderboard_write_returns_true", wrote == true)
		local want = { Speed = 321, MoneyEarned = 9000, Rolls = 40, RarestCar = rarest }
		for _, b in BOARDS do
			local got = stores.Value(b.Store, id)
			flag(
				"leaderboard_write_integer_" .. b.Id,
				isInt(got) and got == want[b.Id],
				tonumber(got) or -1,
				want[b.Id]
			)
		end
		flag(
			"leaderboard_speed_written_with_update_async",
			(stores.Updates.LB_Speed_v1 or 0) >= 1 and (stores.Sets.LB_Speed_v1 or 0) == 0,
			stores.Updates.LB_Speed_v1 or 0,
			1
		)

		-- Speed max rule: a lower Speed (after a rebirth) never overwrites, a higher one does
		p.leaderstats.Speed.Value = 50.5
		p:SetAttribute("Rolls", 25)
		service.Write(p)
		local kept = stores.Value("LB_Speed_v1", id)
		flag("leaderboard_lower_speed_never_overwrites", kept == 321, tonumber(kept) or -1, 321)
		-- "the others are set to the current value"
		local rolls = stores.Value("LB_Rolls_v1", id)
		flag("leaderboard_others_set_to_current_value", rolls == 25, tonumber(rolls) or -1, 25)
		p.leaderstats.Speed.Value = 400.2
		service.Write(p)
		local raised = stores.Value("LB_Speed_v1", id)
		flag("leaderboard_higher_speed_overwrites", raised == 400, tonumber(raised) or -1, 400)

		-- Never for a failed or unloaded save
		local function loaded(index)
			local q, qid = player(index, true)
			q.leaderstats.Speed.Value = 77
			q:SetAttribute("MoneyEarned", 77)
			q:SetAttribute("Rolls", 77)
			gacha.Grant(q, "wooden_car")
			return q, qid
		end
		local failed, failedId = loaded(3)
		failed:SetAttribute("DataFailed", true)
		flag("leaderboard_no_write_data_failed", service.Write(failed) == false and storedNowhere(failedId))
		local unloaded, unloadedId = loaded(4)
		unloaded:SetAttribute("DataLoaded", nil)
		flag("leaderboard_no_write_without_data_loaded", service.Write(unloaded) == false and storedNowhere(unloadedId))

		-- A score of 0 is not written
		local zero, zeroId = player(5, true)
		flag("leaderboard_all_zero_writes_nothing", service.Write(zero) == false and storedNowhere(zeroId))
		local partial, partialId = player(6, true)
		partial.leaderstats.Speed.Value = 5
		flag("leaderboard_partial_write_returns_true", service.Write(partial) == true)
		flag(
			"leaderboard_zero_score_not_written",
			stores.Value("LB_Speed_v1", partialId) == 5
				and stores.Value("LB_MoneyEarned_v1", partialId) == nil
				and stores.Value("LB_Rolls_v1", partialId) == nil
				and stores.Value("LB_RarestCar_v1", partialId) == nil
		)

		-- Seed the boards (replacing what the writes above left) and read them
		local chances = {}
		for _, spec in catalog.All() do
			if type(spec.Chance) == "number" then
				table.insert(chances, spec)
			end
		end
		table.sort(chances, function(a, b)
			return a.Chance > b.Chance
		end)
		local seeds = { Speed = {}, MoneyEarned = {}, Rolls = {}, RarestCar = {} }
		for i = 1, TOP_N + 2 do -- more than TOP_N rows; i = 12 is the best
			seeds.Speed[i] = i * 1111
		end
		for i = 1, TOP_N do
			seeds.MoneyEarned[i] = i * 250000
		end
		for i = 1, 3 do -- seven empty rows
			seeds.Rolls[i] = i * 40
		end
		for i = 1, math.min(#chances, TOP_N) do
			seeds.RarestCar[i] = chances[i].Chance
		end
		local expected = {} -- board id -> { { UserId, Score } }, highest first, at most TOP_N
		for _, b in BOARDS do
			local store = stores.Get(b.Store)
			table.clear(stores.Data[b.Store])
			local rows = {}
			for i, score in seeds[b.Id] do
				store:SetAsync(tostring(ID_BASE + i), score)
				table.insert(rows, { UserId = ID_BASE + i, Score = score })
			end
			table.sort(rows, function(a, c)
				return a.Score > c.Score
			end)
			expected[b.Id] = table.move(rows, 1, math.min(#rows, TOP_N), 1, {})
		end
		service.Refresh()

		local wanted, strays = 0, 0
		for _, b in BOARDS do
			if stores.Sorted[b.Store] then -- the board was really read from its spec store
				wanted += 1
			end
		end
		for _, asked in stores.Asked do
			local known = false
			for _, b in BOARDS do
				known = known or b.Store == asked
			end
			strays += known and 0 or 1
		end
		flag("leaderboard_store_names_match_spec", wanted == #BOARDS and strays == 0, wanted, #BOARDS)

		local tops = {}
		for _, b in BOARDS do
			local top = service.Top(b.Id)
			local topOk = type(top) == "table"
			tops[b.Id] = topOk and top or {}
			local sorted = stores.Sorted[b.Store]
			flag(
				"leaderboard_reads_descending_top_n_" .. b.Id,
				sorted ~= nil and sorted.Ascending == false and sorted.PageSize == TOP_N,
				sorted and tonumber(sorted.PageSize) or -1,
				TOP_N
			)
			local wantRows = expected[b.Id]
			flag("leaderboard_top_count_" .. b.Id, topOk and #top == #wantRows, topOk and #top or -1, #wantRows)
			local descending, integers, exact, names = topOk, topOk, topOk and #top == #wantRows, topOk
			for i, entry in tops[b.Id] do
				local e = type(entry) == "table" and entry or {}
				local previous = tops[b.Id][i - 1]
				if previous and not (type(e.Score) == "number" and previous.Score > e.Score) then
					descending = false
				end
				integers = integers and isInt(e.Score)
				local w = wantRows[i]
				exact = exact and w ~= nil and e.UserId == w.UserId and e.Score == w.Score
				if e.UserId ~= THROWING_NAME_ID then
					names = names and e.Name == nameOf(e.UserId)
				end
			end
			flag("leaderboard_top_descending_" .. b.Id, descending)
			flag("leaderboard_top_integer_scores_" .. b.Id, integers)
			flag("leaderboard_top_matches_store_" .. b.Id, exact)
			flag("leaderboard_top_names_from_lookup_" .. b.Id, names)
		end
		flag("leaderboard_top_n_cap", #tops.Speed == TOP_N, #tops.Speed, TOP_N)
		local first = tops.Speed[1]
		local fallback = "Player " .. tostring(THROWING_NAME_ID)
		flag(
			"leaderboard_failed_name_lookup_shows_player_id",
			type(first) == "table" and first.UserId == THROWING_NAME_ID and first.Name == fallback,
			type(first) == "table" and tostring(first.Name) or "<missing>",
			fallback
		)

		-- The rows match Top(id); empty rows are blank
		local function carFor(chance)
			for _, spec in chances do
				if spec.Chance == chance then
					return spec
				end
			end
			return nil
		end
		local function rowsMatch(boardId)
			local l = labels[boardId]
			if not l or #tops[boardId] == 0 then
				return false
			end
			for i, entry in tops[boardId] do
				local text = l.Rows[i].Text
				local head = ("%d. %s"):format(i, tostring(entry.Name))
				if boardId == "RarestCar" then
					-- spec: "shows the car's name and `1 in <Chance>`": rank and name, then the car, then the odds
					local car = carFor(entry.Score)
					local at = car
						and string.sub(text, 1, #head) == head
						and string.find(text, car.Name, #head + 1, true)
					if not (at and string.find(text, hud.Odds(entry.Score), at + #car.Name, true)) then
						return false
					end
				elseif boardId == "MoneyEarned" then
					-- spec: "scores use Shared/HudFormat": the plain number or the Money form of it
					if
						text ~= head .. "  " .. hud.SpeedText(entry.Score)
						and text ~= head .. "  " .. hud.MoneyText(entry.Score)
					then
						return false
					end
				elseif text ~= head .. "  " .. hud.SpeedText(entry.Score) then
					return false
				end
			end
			return true
		end
		for _, b in BOARDS do
			flag(
				"leaderboard_rows_match_top_" .. b.Id,
				rowsMatch(b.Id),
				rowTexts(labels[b.Id]),
				"<rank>. <Name>  <score>"
			)
			local blank = labels[b.Id] ~= nil
			for i = #tops[b.Id] + 1, TOP_N do
				blank = blank and labels[b.Id].Rows[i].Text == ""
			end
			flag("leaderboard_empty_rows_blank_" .. b.Id, blank)
		end
		local rollRows = labels.Rolls and labels.Rolls.Rows
		flag(
			"leaderboard_rolls_board_has_seven_blank_rows",
			rollRows ~= nil and rollRows[3].Text ~= "" and rollRows[4].Text == "" and rollRows[TOP_N].Text == ""
		)

		-- Names are cached: a second read does not look a known name up again
		service.Refresh()
		local repeated = 0
		for userId, calls in lookups do
			if userId ~= THROWING_NAME_ID and calls > 1 then
				repeated += 1
			end
		end
		flag("leaderboard_names_cached", repeated == 0, repeated, 0)

		-- A throwing store raises no error and keeps the last good rows
		local before, beforeTop = {}, #service.Top("Speed")
		for _, b in BOARDS do
			before[b.Id] = rowTexts(labels[b.Id])
		end
		stores.Throw = true
		local refreshOk = pcall(service.Refresh)
		flag("leaderboard_throwing_store_refresh_no_error", refreshOk)
		local keptRows = true
		for _, b in BOARDS do
			keptRows = keptRows and labels[b.Id] ~= nil and rowTexts(labels[b.Id]) == before[b.Id]
		end
		flag("leaderboard_throwing_store_keeps_rows", keptRows)
		local afterTop = service.Top("Speed")
		flag(
			"leaderboard_throwing_store_keeps_top",
			type(afterTop) == "table" and #afterTop == beforeTop and beforeTop == TOP_N,
			type(afterTop) == "table" and #afterTop or -1,
			TOP_N
		)
		local writeOk, written = pcall(service.Write, p)
		flag("leaderboard_throwing_store_write_no_error", writeOk and written == false)
		stores.Throw = false

		-- The store lookup itself failing (GetOrderedDataStore throws in Studio without API access) raises nothing
		service.SetStore(function()
			error("no OrderedDataStore here")
		end)
		flag("leaderboard_throwing_store_lookup_refresh_no_error", (pcall(service.Refresh)))
		flag("leaderboard_throwing_store_lookup_write_no_error", (pcall(service.Write, p)))

		-- No store: the signs show "No data yet" and nothing errors
		service.SetStore(false)
		flag("leaderboard_no_store_refresh_no_error", (pcall(service.Refresh)))
		local noStoreOk, noStoreWrote = pcall(service.Write, p)
		flag("leaderboard_no_store_write_no_error", noStoreOk and noStoreWrote == false)
		for _, b in BOARDS do
			local l = labels[b.Id]
			local shown = l ~= nil and l.Rows[1].Text == NO_DATA
			for i = 2, TOP_N do
				shown = shown and l.Rows[i].Text == ""
			end
			flag("leaderboard_no_store_shows_no_data_yet_" .. b.Id, shown, rowTexts(l), NO_DATA)
		end
	end)
	-- Restore the real store and name lookup, and let the signs show the real boards again
	pcall(service.SetStore, nil)
	pcall(service.SetNameLookup, nil)
	pcall(service.Refresh)
	for _, p in players do
		p:Destroy()
	end
	flag("leaderboard_no_runtime_error", ok, nil, ok and 1 or tostring(err))
	return r
end

return Tests
