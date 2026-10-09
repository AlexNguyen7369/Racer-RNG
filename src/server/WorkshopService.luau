--!nonstrict
-- Mechanical Workshop, server side (docs/WORKSHOP_SPEC.md). Owns the 7 plots in the spawn area: assigns one to each
-- joining player, builds their workshop, frees it when they leave, and pays idle Speed while they stand in its zone.
-- Clients only see: Workspace.Workshops.Plot_N (Owner attribute, signs) and player attributes Plot, WorkshopLevel,
-- InWorkshop, WorkshopRate. The zone check is the server's maths on the character's position, never a touch event.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Workshop = require(Shared.Workshop)
local WorkshopBuilder = require(Shared.WorkshopBuilder)
local WorkshopConfig = require(Shared.WorkshopConfig)
local CarService = require(script.Parent.CarService)
local GachaService = require(script.Parent.GachaService)
local PlayerData = require(script.Parent.PlayerData)
local LevelService = require(script.Parent.LevelService)

local WorkshopService = {}

local startCFrame = nil -- Track 1's Start CFrame, set by BuildPlots
local plots = {} -- index -> Plot_N model
local owners = {} -- index -> player
local plotOf = setmetatable({}, { __mode = "k" }) -- player -> index

local function userIdOf(player)
	if player:IsA("Player") then
		return player.UserId
	end
	local id = player:GetAttribute("UserId")
	return type(id) == "number" and id ~= 0 and id or -1 -- fakes (tests): never 0, which means "free"
end

local function nameOf(player)
	if player:IsA("Player") then
		return player.DisplayName
	end
	local name = player:GetAttribute("DisplayName")
	return type(name) == "string" and name or player.Name
end

local liveFolder = nil -- Workspace.Workshops, built by Start
local lastBuy = setmetatable({}, { __mode = "k" })
local openRemote = nil

local function nearUpgrade(player)
	local index = plotOf[player]
	local plot = index and plots[index]
	if not plot or owners[index] ~= player or plot:GetAttribute("Owner") ~= userIdOf(player) then
		return false
	end
	local workshop = plot and plot:FindFirstChild("Workshop")
	local pad = workshop and workshop:FindFirstChild("UpgradePad")
	local character = CarService.GetCharacter(player)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return pad
		and root
		and humanoid
		and humanoid.Health > 0
		and not CarService.IsAutoRacing(player)
		and player:GetAttribute("AutoRacing") ~= true
		and (root.Position - pad.Position).Magnitude <= WorkshopConfig.UPGRADE_DISTANCE
end

local function bindUpgrade(player, workshop)
	local pad = workshop:FindFirstChild("UpgradePad")
	if not pad then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "UpgradePrompt"
	prompt.ActionText = "Upgrade"
	prompt.ObjectText = nameOf(player) .. "'s Workshop"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.MaxActivationDistance = WorkshopConfig.UPGRADE_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt.Parent = pad
	prompt.Triggered:Connect(function(who)
		if who == player and nearUpgrade(player) and openRemote then
			openRemote:FireClient(player)
		end
	end)
end

local function buildFolder(newStartCFrame, parent)
	local folder = Instance.new("Folder")
	folder.Name = "Workshops"
	local built = {}
	for i = 1, WorkshopConfig.PLOT_COUNT do
		local plot = WorkshopBuilder.BuildPlot(i, Workshop.PlotCFrame(newStartCFrame, i))
		plot.Parent = folder
		built[i] = plot
	end
	folder.Parent = parent
	return folder, built
end

-- Builds a "Workshops" folder with PLOT_COUNT empty plots for Track 1's Start CFrame under `parent` (default
-- Workspace) and returns it. Only the plots Start builds are assigned: building elsewhere never moves the live ones.
function WorkshopService.BuildPlots(newStartCFrame, parent)
	parent = parent or Workspace
	local old = parent:FindFirstChild("Workshops")
	if old and old ~= liveFolder then
		old:Destroy()
	end
	local folder = buildFolder(newStartCFrame, parent)
	return folder
end

-- The plot's Rate sign always shows what the zone pays: "+N Speed/s" while the owner stands in it, "Stand here: +N
-- Speed/s" otherwise.
local function setRate(player, inZone, rate)
	player:SetAttribute("InWorkshop", inZone)
	player:SetAttribute("WorkshopRate", inZone and rate or 0)
	local index = plotOf[player]
	local workshop = index and plots[index] and plots[index]:FindFirstChild("Workshop")
	local zone = workshop and workshop:FindFirstChild("Zone")
	local gui = zone and zone:FindFirstChild("Rate")
	local text = gui and gui:FindFirstChild("Text")
	if text then
		text.Text = string.format(inZone and "+%.1f Speed/s" or "Stand here: +%.1f Speed/s", rate)
	end
end

-- Gives the player the lowest free plot and builds their workshop. Returns the plot index (0 = none free).
function WorkshopService.Assign(player)
	if plotOf[player] then
		return plotOf[player]
	end
	if player:GetAttribute("WorkshopLevel") == nil then
		player:SetAttribute("WorkshopLevel", 1)
	end
	local taken = {}
	for i, owner in owners do
		if owner.Parent then
			taken[i] = true
		else
			WorkshopService.Release(owner) -- the owner left without a release: free the plot
		end
	end
	local index = plots[1] and Workshop.FreePlot(taken) or 0
	player:SetAttribute("Plot", index)
	setRate(player, false, 0)
	if index == 0 then
		warn(
			"[Workshop] no free plot for "
				.. player.Name
				.. " (Max Players must be "
				.. WorkshopConfig.PLOT_COUNT
				.. ")"
		)
		return 0
	end
	owners[index] = player
	plotOf[player] = index
	local plot = plots[index]
	plot:SetAttribute("Owner", userIdOf(player))
	WorkshopBuilder.SetSign(plot, nameOf(player))
	local workshop = WorkshopBuilder.BuildWorkshop(
		Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		Workshop.PlotCFrame(startCFrame, index)
	)
	workshop.Parent = plot
	bindUpgrade(player, workshop)
	setRate(player, false, WorkshopService.Rate(player))
	return index
end

-- Removes the player's workshop and frees their plot.
function WorkshopService.Release(player)
	local index = plotOf[player]
	plotOf[player] = nil
	player:SetAttribute("Plot", 0)
	player:SetAttribute("InWorkshop", false)
	player:SetAttribute("WorkshopRate", 0)
	if not index then
		return
	end
	if owners[index] == player then
		owners[index] = nil
	end
	local plot = plots[index]
	if plot then
		local workshop = plot:FindFirstChild("Workshop")
		if workshop then
			workshop:Destroy()
		end
		plot:SetAttribute("Owner", 0)
		WorkshopBuilder.SetSign(plot, nil)
	end
end

-- The player's plot index (0 = none).
function WorkshopService.PlotOf(player)
	return plotOf[player] or 0
end

-- Client supplies no price or level. Every guard and the debit run without yielding.
function WorkshopService.BuyUpgrade(player)
	if player:GetAttribute("DataFailed") or not player:GetAttribute("DataLoaded") then
		return false, "Data not loaded"
	end
	if not nearUpgrade(player) then
		return false, "Approach your workshop upgrade slab"
	end
	local level = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel"))
	local nextLevel = WorkshopConfig.Levels[level + 1]
	if not nextLevel then
		return false, "Maximum level"
	end
	local stats = player:FindFirstChild("leaderstats")
	local money = stats and stats:FindFirstChild("Money")
	if not money or money.Value < nextLevel.Price then
		return false, "Not enough Money"
	end
	local index = plotOf[player]
	local replacement = WorkshopBuilder.BuildWorkshop(level + 1, Workshop.PlotCFrame(startCFrame, index))
	money.Value -= nextLevel.Price
	player:SetAttribute("WorkshopLevel", level + 1)
	local old = plots[index]:FindFirstChild("Workshop")
	if old then
		old:Destroy()
	end
	replacement.Parent = plots[index]
	bindUpgrade(player, replacement)
	setRate(player, false, WorkshopService.Rate(player))
	return true, "Upgraded to level " .. (level + 1)
end

-- Speed per second the player earns while in their zone right now.
function WorkshopService.Rate(player)
	return Workshop.Rate(
		PlayerData.SpeedStat(player),
		1,
		Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")),
		GachaService.WorkshopMulti(player)
	)
end

local function inZone(player, index, character)
	if CarService.IsAutoRacing(player) or player:GetAttribute("AutoRacing") == true then
		return false
	end
	character = character or CarService.GetCharacter(player)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root then
		return false
	end
	return Workshop.InZone(startCFrame, index, root.Position)
end

-- One zone check for one player over `dt` seconds: adds the gain if they are in the zone. Returns the Speed added.
-- `character` (optional) defaults to the player's avatar (CarService.GetCharacter / player.Character).
function WorkshopService.Tick(player, dt, character)
	local index = plotOf[player]
	if not index or not startCFrame or type(dt) ~= "number" or dt ~= dt or dt <= 0 then
		return 0
	end
	if typeof(character) ~= "Instance" then
		character = nil
	end
	local rate = WorkshopService.Rate(player)
	if not inZone(player, index, character) then
		setRate(player, false, rate)
		return 0
	end
	setRate(player, true, rate)
	local gain = rate * dt
	LevelService.Tick(player, dt)
	return PlayerData.AddSpeed(player, gain) and gain or 0
end

-- Save fields (PlayerData VERSION 4 saves WorkshopLevel itself): { WorkshopLevel = n }.
function WorkshopService.Snapshot(player)
	return { WorkshopLevel = Workshop.CleanLevel(player:GetAttribute("WorkshopLevel")) }
end

-- Loads saved fields (missing level = 1, clamped to 1 .. MAX_LEVEL).
function WorkshopService.Apply(player, saved)
	saved = type(saved) == "table" and saved or {}
	player:SetAttribute("WorkshopLevel", Workshop.CleanLevel(saved.WorkshopLevel))
end

-- Builds the plots, assigns plots on join (after the save loads, so the saved level is built), frees them on leave,
-- runs the zone check every TICK seconds.
function WorkshopService.Start(newStartCFrame)
	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	openRemote = remotes:FindFirstChild("WorkshopOpen") or Instance.new("RemoteEvent")
	openRemote.Name = "WorkshopOpen"
	openRemote.Parent = remotes
	local buyRemote = remotes:FindFirstChild("WorkshopUpgrade") or Instance.new("RemoteFunction")
	buyRemote.Name = "WorkshopUpgrade"
	buyRemote.Parent = remotes
	buyRemote.OnServerInvoke = function(player)
		local at = os.clock()
		if lastBuy[player] and at - lastBuy[player] < WorkshopConfig.REMOTE_COOLDOWN then
			return false, "Please wait"
		end
		lastBuy[player] = at
		return WorkshopService.BuyUpgrade(player)
	end
	local old = Workspace:FindFirstChild("Workshops")
	if old then
		old:Destroy()
	end
	startCFrame = newStartCFrame
	plots, owners = {}, {}
	table.clear(plotOf)
	liveFolder, plots = buildFolder(newStartCFrame, Workspace)
	local function onPlayer(player)
		while player.Parent and not player:GetAttribute("DataLoaded") and not player:GetAttribute("DataFailed") do
			task.wait(0.2)
		end
		if player.Parent then
			WorkshopService.Assign(player)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(WorkshopService.Release)
	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(WorkshopConfig.TICK)
			local now = os.clock()
			local dt = math.min(now - last, WorkshopConfig.TICK * 4) -- a long server hitch never pays a lump sum
			last = now
			for player in plotOf do
				if player.Parent then
					WorkshopService.Tick(player, dt)
				end
			end
		end
	end)
end

return WorkshopService
