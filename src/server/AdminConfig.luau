--!nonstrict
-- Who may use the chat admin commands (Server/AdminService). Server-only: clients never see this list.
-- The place owner (or, for a group game, members at GROUP_MIN_RANK and above) is always an admin.

return {
	UserIds = {
		-- add Roblox UserIds here, e.g. 123456789,
	},
	GROUP_MIN_RANK = 255, -- group-owned place: this rank and above (255 = group owner)
	ALLOW_IN_STUDIO = true, -- everyone is an admin while testing in Studio
	MAX_ROLLS = 100, -- most rolls one /roll may do
}
