--!nonstrict
-- Pure profile merge helpers; no visible grants occur inside DataStore transforms.
local BoostConfig = require(game:GetService("ReplicatedStorage").Shared.BoostConfig)
local Mailbox = {}

function Mailbox.Valid(gift)
	if type(gift) ~= "table" or type(gift.Grants) ~= "table" or not next(gift.Grants) then
		return false
	end
	for id, count in gift.Grants do
		-- Canonical tier ids only: Merge rewrites the category aliases ("Money") from tier I.
		local item = BoostConfig.Get(id)
		if not item or item.Id ~= id or type(count) ~= "number" or count < 1 or count > 1000 or count % 1 ~= 0 then
			return false
		end
	end
	return true
end

-- Retain mailbox tombstones: an ambiguous write failure can be reconciled against the
-- loaded receipt set without losing or double-applying the grant on a subsequent save.
function Mailbox.Merge(payload, current, known)
	payload.GiftMailbox = type(current.GiftMailbox) == "table" and table.clone(current.GiftMailbox) or {}
	payload.GiftReceipts = table.clone(known)
	payload.Boosts = table.clone(payload.Boosts or {})
	for purchaseId, gift in payload.GiftMailbox do
		if type(purchaseId) == "string" and not known[purchaseId] and Mailbox.Valid(gift) then
			local fits = true
			for id, count in gift.Grants do
				if (payload.Boosts[id] or 0) + count > 1000000 then
					fits = false
				end
			end
			if fits then
				for id, count in gift.Grants do
					payload.Boosts[id] = (payload.Boosts[id] or 0) + count
				end
				payload.GiftReceipts[purchaseId] = true
			end
		end
	end
	-- Snapshot compatibility aliases refer to tier I.
	for _, category in BoostConfig.Order do
		payload.Boosts[category] = payload.Boosts[category .. "I"]
	end
	return payload
end

return Mailbox
