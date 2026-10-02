--!nonstrict
-- The expected UI inventory for the UI test harness (UiScenarios). Owned by ui-test-writer; never loosen a value
-- here to get a green run. Numbers come from the brief, CLAUDE.md or the config modules, not from current pixels.
--
-- Paths are "/"-separated child names starting at the ScreenGui ("IndexUi/Panel/Close"). "*" matches any one
-- child name (one Equip button per index tile, one "+" per stat row).

local UiSpec = {}

-- Pixel tolerance for geometry comparisons (rounding of AbsolutePosition / AbsoluteSize).
UiSpec.Tolerance = 1

-- A button may be at most this many px larger than its visible content on each side (only matters for buttons
-- whose background is invisible: an opaque background IS the visible content).
UiSpec.MaxHitboxPadding = 8

-- Viewports the layout is checked at. "current" is the live Studio viewport (engine AbsolutePosition); the others
-- are solved with the same layout rules (UDim2, AnchorPoint, UISizeConstraint, UIGridLayout, top-bar inset).
-- phone_landscape is a common Roblox phone in landscape (844x390, iPhone 12-14 class).
-- The solver supports UDim2 Position/Size, AnchorPoint, UISizeConstraint, UICorner/UIStroke (no layout effect),
-- ScrollingFrame CanvasPosition/AutomaticCanvasSize and UIGridLayout (TopLeft, Horizontal fill, Left/Top aligned,
-- SortOrder LayoutOrder or Name). Anything else (UIListLayout, UIPadding, AutomaticSize, ...) fails
-- layout_model_supported until the solver is extended.
UiSpec.Viewports = {
	{ Name = "current" },
	{ Name = "desktop_1080p", Size = Vector2.new(1920, 1080) },
	{ Name = "laptop_768p", Size = Vector2.new(1366, 768) },
	{ Name = "hd_720p", Size = Vector2.new(1280, 720) },
	{ Name = "tablet_4x3", Size = Vector2.new(1024, 768) },
	{ Name = "phone_landscape", Size = Vector2.new(844, 390) },
}

-- Every ScreenGui the game creates in PlayerGui. Anything else found in PlayerGui must be in IgnoreGuis
-- (Roblox-created) or the inventory check fails: a new UI must be added here, with its buttons.
--   AlwaysOn  elements shown all the time (HUD panels, toggles, the toast area): never overlap each other
--   Panels    pop-up panels, hidden at rest, opened by a button
--   Buttons   every GuiButton: what it must DO when clicked
--             Does = "toggle_panel" | "close_panel" | "remote"; Count = exact number expected for "*" patterns
--   Overlay   a declared full-screen overlay (may cover everything while shown)
--   NonInteractive  nothing inside may be Active or a GuiButton (must never swallow clicks)
--   NonInteractiveParts  names of parts of an otherwise interactive gui that must not swallow clicks (the part
--             is found by name anywhere in the gui; it and everything inside it may not be Active or a GuiButton)
UiSpec.Guis = {
	SpeedHud = {
		Source = "Client/SpeedHud",
		AlwaysOn = { "Panel" },
		Side = "left", -- CLAUDE.md: Speed stat on the LEFT of the screen
		Buttons = {},
		NonInteractive = true,
	},
	AutoRaceButton = {
		Source = "Client/AutoRaceButton",
		AlwaysOn = { "Toggle" },
		Side = "top_centre",
		Buttons = {
			{
				Path = "Toggle",
				Does = "remote",
				Remote = "SetAutoRace",
				Arg = "not_attr:AutoRacing", -- the opposite of the current AutoRacing attribute
				Label = "HudFormat.AutoButtonText(AutoRacing)",
			},
		},
	},
	IndexUi = {
		Source = "Client/IndexUi",
		AlwaysOn = { "OpenIndex" },
		Panels = { "Panel" },
		PanelPlacement = { Panel = "centre" }, -- brief: the Index panel is centred
		Buttons = {
			{ Path = "OpenIndex", Does = "toggle_panel", Panel = "IndexUi/Panel", Text = "INDEX" },
			{ Path = "Panel/Close", Does = "close_panel", Panel = "IndexUi/Panel" },
			{
				Path = "Panel/Grid/*/Equip",
				Does = "remote",
				Remote = "EquipCar",
				Arg = "tile_id", -- THAT tile's car id
				Count = "catalog", -- one per CarCatalog.All()
				DisabledWhen = "equipped", -- the equipped tile shows "Equipped" and fires nothing
				HiddenWhen = "undiscovered", -- undiscovered tiles have no Equip button
			},
		},
	},
	StatsUi = {
		Source = "Client/StatsUi",
		AlwaysOn = { "OpenStats", "OpenStats/Badge" },
		Panels = { "Panel" },
		PanelPlacement = { Panel = "left_of_buttons" }, -- brief: opens to the LEFT of the INDEX / STATS buttons
		Buttons = {
			{ Path = "OpenStats", Does = "toggle_panel", Panel = "StatsUi/Panel", Text = "STATS" },
			{
				Path = "Panel/*/Plus",
				Does = "remote",
				Remote = "AllocateStat",
				Arg = "row_stat", -- THAT row's stat
				Count = "stats", -- one per GachaConfig.STATS
				DisabledWhen = "no_points_or_disabled_stat",
			},
		},
		DisabledStats = { Workshop = true }, -- brief: the Workshop row is disabled and never fires
	},
	-- docs/SPAWN_AND_ROLLS_SPEC.md section 5, owner's revision (2026-10-01): the toast is the way into the showcase.
	-- Its area is always reserved (it must never overlap another element), it is a button only while shown
	-- (Visible = false once faded: no invisible hitbox) and it hides while any panel or the showcase is open.
	RollToast = {
		Source = "Client/RollToast",
		AlwaysOn = { "Toast" },
		Buttons = {
			{
				Path = "Toast",
				Does = "open_overlay",
				Overlay = "RollShowcase",
				Label = "<NEW! >CarName · Rarity of the latest RollResult",
			},
		},
	},
	-- Full-screen roll showcase (created by Client/RollToast). An Overlay: exempt from the overlap rules while
	-- open; at rest nothing of it may be visible or clickable. UiSpec.Showcase holds its parts and numbers.
	RollShowcase = {
		Source = "Client/RollToast",
		Overlay = true,
		Buttons = {
			{ Path = "Backdrop", Does = "close_overlay", Overlay = "RollShowcase" }, -- a click off the card closes
		},
	},
	-- The rolls strip: ONLY the TURBO LUCK bar now (no ROLLS button, no feed). Display only.
	RollUi = {
		Source = "Client/RollUi",
		AlwaysOn = { "TurboBar" },
		Side = "bottom_centre",
		Buttons = {},
		NonInteractive = true, -- TurboBar, Fill, Label, TurboPop: read-outs, never swallow a click
	},
	LoserScreen = {
		Source = "Client/NpcRacerView",
		Overlay = true,
		Buttons = {},
		NonInteractive = true,
	},
}

-- Right-edge button column (brief): INDEX at vertical centre -32 px, STATS at +32 px, both at the right edge.
UiSpec.RightColumn = {
	{ Path = "IndexUi/OpenIndex", CentreYOffset = -32 },
	{ Path = "StatsUi/OpenStats", CentreYOffset = 32 },
	MaxRightGap = 32, -- px from the screen's right edge to the button's right edge
}

-- Pop-up panels are mutually exclusive: opening one hides the others (Client/PanelSwitch, used by the buttons).
-- Names maps each declared panel to its PanelSwitch name. ui_panels and the open_*_while_*_open clicks enforce it.
UiSpec.PanelSwitch = {
	Module = "PanelSwitch", -- ModuleScript in StarterPlayerScripts.Client
	Names = { ["IndexUi/Panel"] = "Index", ["StatsUi/Panel"] = "Stats" },
}

-- A panel's top edge must be at least this far below the top-centre Auto Race button's bottom edge.
UiSpec.PanelTopMargin = 4

-- AlwaysOn elements that must be hidden (Visible = false) while any panel is open (ui_toast enforces it) and
-- while the showcase is open (click checks); the overlap checks then only place them in the rest state.
UiSpec.HiddenWhilePanelOpen = { "RollToast/Toast" }

-- Overlaps that are allowed (a modal panel may cover the HUD read-out, never a button). The toast is a button
-- now and hides while a panel is open, so it gets no allowance. Removed with the roll feed (owner's revision):
-- every "RollUi/Feed" pair.
UiSpec.AllowOverlap = {
	{ "IndexUi/Panel", "SpeedHud/Panel" },
	{ "StatsUi/Panel", "SpeedHud/Panel" },
}

-- The rolls strip (docs/SPAWN_AND_ROLLS_SPEC.md sections 4 and 5, owner's revision): only the TURBO LUCK bar,
-- bottom centre, its bottom edge BottomGap px above the screen bottom, Size px. Turbo numbers are read from
-- GachaConfig (TURBO_EVERY, TURBO_LUCK, TurboProgress); FallbackTurbo is the brief's value, used only to keep
-- computing the other checks while GachaConfig lacks them (gacha_turbo_config_present fails then).
UiSpec.RollUi = {
	BottomGap = 10, -- px from the screen bottom to TurboBar's bottom edge
	BarSize = Vector2.new(240, 16),
	FillTolerance = 0.03, -- |Fill width / TurboBar width - TurboProgress / TURBO_EVERY| (one step is 0.1)
	FallbackTurbo = { Every = 10, Luck = 5 },
	Removed = { "RollsButton", "Feed" }, -- the owner removed them: they must not exist any more
}

-- The roll showcase (RollShowcase ScreenGui, owner's revision). Card parts are found by name anywhere in Card.
UiSpec.Showcase = {
	Gui = "RollShowcase",
	Backdrop = "Backdrop", -- full-screen TextButton, no text, dark, BackgroundTransparency ~0.35
	BackdropTransparency = { Min = 0.2, Max = 0.5 }, -- "~0.35"
	BackdropMaxLuminance = 0.3, -- "dark"
	Card = "Card", -- centred Frame, Active (a click on it does NOT close)
	CardParts = { "Viewport", "Odds", "CarName", "Rarity", "SpeedMulti", "NewBadge", "TurboBadge" },
	TurboBadgeText = "TURBO x<TURBO_LUCK>",
	SecretMinLuminance = 0.5, -- Secret's colour is near-black: its Rarity / Odds text must still read (light)
	Blur = "RollShowcaseBlur", -- BlurEffect in Lighting: Enabled while open, disabled when closed
	CornerInset = 24, -- px: the backdrop click lands this far in from the bottom-right corner (clear of the card)
}

-- Created by Roblox, not the game.
UiSpec.IgnoreGuis = { Freecam = true, BubbleChat = true, Chat = true, TouchGui = true, RbxCameraUI = true }

UiSpec.Billboards = {
	WinText = { Tag = "WinPad", Label = "Amount", MaxDistance = "TrackBuilder.WIN_TEXT_DISTANCE", Text = "$<Cash>" },
	NpcLabel = { Label = "Text", MaxDistance = "NpcConfig.LABEL_DISTANCE", Text = "NpcConfig.For(track).Label" },
}

-- Seconds to wait for live events the checks need.
UiSpec.Waits = {
	GuiAppear = 15, -- each ScreenGui must exist in PlayerGui within this
	HudSettle = 2.5, -- HUD counters must reach the server value within this (ui-tester inventory: ~2 s)
	RollToast = 12, -- a Remotes.RollResult must arrive within this (GachaConfig.ROLL_INTERVAL = 3 s)
	ToastShown = 0.3, -- the toast must be showing (Visible, text opaque) this soon after a RollResult
	ToastGone = 2.6, -- and Visible = false this long after it (shows ~1.6 s, fades; < ROLL_INTERVAL 3 s)
	NpcStart = 20, -- an NPC must be on track (or start) within this while auto racing
	ClickDone = 60, -- click protocol: ui-tester must click within this
	ClickSettle = 1.5, -- after the click, the server answer must show within this
	LoseEvent = 30, -- ui_loser waits this long for a Result Lose (ServerSetup lose_event)
	LoserShowGrace = 0.2, -- the loser screen must be shown this soon after the Lose
	LoserHideGrace = 0.5, -- and hidden this soon after the next Reset / Start / Stop
	TurboRoll = 35, -- a turbo roll comes every TURBO_EVERY (10) rolls x ROLL_INTERVAL (3 s) = 30 s at most
	TurboPopShow = 0.5, -- TurboPop must be showing "x<TURBO_LUCK>" this soon after a turbo RollResult
	TurboPopHide = 2, -- and hidden again (bar back to TurboProgress, 0 right after a turbo) this soon after it
	RollsStable = 6, -- ui_rolls waits at most this long for a moment HudSettle s after the last Rolls change
}

--[[
Server-side setup. Done by src/server/CarTest/UiTestSetup.server.luau (Studio only, live modules), triggered by
ui-tester on the SERVER datamodel (a client cannot: client attribute changes do not replicate):
  1. ReplicatedStorage:SetAttribute("UiTestSetup", "<id>:<nonce>")   (a fresh nonce every time)
  2. wait until ReplicatedStorage:GetAttribute("UiTestSetupDone") == "<id>:<nonce>"
  3. ReplicatedStorage:GetAttribute("UiTestSetupError") must be nil/empty, otherwise the step failed
The client harness never changes saved state and never triggers setup; it reads the replicated state. Checks
whose state is missing fail with value "state_missing:<Id>".
]]
UiSpec.ServerSetup = {
	{
		Id = "snapshot",
		When = "before UiTestRun and before any click",
		What = "Remembers the player's GachaService snapshot and AutoRacing so 'restore' can put them back.",
	},
	{
		Id = "spy",
		When = "before any click (UiSpec.Clicks)",
		What = "Creates ReplicatedStorage.UiTestSpy: one attribute per RemoteEvent, a JSON list of "
			.. "{ user = UserId, args = {...} } per OnServerEvent. The real handlers still run, so 'snapshot' / "
			.. "'restore' must wrap the clicks.",
	},
	{
		Id = "index_states",
		When = "before UiTestRun (ui_index needs a discovered, an undiscovered AND an equipped catalog tile)",
		What = "Owns every catalog car but the rarest (stays '???'), equips the first owned one, sets every "
			.. "Alloc_* to 0 so StatPoints = FreePoints >= 1.",
	},
	{
		Id = "stat_points",
		When = "before each allocate_* click that expects a fire (and allocate_workshop_disabled)",
		What = "Same allocation reset as index_states: StatPoints >= 1.",
	},
	{
		Id = "no_stat_points",
		When = "before click allocate_no_points",
		What = "Spends every free point (on the server) so StatPoints == 0.",
	},
	{
		Id = "auto_racing",
		When = "before UiTestRun and the showcase clicks (ui_billboards needs an NPC on track, ui_toast, ui_rolls "
			.. "and the toast / showcase clicks need auto-rolls)",
		What = "Puts the player in auto race (AutoRacing == true).",
	},
	{
		Id = "lose_event",
		When = "just before or during UiTestRun (ui_loser waits Waits.LoseEvent s for it)",
		What = "Fires NpcRace { Type = 'Result', Result = 'Lose' } to this client, then Reset/Start after "
			.. "NpcConfig.LOSE_SCREEN_SECONDS, like a real loss.",
	},
	-- 'roll_burst' was removed with the roll feed (owner's revision 2026-10-01): nothing needs it any more.
	{
		Id = "turbo_next",
		When = "before click showcase_card_click_stays_open (its live update must be a turbo roll); optional for "
			.. "UiTestRun: when the harness prints '[UITEST] WAIT turbo_roll' (LocalPlayer attribute UiTestWaiting "
			.. "== 'turbo_roll'); without it ui_rolls waits up to Waits.TurboRoll for a natural turbo roll",
		What = "Sets the player's Rolls attribute to the next value with Rolls % GachaConfig.TURBO_EVERY == "
			.. "TURBO_EVERY - 1, so the next auto roll is a turbo roll. 'restore' puts Rolls back.",
	},
	{
		Id = "restore",
		When = "after the run and the clicks",
		What = "Applies the 'snapshot', restores AutoRacing and removes UiTestSpy.",
	},
}

-- Click coordinates: UiTestClickTarget.x/y and the "[UITEST] CLICK" line are in mcp user_mouse_input's space:
-- pixels from the top-left of the area BELOW the top bar (= AbsolutePosition of an inset-respecting ScreenGui).
-- user_mouse_input adds the top-bar inset itself. screenX/screenY (window pixels, top bar included) are given
-- for reference only. The harness then checks where the press REALLY landed (UserInputService.InputBegan
-- position, top bar added back; fallback GetMouseLocation) and that the target button was topmost there.
UiSpec.ClickSpace = "below_topbar"

--[[
Clicks ui-tester performs with mcp__Roblox_Studio__user_mouse_input (a LocalScript can not fire Activated).
Protocol, per click (run them in this order; the showcase clicks build on each other):
 1. ui-tester runs the click's NeedSetup ids through the UiTestSetup protocol (UiSpec.ServerSetup), sets ReplicatedStorage attributes UiTestClickDone = nil
    and UiTestClick = nil, then UiTestClick = Id (Server datamodel; attributes only replicate when they change).
 2. the harness prepares (opens/closes Prepare panels, scrolls the target tile into view, waits for the target to be
    shown when Prepare.WaitShown), then publishes the LocalPlayer attribute
    UiTestClickTarget = JSON { id, x, y, screenX, screenY, done } (x, y in UiSpec.ClickSpace) and prints
    "[UITEST] CLICK <id> x=<x> y=<y> done=<done>".
 3. ui-tester clicks (x, y) once AT ONCE (the toast is only shown ~1.6 s), then sets ReplicatedStorage attribute
    UiTestClickDone = <done> (Server datamodel). <done> is the Id on the first attempt, "<Id>#<n>" on retry n.
 4. Retries (only clicks with Retries): if the press landed while the target was not shown (the toast had faded)
    and nothing else took it, the harness prints "[UITEST] RETRY <id> x=<x> y=<y> done=<id>#<n>" and publishes a
    new UiTestClickTarget; ui-tester repeats step 3 with the new <done>. A press that lands on ANOTHER clickable
    element is never retried: it fails click_landed_on_button.
 5. the harness waits ClickSettle, checks Expect and prints "[UITEST] {"scenario":"click:<id>",...}" and mirrors it
    into the LocalPlayer attribute UiTestClickResult. Then it restores the panels it touched (never the showcase:
    only real clicks open or close it).
Prepare:
 Open / Closed  declared panels forced visible / hidden before the click
 WaitShown      wait (Waits.RollToast) for the target to be shown by a real RollResult before publishing
 Showcase       required showcase state before the click (true = open). The harness never forces it; a wrong state
                fails with state_missing:click:<previous click id>.
 WaitSeconds    extra wait before publishing
ClickAt: where to click when it is not the target's centre: "corner" (UiSpec.Showcase.CornerInset px in from the
 bottom-right corner, off the card) or a "<Gui>/<Path>" whose centre is used. The target must be topmost there.
Expect:
 Panels   = { [panelPath] = visibleAfter }  (every other declared panel must keep its visibility)
 Showcase = true/false: showcase open after the click (default: unchanged)
 Remote   = { Name, Arg } exactly one call of that remote and no other remote; Remote = false: no remote at all
 After    = post-conditions once the server / UI answered
]]
local CLOSED = { "IndexUi/Panel", "StatsUi/Panel" }
UiSpec.Clicks = {
	{
		Id = "open_index",
		Gui = "IndexUi",
		Path = "OpenIndex",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["IndexUi/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_index_closed",
		Gui = "IndexUi",
		Path = "OpenIndex",
		Prepare = { Open = { "IndexUi/Panel" }, Closed = { "StatsUi/Panel" }, Showcase = false },
		Expect = { Panels = { ["IndexUi/Panel"] = false }, Remote = false },
	},
	{
		Id = "close_index",
		Gui = "IndexUi",
		Path = "Panel/Close",
		Prepare = { Open = { "IndexUi/Panel" }, Closed = { "StatsUi/Panel" }, Showcase = false },
		Expect = { Panels = { ["IndexUi/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_stats",
		Gui = "StatsUi",
		Path = "OpenStats",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["StatsUi/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_stats_closed",
		Gui = "StatsUi",
		Path = "OpenStats",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		Expect = { Panels = { ["StatsUi/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_stats_while_index_open",
		Gui = "StatsUi",
		Path = "OpenStats",
		Prepare = { Open = { "IndexUi/Panel" }, Closed = { "StatsUi/Panel" }, Showcase = false },
		Expect = { Panels = { ["StatsUi/Panel"] = true, ["IndexUi/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_index_while_stats_open",
		Gui = "IndexUi",
		Path = "OpenIndex",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		Expect = { Panels = { ["IndexUi/Panel"] = true, ["StatsUi/Panel"] = false }, Remote = false },
	},
	{
		Id = "auto_race_toggle",
		Gui = "AutoRaceButton",
		Path = "Toggle",
		Prepare = { Closed = CLOSED, Showcase = false },
		NeedSetup = { "snapshot", "spy" },
		Expect = {
			Remote = { Name = "SetAutoRace", Arg = "not_attr:AutoRacing" },
			After = { "autorace_label_follows_server", "autoracing_is_arg" },
		},
	},
	{
		Id = "auto_race_toggle_back",
		Gui = "AutoRaceButton",
		Path = "Toggle",
		Prepare = { Closed = CLOSED, Showcase = false, WaitSeconds = 1.5 }, -- past the 1 s pending lock
		NeedSetup = { "spy" },
		Expect = {
			Remote = { Name = "SetAutoRace", Arg = "not_attr:AutoRacing" },
			After = { "autorace_label_follows_server", "autoracing_is_arg" },
		},
	},
	{
		Id = "equip_discovered_tile",
		Gui = "IndexUi",
		Path = "Panel/Grid/{discovered_unequipped}/Equip",
		Prepare = { Open = { "IndexUi/Panel" }, Closed = { "StatsUi/Panel" }, Showcase = false },
		NeedSetup = { "snapshot", "spy", "index_states" },
		Expect = {
			Remote = { Name = "EquipCar", Arg = "tile_id" },
			After = { "equipped_is_tile", "tile_shows_equipped" },
		},
	},
	{
		Id = "equip_equipped_tile",
		Gui = "IndexUi",
		Path = "Panel/Grid/{equipped}/Equip",
		Prepare = { Open = { "IndexUi/Panel" }, Closed = { "StatsUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "index_states" },
		Expect = { Remote = false, After = { "tile_shows_equipped" } },
	},
	{
		Id = "allocate_speed",
		Gui = "StatsUi",
		Path = "Panel/Speed/Plus",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc" },
		},
	},
	{
		Id = "allocate_money",
		Gui = "StatsUi",
		Path = "Panel/Money/Plus",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc" },
		},
	},
	{
		Id = "allocate_luck",
		Gui = "StatsUi",
		Path = "Panel/Luck/Plus",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc" },
		},
	},
	{
		Id = "allocate_workshop_disabled",
		Gui = "StatsUi",
		Path = "Panel/Workshop/Plus",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "stat_points" }, -- even WITH free points the Workshop row fires nothing
		Expect = { Remote = false, After = { "alloc_unchanged", "points_unchanged" } },
	},
	{
		Id = "allocate_no_points",
		Gui = "StatsUi",
		Path = "Panel/Speed/Plus",
		Prepare = { Open = { "StatsUi/Panel" }, Closed = { "IndexUi/Panel" }, Showcase = false },
		NeedSetup = { "spy", "no_stat_points" },
		Expect = { Remote = false, After = { "alloc_unchanged", "points_unchanged" } },
	},
	-- Roll toast -> showcase (owner's revision). Run these five in this order, with auto_racing active.
	{
		Id = "open_showcase_from_toast",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, WaitShown = true },
		Retries = 4,
		NeedSetup = { "spy", "auto_racing" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = {
				"showcase_card_is_latest_roll",
				"showcase_blur_on",
				"showcase_layout",
				"showcase_covers_buttons",
				"toast_hidden_while_showcase_open",
			},
		},
	},
	{
		Id = "showcase_card_click_stays_open",
		Gui = "RollShowcase",
		Path = "Card", -- an Active Frame, not a button: the click must be swallowed by the card, not the backdrop
		Prepare = { Showcase = true },
		NeedSetup = { "spy", "turbo_next" }, -- the next auto roll is a turbo roll
		Expect = {
			Showcase = true,
			Remote = false,
			After = { "showcase_blur_on", "showcase_updates_live_turbo", "toast_hidden_while_showcase_open" },
		},
	},
	{
		Id = "showcase_backdrop_closes",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "corner",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = { Showcase = false, Remote = false, After = { "showcase_blur_off", "normal_view_back" } },
	},
	{
		Id = "open_showcase_from_toast_again",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, WaitShown = true },
		Retries = 4,
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = { "showcase_card_is_latest_roll", "showcase_blur_on" },
		},
	},
	{
		-- The backdrop covers the INDEX button: clicking there closes the showcase and does NOT open the index
		Id = "showcase_backdrop_over_index_button",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "IndexUi/OpenIndex",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Panels = { ["IndexUi/Panel"] = false, ["StatsUi/Panel"] = false },
			Remote = false,
			After = { "showcase_blur_off", "normal_view_back" },
		},
	},
}

return UiSpec
