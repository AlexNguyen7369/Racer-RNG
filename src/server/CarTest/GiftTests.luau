--!nonstrict
-- BRIEF: durable recipient routing, offline mail, atomic profile claim, duplicate/save-failure retries.
local H = require(script.Parent.AcceptanceSupport)
local Server = script.Parent.Parent
local Shared = game:GetService("ReplicatedStorage").Shared
local Tests = {}

function Tests.gifting()
	local r, flag = H.report("gifting")
	local service = require(Server.GiftService)
	local config = require(Shared.MonetizationConfig)
	local product = config.Products[1]
	local oldId, oldCooldown = product.GiftProductId, service.COOLDOWN
	local grant, retry = Enum.ProductPurchaseDecision.PurchaseGranted, Enum.ProductPurchaseDecision.NotProcessedYet
	local function player(id)
		return {
			UserId = id,
			GetAttribute = function(_, name)
				return name == "DataLoaded" and true or nil
			end,
		}
	end
	local sender, recipient = player(991111), player(991112)
	local online = { [sender.UserId] = sender, [recipient.UserId] = recipient }
	local store = H.store()
	local mailbox, attempts = {}, 0
	local failMail = false
	local function deposit(uid, purchaseId, gift)
		attempts += 1
		if failMail then
			return false
		end
		mailbox[uid] = mailbox[uid] or {}
		mailbox[uid][purchaseId] = mailbox[uid][purchaseId] or H.copy(gift)
		return true
	end
	local ok, err = pcall(function()
		product.GiftProductId = 99887766
		service.COOLDOWN = 0
		service.SetStore(store)
		service.SetPlayers({
			GetPlayerByUserId = function(_, id)
				return online[id]
			end,
		})
		service.SetMailbox(deposit)
		flag("gift_self_rejected", service.Prepare(sender, product.Id, sender.UserId) == false)
		flag("gift_offline_selection_rejected", service.Prepare(sender, product.Id, 991119) == false)
		flag("gift_invalid_recipient_rejected", service.Prepare(sender, product.Id, "991112") == false)
		flag("gift_invalid_product_rejected", service.Prepare(sender, "unknown", recipient.UserId) == false)
		flag("gift_server_luck_rejected", service.Prepare(sender, "server_luck_2x", recipient.UserId) == false)
		store.fail = true
		flag("gift_prepare_save_failure", service.Prepare(sender, product.Id, recipient.UserId) == false)
		store.fail = false
		flag("gift_prepare_saved", service.Prepare(sender, product.Id, recipient.UserId) == true)
		flag("gift_one_pending", service.Prepare(sender, product.Id, recipient.UserId) == false)
		local receipt =
			{ PlayerId = sender.UserId, ProductId = product.GiftProductId, PurchaseId = "gift-acceptance-1" }
		online[recipient.UserId] = nil -- recipient leaves after the buyer chose them
		failMail = true
		flag("gift_mailbox_failure_retries", service.ProcessReceipt(receipt) == retry)
		flag("gift_mailbox_failure_no_delivery", next(mailbox) == nil)
		failMail = false
		store.retry = true
		flag("gift_offline_mailbox_durable", service.ProcessReceipt(receipt) == grant)
		flag("gift_recipient_fixed", mailbox[recipient.UserId][receipt.PurchaseId].RecipientId == recipient.UserId)
		flag("gift_server_grants", H.same(mailbox[recipient.UserId][receipt.PurchaseId].Grants, product.Grants))
		flag("gift_duplicate_acknowledged", service.ProcessReceipt(receipt) == grant)
		local count = 0
		for _ in mailbox[recipient.UserId] do
			count += 1
		end
		flag("gift_duplicate_single_mail", count == 1, count, 1)
		local other = player(991113)
		online[other.UserId] = other
		flag("gift_next_recipient_prepared", service.Prepare(sender, product.Id, other.UserId) == true)
		flag("gift_old_receipt_still_acknowledged", service.ProcessReceipt(receipt) == grant)
		flag("gift_old_receipt_not_redirected", mailbox[other.UserId] == nil)
		flag("gift_old_receipt_keeps_pending", service.Prepare(sender, product.Id, other.UserId) == false)
		flag("gift_cancel_pending", service.Cancel(sender.UserId, product.GiftProductId) == true)
		flag("gift_after_cancel_preparable", service.Prepare(sender, product.Id, other.UserId) == true)
		store.failAfterTransform = true
		receipt.PurchaseId = "gift-acceptance-2"
		flag("gift_route_commit_failure_retries", service.ProcessReceipt(receipt) == retry)
		flag("gift_route_failure_no_mail", mailbox[other.UserId] == nil)
		store.failAfterTransform = false
		flag("gift_route_commit_retry", service.ProcessReceipt(receipt) == grant)
		flag("gift_second_recipient_delivered", mailbox[other.UserId][receipt.PurchaseId] ~= nil)
		flag("gift_normal_receipt_delegated", service.ProcessReceipt({ ProductId = 112233 }) == nil)
		flag(
			"gift_missing_purchase_id_retries",
			service.ProcessReceipt({ ProductId = product.GiftProductId, PlayerId = sender.UserId }) == retry
		)
		service.COOLDOWN = 10
		flag("gift_cooldown_enforced", service.Prepare(sender, product.Id, other.UserId) == false)
		flag("gift_deposit_only_after_route", attempts >= 3)
	end)
	product.GiftProductId, service.COOLDOWN = oldId, oldCooldown
	service.SetStore(nil)
	service.SetPlayers(nil)
	service.SetMailbox(nil)
	flag("gifting_no_error", ok, ok and 1 or tostring(err))
	return r
end

function Tests.gift_mailbox()
	local r, flag = H.report("gift_mailbox")
	local data = require(Server.PlayerData)
	local boosts = require(Server.BoostService)
	local mailbox = require(Server.GiftMailbox)
	local cleanup = {}
	local uid = 990078111
	local store =
		H.store({ [data.KeyFor(uid)] = { Version = 9, Boosts = { LuckIII = 2 }, Money = 77, Checkpoint = 1 } })
	local gift = { Grants = { LuckIII = 5 }, SenderId = 991111, RecipientId = uid, ProductId = 99887766 }
	local ok, err = pcall(function()
		data.SetStore(store)
		flag("mailbox_self_contained_valid", mailbox.Valid(gift) == true)
		flag("mailbox_invalid_grants_rejected", mailbox.Valid({ Grants = { Money = 1 } }) == false)
		flag("mailbox_invalid_count_rejected", mailbox.Valid({ Grants = { LuckIII = 0 / 0 } }) == false)
		flag("mailbox_enqueue_offline", data.EnqueueGift(uid, "mail-a", gift) == true)
		flag("mailbox_enqueue_preserves_save", store.data[data.KeyFor(uid)].Money == 77)
		flag("mailbox_duplicate_enqueue", data.EnqueueGift(uid, "mail-a", gift) == true)
		local p = H.player(cleanup, uid)
		flag("mailbox_join_claim", data.Load(p, uid) == true)
		flag("mailbox_join_exact_grant", boosts.Count(p, "LuckIII") == 7, boosts.Count(p, "LuckIII"), 7)
		local saved = store.data[data.KeyFor(uid)]
		flag(
			"mailbox_v10_and_receipt_atomic",
			saved.Version == 10 and saved.GiftReceipts["mail-a"] == true and saved.Boosts.LuckIII == 7
		)
		flag("mailbox_lock_retained", saved.Lock ~= nil and saved.Lock.Id == data.SessionId())
		flag("mailbox_redelivery_enqueue", data.EnqueueGift(uid, "mail-a", gift) == true)
		flag("mailbox_duplicate_save", data.Save(p, uid) == true and boosts.Count(p, "LuckIII") == 7)
		flag("mailbox_next_gift", data.EnqueueGift(uid, "mail-b", gift) == true)
		store.failAfterTransform = true
		flag("mailbox_claim_save_failure", data.Save(p, uid) == false)
		flag("mailbox_failed_claim_invisible", boosts.Count(p, "LuckIII") == 7)
		flag("mailbox_failed_claim_unmarked", store.data[data.KeyFor(uid)].GiftReceipts["mail-b"] == nil)
		store.failAfterTransform = false
		store.retry = true
		local invisible = true
		store.inspect = function()
			invisible = invisible and boosts.Count(p, "LuckIII") == 7
		end
		flag("mailbox_retry_claim", data.Save(p, uid) == true)
		store.inspect = nil
		flag("mailbox_transform_has_no_live_grants", invisible)
		flag("mailbox_retry_exactly_once", boosts.Count(p, "LuckIII") == 12, boosts.Count(p, "LuckIII"), 12)
		flag("mailbox_repeat_no_duplicate", data.Save(p, uid, true) == true and boosts.Count(p, "LuckIII") == 12)
		local q = H.player(cleanup, uid)
		flag("mailbox_reload_keeps_receipts", data.Load(q, uid) == true and boosts.Count(q, "LuckIII") == 12)
		flag("mailbox_missing_v9_fields_default", type(store.data[data.KeyFor(uid)].GiftReceipts) == "table")
		local before = H.copy(store.data[data.KeyFor(uid)])
		store.fail = true
		flag("mailbox_enqueue_failure", data.EnqueueGift(uid, "mail-c", gift) == false)
		flag("mailbox_enqueue_failure_preserves", H.same(before, store.data[data.KeyFor(uid)]))
	end)
	data.SetStore(nil)
	for _, object in cleanup do
		object:Destroy()
	end
	flag("gift_mailbox_no_error", ok, ok and 1 or tostring(err))
	return r
end
return Tests
