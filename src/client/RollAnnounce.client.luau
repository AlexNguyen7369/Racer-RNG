--!nonstrict
-- Emphasized rolls in global chat (owner, 2026-10-02): the server (GachaService) fires Remotes.RollAnnounce to
-- everyone with the player, the car and their total rolls; this shows it as a system message in the general channel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CarCatalog = require(Shared.CarCatalog)
local GachaConfig = require(Shared.GachaConfig)
local HudFormat = require(Shared.HudFormat)
local announceRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("RollAnnounce")

local function escape(str)
	return (tostring(str):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

local function general()
	local channels = TextChatService:FindFirstChild("TextChannels")
	return channels and channels:FindFirstChild("RBXGeneral")
end

announceRemote.OnClientEvent:Connect(function(_, displayName, id, rolls)
	local spec = CarCatalog.Get(id)
	local channel = general()
	if not spec or not channel then
		return
	end
	local color = (GachaConfig.RARITY_COLORS[spec.Rarity] or Color3.new(1, 1, 1)):ToHex()
	if spec.Rarity == "Secret" then
		color = "FFFFFF"
	end
	local odds = spec.Chance and HudFormat.Odds(spec.Chance) or "Common"
	channel:DisplaySystemMessage(
		string.format(
			'%s rolled <font color="#%s"><b>%s</b></font> (%s)! Total rolls: %s',
			escape(displayName),
			color,
			escape(spec.Name),
			odds,
			tostring(math.floor(tonumber(rolls) or 0))
		)
	)
end)
