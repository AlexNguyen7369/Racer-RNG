--!nonstrict
-- Robux developer-product receipts and redeem codes (docs/SHOP_PURCHASES_SPEC.md). Both grant potions only, through
-- BoostService; neither ever touches Money or Speed. The one exception is the offline-reward double
-- (docs/OFFLINE_DOUBLE_SPEC.md): it adds the player's last offline Speed reward once more, never Money.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")

local Monetization = require(ReplicatedStorage.Shared.MonetizationConfig)
local CodeConfig = require(script.Parent.CodeConfig)
local BoostService = require(script.Parent.BoostService)

local ShopService = {}
ShopService.MAX_RECEIPTS = 100
ShopService.CODE_COOLDOWN = 2
ShopService.MAX_CODE_LENGTH = 32

local state = {} -- [player] = { Receipts = { id, ... }, Codes = { [CODE] = true } }
local processing = {} -- [purchaseId] = true while a receipt is being granted
local lastRedeem = {}
local offline = {} -- [player] = { Amount, Doubled, Closed }: this session's offline reward (Closed = window over)
local saveFn = nil

local function stateFor(player)
	local s = state[player]
	if not s then
		s = { Receipts = {}, Codes = {} }
		state[player] = s
	end
	return s
end

local function loaded(player)
	return player:GetAttribute("DataLoaded") == true and not player:GetAttribute("DataFailed")
end

local function playerData()
	return require(script.Parent.PlayerData) -- lazy: PlayerData requires this module
end

local function save(player)
	if saveFn then
		return saveFn(player)
	end
	return playerData().Save(player)
end

local function grant(player, grants, sign)
	for id, count in grants do
		BoostService.Add(player, id, sign * count)
	end
end

function ShopService.SetSave(fn)
	saveFn = fn
end

function ShopService.Product(productId)
	if type(productId) ~= "number" or productId <= 0 then
		return nil
	end
	for _, product in Monetization.Products do
		if product.ProductId == productId then
			return product
		end
	end
	return nil
end

function ShopService.Apply(player, data)
	data = type(data) == "table" and data or {}
	local s = stateFor(player)
	s.Receipts, s.Codes = {}, {}
	if type(data.Receipts) == "table" then
		for _, id in data.Receipts do
			if type(id) == "string" and id ~= "" then
				table.insert(s.Receipts, id)
			end
		end
		while #s.Receipts > ShopService.MAX_RECEIPTS do
			table.remove(s.Receipts, 1)
		end
	end
	if type(data.Codes) == "table" then
		for _, code in data.Codes do
			if type(code) == "string" and code ~= "" then
				s.Codes[string.upper(code)] = true
			end
		end
	end
end

function ShopService.Snapshot(player)
	local s = stateFor(player)
	local codes = {}
	for code in s.Codes do
		table.insert(codes, code)
	end
	table.sort(codes)
	return { Receipts = table.clone(s.Receipts), Codes = codes }
end

-- Applies a receipt once: give() grants (false = can not grant now), the purchase id is recorded, then saved.
-- A failed save runs undo() and drops the id, so Roblox's retry grants it exactly once later.
local function commit(player, purchaseId, give, undo)
	processing[purchaseId] = true
	if not give() then
		processing[purchaseId] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local s = stateFor(player)
	table.insert(s.Receipts, purchaseId)
	local dropped = nil
	if #s.Receipts > ShopService.MAX_RECEIPTS then
		dropped = table.remove(s.Receipts, 1)
	end
	local ok, saved = pcall(save, player)
	processing[purchaseId] = nil
	if ok and saved then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	undo()
	table.remove(s.Receipts, table.find(s.Receipts, purchaseId))
	if dropped then
		table.insert(s.Receipts, 1, dropped)
	end
	return Enum.ProductPurchaseDecision.NotProcessedYet
end

-- Called by PlayerData once the save is loaded, with the offline Speed it just credited (0 = none).
function ShopService.SetOfflineReward(player, amount)
	if type(amount) ~= "number" or amount ~= amount or amount <= 0 or amount == math.huge then
		offline[player] = nil
		player:SetAttribute("OfflineDoubleOpen", false)
		return
	end
	local reward = { Amount = amount, Doubled = false, Closed = false }
	offline[player] = reward
	player:SetAttribute("OfflineDoubled", nil)
	player:SetAttribute("OfflineDoubleOpen", true)
	task.delay(Monetization.OfflineDouble.WINDOW_SECONDS, function()
		reward.Closed = true
		if offline[player] == reward then
			player:SetAttribute("OfflineDoubleOpen", false)
		end
	end)
end

-- Offline double receipt: grants the remembered amount once, even if the panel window closed while Roblox's
-- prompt was open. No undoubled reward this session: NotProcessedYet (Roblox retries; a later reward takes it).
local function processOfflineDouble(player, purchaseId)
	local reward = offline[player]
	return commit(player, purchaseId, function()
		if not reward or reward.Doubled or not playerData().AddSpeed(player, reward.Amount) then
			return false
		end
		reward.Doubled = true
		player:SetAttribute("OfflineDoubleOpen", false)
		player:SetAttribute("OfflineDoubled", reward.Amount)
		return true
	end, function()
		reward.Doubled = false
		player:SetAttribute("OfflineDoubled", nil)
		local speed = playerData().Setup(player)
		speed.Value = math.max(0, speed.Value - reward.Amount)
		player:SetAttribute("OfflineDoubleOpen", offline[player] == reward and not reward.Closed)
	end)
end

function ShopService.ProcessReceipt(info)
	local giftDecision = require(script.Parent.GiftService).ProcessReceipt(info)
	if giftDecision then
		return giftDecision
	end
	local doubleId = Monetization.OfflineDouble.ProductId
	local isDouble = doubleId > 0 and info.ProductId == doubleId
	local product = ShopService.Product(info.ProductId)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	if not (isDouble or (product and product.Grants)) or not player or not loaded(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local purchaseId = tostring(info.PurchaseId)
	-- In flight first: the id is recorded before its save finishes, and that save may still fail.
	if processing[purchaseId] then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local s = stateFor(player)
	if table.find(s.Receipts, purchaseId) then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	if isDouble then
		return processOfflineDouble(player, purchaseId)
	end
	return commit(player, purchaseId, function()
		grant(player, product.Grants, 1)
		return true
	end, function()
		grant(player, product.Grants, -1)
	end)
end

function ShopService.Redeem(player, text)
	if type(text) ~= "string" then
		return false, "Invalid code"
	end
	local code = string.upper((string.gsub(text, "^%s*(.-)%s*$", "%1")))
	if code == "" or #code > ShopService.MAX_CODE_LENGTH then
		return false, "Invalid code"
	end
	if not loaded(player) then
		return false, "Data not loaded"
	end
	local at = os.clock()
	if lastRedeem[player] and at - lastRedeem[player] < ShopService.CODE_COOLDOWN then
		return false, "Please wait"
	end
	lastRedeem[player] = at
	local entry = CodeConfig.Codes[code]
	if not entry then
		return false, "Invalid code"
	end
	local s = stateFor(player)
	if s.Codes[code] then
		return false, "Already redeemed"
	end
	grant(player, entry.Grants, 1)
	s.Codes[code] = true
	return true, "Code redeemed!"
end

function ShopService.Start()
	local remotes = ReplicatedStorage:FindFirstChild("Remotes") or Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
	local redeem = remotes:FindFirstChild("RedeemCode") or Instance.new("RemoteFunction")
	redeem.Name = "RedeemCode"
	redeem.Parent = remotes
	redeem.OnServerInvoke = ShopService.Redeem
	MarketplaceService.ProcessReceipt = ShopService.ProcessReceipt
	require(script.Parent.GiftService).Start(remotes)
	Players.PlayerRemoving:Connect(function(player)
		lastRedeem[player] = nil
		offline[player] = nil
		-- shortcut: the leave save reads this state, so drop it later instead of racing PlayerData's handler.
		task.delay(60, function()
			if not player.Parent then
				state[player] = nil
			end
		end)
	end)
end

return ShopService
