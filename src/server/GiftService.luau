--!nonstrict
-- Durable gift routing. Only ShopService owns MarketplaceService.ProcessReceipt.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.MonetizationConfig)
local Boosts = require(ReplicatedStorage.Shared.BoostConfig)

local GiftService = {}
GiftService.COOLDOWN = 2
local store, mailboxFn, playerSource
local busy, lastRequest = {}, {}

function GiftService.SetStore(value)
	store = value
end
function GiftService.SetPlayers(value)
	playerSource = value
end
function GiftService.SetMailbox(fn)
	mailboxFn = fn
end
local function players()
	return playerSource or Players
end
local function routes()
	if not store then
		store = DataStoreService:GetDataStore("GiftRoutes_v1")
	end
	return store
end
local function loaded(player)
	return player and player:GetAttribute("DataLoaded") == true and not player:GetAttribute("DataFailed")
end
local function validId(id)
	return type(id) == "number" and id > 0 and id < 2 ^ 53 and id % 1 == 0
end
local function validGrants(product)
	if product.Section ~= "Potions" and product.Section ~= "Bundle" then
		return false
	end
	if type(product.Grants) ~= "table" or next(product.Grants) == nil then
		return false
	end
	for id, count in product.Grants do
		if not Boosts.Get(id) or not validId(count) or count > 1000 then
			return false
		end
	end
	return true
end
function GiftService.Product(productId)
	for _, product in Config.Products do
		if validId(product.GiftProductId) and product.GiftProductId == productId and validGrants(product) then
			return product
		end
	end
	return nil
end
local function recordOf(current)
	local record = type(current) == "table" and table.clone(current) or {}
	record.Receipts = type(record.Receipts) == "table" and table.clone(record.Receipts) or {}
	return record
end
local function key(userId)
	return "Buyer_" .. tostring(userId)
end

-- Persists the selection before a prompt may open. No client grants/prices are accepted.
function GiftService.Prepare(player, id, recipientId)
	local product
	for _, candidate in Config.Products do
		if candidate.Id == id then
			product = candidate
			break
		end
	end
	if not product or not GiftService.Product(product.GiftProductId) then
		return false, "Gift unavailable"
	end
	if not loaded(player) then
		return false, "Data not loaded"
	end
	if not validId(recipientId) or recipientId == player.UserId then
		return false, "Choose another player"
	end
	local recipient = players():GetPlayerByUserId(recipientId)
	if not loaded(recipient) then
		return false, "Recipient must be in this server with loaded data"
	end
	local buyerId = player.UserId
	if busy[buyerId] or (lastRequest[buyerId] and os.clock() - lastRequest[buyerId] < GiftService.COOLDOWN) then
		return false, "Please wait"
	end
	lastRequest[buyerId] = os.clock()
	busy[buyerId] = true
	local pending = {
		Token = HttpService:GenerateGUID(false),
		ProductId = product.GiftProductId,
		Product = product.Id,
		RecipientId = recipientId,
		SenderId = buyerId,
		Grants = table.clone(product.Grants),
	}
	local ok, result = pcall(function()
		return routes():UpdateAsync(key(buyerId), function(current)
			local record = recordOf(current)
			if record.Pending then
				return record
			end
			record.Pending = pending
			return record
		end)
	end)
	busy[buyerId] = nil
	if not ok or not result then
		return false, "Could not save gift; try again"
	end
	if not result.Pending or result.Pending.Token ~= pending.Token then
		return false, "Finish your pending gift first"
	end
	return true, product.GiftProductId
end

-- Only the server's purchase prompt callback invokes cancellation, never a client remote.
function GiftService.Cancel(buyerId, productId)
	local ok = pcall(function()
		routes():UpdateAsync(key(buyerId), function(current)
			local record = recordOf(current)
			local pending = record.Pending
			if pending and pending.ProductId == productId and not pending.PurchaseId then
				record.Pending = nil
			end
			return record
		end)
	end)
	return ok
end

function GiftService.ProcessReceipt(info)
	if not GiftService.Product(info.ProductId) then
		return nil -- ordinary receipt: ShopService handles it
	end
	local retry = Enum.ProductPurchaseDecision.NotProcessedYet
	if not validId(info.PlayerId) or type(info.PurchaseId) ~= "string" or info.PurchaseId == "" then
		return retry
	end
	-- Route first: preserve purchase-id -> recipient forever, across new pending gifts/rejoins.
	local ok, routeRecord = pcall(function()
		return routes():UpdateAsync(key(info.PlayerId), function(current)
			local record = recordOf(current)
			if record.Receipts[info.PurchaseId] then
				return record
			end
			local pending = record.Pending
			if
				not pending
				or pending.ProductId ~= info.ProductId
				or (pending.PurchaseId and pending.PurchaseId ~= info.PurchaseId)
			then
				return nil
			end
			local route = table.clone(pending)
			route.PurchaseId = info.PurchaseId
			record.Pending = route
			record.Receipts[info.PurchaseId] = route
			return record
		end)
	end)
	local route = ok and routeRecord and routeRecord.Receipts[info.PurchaseId]
	if not route or route.ProductId ~= info.ProductId then
		return retry
	end
	local deposited, saved = pcall(function()
		if mailboxFn then
			return mailboxFn(route.RecipientId, info.PurchaseId, route)
		end
		return require(script.Parent.PlayerData).EnqueueGift(route.RecipientId, info.PurchaseId, route)
	end)
	if not deposited or not saved then
		return retry
	end
	-- A failure here is retried safely: the mailbox de-duplicates the PurchaseId.
	local cleared, result = pcall(function()
		return routes():UpdateAsync(key(info.PlayerId), function(current)
			local record = recordOf(current)
			if record.Pending and record.Pending.Token == route.Token then
				record.Pending = nil
			end
			return record
		end)
	end)
	if not cleared or not result then
		return retry
	end
	local recipient = players():GetPlayerByUserId(route.RecipientId)
	if loaded(recipient) and not mailboxFn then
		task.spawn(function()
			require(script.Parent.PlayerData).Save(recipient)
		end)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function GiftService.Start(remotes)
	local remote = remotes:FindFirstChild("PrepareGift") or Instance.new("RemoteFunction")
	remote.Name = "PrepareGift"
	remote.Parent = remotes
	remote.OnServerInvoke = function(player, productId, recipientId)
		local ok, result = GiftService.Prepare(player, productId, recipientId)
		if not ok then
			return false, result
		end
		local prompted = pcall(function()
			MarketplaceService:PromptProductPurchase(player, result)
		end)
		if not prompted then
			GiftService.Cancel(player.UserId, result)
			return false, "Purchase prompt unavailable"
		end
		return true, "Complete the Roblox purchase to send your gift"
	end
	MarketplaceService.PromptProductPurchaseFinished:Connect(function(userId, productId, purchased)
		if not purchased and GiftService.Product(productId) then
			GiftService.Cancel(userId, productId)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player.UserId] = nil
	end)
end

return GiftService
