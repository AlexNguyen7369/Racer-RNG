--!nonstrict
-- Shows the server's replies to this player's admin commands (Server/AdminService, Remotes.AdminMessage)
-- as system messages in the chat. Display only: the server already decided and did everything.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("AdminMessage")

local function escape(text)
	return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

remote.OnClientEvent:Connect(function(message)
	if type(message) ~= "string" or message == "" then
		return
	end
	if TextChatService.ChatVersion == Enum.ChatVersion.TextChatService then
		local channels = TextChatService:FindFirstChild("TextChannels")
		local system = channels and channels:FindFirstChild("RBXSystem")
		if system then
			for line in message:gmatch("[^\n]+") do
				system:DisplaySystemMessage('<font color="#FFD54A">[Admin]</font> ' .. escape(line))
			end
			return
		end
	end
	print("[Admin] " .. message)
end)
