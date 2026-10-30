--!nonstrict
-- The expected UI inventory for the UI test harness (UiScenarios). Owned by ui-test-writer; never loosen a value
-- here to get a green run.
--
-- Owner decision 2026-10-06: Isaac's Racer UI (Client/RollToast + Client/RollToast/Ui/*, generated from
-- ui/specs/*.ui.json and baked into StarterGui) is THE UI spec. The old ScreenGuis (SpeedHud, AutoRaceButton,
-- IndexUi, StatsUi, RollUi) were replaced and must not come back. Numbers come from CLAUDE.md, the config modules
-- (RollAnimConfig, GachaConfig, WorkshopConfig, TrackBuilder, NpcConfig) and the Racer UI spec files
-- (ui/specs/*.ui.json, their generated layout is mirrored in UiResponsive), never from measured pixels.
--
-- Paths are "/"-separated child names starting at the ScreenGui ("RacerHud/Race/Face"). "*" matches any one child
-- name (one Equip button per index tile, one "+" per stat row); "**" matches any number of child names (zero or more:
-- cards found by name at any depth under their section).

local UiSpec = {}

local MarketConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("MarketConfig"))
-- A MarketConfig item's Name (a readable placeholder when the id is gone, so the spec still loads and the click fails)
local function marketName(kind, id)
	local item = MarketConfig.Get(kind, id)
	return item and item.Name or ("missing MarketConfig " .. kind .. " " .. id)
end

-- Pixel tolerance for geometry comparisons (rounding of AbsolutePosition / AbsoluteSize).
UiSpec.Tolerance = 1

-- A button may be at most this many px larger than its visible content on each side (only matters for buttons
-- whose background is invisible: an opaque background IS the visible content).
UiSpec.MaxHitboxPadding = 8

-- Viewports the layout is checked at. "current" is the live Studio viewport (engine AbsolutePosition: the emulated
-- phone screen under Device emulation, the real game view at a desktop size with Device = none); the others
-- are solved with the same layout rules (UDim2, AnchorPoint, UISizeConstraint, UIScale, UIPadding, UIListLayout,
-- UIGridLayout, ScrollingFrame canvas, top-bar inset) and the Racer UI's own responsive rules (UiResponsive: phone
-- variant at ViewportSize.Y <= 500, UIScale k per height).
-- phone_landscape is a common Roblox phone in landscape (844x390, iPhone 12-14 class); phone_small_landscape the
-- smallest common one (667x375, iPhone SE / 8 class).
UiSpec.Viewports = {
	{ Name = "current" },
	{ Name = "desktop_1080p", Size = Vector2.new(1920, 1080) },
	{ Name = "laptop_768p", Size = Vector2.new(1366, 768) },
	{ Name = "hd_720p", Size = Vector2.new(1280, 720) },
	{ Name = "tablet_4x3", Size = Vector2.new(1024, 768) },
	{ Name = "phone_landscape", Size = Vector2.new(844, 390) },
	{ Name = "phone_small_landscape", Size = Vector2.new(667, 375) },
}

-- UIScale objects that are transient visual feedback, not layout: Racer UI's hover / press scale
-- (Client/RollToast/Ui/RacerMotion, 1.035 on hover, 0.97 while pressed) and Client/UiMotion's MotionScale (Pop, the
-- PanelSwitch open scale 0.92 -> 1; docs/HUD_LAYOUT_SPEC.md section 10). Geometry is measured with them at 1x, after
-- the open motion settled (UiSpec.Waits.PanelMotion).
UiSpec.TransientScales = { HoverScale = true, MotionScale = true }

-- Roblox's own top-bar buttons. The Racer UI guis ignore the inset (IgnoreGuiInset = true), so nothing of theirs may
-- sit on the area Roblox's buttons use: the live GuiService.TopbarInset (everything left of Min.X / right of Max.X in
-- the top band is Roblox's) and, always, the reserved rect of the Racer UI spec (ui/specs/*.ui.json theme.reserved
-- "RobloxTopBar", x 0..360, y 0..58).
UiSpec.TopBar = { Reserved = { X = 0, Y = 0, W = 360, H = 58 } }

-- Every ScreenGui the game creates in PlayerGui. Anything else found in PlayerGui must be in IgnoreGuis
-- (Roblox-created) or the inventory check fails: a new UI must be added here, with its buttons.
--   AlwaysOn   elements shown all the time (HUD buttons, read-outs, the compact roll's area): never overlap each other
--   Readouts   the AlwaysOn elements that are display only (never take a click; a modal panel may cover them)
--   Panels     pop-up panels, hidden at rest, opened by a button (the panel is the outer Frame PanelSwitch toggles)
--   Buttons    every GuiButton: what it must DO when clicked
--              Does = "toggle_panel" | "open_panel" | "close_panel" | "remote" | "open_overlay" | "close_overlay"
--                     | "local" ("open_panel": opens it, a second click leaves it open; only its Close hides it)
--              Count = exact number expected for "*" patterns ("duel_tracks": the Tracks of the latest PickTrack
--              message, 0 before any; "dynamic": depends on the view last rendered, its scenario / clicks count it);
--              Label = the text it must show
--   Overlay    a declared full-screen overlay (may cover everything while shown)
--   NonInteractive  nothing inside may be Active or a GuiButton (must never swallow clicks)
--   NonInteractiveParts  paths (from the gui) of parts of an otherwise interactive gui that must not swallow clicks
UiSpec.Guis = {
	-- The HUD (ui/specs/RacerHud.ui.json). Roll entry is the top-centre compact
	-- animation; its enlarged showcase owns the AUTO toggle.
	RacerHud = {
		Source = "Client/RollToast/RacerUiController (Ui/RacerHud)",
		AlwaysOn = {
			"Race/Face",
			"Speed",
			"Money",
			"Turbo",
		},
		Readouts = { "Speed", "Money", "Turbo" },
		NonInteractiveParts = { "Speed", "Money", "Turbo" },
		Buttons = {
			{
				Path = "Race/Face",
				Does = "remote",
				Remote = "SetAutoRace",
				Arg = "not_attr:AutoRacing", -- the opposite of the current AutoRacing attribute
				Label = "upper(HudFormat.AutoButtonText(AutoRacing))", -- "AUTO RACE" / "STOP AUTO"
			},
		},
	},
	-- Current persistent HUD entry points (docs/HUD_LAYOUT_SPEC.md). The generated
	-- RacerHud navigation/settings nodes remain hidden compatibility assets and are
	-- deliberately absent from this live inventory.
	HudChrome = {
		Source = "Client/HudChrome",
		AlwaysOn = {
			"Grid/Index",
			"Grid/Stats",
			"Grid/Stats/Badge",
			"Grid/Rebirth",
			"ShopColumn/Shop",
			"ItemsSlot/Items",
			"UpgradeSlot/Upgrade",
			"TopRight/Daily",
			"TopRight/Quests",
			"TopRight/Market",
			"TopRight/Settings",
		},
		Readouts = { "Grid/Stats/Badge" },
		Buttons = {
			{ Path = "Grid/Index", Does = "toggle_panel", Panel = "RacerIndex/Panel", Text = "Index" },
			{ Path = "Grid/Stats", Does = "toggle_panel", Panel = "RacerStats/Panel", Text = "Stats" },
			{ Path = "Grid/Rebirth", Does = "toggle_panel", Panel = "RacerRebirth/Panel", Text = "Rebirth" },
			{ Path = "ShopColumn/Shop", Does = "toggle_panel", Panel = "ShopUi/Backdrop", Text = "Shop" },
			{ Path = "ItemsSlot/Items", Does = "toggle_panel", Panel = "RacerBackpack/Panel", Text = "Items" },
			{ Path = "UpgradeSlot/Upgrade", Does = "toggle_panel", Panel = "RacerUpgrades/Panel", Text = "Upgrade" },
			{
				Path = "TopRight/Daily",
				Does = "toggle_panel",
				Panel = "DailyBoosts/ModalBackdrop",
				Label = "Daily before claim; countdown after claim",
			},
			{ Path = "TopRight/Quests", Does = "toggle_panel", Panel = "DailyBoosts/ModalBackdrop", Text = "Quests" },
			{ Path = "TopRight/Market", Does = "toggle_panel", Panel = "MarketUi/Backdrop", Text = "Market" },
			{ Path = "TopRight/Settings", Does = "toggle_panel", Panel = "RacerSettings/Panel" },
		},
	},
	-- CAR INDEX modal (ui/specs/RacerIndex.ui.json; tiles built by Components.BakeIndex)
	RacerIndex = {
		Source = "Client/RollToast/RacerUiController (Ui/RacerIndex, Ui/RacerComponents)",
		Panels = { "Panel" },
		Buttons = {
			{
				Path = "Panel/Face/Header/Face/Close/Face",
				Does = "close_panel",
				Panel = "RacerIndex/Panel",
				Text = "X",
			},
			{
				Path = "Panel/Face/GridHost/Gallery/*/Equip",
				Does = "remote",
				Remote = "EquipCar",
				Arg = "tile_id", -- THAT tile's car id
				Count = "catalog", -- one per CarCatalog.All()
				DisabledWhen = "equipped", -- the equipped tile shows "EQUIPPED" and fires nothing
				HiddenWhen = "undiscovered", -- undiscovered tiles have no Equip button
			},
		},
	},
	-- STATS modal (ui/specs/RacerStats.ui.json; rows built by Components.BakeStats)
	RacerStats = {
		Source = "Client/RollToast/RacerUiController (Ui/RacerStats, Ui/RacerComponents)",
		Panels = { "Panel" },
		Buttons = {
			{
				Path = "Panel/Face/Header/Face/Close/Face",
				Does = "close_panel",
				Panel = "RacerStats/Panel",
				Text = "X",
			},
			{
				Path = "Panel/Face/StatsHost/Rows/*/Plus",
				Does = "remote",
				Remote = "AllocateStat",
				Arg = "row_stat", -- THAT row's stat
				Count = "stats", -- one per GachaConfig.STATS
				DisabledWhen = "no_points_or_disabled_stat",
			},
		},
		DisabledStats = {}, -- Every implemented stat, including Workshop, accepts allocation with free points.
		-- The header's free-points read-out (RacerStats.ui.json "1 FREE POINT"): exactly the server's StatPoints,
		-- singular for 1, plural otherwise ("0 FREE POINTS", "1 FREE POINT", "3 FREE POINTS").
		PointsLabel = "RacerStats/Panel/Face/Header/Face/Points",
		PointsText = { Singular = "%d FREE POINT", Plural = "%d FREE POINTS" },
	},
	-- SETTINGS modal (ui/specs/RacerSettings.ui.json): local preferences plus the read-only Player Profile category.
	RacerSettings = {
		Source = "Client/RollToast/RacerUiController (Ui/RacerSettings)",
		Panels = { "Panel" },
		Buttons = {
			{
				Path = "Panel/Face/Header/Face/Close/Face",
				Does = "close_panel",
				Panel = "RacerSettings/Panel",
				Text = "X",
			},
			{
				Path = "Panel/Face/Header/Face/CategoryTabs/SettingsTab",
				Does = "local",
				Effect = "settings_category",
				Text = "SETTINGS",
			},
			{
				Path = "Panel/Face/Header/Face/CategoryTabs/ProfileTab",
				Does = "local",
				Effect = "profile_category",
				Text = "PLAYER PROFILE",
			},
			{
				-- Session-local mute: every Sound's Volume goes to 0 (new ones too); label "OFF" while muted
				Path = "Panel/Face/SoundRow/Face/SoundToggle/Face",
				Does = "local",
				Effect = "mute",
				Label = "UiSpec.Settings.SoundText[not muted]",
			},
			{
				-- LocalPlayer attribute ReduceEffects (no shake, no flashes); label "ON" while effects are reduced
				Path = "Panel/Face/EffectsRow/Face/EffectsToggle/Face",
				Does = "local",
				Effect = "attr:ReduceEffects",
				Label = "UiSpec.Settings.EffectsText[ReduceEffects]",
			},
			{
				-- Session-local bird's-eye camera preference used while auto-racing
				Path = "Panel/Face/AutoRow/Face/AutoToggle/Face",
				Does = "local",
				Effect = "attr:TopDownView",
				Label = "TOP-DOWN VIEW [TopDownView]",
			},
		},
	},
	-- REBIRTH modal, rebuilt (owner 2026-10-15, docs/REBIRTH_SPEC.md "Panel"): every node comes from
	-- ui/specs/RacerRebirth.ui.json (RebirthButton is a generated "button" node, so its clickable part is
	-- RebirthButton/Face and its text RebirthButton/Face/RebirthButtonLabel); RacerUiController only binds the live
	-- values. The old ComingSoon label and the runtime Status label are gone. UiSpec.Rebirth holds the nodes and texts.
	RacerRebirth = {
		Source = "Client/RollToast/RacerUiController (Ui/RacerRebirth)",
		Panels = { "Panel" },
		Buttons = {
			{
				Path = "Panel/Face/Header/Face/Close/Face",
				Does = "close_panel",
				Panel = "RacerRebirth/Panel",
				Text = "X",
			},
			{
				-- Asks the server (RemoteFunction Rebirth, no argument: the server decides everything). Disabled
				-- (Active false, fires nothing) below the level milestone. Rebirth milestones continue indefinitely.
				Path = "Panel/Face/RebirthButton/Face",
				Does = "remote",
				Remote = "Rebirth",
				Arg = "none",
				Text = "REBIRTH",
				DisabledWhen = "not_eligible",
			},
		},
	},
	-- The compact roll (docs/ROLL_ANIMATION_CONTRACT.md): top centre, directly UNDER the Race button. With no panel
	-- open its area is always reserved (the overlap checks place it there even while hidden between rolls); while any
	-- panel is open it is hidden (UiSpec.HiddenWhilePanelOpen, owner decision 2026-10-08). It is a button only while
	-- shown (Visible = false at rest: no invisible hitbox; shown at rest only while AutoRoll is false, with "AUTO OFF").
	-- Text is "": its parts draw it.
	RollToast = {
		Source = "Client/RollToast",
		AlwaysOn = { "Toast" },
		Buttons = {
			{
				Path = "Toast",
				Does = "open_overlay",
				Overlay = "RollShowcase",
				Label = "the bare car art and Odds of the latest RollResult (no card)",
			},
		},
		NonInteractiveParts = { "FlyIcon" },
	},
	-- The enlarged view (ui/specs/RollShowcase.ui.json + parts added by Client/RollToast). An Overlay: exempt from the
	-- overlap rules while open; at rest nothing of it may be visible or clickable. UiSpec.Showcase holds its parts.
	RollShowcase = {
		Source = "Client/RollToast (Ui/RollShowcase)",
		Overlay = true,
		Buttons = {
			{ Path = "Backdrop", Does = "close_overlay", Overlay = "RollShowcase" }, -- a click off the card closes
			{
				Path = "AutoButton",
				Does = "remote",
				Remote = "SetAutoRoll",
				Arg = "not_attr:AutoRoll", -- does NOT close the view
				Label = "UiSpec.AutoRollText.Showcase[AutoRoll]",
			},
		},
	},
	LoserScreen = {
		Source = "Client/NpcRacerView",
		Overlay = true,
		Buttons = {},
		NonInteractive = true,
	},
	-- The world dim behind open panels (UiSpec.PanelDimmers); below the HUD, never takes a click.
	PanelDim = {
		Source = "Client/HudChrome",
		Buttons = {},
		NonInteractive = true,
	},
}

-- The ScreenGuis the Racer UI replaced (owner decision 2026-10-06): their scripts are disabled and they must not be
-- in PlayerGui (two HUDs at once). RacerHudConcept is an unused concept draft (ui/concept-draft): never shipped.
UiSpec.RemovedGuis = { "SpeedHud", "AutoRaceButton", "IndexUi", "StatsUi", "RollUi", "RacerHudConcept" }
UiSpec.LegacyControls = {
	Path = "RacerHud/RollControls",
	PhoneMaxHeight = 500,
	ResizeScenario = "ui_legacy_controls_resize",
	ResizeProtocol = "After RacerUiReady, resize real game viewport desktop (>500 high) -> phone (<=500) -> desktop. "
		.. "Wait at least two rendered frames at each size. Run ui_legacy_controls_resize with UiTestScenario; "
		.. "no observed resize is a failure, not a pass. Restore the original viewport afterwards.",
}

-- Scenarios ui-tester's tools can not perform (same rule as UiSpec.Clicks Manual, owner decision 2026-10-08): not in
-- UiScenarios.Names; the harness lists them as "[UITEST] MANUAL <name> reason=..." (not a pass, not a failure, never
-- blocking the gate). The owner runs them by hand with UiTestScenario (steps in the dashboard's Needs-you list); the
-- scenario still checks everything when run and fails without an observed resize.
UiSpec.ManualScenarios = {
	{
		Name = UiSpec.LegacyControls.ResizeScenario,
		Manual = "needs the real game viewport resized desktop (>500 high) -> phone (<=500) -> desktop; with the "
			.. "Device Simulator off automation can not resize the Studio game view (MCP has no window-resize input)",
	},
}

-- Labels whose text follows a server attribute (each button names what it shows).
UiSpec.AutoRollText = {
	Showcase = { [true] = "AUTO: ON", [false] = "AUTO: OFF" }, -- RollShowcase/AutoButton
}
UiSpec.Settings = {
	Title = "SETTINGS",
	CategoryAttribute = "Category",
	Categories = { Settings = "Settings", Profile = "Profile" },
	SettingsTab = "RacerSettings/Panel/Face/Header/Face/CategoryTabs/SettingsTab",
	ProfileTab = "RacerSettings/Panel/Face/Header/Face/CategoryTabs/ProfileTab",
	ProfileHost = "RacerSettings/Panel/Face/PlayerProfile",
	ProfileRows = { "TotalRolls", "BestRoll", "CarsDiscovered", "Level", "Speed", "Luck", "SessionTime" },
	SoundText = { [true] = "ON", [false] = "OFF" }, -- [sound on]
	EffectsText = { [true] = "ON", [false] = "OFF" }, -- [ReduceEffects]
	ProbeVolume = 0.5, -- the test's own Sound (created and destroyed by the sound clicks) must follow the toggle
}
-- The Rebirth panel (ui_rebirth, clicks rebirth_*), rebuilt from the owner's reference image (2026-10-15,
-- docs/REBIRTH_SPEC.md "Panel"). Numbers come from Shared/RebirthConfig (NextMultiplier,
-- POINTS_PER_REBIRTH), Shared/LevelConfig.RebirthLevelRequirement(RebirthLevel) and the player's Level /
-- RebirthLevel attributes, never from the panel's pixels.
-- Nodes are found BY NAME under the panel (the generator decides where the Face frames go): each must exist exactly
-- once below its Parent node (Parent "Panel" = RacerRebirth/Panel), be shown while the panel is open, lie inside its
-- Parent's rect and inside the panel at every UiSpec.Viewports entry, and have a row in UiResponsive.Nodes (so the
-- phone variant is really simulated) unless its Size and Position are scale-only (then it is the same at every variant). Class: the instance's class. Text: exact text; Contains: every piece must be
-- in the text; Colour: the heading's TextColor3 family (UiSpec.Rebirth.Colours).
UiSpec.Rebirth = {
	Panel = "RacerRebirth/Panel",
	Title = "RacerRebirth/Panel/Face/Header/Face/Title",
	TitleText = "REBIRTH",
	Nodes = {
		{ Name = "Header", Parent = "Panel", Class = "Frame" },
		{ Name = "Title", Parent = "Header", Class = "TextLabel", Text = "REBIRTH" },
		{ Name = "Close", Parent = "Header", Class = "Frame" },
		{ Name = "Warning", Parent = "Panel", Class = "Frame" },
		{ Name = "WarningTitle", Parent = "Warning", Class = "TextLabel", Text = "WARNING", Colour = "red" },
		{
			Name = "WarningText",
			Parent = "Warning",
			Class = "TextLabel",
			Contains = { "Rebirth resets your Money and Speed", "(Robux purchases stay)" },
		},
		{ Name = "Rewards", Parent = "Panel", Class = "Frame" },
		{
			Name = "RewardsTitle",
			Parent = "Rewards",
			Class = "TextLabel",
			Text = "REWARDS UNLOCKED",
			Colour = "yellow",
		},
		{ Name = "LuckReward", Parent = "Rewards", Class = "Frame" },
		{ Name = "SpeedReward", Parent = "Rewards", Class = "Frame" },
		{ Name = "PointReward", Parent = "Rewards", Class = "Frame" },
		{ Name = "LuckRewardIcon", Parent = "LuckReward", Class = "ImageLabel" },
		{ Name = "LuckRewardCaption", Parent = "LuckReward", Class = "TextLabel" },
		{ Name = "SpeedRewardIcon", Parent = "SpeedReward", Class = "ImageLabel" },
		{ Name = "SpeedRewardCaption", Parent = "SpeedReward", Class = "TextLabel" },
		{ Name = "PointRewardIcon", Parent = "PointReward", Class = "ImageLabel" },
		{ Name = "PointRewardCaption", Parent = "PointReward", Class = "TextLabel" },
		{ Name = "Requirements", Parent = "Panel", Class = "Frame" },
		{
			Name = "RequirementsTitle",
			Parent = "Requirements",
			Class = "TextLabel",
			Text = "REQUIREMENTS",
			Colour = "purple",
		},
		{ Name = "Bar", Parent = "Requirements", Class = "Frame" },
		{ Name = "Fill", Parent = "Bar", Class = "Frame" },
		{ Name = "BarText", Parent = "Bar", Class = "TextLabel" },
		{ Name = "RebirthButton", Parent = "Panel", Class = "Frame" },
	},
	-- Each reward tile <Name> holds <Name>Icon (ImageLabel with a non-empty Image) and <Name>Caption (TextLabel), not
	-- overlapping (node ids are unique in the generator, so the tile name is the prefix; both are listed in Nodes).
	-- Caption = Format with the NEXT rebirth's gain: Multiplier tiles use RebirthConfig.NextMultiplier(RebirthLevel)
	-- = SpeedGainMulti(RebirthLevel + 1), the NEXT TOTAL (x1.5 at level 0, x2 at level 1 ... x10, then x10 per
	-- rebirth to x100b at 20, the last; owner 2026-10-27 rev. 4, docs/REBIRTH_SPEC.md "Panel"), others RebirthConfig[Config].
	Tiles = {
		-- %s = HudFormat.Multi(next multiplier) ("x7.5", HUD spec section 8, owner 2026-10-27; was "x%.2f")
		{ Name = "LuckReward", Multiplier = true, Format = "%s Luck" },
		{ Name = "SpeedReward", Multiplier = true, Format = "%s Speed Gain" },
		{ Name = "PointReward", Config = "POINTS_PER_REBIRTH", Format = "+%d Stat Point", Plural = "+%d Stat Points" },
	},
	-- The panel's sections, shown together: no two may overlap (at every viewport).
	Sections = { "Header", "Warning", "Rewards", "Requirements", "RebirthButton" },
	-- Groups of nodes inside one section, shown together: no two of a group may overlap (at every viewport).
	Disjoint = {
		{ "Title", "Close" },
		{ "WarningTitle", "WarningText" },
		{ "RewardsTitle", "LuckReward", "SpeedReward", "PointReward" },
		{ "RequirementsTitle", "Bar" },
		{ "LuckRewardIcon", "LuckRewardCaption" },
		{ "SpeedRewardIcon", "SpeedRewardCaption" },
		{ "PointRewardIcon", "PointRewardCaption" },
	},
	BarFormat = "%d / %d Level", -- Level / LevelConfig.RebirthLevelRequirement(RebirthLevel)
	FillTolerance = 0.03, -- |Fill width / Fill parent width - clamp(Level / required, 0, 1)|
	-- Gone with the rebuild: no descendant of the panel may carry these names.
	Removed = { "ComingSoon", "Status" },
	Button = "RacerRebirth/Panel/Face/RebirthButton/Face",
	ButtonLabel = "RebirthButtonLabel", -- the generated label inside the button's Face
	ButtonText = "REBIRTH",
	-- What the button may show besides ButtonText: the server's replies (RebirthService.Rebirth, REBIRTH_SPEC item 4).
	-- "%d" = the required level. A label also passes when it starts with "REBIRTH COMPLETE".
	ButtonReplies = {
		"Reach Level %d",
		"Stop Auto before rebirthing",
		"Please wait",
		"Data not loaded",
		"Stats not ready",
	},
	-- TextColor3 / BackgroundColor3 families (0..1 channels): red, yellow, purple headings; green = the met bar fill.
	Colours = {
		red = function(c)
			return c.R >= 0.6 and c.G <= 0.45 and c.B <= 0.45
		end,
		yellow = function(c)
			return c.R >= 0.6 and c.G >= 0.6 and c.B <= 0.45
		end,
		purple = function(c)
			return c.R >= 0.4 and c.B >= 0.5 and c.G <= c.R - 0.15 and c.G <= c.B - 0.15
		end,
		green = function(c)
			return c.G >= 0.5 and c.G >= c.R + 0.15 and c.G >= c.B + 0.15
		end,
	},
}
-- The HUD (ui/specs/RacerHud.ui.json). Gaps are the spec's offsets (they are not scaled by the UIScale k).
UiSpec.Hud = {
	Race = "RacerHud/Race/Face",
	RaceLabel = "RacerHud/Race/Face/RaceLabel",
	RaceTop = 72, -- px from the screen top (IgnoreGuiInset) to the Race button's top edge, below the top bar
	NavButtons = {
		"HudChrome/Grid/Index",
		"HudChrome/Grid/Stats",
		"HudChrome/Grid/Rebirth",
	},
	NavLabels = { "Index", "Stats", "Rebirth" }, -- stacked top to bottom on the LEFT edge
	NavMaxLeftGap = 32, -- px from the screen's left edge to the column
	Speed = "RacerHud/Speed",
	-- The speed icon is the speedometer's hub (docs/HUD_LAYOUT_SPEC.md section 9, owner 2026-10-27): a child of Speed,
	-- drawn above the dial (higher ZIndex), its centre inside the dial.
	SpeedIcon = "RacerHud/Speed/SpeedIcon",
	-- Round speedometer on the left of the Speed group (section 9): Frame (or CanvasGroup), non-interactive, holds a
	-- needle object Needle (attribute DialValue = the car's real speed in studs/s, 0 on foot) and a TextLabel DialSpeed.
	SpeedDial = "RacerHud/Speed/SpeedDial",
	DialNeedle = "Needle",
	DialText = "DialSpeed",
	DialValueAttr = "DialValue",
	SpeedValue = "RacerHud/Speed/SpeedValue",
	SpeedSuffix = " SPEED",
	SpeedCentreTolerance = 2, -- px: the visible icon + number are centred on the screen (brief 2026-10-06: Speed centred; CLAUDE.md still says left)
	Money = "RacerHud/Money",
	MoneyValue = "RacerHud/Money/MoneyValue",
	-- Rounded navy plate behind MoneyValue and Unbanked (section 9): lower ZIndex than both, non-interactive, holds both.
	MoneyPlate = "RacerHud/Money/MoneyPlate",
	-- Counters with a text gradient (section 9): a UIGradient child on each.
	GradientLabels = { "RacerHud/Money/MoneyValue", "RacerHud/Money/Unbanked", "RacerHud/Speed/SpeedValue" },
	Unbanked = "RacerHud/Money/Unbanked",
	UnbankedPrefix = "UNBANKED ",
	Turbo = "RacerHud/Turbo",
	TurboFill = "RacerHud/Turbo/Face/TurboFill",
	TurboLabel = "RacerHud/Turbo/Face/TurboLabel",
	TurboBottomGap = { Desktop = 22, Phone = 16 }, -- px from the screen bottom to the TURBO LUCK bar's bottom edge
	Settings = "HudChrome/TopRight/Settings",
	PointsBadge = "HudChrome/Grid/Stats/Badge",
	BottomGap = { Desktop = 22, Phone = 16 }, -- px: Money (bottom left) and TURBO bar bottom edges
	SideGap = { Desktop = 22, Phone = 12 }, -- px: Money's left edge from the screen side
}

-- The top controls (owner-approved layout, CLAUDE.md + ui/specs/RacerHud.ui.json, reconfirmed 2026-10-08): the Race
-- button (AUTO RACE / STOP AUTO) at the top centre (ui_layout autorace_top_centre_x / autorace_below_topbar) and
-- Settings in the top-right corner (ui.json: AnchorPoint (1, 0), Position (1, -12, 0, 12)). Both stay reachable while
-- any pop-up panel is open: no open panel may cover either of them (ui_layout panel_clear_of_top_controls_*).
UiSpec.TopControls = {
	Race = UiSpec.Hud.Race,
	Settings = UiSpec.Hud.Settings,
	SettingsMaxRightGap = 32, -- px from the screen's right edge to Settings' right edge
	SettingsMaxTopGap = 32, -- px from the screen's top edge (IgnoreGuiInset) to Settings' top edge
}

-- TURBO LUCK bar (ui/specs/RacerHud.ui.json "Live turbo progress meter"): the server's TurboCount / TurboEvery
-- (upgrade tree; fallback GachaConfig TurboProgress(Rolls) / TURBO_EVERY before they arrive). A turbo roll shows
-- "TURBO x<multi>!" (multi = the RollResult's, = the player's TurboMulti attribute) then the bar is back to 0.
UiSpec.Turbo = {
	LabelFormat = "TURBO LUCK %d/%d",
	PopFormat = "TURBO x%s!",
	FillTolerance = 0.03, -- |Fill width / bar width - TurboCount / TurboEvery|
	FallbackMulti = 10, -- UpgradeConfig.BASE_TURBO.Multi (no Turbo tier owned)
}

-- Pop-up panels are mutually exclusive: opening one hides the others (Client/PanelSwitch, used by the buttons).
-- Names maps each declared panel to its PanelSwitch name. ui_panels and the open_*_while_*_open clicks enforce it.
UiSpec.PanelSwitch = {
	Module = "PanelSwitch", -- ModuleScript in StarterPlayerScripts.Client
	Names = {
		["RacerIndex/Panel"] = "Index",
		["RacerStats/Panel"] = "Stats",
		["RacerSettings/Panel"] = "Settings",
		["RacerRebirth/Panel"] = "Rebirth",
		["RacerBackpack/Panel"] = "Backpack",
		["RacerUpgrades/Panel"] = "Upgrades",
		["ShopUi/Backdrop"] = "Shop",
		["DailyBoosts/ModalBackdrop"] = "Daily",
		["MarketUi/Backdrop"] = "Market",
		["CheckpointUi/Panel"] = "Checkpoints",
	},
}

-- Panels a fixture opens that are not in PanelSwitch.Names (closed by UiScenarios.CloseFixturePanels, bug 081c684a):
-- the OFFLINE REWARD modal (Client/ProgressionUi panel "Welcome", Client/WelcomeStyle), opened by offline_* fixtures
-- and again when 'restore' puts a nonzero OfflineSpeed back.
UiSpec.FixturePanels = {
	Welcome = "RacerWelcome/Panel",
	Names = { ["RacerWelcome/Panel"] = "Welcome" },
}

-- Money market (Client/MarketUi; docs/HUD_LAYOUT_SPEC.md section 2 "Market", owner 2026-10-16: the Backpack look).
-- Backdrop is the full-screen dim, NON-interactive Frame (owner 2026-10-20, docs/HUD_LAYOUT_SPEC.md section 6: HUD
-- tiles stay clickable while it is open; a click on empty screen that no GUI processed closes it, click
-- close_market_outside); Panel holds Header (square red X),
-- side Tabs (one per MarketConfig.Items kind), the tile Grid of the selected kind and the Detail pane of the selected
-- tile. UiSpec.Market holds the parts; ui_market and the market_* clicks check them.
UiSpec.Guis.MarketUi = {
	Source = "Client/MarketUi",
	Panels = { "Backdrop" },
	Buttons = {
		{ Path = "Backdrop/Panel/Header/Close", Does = "close_panel", Panel = "MarketUi/Backdrop", Text = "X" },
		{ Path = "Backdrop/Panel/Tabs/TrailTab", Does = "local", Effect = "market_tab:Trail" },
		{ Path = "Backdrop/Panel/Tabs/AuraTab", Does = "local", Effect = "market_tab:Aura" },
		{ Path = "Backdrop/Panel/Tabs/PotionTab", Does = "local", Effect = "market_tab:Potion" },
		{
			-- One tile per MarketConfig.Items[<shown kind>] entry, named <Kind>_<Id> (ui_market counts them)
			Path = "Backdrop/Panel/Grid/*",
			Does = "local",
			Effect = "market_select", -- Detail shows THAT tile's item
			Count = "dynamic",
		},
		{
			-- BUY (not owned, and every potion) invokes MarketPurchase(kind, id); EQUIP (owned) invokes
			-- MarketEquip(kind, id); EQUIPPED fires nothing. Always for the item the Detail pane shows.
			Path = "Backdrop/Panel/Detail/Action",
			Does = "remote",
			Remote = "MarketPurchase|MarketEquip",
			Arg = "detail_kind_id",
			Label = "UiSpec.Market.ActionText",
			DisabledWhen = "equipped",
		},
	},
}

UiSpec.Guis.RacerBackpack = {
	Source = "Client/BackpackUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Panel/Header/Close", Does = "close_panel", Panel = "RacerBackpack/Panel", Text = "X" },
		{ Path = "Panel/Tabs/MiscTab", Does = "local", Effect = "backpack_category", Text = "Misc" },
		{ Path = "Panel/Tabs/TrailsTab", Does = "local", Effect = "backpack_category", Text = "Trails" },
		{ Path = "Panel/Tabs/AurasTab", Does = "local", Effect = "backpack_category", Text = "Auras" },
		-- Owner 2026-10-20 (docs/HUD_LAYOUT_SPEC.md section 3): the Cars tab lists the owned cars (UiSpec.Backpack).
		{ Path = "Panel/Tabs/CarsTab", Does = "local", Effect = "backpack_category", Text = "Cars" },
		{
			-- Misc tiles invoke UseBoost(id); Trails / Auras tiles invoke MarketEquip(kind, id); Cars tiles fire
			-- EquipCar(THAT tile's car id), the equipped car's tile fires nothing (clicks backpack_equip_car*).
			Path = "Panel/Items/*",
			Does = "remote",
			Remote = "UseBoost|MarketEquip|EquipCar",
			Arg = "item_id",
			Count = "dynamic",
			ClickCoverage = "ui_motion_dynamic",
		},
	},
}

-- Robux Shop (Client/ShopUi; docs/GAMEPASS_SHOP_SPEC.md, owner rewrite 2026-10-16). Cards are found BY NAME under
-- their section ("**" = any depth): the spec fixes the names, not the wrapper frames. UiSpec.Shop holds the parts.
UiSpec.Guis.ShopUi = {
	Source = "Client/ShopUi",
	Panels = { "Backdrop" },
	Buttons = {
		{ Path = "Backdrop/Panel/Close", Does = "close_panel", Panel = "ShopUi/Backdrop", Text = "X" },
		{
			-- Codes: sends the Input text to the server (RemoteFunction RedeemCode); Status shows the reply
			Path = "Backdrop/Panel/Items/Codes/**/Redeem",
			Does = "remote",
			Remote = "RedeemCode",
			Arg = "input_text",
		},
		{
			-- Every price button. Id 0: "Coming soon", a click does nothing; id > 0: PromptGamePassPurchase /
			-- PromptProductPurchase (Roblox's own prompt, no game remote). ui_shop counts them per section.
			Path = "Backdrop/Panel/Items/**/Buy",
			Does = "local",
			Effect = "prompt_purchase_or_nothing",
			Count = "dynamic",
		},
	},
}

-- The Shop's parts (docs/GAMEPASS_SHOP_SPEC.md section 1). Sections are direct children of Items, top to bottom in
-- this order. Cards: a Frame named by the item Id somewhere under its section, holding exactly one "Buy" TextButton:
-- Featured = CarCatalog.Passes(), Gamepasses = MonetizationConfig.Gamepasses, Potions = Products with Section
-- "Potions" plus the Bundle banner (Frame "Bundle", the Section "Bundle" product), ServerLuck = Section "ServerLuck".
UiSpec.Shop = {
	Gui = "ShopUi",
	Panel = "ShopUi/Backdrop/Panel",
	Close = "ShopUi/Backdrop/Panel/Close",
	CloseText = "X",
	Items = "ShopUi/Backdrop/Panel/Items",
	Sections = { "Featured", "Gamepasses", "Potions", "ServerLuck", "Codes", "Thanks" },
	SectionTitles = { Gamepasses = "Gamepasses", Potions = "Potions", Codes = "Codes" },
	Bundle = "Bundle",
	BuyName = "Buy",
	ComingSoon = "Coming soon", -- id 0 (GamepassId / ProductId)
	-- An owned gamepass car (attribute Pass_<carId>): its Featured button equips it (docs/GAMEPASS_CARS_SPEC.md, owner
	-- 2026-10-20, later than GAMEPASS_SHOP_SPEC section 2's "Owned"): "Equipped" while it is EquippedCar, else "Equip".
	OwnedCar = { Equip = "Equip", Equipped = "Equipped" },
	ThanksText = "Thanks for your support!",
	Codes = { Input = "Input", Redeem = "Redeem", Status = "Status" },
	-- The text the redeem click types: never a real code (Server/CodeConfig keys are upper case words; this has a
	-- prefix no code uses), so the real RedeemCode answers "Invalid code" and saves nothing.
	TestCode = "UITEST-NOT-A-CODE",
	-- What Status may show after the redeem click: the server's replies for a bad code (SHOP_PURCHASES_SPEC 3)
	BadCodeReplies = { "Invalid code", "Please wait", "Data not loaded" },
	ReplyWait = 4, -- s for the reply to show
}

-- The Market's parts (docs/HUD_LAYOUT_SPEC.md section 2 "Market"). Tab -> MarketConfig.Items kind; tiles are
-- Grid/<Kind>_<Id>; Detail parts by name directly under Detail.
UiSpec.Market = {
	Gui = "MarketUi",
	Panel = "MarketUi/Backdrop/Panel",
	Header = "MarketUi/Backdrop/Panel/Header",
	Close = "MarketUi/Backdrop/Panel/Header/Close",
	CloseText = "X",
	Tabs = "MarketUi/Backdrop/Panel/Tabs",
	TabKinds = { TrailTab = "Trail", AuraTab = "Aura", PotionTab = "Potion" },
	TabOrder = { "TrailTab", "AuraTab", "PotionTab" }, -- top to bottom (side tabs)
	Grid = "MarketUi/Backdrop/Panel/Grid",
	TileFormat = "%s_%s", -- Kind, Id
	Detail = "MarketUi/Backdrop/Panel/Detail",
	DetailParts = {
		{ Name = "Name", Class = "TextLabel" },
		{ Name = "Rarity", Class = "TextLabel" },
		{ Name = "Preview", Class = "ViewportFrame" },
		-- Since the Market restyle (016c467) Price is a Frame row; its TextLabel "Value" (PriceText) holds the text
		{ Name = "Price", Class = "Frame" },
		{ Name = "Description", Class = "TextLabel" },
		{ Name = "Action", Class = "TextButton" },
	},
	-- Action label for the shown item: potions are always BUY (consumables)
	ActionText = { Buy = "BUY", Equip = "EQUIP", Equipped = "EQUIPPED" },
	-- The tile the market_select_tile click picks (a potion: shown to every player, never owned-only); not the first
	-- potion, so selecting it really changes Detail.
	SelectKind = "Potion",
	SelectId = "SpeedII",
	-- The price text inside Detail/Price
	PriceText = "Value",
	-- Owner 2026-10-28 (docs/HUD_LAYOUT_SPEC.md section 6): on phones (viewport height <= PhoneMaxHeight) the Market
	-- shows its Grid only (Detail hidden); tapping a tile swaps Grid for Detail, whose Back button (a TextButton whose
	-- label contains BackText) swaps back. Desktop keeps Grid and Detail side by side.
	PhoneMaxHeight = 500,
	Back = "MarketUi/Backdrop/Panel/Detail/Back",
	BackText = "BACK",
	-- Client/MarketUi fitTabs: a UIScale "Scale" in each side tab (not on the rail), fitted to the rail's height.
	-- Mirrored so the layout solver models it at every viewport (UiScenarios marketTabScale). PhoneMin: Market only, on
	-- phones (height <= PhoneMaxHeight) the tabs may shrink to it so every tab stays inside the rail (6365809, section 6
	-- no overlap; Backpack keeps Min).
	TabFit = { ScaleName = "Scale", RailWidth = 96, TabSize = 96, Gap = 10, Min = 0.4, PhoneMin = 0.1, Max = 1 },
}

-- Panels fitted by Client/PanelBand.Fit (docs/HUD_LAYOUT_SPEC.md: between the left grid and the Shop column, below the
-- Race button, above the TURBO LUCK bar and the Money read-out). Value = the panel's max width (mirrored from the
-- client's Band.Fit call; the band rule itself is the spec). The layout solver fits them like PanelBand does.
UiSpec.BandPanels = {
	["ShopUi/Backdrop/Panel"] = 900,
	["MarketUi/Backdrop/Panel"] = 900,
	["CheckpointUi/Panel"] = 760,
	["DailyBoosts/ModalBackdrop/Modal"] = 760,
	["RacerBackpack/Panel"] = 760,
	-- Client/ProgressionUi panel(): Band.Fit(p, 700)
	["RacerWorkshop/Panel"] = 700,
	["RacerWelcome/Panel"] = 700,
}
UiSpec.Band = {
	Race = "RacerHud/Race",
	Turbo = "RacerHud/Turbo",
	Grid = "HudChrome/Grid",
	ShopColumn = "HudChrome/ShopColumn",
	Money = "RacerHud/Money",
	Gap = 8,
	-- No minimum size: PanelBand.Fit never makes a panel larger than the band (HUD_LAYOUT_SPEC section 6, no overlap;
	-- the old 240x160 floor pushed panels over the Race button on short phones, e72e9fc).
}

-- Owner 2026-10-29 (docs/HUD_LAYOUT_SPEC.md section 6, replaces the 2026-10-28 stacking rule): the Items / Upgrade
-- pair NEVER stacks. At every viewport, phone_small_landscape and phone_landscape included, it stays beside the bars
-- (Items right edge = bars left - SlotGap, Upgrade left = bars right + SlotGap, icon centre on the gap between Level
-- and Turbo) and overlaps none of Clear; on desktop (height > 500) the pair is never shrunk (pair UIScale =
-- BottomScale exactly). (The 2026-10-28 Stacked rects at 667x375 and StackMaxHeight were removed with that rule.)
UiSpec.HudPair = {
	-- The slot holders (one CELL each, scaled by their UIScale "Scale"), not the buttons inside
	Items = "HudChrome/ItemsSlot",
	Upgrade = "HudChrome/UpgradeSlot",
	Level = "RacerHud/Level",
	Turbo = "RacerHud/Turbo",
	Money = "RacerHud/Money",
	Speed = "RacerHud/Speed",
	Clear = {
		"RacerHud/Speed",
		"RacerHud/Money",
		"RacerHud/Level",
		"RacerHud/Turbo",
		"HudChrome/Grid",
		"HudChrome/ShopColumn",
	},
	SlotGap = 10,
	BottomScale = 0.75,
	IconMid = 36 / 94,
	Tol = 2,
	-- Every UiSpec viewport except the live one (checked by the same rule in hudPairChecks)
	Beside = {
		"desktop_1080p",
		"laptop_768p",
		"hd_720p",
		"tablet_4x3",
		"phone_landscape",
		"phone_small_landscape",
	},
	Desktop = { "desktop_1080p", "laptop_768p", "hd_720p", "tablet_4x3" },
}

-- Owner 2026-10-29 (docs/HUD_LAYOUT_SPEC.md sections 6 and 9): on phones (viewport height <= PhoneMaxHeight) the
-- whole Speed readout (RacerHud/Speed: dial, SpeedValue and its rising +Speed MotionFloat) sits at the BOTTOM RIGHT,
-- the float rises above it there, and none of it overlaps the weather icon, the potion buttons or any HUD element
-- in Clear. Desktop and tablet keep it bottom centre (ui_layout speed_group_centred_<viewport>).
-- "Bottom right" (owner 2026-10-29, HUD_LAYOUT_SPEC section 9, placeholders): the Speed group's right edge within
-- MaxRightGap px of the screen's right edge and its bottom within MaxBottomGap px of the bottom; the test also keeps
-- it wholly in the right half and the bottom half. When the corner is crowded it may scale down, never below
-- MinScaleOfK x the phone k (its UIScale >= MinScaleOfK x UiResponsive.K(viewport); placeholder).
UiSpec.PhoneSpeed = {
	Group = "RacerHud/Speed",
	PhoneMaxHeight = 500,
	MaxRightGap = 24,
	MaxBottomGap = 130,
	MinScaleOfK = 0.5,
	Clear = {
		"RacerProgression/WeatherIcon",
		"RacerProgression/PotionStatus",
		"RacerHud/Money",
		"RacerHud/Level",
		"RacerHud/Turbo",
		"RacerHud/Race/Face",
		"HudChrome/ItemsSlot",
		"HudChrome/UpgradeSlot",
		"HudChrome/Grid",
		"HudChrome/ShopColumn",
		"HudChrome/TopRight",
		"RollToast/Toast",
		-- Bottom-right HUD labels (bug 102389fe: Speed covered the claim status): the Daily / Quest claim answer
		-- (Client/BoostDailyUi, 16 px in, 130 px up) and the workshop rate line (Client/ProgressionUi R4)
		"DailyBoosts/Status",
		"RacerProgression/WorkshopRate",
	},
	-- Besides Clear, every AlwaysOn element of every UiSpec.Guis entry (outside RacerHud/Speed) is checked too, so a
	-- new always-on HUD label can not slip under the readout unlisted.
	-- Each shown child of these is checked too (the potion buttons)
	ClearChildrenOf = { "RacerProgression/PotionStatus" },
	FloatSampleSeconds = 3, -- s the float is followed frame by frame (its whole rise, until it is destroyed)
}

-- CLAUDE.md: panels open BELOW the Race (Auto Race) button and end ABOVE the bottom TURBO LUCK bar. The progression
-- panels (Upgrades / Workshop / Welcome) keep their rule: below the Race button by this margin (and in the PanelBand,
-- Band.Gap below it; the compact roll hides under panels, owner 2026-10-28), and this far above the TURBO bar
-- (ui_progression_layout).
UiSpec.PanelTopMargin = 4

-- The four Racer panels (owner decision 2026-10-08; band since docs/HUD_LAYOUT_SPEC.md 2026-10-15 sections 1 and 6:
-- RacerUiController.fitPanels reads Client/PanelBand.Rect, the Shop / Market band): centred in the band, Gap px below
-- the Race Face's bottom, Gap px above the TURBO LUCK bar's top, inside the band (past the icon grid and the Shop
-- column, the wider margin on both sides, above Money when Money reaches into it), centred vertically in it, their
-- UIScale shrinking below the generated k only when the band is too small. ui_layout <panel>_centred_x /
-- _below_autorace / _above_turbo / _clear_of_nav / _inside_band / _band_centred_y check it at every viewport.
UiSpec.RacerPanelBand = {
	Panels = {
		["RacerIndex/Panel"] = "index_panel",
		["RacerStats/Panel"] = "stats_panel",
		["RacerSettings/Panel"] = "settings_panel",
		["RacerRebirth/Panel"] = "rebirth_panel",
	},
	Gap = 8,
	Navigation = "HudChrome/Grid",
}

-- Elements that are intentionally HIDDEN while a pop-up panel is open (for example,
-- the old daily/market controls): they are left out of the overlap lists in that
-- state, and ui_panels proves they really are hidden (Visible false) then.
-- When = "any": any PanelSwitch panel open; "other_than:<panel>": any panel but that one.
UiSpec.HiddenWhilePanelOpen = {
	["DailyBoosts/Status"] = "any",
	-- Owner 2026-10-28 (docs/HUD_LAYOUT_SPEC.md section 6): the compact roll hides under every panel
	["RollToast/Toast"] = "any",
}
-- ProgressionUi applies its visibility on a 0.25 s poll: the checks wait up to this long for it.
UiSpec.HiddenWhilePanelOpenWait = 1

-- Owner 2026-10-20 (docs/HUD_LAYOUT_SPEC.md section 6, replaces the per-HUD veils): a panel never dims the whole
-- screen. Client/HudChrome makes ONE ScreenGui `Gui` (DisplayOrder `DisplayOrder`, IgnoreGuiInset) holding the
-- non-interactive full-screen Frame `Dim`; the ScreenGui is Enabled only while PanelSwitch.AnyOpen(). It draws below
-- every ScreenGui in `Below` (strictly lower DisplayOrder), so the HUD stays fully bright and clickable. The old
-- veils in `Retired` must be gone. While a panel is open, no visible GuiObject in an enabled ScreenGui other than
-- `Gui` (and the declared `VeilExempt` full-screen overlays) may cover at least `Veil.MinCoverage` of the viewport
-- with BackgroundTransparency below `Veil.MaxTransparency` (that would be a full-screen dark frame over the HUD).
UiSpec.PanelDimmers = {
	Gui = "PanelDim",
	Frame = "PanelDim/Dim",
	DisplayOrder = 0,
	Below = { "HudChrome", "RacerHud", "RollToast", "RacerProgression" },
	Retired = {
		"HudChrome/PanelDimmer",
		"RacerHud/PanelDimmer",
		"RollToast/PanelDimmer",
		"RacerProgression/PanelDimmer",
	},
	VeilExempt = { RollShowcase = true, LoserScreen = true, RacerUpgrades = true },
	Veil = { MinCoverage = 0.9, MaxTransparency = 0.95 },
	PersistentButtons = {
		"HudChrome/Grid/Index",
		"HudChrome/Grid/Stats",
		"HudChrome/Grid/Rebirth",
		"HudChrome/ShopColumn/Shop",
		"HudChrome/ItemsSlot/Items",
		"HudChrome/UpgradeSlot/Upgrade",
		"HudChrome/TopRight/Daily",
		"HudChrome/TopRight/Quests",
		"HudChrome/TopRight/Market",
		"HudChrome/TopRight/Settings",
		"RacerHud/Race/Face",
		"RacerProgression/WeatherIcon",
	},
	DynamicPersistentRoots = { "RacerProgression/PotionStatus" },
	Transparency = { Min = 0.45, Max = 0.75 },
}

UiSpec.Motion = {
	Sound = "HudPressSound",
	SoundId = "rbxasset://sounds/volume_slider.ogg",
	PlaybackSpeed = 1.35,
	Volume = 0.22,
	Scale = "HoverScale",
	-- Owner 2026-10-27 (docs/HUD_LAYOUT_SPEC.md section 1, design doc "HUD art and hover"): hover is scale-only,
	-- "slight enlargement (1.035), never a white outlined button box". Every target carries HoverScale at rest 1;
	-- no target may carry the old hover outline (ForbiddenHighlight) or any UIStroke whose name contains "Hover".
	RestScale = 1,
	HoverScaleValue = 1.035,
	ForbiddenHighlight = "RacerHoverHighlight",
}

-- Owner 2026-10-26 (docs/UPGRADE_TREE_SPEC.md section 5, docs/HUD_LAYOUT_SPEC.md sections 1 and 6): like the roll
-- showcase, these panels are full-screen overlays. While one is open, everything in its ScreenGui may cover any
-- element of another ScreenGui (the HUD entries need not be drawn or clickable), and the panel band rules
-- (below roll / race, above turbo) do not apply. Overlaps INSIDE its ScreenGui (tile vs tile, tile vs chrome) and
-- every other panel's rules stay checked.
UiSpec.FullScreenPanels = { ["RacerUpgrades/Panel"] = true }

-- Overlaps that are allowed: a modal panel may cover a read-out (Speed, Money), never a button or the TURBO bar.
UiSpec.AllowOverlap = {}
for _, panel in { "RacerIndex/Panel", "RacerStats/Panel", "RacerSettings/Panel", "RacerRebirth/Panel" } do
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Money" })
end

-- A PanelSwitch panel (every entry of UiSpec.PanelSwitch.Names, incl. the progression panels) AND everything inside it
-- may overlap these read-outs (not interactive), but ONLY where the panel really draws over them (ui_layout verifies
-- it for every such overlap, panel and button alike): the panel's ScreenGui has a higher DisplayOrder than the
-- read-out's, and the overlap lies inside the panel's opaque, shown surface whose BackgroundTransparency is at most
-- MaxSurfaceTransparency, with no CanvasGroup fading it. The surface: from the PanelSwitch node, step into the first
-- child named in Surfaces while there is one (Racer panels: Panel/Face; Shop / Market: the transparent Backdrop ->
-- Panel; Daily: ModalBackdrop -> Modal), so a full-screen transparent Backdrop is never read as the surface.
-- A read-out drawn above a panel button is never allowed.
UiSpec.PanelCoversReadouts = {
	-- Money (and MoneyValue / Unbanked inside it) is a display-only read-out like Speed (2026-10-08, gate run 5).
	Readouts = { "RacerHud/Speed", "RacerHud/Money" },
	Surfaces = { "Panel", "Modal", "Face" },
	MaxSurfaceTransparency = 0.05,
}

-- The enlarged view (RollShowcase ScreenGui). Card parts are found by name anywhere in RollShowcase/Card.
UiSpec.Showcase = {
	Gui = "RollShowcase",
	Backdrop = "Backdrop", -- full-screen TextButton, no text, dark, BackgroundTransparency ~0.35
	BackdropTransparency = { Min = 0.2, Max = 0.5 },
	BackdropMaxLuminance = 0.3,
	Card = "Card", -- Frame, Active (a click on it does NOT close)
	-- ScreenGuis hidden while the view is open (CLAUDE.md "UI tests": the HUD hides while the roll showcase is open;
	-- hud_hidden_while_showcase_open: Enabled false, or nothing in it visible and drawing, no button shown)
	HiddenGuis = { "RacerHud" },
	Body = "Card/CardBody/Face", -- the animated card body (PopIn grows it, LAND_POP pops it)
	CardCentreScale = 0.46, -- RollShowcase.ui.json positions the card centre at 46% of the viewport height
	-- Every part the enlarged card must have (presence; Racer UI names)...
	CardParts = {
		"Glow",
		"Ring",
		"Burst",
		"Reel",
		"Streaks",
		"Smoke",
		"Viewport",
		"Placeholder",
		"Flare",
		"ResultName",
		"ResultSpeed",
		"ResultRarity",
		"ResultOdds",
		"NewBadge",
		"TurboBadge",
		"TurboFlames",
		"RollHeader",
	},
	-- ...and the content parts that must lie inside the card while shown (effects such as Burst may spill out)
	ContentParts = {
		"Viewport",
		"ResultName",
		"ResultSpeed",
		"ResultRarity",
		"ResultOdds",
		"NewBadge",
		"TurboBadge",
		"ScrapBadge",
	},
	-- %s = HudFormat.Multi(SpeedMulti) (docs/HUD_LAYOUT_SPEC.md section 8, owner 2026-10-27; was "x%s SPEED MULTIPLIER")
	SpeedText = "%s SPEED",
	-- The contract alias (Aliases.Speed, also named SpeedMulti): "Speed " .. HudFormat.Multi(SpeedMulti) (was "25x Speed")
	SpeedAliasText = "Speed %s",
	TurboBadgeText = "TURBO x%s", -- %s = the roll's turbo multi
	-- Duplicates are kept as copies and pay $0 (docs/WORKSHOP_SPEC.md "5b. Showcase", owner 2026-10-22): the card's
	-- ScrapBadge shows this on a duplicate roll (never a Money amount), and is hidden on a new car. RollResult's
	-- 5th argument (scrapMoney) must be 0.
	CopyBadge = "ScrapBadge",
	CopyBadgeText = "+1 COPY",
	GoldOdds = Color3.fromRGB(255, 200, 60), -- contract: Legendary and rarer show gold odds
	SecretMinLuminance = 0.5, -- Secret's colour is near-black: its Rarity / Odds text must still read (light)
	NameStrokeMaxLuminance = 0.3, -- ResultName: a DARK UIStroke outline
	CarNameStrokeMaxLuminance = 0.3, -- compatibility probe name for the same ResultName outline
	Blur = "RollShowcaseBlur", -- BlurEffect in Lighting: Enabled while open, disabled when closed
	CornerInset = 24, -- px: the backdrop click lands this far in from the bottom-right corner (clear of the card)
	Hint = "Hint", -- Backdrop/Hint
	HintText = "Tap anywhere to close",
	-- RollShowcase/AutoButton: bottom centre, AnchorPoint (0.5, 1), bottom edge BottomGap px above the screen bottom
	-- (Racer UI: 38, below the card on small phones; the HUD and its TURBO bar are hidden while the view is open),
	-- above the Hint, clear of the card, at least MinSize (tap-sized on a phone)
	AutoButton = { Path = "AutoButton", MinSize = Vector2.new(160, 44), BottomGap = 38 },
	Takeover = "Takeover", -- Secret only: full-screen frame in RollShowcase during its hold
}

-- The compact roll RollToast/Toast ("Compact = no card", owner decision 4): an invisible background, a transparent
-- Body filling it with ONLY the bare car art and its odds. Racer UI layout, top to bottom: the AUTO OFF caption band,
-- the car art (RollAnimConfig.COMPACT_HEIGHT tall), the odds band; Toast height = COMPACT_HEIGHT + ExtraHeight.
UiSpec.Compact = {
	Body = "Body",
	Parts = { "Body", "Reel", "Streaks", "Smoke", "Viewport", "Placeholder", "Odds" },
	Forbidden = { -- must not EXIST anywhere in RollToast/Toast (not just be hidden)
		"Glow",
		"CarName",
		"ResultName",
		"SpeedMulti",
		"ResultSpeed",
		"Rarity",
		"ResultRarity",
		"NewBadge",
		"TurboBadge",
		"TurboFlames",
		"Ring",
		"Burst",
		"Flare",
	},
	AutoOff = "AutoOff", -- caption part, shown only while AutoRoll is false
	ExtraHeight = 44, -- caption band (24) + odds band (20)
	ModelShare = 90 / 110, -- 24 px caption + 66 px art in the 110 px compact toast
	SplitTolerance = 0.02, -- proportional tolerance for Roblox's layout rounding
}

-- The roll animation (docs/ROLL_ANIMATION_CONTRACT.md). Numbers are read from Shared/RollAnimConfig; Fallback is the
-- contract's table, used only to keep computing the other checks while the module is missing
-- (roll_anim_config_present fails then).
UiSpec.RollAnim = {
	Module = "RollAnimConfig",
	Fallback = {
		POP = 0.15,
		SPIN = 0.8,
		LAND = 0.15,
		EXIT = 0.15,
		SWITCH = 0.3,
		HOLD = {
			Common = 0.3,
			Uncommon = 0.3,
			Rare = 0.4,
			Epic = 0.6,
			Legendary = 1.5,
			Mythic = 2.5,
			Secret = 4,
		},
		REEL_CARS = 6,
		LAND_POP = 1.15,
		COMPACT_WIDTH = 0.12,
		COMPACT_MIN = 100,
		COMPACT_MAX = 230,
		COMPACT_HEIGHT = 66,
		COMPACT_GAP = 8,
		ENLARGED_FACTOR = 3,
		ENLARGED_WIDTH = 0.6, -- the enlarged card no longer derives from the compact size
		-- ENLARGED_MAX (780x336) and PANEL_TOP are retired (owner decisions 2026-10-08): the enlarged card follows
		-- ui/specs/RollShowcase.ui.json with no cap, and the Racer panels are fitted in the Race..TURBO band.
	},
	Numbers = {
		"POP",
		"SPIN",
		"LAND",
		"EXIT",
		"SWITCH",
		"REEL_CARS",
		"LAND_POP",
		"COMPACT_WIDTH",
		"COMPACT_MIN",
		"COMPACT_MAX",
		"COMPACT_HEIGHT",
		"COMPACT_GAP",
		"ENLARGED_FACTOR",
		"ENLARGED_WIDTH",
	},
	Vectors = {},
	Functions = { "Hold", "Duration", "ExtraPause", "Reel" },
	Phases = { "PopIn", "Spin", "Land", "Hold", "Exit", "Idle" }, -- one roll, in this order
	PhaseTolerance = 0.1, -- s, per phase length (frame quantisation at both ends)
	PhaseStart = 0.2, -- s from the RollResult to PopIn (+ SWITCH for an emphasized roll)
	LandPopTolerance = 0.06, -- peak body width / nominal within LAND_POP +- this during Land
	SettledTolerance = 0.02, -- body width / nominal within 1 +- this during Hold (back to 1x)
	PopInStartMax = 0.25, -- the body grows from 0: its smallest width during PopIn <= this x nominal
	ExitShrinkMax = 0.5, -- the compact body shrinks on Exit: its smallest width during Exit <= this x nominal
	GlowTurnWait = 0.2, -- s between two Glow UIGradient.Rotation samples in Hold (it must have turned)
	GlowTurnMin = 0.5, -- degrees
	FlyIcon = "FlyIcon", -- a small car icon: no text, takes no clicks
	FlyTarget = "HudChrome/Grid/Index",
	FlyArrive = 24, -- px: the FlyIcon centre comes at least this close to the target's rectangle
	SwitchGrace = 0.2, -- s after SWITCH for the view to be back to Compact after an emphasized roll
	ViewAttr = "View", -- RollToast ScreenGui attribute: "Compact" | "Enlarged"
	AutoOffCaption = "AUTO OFF",
	AutoButtonText = { [true] = "AUTO: ON", [false] = "AUTO: OFF" },
}

-- Global announcement of an emphasized roll (Remotes.RollAnnounce -> Client/RollAnnounce -> RBXGeneral).
UiSpec.Announce = {
	Remote = "RollAnnounce",
	Channel = "RBXGeneral",
	Format = "%s rolled %s (%s)! Total rolls: %d", -- DisplayName, Car Name, odds, Rolls after the roll
}

-- Client scripts that build no ScreenGui but must exist (StarterPlayerScripts.Client).
UiSpec.ClientScripts = { "RollAnnounce" }

-- Remotes the UI fires or listens to (ReplicatedStorage.Remotes, RemoteEvents).
UiSpec.Remotes =
	{ "SetAutoRace", "SetAutoRoll", "EquipCar", "AllocateStat", "RollResult", "RollAnnounce", "NpcRace", "Duel" }

-- Created by Roblox, not the game: an explicit list of engine ScreenGui names (never a pattern or wildcard).
-- ProximityPrompts: the engine's default ProximityPrompt UI (the workshop E prompt), created on first prompt shown.
UiSpec.IgnoreGuis = {
	Freecam = true,
	BubbleChat = true,
	Chat = true,
	TouchGui = true,
	RbxCameraUI = true,
	ProximityPrompts = true,
}

UiSpec.Billboards = {
	WinText = {
		Tag = "WinPad",
		Label = "Amount",
		MaxDistance = "TrackBuilder.WIN_TEXT_DISTANCE",
		Text = "HudFormat.MoneyText(Cash)",
	},
	NpcLabel = { Label = "Text", MaxDistance = "NpcConfig.LABEL_DISTANCE", Text = "NpcConfig.For(track).Label" },
	-- Mechanical Workshop (docs/WORKSHOP_SPEC.md section 2): Workspace.Workshops.Plot_1..PLOT_COUNT
	WorkshopSign = {
		Path = "Base/Sign", -- BillboardGui, label "Text"
		EmptyText = "WorkshopConfig.EMPTY_TEXT", -- "EMPTY PLOT" when the plot's Owner attribute is 0
		OwnedText = "%s's Workshop", -- the owner's DisplayName
		MaxDistance = "WorkshopConfig.SIGN_DISTANCE", -- 120
	},
	-- Best Roll Ever pedestal (docs/LEADERBOARD_SPEC.md section 3a): Workspace.SpawnArea.BestRoll.Pedestal.Stats.
	-- Odds / Car / Player follow the RarestCar board (server); here only that they exist. Title is fixed.
	BestRollStats = {
		Path = "SpawnArea/BestRoll/Pedestal/Stats", -- under Workspace
		Adornee = "CarMount", -- Pedestal.CarMount
		Labels = { Title = "BEST ROLL EVER", Odds = true, Car = true, Player = true }, -- true = must exist, any text
		MaxDistance = "LeaderboardConfig.BEST_ROLL.TEXT_DISTANCE", -- 150
	},
	-- Gamepass car pedestals (docs/GAMEPASS_CARS_SPEC.md section 5): one per PassCarConfig.Pedestals entry,
	-- Workspace.SpawnArea.PassCars.Pass_<carId>.Pedestal.Stats; Title = the catalog car's Name, Tag = "GAMEPASS".
	PassCarStats = {
		Path = "SpawnArea/PassCars/Pass_<carId>/Pedestal/Stats",
		Labels = { Title = "CarCatalog.Get(carId).Name", Tag = "GAMEPASS" },
		MaxDistance = "PassCarConfig.TEXT_DISTANCE", -- 150
		-- Pedestal.Buy ProximityPrompt: ObjectText = car Name; ActionText by the car's GamepassId
		Prompt = { Name = "Buy", ActionTextNoPass = "Coming soon", ActionTextPass = "Unlock" },
	},
}

-- Seconds to wait for live events the checks need.
UiSpec.Waits = {
	GuiAppear = 15, -- each ScreenGui must exist in PlayerGui within this
	HudSettle = 2.5, -- HUD counters must reach the server value within this
	-- s: a panel's open motion (scale 0.92 -> 1 or a 12 px slide, 0.2 s) and its tile cascade (about 0.55 s) have
	-- settled; setPanels waits this after opening a panel unless motion is reduced (HUD spec section 10)
	PanelMotion = 0.65,
	HudLag = 0.5, -- s: a HUD counter may show any server value from this long ago up to now (count-up, HUD spec 9)
	HudFollow = 2, -- s: ui_hud re-samples a counter every frame for this long before it fails
	RollsStable = 15, -- allow the turbo meter to settle after the latest server roll
	RollToast = 12, -- a Remotes.RollResult must arrive within this (GachaConfig.ROLL_INTERVAL = 3 s)
	ToastShown = 0.3, -- the compact roll must be showing (Visible, drawn) this soon after a RollResult
	ToastGoneGrace = 0.3, -- and Visible = false this long after RollAnimConfig's roll length
	CardSettle = 4, -- a card must reach Phase Hold or Idle (1x, geometry measurable) within this
	AutoOffWatch = 1, -- with AutoRoll false, no RollResult for ROLL_INTERVAL + this
	EmphasizedRoll = 25, -- ui_roll_emphasized waits this long for an emphasized roll (ServerSetup emphasized_next)
	AnnounceWait = 3, -- the RollAnnounce event and its RBXGeneral message arrive this soon after the roll
	NpcStart = 20, -- an NPC must be on track (or start) within this while auto racing
	ClickDone = 60, -- click protocol: ui-tester must click within this
	ClickSettle = 1.5, -- after the click, the server answer must show within this (Race has a 1 s pending lock)
	MotionRest = 3, -- s ui_hud waits for a payout Pop (UiMotion MotionScale) to settle before measuring the Money plate
	LoseEvent = 30, -- ui_loser waits this long for a Result Lose (ServerSetup lose_event)
	LoserShowGrace = 0.2, -- the loser screen must be shown this soon after the Lose
	LoserHideGrace = 0.5, -- and hidden this soon after the next Reset / Start / Stop
	TurboRoll = 35, -- a turbo roll comes every TurboEvery (10) rolls x ROLL_INTERVAL (3 s) = 30 s at most
	TurboPopShow = 0.5, -- the TURBO label must show "TURBO x<multi>!" this soon after a turbo RollResult
	TurboPopHide = 2, -- and be back to "TURBO LUCK 0/<every>" (bar empty) this soon after it
	TurboStable = 6, -- ui_turbo waits at most this long for a moment HudSettle s after the last turbo change
	WorkshopPlot = 15, -- the player's plot (attribute Plot) and its Workshop must exist within this
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
		When = "before UiTestRun and before any click (it is the baseline: never listed in a click's NeedSetup), and "
			.. "again after every 'restore' before the next fixture or click",
		What = "Remembers the player's GachaService snapshot, AutoRacing and AutoRoll so 'restore' can put them back. "
			.. "A second 'snapshot' before 'restore' is a no-op (the first baseline is kept); 'restore' consumes it, so "
			.. "take a fresh 'snapshot' before each fixture that follows a restore.",
	},
	{
		Id = "spy",
		When = "before any click (UiSpec.Clicks)",
		What = "Creates ReplicatedStorage.UiTestSpy: one attribute per RemoteEvent, a JSON list of "
			.. "{ user = UserId, args = {...} } per OnServerEvent. The real handlers still run.",
	},
	{
		Id = "index_states",
		When = "before UiTestRun (ui_index needs a discovered, an undiscovered AND an equipped catalog tile)",
		What = "Owns every catalog car but the rarest (stays '???'), equips the first owned one, sets every "
			.. "Alloc_* to 0 so StatPoints = FreePoints >= 1.",
	},
	{
		Id = "stat_points",
		When = "before each allocate_* click that expects a fire",
		What = "Same allocation reset as index_states: StatPoints >= 1.",
	},
	{ Id = "no_stat_points", When = "before click allocate_no_points", What = "StatPoints == 0." },
	{
		Id = "auto_racing",
		When = "before UiTestRun and the showcase clicks (NPC on track, auto-rolls)",
		What = "Puts the player in auto race (AutoRacing == true).",
	},
	{
		Id = "on_foot",
		When = "before the ui_speed_dial fixture run (UiSpec.Progression.FixtureChecks) and first in the NeedSetup of "
			.. "every click whose After pins Money (progression_not_optimistic: a racing car's pad payouts would move "
			.. "it mid-check); needs 'snapshot' first",
		What = "Stops auto race (AutoRacing == false, avatar on foot at the walk spawn, no car). 'restore' puts "
			.. "AutoRacing back.",
	},
	{
		Id = "lose_event",
		When = "just before or during UiTestRun (ui_loser waits Waits.LoseEvent s for it)",
		What = "Fires NpcRace { Type = 'Result', Result = 'Lose' } to this client, then Reset/Start after "
			.. "NpcConfig.LOSE_SCREEN_SECONDS, like a real loss.",
	},
	{
		Id = "turbo_next",
		When = "before click showcase_card_click_stays_open; optional for UiTestRun ('[UITEST] WAIT turbo_roll')",
		What = "Makes the next auto roll a turbo roll. Turbo now follows the upgrade tree's TurboCount / TurboEvery "
			.. "(UpgradeService: turbo when TurboCount + 1 >= TurboEvery), so it must set TurboCount = TurboEvery - 1 "
			.. "(setting Rolls alone no longer does it). Without it the checks wait up to Waits.TurboRoll for a "
			.. "natural turbo roll. 'restore' puts it back.",
	},
	{
		Id = "emphasized_next",
		When = "during UiTestRun when the harness prints '[UITEST] WAIT emphasized_roll'; needs 'snapshot' first",
		What = "Takes every rollable car away until the next roll happened (emphasized, new), then gives exactly the "
			.. "cars owned before back.",
	},
	{
		Id = "auto_roll_on",
		When = "before UiTestRun if AutoRoll is false (a scenario fails with state_missing:auto_roll_on)",
		What = "Turns auto-rolling back on (AutoRoll = true).",
	},
	{
		Id = "restore",
		When = "after the run and the clicks",
		What = "Applies the 'snapshot', restores AutoRacing and AutoRoll and removes UiTestSpy. It CONSUMES the "
			.. "snapshot (deliberately: a kept baseline would survive into a later session and make its 'snapshot' a "
			.. "no-op, restoring stale money/cars). Any fixture after a restore needs a fresh 'snapshot' first, else "
			.. "it errors 'snapshot required'. Restore can stop auto race, and CarService then holds the avatar at the "
			.. "walk spawn for ~2 s: the world fixtures (workshop_*_prompt) re-place the avatar until "
			.. "it stays put and error if it does not.",
	},
}

-- Click coordinates: UiTestClickTarget.x/y and the "[UITEST] CLICK" line are in mcp user_mouse_input's space:
-- pixels from the top-left of the area BELOW the top bar (= AbsolutePosition of an inset-respecting ScreenGui).
-- user_mouse_input adds the top-bar inset itself. screenX/screenY (window pixels, top bar included) are given
-- for reference only. The harness then checks where the press REALLY landed (UserInputService.InputBegan
-- position, top bar added back; fallback GetMouseLocation) and that the target button was topmost there.
UiSpec.ClickSpace = "below_topbar"
-- Mouse clicks need an UNEMULATED game view. Under Studio device emulation (e.g. 750x361 phone) the emulated screen is
-- drawn scaled inside the Studio viewport, and user_mouse_input's coordinates are NOT mapped through that transform
-- (seen 2026-10-08: target (67,38) was pressed at (683,97)), so every click lands somewhere else. Protocol:
--  1. Geometry / state scenarios (UiTestRun, UiTestScenario) may run under emulation (phone checks need it).
--  2. Before the first UiTestClick ui-tester turns device emulation OFF (Studio Test tab > Device: none / "Actual
--     resolution"), waits two frames, and only then starts the clicks. Clicks are never run under emulation.
--  3. UiTestClickTarget carries viewportX / viewportY (Camera.ViewportSize the harness computed x, y in) and
--     insetY. ui-tester compares them with the Studio game view it is clicking in; on a mismatch it stops and reports
--     "click space mismatch", it does not click. The harness still verifies where the press really landed
--     (click_landed_on_button), so a wrong space can never pass as a click on the target.
UiSpec.ClickNeedsUnemulatedView = true
-- Phone-height clicks (Prepare.PhoneOnly, e.g. the compact phone Market): ui-tester resizes the REAL game view to a
-- height <= PhoneMaxHeight (UiSpec.LegacyControls.ResizeProtocol, no emulation), runs them, then restores the view.
UiSpec.PhoneMaxHeight = 500

--[[
Clicks ui-tester performs with mcp__Roblox_Studio__user_mouse_input (a LocalScript can not fire Activated).
Protocol, per click (run them in THIS order; several build on the previous one):
 1. ui-tester runs the click's NeedSetup ids through the UiTestSetup protocol (UiSpec.ServerSetup), sets ReplicatedStorage
    attributes UiTestClickDone = nil and UiTestClick = nil, then UiTestClick = Id (Server datamodel).
 2. the harness prepares (opens/closes Prepare panels, scrolls the target tile into view, waits for the target to be
    shown when Prepare.WaitShown), then publishes the LocalPlayer attribute
    UiTestClickTarget = JSON { id, x, y, screenX, screenY, done } (x, y in UiSpec.ClickSpace) and prints
    "[UITEST] CLICK <id> x=<x> y=<y> done=<done>".
 3. ui-tester clicks (x, y) once AT ONCE (the compact roll is only shown ~1.6 s), then sets ReplicatedStorage attribute
    UiTestClickDone = <done> (Server datamodel). <done> is the Id on the first attempt, "<Id>#<n>" on retry n.
    After the click ui-tester moves the mouse away from the UI (e.g. the screen centre-right) so no hover remains.
 4. Retries (only clicks with Retries): if the press landed while the target was not shown (the roll had faded) and
    nothing else took it, the harness prints "[UITEST] RETRY <id> x=<x> y=<y> done=<id>#<n>" and publishes a new
    UiTestClickTarget; ui-tester repeats step 3. A press that lands on ANOTHER clickable element is never retried.
    A click with RetryLostPress is also retried (same RETRY line) when its press landed on the target and no remote
    was logged within ClickSettle; it is never retried once anything fired.
 5. the harness waits ClickSettle, checks Expect and prints "[UITEST] {"scenario":"click:<id>",...}" and mirrors it
    into the LocalPlayer attribute UiTestClickResult. Then it restores the panels it touched (never the showcase:
    only real clicks open or close it).
Prepare:
 Open / Closed  declared panels forced visible / hidden before the click
 WaitShown      wait (Waits.RollToast) for the target to be shown by a real RollResult before publishing
 RequireShown   the target must already be shown (no roll is waited for), else state_missing:<previous click id>
 AttrIs         { [attribute] = value } the LocalPlayer must have before the click, else state_missing
 AttrNot        { [attribute] = value } the LocalPlayer must NOT have before the click, else state_missing
 Showcase       required showcase state before the click (true = open); never forced
 SoundProbe     the harness creates its own Sound (Volume UiSpec.Settings.ProbeVolume) before the click and
                destroys it after the checks
 TargetActive   the target's Active before the click (true / false), else state_missing: a disabled-button click is
                never sent to a button that turned out enabled, and the other way round
 Intercept      a RemoteFunction that must be intercepted (ServerSetup progression_spy) before the click is published,
                even when Expect.Remote is false: the click may never reach the real handler (Rebirth, DailyClaim,
                UseBoost change saved state)
 Intercept may also be a list of RemoteFunction names (each must be intercepted)
 LabelIs        the target's label text before the click (else state_missing: the previous click did not land)
 LabelHas       a piece the target's label text must contain before the click (else state_missing)
 TextIs         { [path] = text } labels that must show that text (case-insensitive) before the click, else
                state_missing (the earlier click that sets it up did not land)
 SetText        { [path] = text } TextBox / TextLabel texts the harness sets before the click (typing into a box);
                put back afterwards
 ScrollIntoView the harness scrolls the target's ScrollingFrame so the target is fully shown; put back afterwards
 WaitSeconds    extra wait before publishing
 KeepPanels     no panel is closed, reopened or restored: the click starts from the view the previous click left
                (Checkpoints Detail after a card click; a reopen shows the current checkpoint again)
 LeavePanels    panels prepared as usual but NOT restored after the click (the next click uses KeepPanels)
ClickAt: where to click when it is not the target's centre: "corner" (UiSpec.Showcase.CornerInset px in from the
 bottom-right corner, off the card) or a "<Gui>/<Path>" whose centre is used. The target must be topmost there.
 "empty": the target is a click-through panel (UiSpec.ClickThroughBackdrops); the harness picks the first point of a
 UiSpec.EmptyClickStep px grid (scanned row by row from the top-left, below the top bar, CornerInset in from every
 edge) that lies outside the panel's UiSpec.PanelBody and where NOTHING takes a click (no GuiButton, TextBox or
 Active object). Nothing may be topmost there before the click, and the press must land on nothing.
Key: instead of Gui/Path, a key press ("Escape"). The harness prints "[UITEST] KEY <id> key=<key> done=<done>" and
 publishes UiTestClickTarget = JSON { id, key, done }; ui-tester presses that key once in the game view (Roblox Studio
 MCP keyboard input; the Studio window must have focus), closes Roblox's own menu if the key opened it (the harness
 records GuiService.MenuIsOpen in the result's info), then sets UiTestClickDone = <done> as for a click.
Manual = "<reason>": a check ui-tester's tools can not perform (owner decision 2026-10-08). ui-tester does NOT run
 it and reports it as MANUAL (not a pass, not a failure; it never blocks the gate). The owner performs it by hand
 (steps in the dashboard's Needs-you list) with the same protocol; the harness still checks Expect when it is run.
Expect:
 Panels   = { [panelPath] = visibleAfter }  (every other declared panel must keep its visibility)
 Showcase = true/false: showcase open after the click (default: unchanged)
 Remote   = { Name, Arg } exactly one call of that remote and no other remote; Remote = false: no remote at all
            { Name, Args = { ... } }: the call's whole argument list, in order
 After    = post-conditions once the server / UI answered
]]
local CLOSED = {
	"RacerIndex/Panel",
	"RacerStats/Panel",
	"RacerSettings/Panel",
	"RacerRebirth/Panel",
	"RacerBackpack/Panel",
	"ShopUi/Backdrop",
	"MarketUi/Backdrop",
}
local function only(open)
	local closed = {}
	for _, p in CLOSED do
		if p ~= open then
			table.insert(closed, p)
		end
	end
	return { Open = { open }, Closed = closed, Showcase = false }
end
local CLOSE = "Panel/Face/Header/Face/Close/Face"
local ESCAPE_MANUAL =
	"VirtualInput::SendKey: Escape is permanently bound to a CoreGUI core action (MCP can not send it)"

UiSpec.Clicks = {
	{
		Id = "open_market",
		Gui = "HudChrome",
		Path = "TopRight/Market",
		Prepare = { Closed = CLOSED },
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false },
	},
	{
		-- Owner 2026-10-20: the Backdrop is no button; a click on empty screen (nothing Active there, outside the
		-- Panel) is unprocessed and PanelFrame.CloseOnOutsideClick closes the Market
		Id = "close_market_outside",
		Gui = "MarketUi",
		Path = "Backdrop",
		ClickAt = "empty",
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = false }, Remote = false },
	},
	{
		Id = "close_market",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Header/Close",
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = false }, Remote = false },
	},
	-- Tabs switch the grid (and nothing else: no remote, the panel stays open)
	{
		Id = "market_tab_aura",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Tabs/AuraTab",
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_grid_shows_aura" } },
	},
	{
		Id = "market_tab_trail",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Tabs/TrailTab",
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_grid_shows_trail" } },
	},
	{
		Id = "market_tab_potion",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Tabs/PotionTab",
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_grid_shows_potion" } },
	},
	-- A tile click selects: Detail shows THAT item; nothing is bought or equipped
	{
		Id = "market_select_tile",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Grid/Potion_SpeedII",
		Prepare = (function()
			local p = only("MarketUi/Backdrop")
			p.ScrollIntoView = true -- the harness then aims at the tile's visible (clip-cut) centre
			return p
		end)(),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_detail_shows_tile" } },
	},
	-- Runs right after market_select_tile at every game view (desktop: Detail beside the Grid; phone: the tile
	-- tap opened the Detail view), before the phone-only clicks below that go back to the Grid.
	-- BUY on the selected potion invokes MarketPurchase("Potion", "SpeedII") once; the real handler never runs
	-- (Intercept: ServerSetup progression_spy must proxy MarketPurchase and MarketEquip, else the click is refused).
	{
		Id = "market_action_buy",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Detail/Action",
		Prepare = {
			Open = { "MarketUi/Backdrop" },
			Closed = CLOSED,
			Showcase = false,
			Intercept = { "MarketPurchase", "MarketEquip" },
			LabelIs = "BUY",
			TextIs = { ["MarketUi/Backdrop/Panel/Detail/Name"] = marketName("Potion", "SpeedII") },
		},
		NeedSetup = { "spy", "progression_spy" },
		Expect = {
			Panels = { ["MarketUi/Backdrop"] = true },
			Remote = { Name = "MarketPurchase", Args = { "Potion", "SpeedII" } },
		},
	},
	-- Phone Market (owner 2026-10-28, HUD_LAYOUT_SPEC section 6): a tile tap swaps the Grid for the Detail view
	-- (nothing bought), and Back swaps back; run in this order at a phone-height game view (Prepare.PhoneOnly).
	{
		Id = "market_phone_tile_opens_detail",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Grid/Potion_SpeedII",
		Prepare = (function()
			local p = only("MarketUi/Backdrop")
			p.PhoneOnly = true
			p.LeavePanels = true
			return p
		end)(),
		Expect = {
			Panels = { ["MarketUi/Backdrop"] = true },
			Remote = false,
			After = { "market_phone_detail_view", "market_detail_shows_tile" },
		},
	},
	{
		Id = "market_phone_back",
		Gui = "MarketUi",
		Path = "Backdrop/Panel/Detail/Back",
		Prepare = { KeepPanels = true, Showcase = false, PhoneOnly = true, RequireShown = true },
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_phone_grid_view" } },
	},
	-- Shop and Market follow PanelSwitch: opening one from the HUD closes the panel that was open
	{
		Id = "open_market_while_stats_open",
		Gui = "HudChrome",
		Path = "TopRight/Market",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true, ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_shop",
		Gui = "HudChrome",
		Path = "ShopColumn/Shop",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["ShopUi/Backdrop"] = true }, Remote = false },
	},
	{
		-- Owner 2026-10-20: as close_market_outside, for the Shop
		Id = "close_shop_outside",
		Gui = "ShopUi",
		Path = "Backdrop",
		ClickAt = "empty",
		Prepare = only("ShopUi/Backdrop"),
		Expect = { Panels = { ["ShopUi/Backdrop"] = false }, Remote = false },
	},
	{
		Id = "close_shop",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Close",
		Prepare = only("ShopUi/Backdrop"),
		Expect = { Panels = { ["ShopUi/Backdrop"] = false }, Remote = false },
	},
	{
		Id = "open_shop_while_index_open",
		Gui = "HudChrome",
		Path = "ShopColumn/Shop",
		Prepare = only("RacerIndex/Panel"),
		Expect = { Panels = { ["ShopUi/Backdrop"] = true, ["RacerIndex/Panel"] = false }, Remote = false },
	},
	-- Id 0 price buttons ("Coming soon") do nothing: no remote, the Shop stays open (LabelHas refuses the click if
	-- the item got a real id, so no real purchase prompt is ever opened by the suite)
	{
		-- Needs a player who never owned the Ember Wyvern: GAMEPASS_CARS_SPEC section 3 (owner 2026-10-20) makes a
		-- Studio admin own every gamepass car, ownership is never revoked in a session (a fixture clearing Pass_<id>
		-- is not a game state) and the Shop builds once. Studio runs check the owned button instead
		-- (shop_featured_owned_equips); the gamepass and bundle "Coming soon" clicks below stay automatic.
		Id = "shop_featured_coming_soon",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Featured/**/ember_wyvern/Buy",
		Manual = "needs a non-admin player who does not own ember_wyvern (a Studio admin owns every gamepass car)",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.AttrNot = { Pass_ember_wyvern = true }
			p.LabelHas = "Coming soon"
			p.ScrollIntoView = true
			return p
		end)(),
		Expect = { Panels = { ["ShopUi/Backdrop"] = true }, Remote = false, After = { "shop_no_purchase_prompt" } },
	},
	{
		-- GAMEPASS_CARS_SPEC section 3 (owner 2026-10-20): an owned gamepass car's Featured button shows "Equip" and
		-- fires EquipCar with THAT car (the spy logs it; the real equip is put back by 'restore')
		Id = "shop_featured_owned_equips",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Featured/**/ember_wyvern/Buy",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.AttrIs = { Pass_ember_wyvern = true }
			p.AttrNot = { EquippedCar = "ember_wyvern" }
			p.LabelIs = "Equip"
			p.ScrollIntoView = true
			return p
		end)(),
		NeedSetup = { "spy" },
		Expect = {
			Panels = { ["ShopUi/Backdrop"] = true },
			Remote = { Name = "EquipCar", Args = { "ember_wyvern" } },
			After = { "shop_no_purchase_prompt" },
		},
	},
	{
		Id = "shop_gamepass_coming_soon",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Gamepasses/**/vip/Buy",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.LabelHas = "Coming soon"
			p.ScrollIntoView = true
			return p
		end)(),
		Expect = { Panels = { ["ShopUi/Backdrop"] = true }, Remote = false, After = { "shop_no_purchase_prompt" } },
	},
	{
		Id = "shop_bundle_coming_soon",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Potions/**/Bundle/**/Buy",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.LabelHas = "Coming soon"
			p.ScrollIntoView = true
			return p
		end)(),
		Expect = { Panels = { ["ShopUi/Backdrop"] = true }, Remote = false, After = { "shop_no_purchase_prompt" } },
	},
	-- Redeem sends the typed text to the real RedeemCode (a bad code: the server answers "Invalid code" and saves
	-- nothing) and Status shows the server's reply. SetText types the code and blanks Status before the click.
	-- shortcut: "grants nothing" is proven by the server's bad-code reply (BadCodeReplies), not by diffing boost counts.
	{
		Id = "shop_redeem_invalid_code",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Codes/**/Redeem",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.ScrollIntoView = true
			p.SetText = {
				["ShopUi/Backdrop/Panel/Items/Codes/**/Input"] = UiSpec.Shop.TestCode,
				["ShopUi/Backdrop/Panel/Items/Codes/**/Status"] = "",
			}
			return p
		end)(),
		-- progression_spy proxies RedeemCode (logs the call; a "UITEST-" code goes on to the real ShopService.Redeem)
		NeedSetup = { "spy", "progression_spy" },
		Expect = {
			Panels = { ["ShopUi/Backdrop"] = true },
			-- exactly one RedeemCode call carrying the typed text, and no other remote (SHOP_PURCHASES_SPEC 3)
			Remote = { Name = "RedeemCode", Args = { UiSpec.Shop.TestCode } },
			After = { "shop_redeem_status_from_server" },
		},
	},
	-- Panels: each opens with its HUD button, closes with a second click and with its X
	{
		Id = "open_index",
		Gui = "HudChrome",
		Path = "Grid/Index",
		Prepare = { Closed = CLOSED, Showcase = false },
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerIndex/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_index_closed",
		Gui = "HudChrome",
		Path = "Grid/Index",
		Prepare = only("RacerIndex/Panel"),
		Expect = { Panels = { ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "close_index",
		Gui = "RacerIndex",
		Path = CLOSE,
		Prepare = only("RacerIndex/Panel"),
		Expect = { Panels = { ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_stats",
		Gui = "HudChrome",
		Path = "Grid/Stats",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerStats/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_stats_closed",
		Gui = "HudChrome",
		Path = "Grid/Stats",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "close_stats",
		Gui = "RacerStats",
		Path = CLOSE,
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_settings",
		Gui = "HudChrome",
		Path = "TopRight/Settings",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerSettings/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_settings_closed",
		Gui = "HudChrome",
		Path = "TopRight/Settings",
		Prepare = only("RacerSettings/Panel"),
		Expect = { Panels = { ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "close_settings",
		Gui = "RacerSettings",
		Path = CLOSE,
		Prepare = only("RacerSettings/Panel"),
		Expect = { Panels = { ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "settings_open_profile",
		Gui = "RacerSettings",
		Path = "Panel/Face/Header/Face/CategoryTabs/ProfileTab",
		Prepare = only("RacerSettings/Panel"),
		Expect = {
			Panels = { ["RacerSettings/Panel"] = true },
			Remote = false,
			After = { "settings_profile_category" },
		},
	},
	{
		Id = "settings_show_controls",
		Gui = "RacerSettings",
		Path = "Panel/Face/Header/Face/CategoryTabs/SettingsTab",
		Prepare = only("RacerSettings/Panel"),
		Expect = {
			Panels = { ["RacerSettings/Panel"] = true },
			Remote = false,
			After = { "settings_controls_category" },
		},
	},
	{
		Id = "open_rebirth",
		Gui = "HudChrome",
		Path = "Grid/Rebirth",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerRebirth/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_rebirth_closed",
		Gui = "HudChrome",
		Path = "Grid/Rebirth",
		Prepare = only("RacerRebirth/Panel"),
		Expect = { Panels = { ["RacerRebirth/Panel"] = false }, Remote = false },
	},
	{
		Id = "close_rebirth",
		Gui = "RacerRebirth",
		Path = CLOSE,
		Prepare = only("RacerRebirth/Panel"),
		Expect = { Panels = { ["RacerRebirth/Panel"] = false }, Remote = false },
	},
	-- Mutually exclusive through the real buttons (the HUD button must be reachable while another panel is open)
	{
		Id = "open_stats_while_index_open",
		Gui = "HudChrome",
		Path = "Grid/Stats",
		Prepare = only("RacerIndex/Panel"),
		Expect = { Panels = { ["RacerStats/Panel"] = true, ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_index_while_stats_open",
		Gui = "HudChrome",
		Path = "Grid/Index",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerIndex/Panel"] = true, ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_settings_while_stats_open",
		Gui = "HudChrome",
		Path = "TopRight/Settings",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerSettings/Panel"] = true, ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_rebirth_while_settings_open",
		Gui = "HudChrome",
		Path = "Grid/Rebirth",
		Prepare = only("RacerSettings/Panel"),
		Expect = { Panels = { ["RacerRebirth/Panel"] = true, ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_index_while_rebirth_open",
		Gui = "HudChrome",
		Path = "Grid/Index",
		Prepare = only("RacerRebirth/Panel"),
		Expect = { Panels = { ["RacerIndex/Panel"] = true, ["RacerRebirth/Panel"] = false }, Remote = false },
	},
	-- Escape closes whichever panel is open (RacerUiController: InputBegan Escape -> PanelSwitch.Close for all four).
	-- A script can not send a key, and the Studio MCP can not send Escape either, so these are MANUAL (owner decision
	-- 2026-10-08): the owner presses Escape by hand with the Key protocol.
	{
		Id = "escape_closes_index",
		Key = "Escape",
		Manual = ESCAPE_MANUAL,
		Prepare = only("RacerIndex/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_stats",
		Key = "Escape",
		Manual = ESCAPE_MANUAL,
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_settings",
		Key = "Escape",
		Manual = ESCAPE_MANUAL,
		Prepare = only("RacerSettings/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_rebirth",
		Key = "Escape",
		Manual = ESCAPE_MANUAL,
		Prepare = only("RacerRebirth/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerRebirth/Panel"] = false }, Remote = false },
	},
	-- Race button: fires SetAutoRace(not AutoRacing); the label follows the server, not the click
	{
		Id = "auto_race_toggle",
		Gui = "RacerHud",
		Path = "Race/Face",
		Prepare = { Closed = CLOSED, Showcase = false },
		NeedSetup = { "spy" },
		Expect = {
			Remote = { Name = "SetAutoRace", Arg = "not_attr:AutoRacing" },
			After = { "autorace_label_follows_server", "autoracing_is_arg" },
		},
	},
	{
		Id = "auto_race_toggle_back",
		Gui = "RacerHud",
		Path = "Race/Face",
		Prepare = { Closed = CLOSED, Showcase = false, WaitSeconds = 1.5 }, -- past the 1 s pending lock
		NeedSetup = { "spy" },
		Expect = {
			Remote = { Name = "SetAutoRace", Arg = "not_attr:AutoRacing" },
			After = { "autorace_label_follows_server", "autoracing_is_arg" },
		},
	},
	-- Index: Equip fires EquipCar with THAT tile's id; the equipped tile fires nothing
	{
		Id = "equip_discovered_tile",
		Gui = "RacerIndex",
		Path = "Panel/Face/GridHost/Gallery/{discovered_unequipped}/Equip",
		Prepare = only("RacerIndex/Panel"),
		NeedSetup = { "spy", "index_states" },
		Expect = {
			Remote = { Name = "EquipCar", Arg = "tile_id" },
			After = { "equipped_is_tile", "tile_shows_equipped" },
		},
	},
	{
		Id = "equip_equipped_tile",
		Gui = "RacerIndex",
		Path = "Panel/Face/GridHost/Gallery/{equipped}/Equip",
		Prepare = only("RacerIndex/Panel"),
		NeedSetup = { "spy", "index_states" },
		Expect = { Remote = false, After = { "tile_shows_equipped" } },
	},
	-- Stats: "+" fires AllocateStat with THAT row's stat, including Workshop; no points fires nothing.
	{
		Id = "allocate_speed",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Speed/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc", "points_label_follows_server" },
		},
	},
	{
		Id = "allocate_money",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Money/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc", "points_label_follows_server" },
		},
	},
	{
		Id = "allocate_luck",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Luck/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc", "points_label_follows_server" },
		},
	},
	{
		Id = "allocate_workshop",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Workshop/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "stat_points" },
		Expect = {
			Remote = { Name = "AllocateStat", Arg = "row_stat" },
			After = { "alloc_incremented", "points_decremented", "row_shows_alloc", "points_label_follows_server" },
		},
	},
	{
		Id = "allocate_workshop_no_points",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Workshop/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "no_stat_points" },
		Expect = { Remote = false, After = { "alloc_unchanged", "points_unchanged", "row_shows_alloc" } },
	},
	{
		Id = "allocate_no_points",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Speed/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "no_stat_points" },
		Expect = { Remote = false, After = { "alloc_unchanged", "points_unchanged" } },
	},
	-- Settings: local preferences (no remote), each clicked twice so the session is left as it was
	{
		Id = "sound_off",
		Gui = "RacerSettings",
		Path = "Panel/Face/SoundRow/Face/SoundToggle/Face",
		Prepare = { Open = { "RacerSettings/Panel" }, Showcase = false, SoundProbe = true, LabelIs = "ON" },
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "sound_label_off", "sound_probe_muted" } },
	},
	{
		Id = "sound_on",
		Gui = "RacerSettings",
		Path = "Panel/Face/SoundRow/Face/SoundToggle/Face",
		Prepare = { Open = { "RacerSettings/Panel" }, Showcase = false, SoundProbe = true, LabelIs = "OFF" },
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "sound_label_on", "sound_probe_restored" } },
	},
	{
		Id = "effects_reduce_on",
		Gui = "RacerSettings",
		Path = "Panel/Face/EffectsRow/Face/EffectsToggle/Face",
		Prepare = { Open = { "RacerSettings/Panel" }, Showcase = false, AttrNot = { ReduceEffects = true } },
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "reduce_effects_flipped", "effects_label_follows_attr" } },
	},
	{
		Id = "effects_reduce_off",
		Gui = "RacerSettings",
		Path = "Panel/Face/EffectsRow/Face/EffectsToggle/Face",
		Prepare = { Open = { "RacerSettings/Panel" }, Showcase = false, AttrIs = { ReduceEffects = true } },
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "reduce_effects_flipped", "effects_label_follows_attr" } },
	},
	{
		Id = "top_down_on",
		Gui = "RacerSettings",
		Path = "Panel/Face/AutoRow/Face/AutoToggle/Face",
		Prepare = {
			Open = { "RacerSettings/Panel" },
			Showcase = false,
			AttrNot = { TopDownView = true },
			LabelIs = "OFF",
		},
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "top_down_flipped", "top_down_label_follows_attr" } },
	},
	{
		Id = "top_down_off",
		Gui = "RacerSettings",
		Path = "Panel/Face/AutoRow/Face/AutoToggle/Face",
		Prepare = {
			Open = { "RacerSettings/Panel" },
			Showcase = false,
			AttrIs = { TopDownView = true },
			LabelIs = "ON",
		},
		NeedSetup = { "spy" },
		Expect = { Remote = false, After = { "top_down_flipped", "top_down_label_follows_attr" } },
	},
	-- Compact roll -> enlarged view (docs/ROLL_ANIMATION_CONTRACT.md). Run these eleven in this order, with
	-- auto_racing active and AutoRoll on; 'restore' afterwards puts AutoRoll back too.
	{
		Id = "open_showcase_from_toast",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, WaitShown = true, AttrIs = { AutoRoll = true } },
		Retries = 4,
		NeedSetup = { "spy", "auto_racing" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = {
				"view_enlarged",
				"showcase_card_is_latest_roll",
				"showcase_blur_on",
				"showcase_layout",
				"hud_hidden_while_showcase_open",
				"weather_icon_hidden_while_showcase_open",
				"autobutton_label_follows_server",
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
			After = {
				"showcase_blur_on",
				"view_enlarged",
				"showcase_updates_live_turbo",
				"showcase_result_stays_after_exit",
				"toast_hidden_while_showcase_open",
			},
		},
	},
	-- Closes the view after rolls played on the open card (the turbo roll above). Ordered here, right after a click
	-- that leaves the showcase open, because Prepare.Showcase is never forced (it used to follow top_down_off with
	-- nothing opening the view, so it could only report state_missing).
	{
		Id = "showcase_backdrop_closes_after_rolls",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "corner",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Remote = false,
			After = { "showcase_blur_off", "view_compact", "normal_view_back", "weather_icon_shown_after_showcase" },
		},
	},
	{
		-- Reopen for the AUTO clicks below: the compact roll is the only entry point (AUTO is intentionally only
		-- reachable from RollShowcase/AutoButton after clicking the compact top-centre RollToast animation)
		Id = "open_showcase_from_toast_after_close",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, WaitShown = true, AttrIs = { AutoRoll = true } },
		Retries = 4,
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = {
				"view_enlarged",
				"showcase_card_is_latest_roll",
				"showcase_blur_on",
				"hud_hidden_while_showcase_open",
				"weather_icon_hidden_while_showcase_open",
			},
		},
	},
	{
		Id = "showcase_auto_off",
		Gui = "RollShowcase",
		Path = "AutoButton",
		Prepare = { Showcase = true, AttrIs = { AutoRoll = true } },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = { Name = "SetAutoRoll", Arg = "not_attr:AutoRoll" },
			After = {
				"autoroll_is_arg",
				"autobutton_label_follows_server",
				"view_enlarged",
				"showcase_blur_on",
				"no_rolls_while_auto_off",
			},
		},
	},
	{
		Id = "showcase_backdrop_closes",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "corner",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Remote = false,
			After = {
				"showcase_blur_off",
				"view_compact",
				"toast_shows_auto_off",
				"normal_view_back",
				"weather_icon_shown_after_showcase",
			},
		},
	},
	{
		-- With AUTO off the compact roll stays shown, so the enlarged view (and its AUTO button) is always reachable
		Id = "open_showcase_from_auto_off_toast",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, RequireShown = true, AttrIs = { AutoRoll = false } },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = { "view_enlarged", "showcase_blur_on", "toast_hidden_at_once", "autobutton_label_follows_server" },
		},
	},
	{
		Id = "showcase_auto_on",
		Gui = "RollShowcase",
		Path = "AutoButton",
		Prepare = { Showcase = true, AttrIs = { AutoRoll = false } },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = { Name = "SetAutoRoll", Arg = "not_attr:AutoRoll" },
			After = { "autoroll_is_arg", "autobutton_label_follows_server", "view_enlarged", "rolls_resume" },
		},
	},
	{
		-- The backdrop covers the INDEX button (the HUD is hidden): clicking there closes the view, opens nothing
		Id = "showcase_backdrop_over_index_button",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "HudChrome/Grid/Index",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Panels = { ["RacerIndex/Panel"] = false },
			Remote = false,
			After = { "showcase_blur_off", "view_compact", "normal_view_back", "weather_icon_shown_after_showcase" },
		},
	},
	{
		Id = "open_showcase_from_toast_again",
		Gui = "RollToast",
		Path = "Toast",
		Prepare = { Closed = CLOSED, Showcase = false, WaitShown = true, AttrIs = { AutoRoll = true } },
		Retries = 4,
		NeedSetup = { "spy" },
		Expect = {
			Showcase = true,
			Remote = false,
			After = { "view_enlarged", "showcase_card_is_latest_roll", "showcase_blur_on" },
		},
	},
	{
		Id = "showcase_backdrop_closes_again",
		Gui = "RollShowcase",
		Path = "Backdrop",
		ClickAt = "corner",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Remote = false,
			After = { "showcase_blur_off", "view_compact", "normal_view_back", "weather_icon_shown_after_showcase" },
		},
	},
}

-- Progression contract agreed with main, 2026-10-07. These are additions to the Racer UI gate.
UiSpec.Guis.RacerProgression = {
	Source = "Client/ProgressionUi",
	-- Upgrade moved to HudChrome. Weather and active potion controls remain
	-- persistent on this layer and are dimmed, never removed, over panels.
	AlwaysOn = { "WeatherIcon" },
	Buttons = {
		{
			Path = "WeatherIcon",
			Does = "local",
			Effect = "toggle:RacerProgression/WeatherIcon/Card",
			Label = "WeatherConfig.Events[WeatherEvent].Icon (the clear icon when no weather is active)",
		},
		{
			Path = "PotionStatus/*",
			Does = "local",
			Effect = "potion_detail",
			Count = "dynamic",
			ClickCoverage = "ui_motion_dynamic",
		},
	},
}
-- Weather icon (docs/WEATHER_EVENTS_SPEC.md "Weather icon", design doc "Weather events"; owner 2026-10-13). Checked by
-- ui_weather (every weather_* fixture), the weather_card_* clicks and the showcase clicks' weather_icon_* conditions.
UiSpec.Weather = {
	Banner = "RacerProgression/WeatherBanner", -- the old text banner: must not exist
	Icon = "RacerProgression/WeatherIcon", -- TextButton, Text = WeatherConfig.Events[id].Icon
	Card = "RacerProgression/WeatherIcon/Card", -- Frame, hidden by default; shown on hover, toggled by a click
	Labels = { "Title", "Stats", "Time" }, -- TextLabels directly under the Card
	IconSize = Vector2.new(44, 44),
	-- Bottom-right corner: the icon's right and bottom edges are on screen and at most this far from the screen's
	-- edges (the HUD's other corner controls sit 12 to 22 px in; the showcase's corner click uses 24)
	CornerMargin = 24,
	-- Phones (viewport height <= UiResponsive.PHONE_MAX_HEIGHT): keep the
	-- weather status clear of the HudChrome top-right pills.
	-- The bottom limit is unchanged. Gap is the spec's 8 px edge gap (the solver's model, UiResponsive.Progression).
	PhoneRight = 140,
	Gap = 8,
	MarketButton = "HudChrome/TopRight/Market",
	ClearId = "clear", -- shown for WeatherEvent "" as well
	ClearTitle = "CLEAR",
	-- Stats = WeatherConfig.Describe(id): every multiplier that is not 1, in this order, joined by Separator
	StatParts = {
		{ Key = "Luck", Text = "LUCK x" },
		{ Key = "Money", Text = "MONEY x" },
		{ Key = "NpcSpeed", Text = "NPC SPEED x" },
	},
	Separator = " • ",
	NoBonus = "NO BONUS",
	TimeText = "^(%d+)s left$", -- "" when no weather is active
	TimeTolerance = 1, -- s between the shown countdown and ceil(WeatherEndsAt - server time)
}
-- The hex upgrade tree (Client/ProgressionUi + Client/RollToast/Ui/UpgradeTreeView; chrome generated from
-- ui/specs/RacerUpgrades.ui.json into Client/Ui/RacerUpgrades). The chrome (TreeTitle, Close, ZoomTools, Details,
-- Balance) sits directly in the ScreenGui; the tree is Panel/Canvas (a clipping ScrollingFrame panned by drag and the
-- wheel) / TreeWorld (UIScale TreeZoom) holding the Start node and one TextButton per UpgradeTree tile, named by its
-- id. Every tile UpgradeTree.Tiles() defines (docs/UPGRADE_TREE_SPEC.md section 1, Walkspeed included) must be there.
UiSpec.Guis.RacerUpgrades = {
	Source = "Client/ProgressionUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Close/Face", Does = "close_panel", Panel = "RacerUpgrades/Panel", Text = "X" },
		{ Path = "ZoomTools/Exit/Face", Does = "close_panel", Panel = "RacerUpgrades/Panel", Text = "EXIT" },
		{ Path = "ZoomTools/ZoomIn/Face", Does = "local", Effect = "tree_zoom_in", Text = "+" },
		{ Path = "ZoomTools/ZoomOut/Face", Does = "local", Effect = "tree_zoom_out", Text = "-" },
		-- The tree's root node (START / UPGRADES): owned by everyone, a click fires nothing (click upgrade_start_inert).
		{ Path = "Panel/Canvas/TreeWorld/Start", Does = "local", Effect = "none" },
		{
			Path = "Panel/Canvas/TreeWorld/*",
			Does = "remote",
			Remote = "BuyUpgrade",
			Arg = "upgrade_id",
			Count = "upgrades",
		},
	},
}
UiSpec.Guis.RacerWorkshop = {
	Source = "Client/ProgressionUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Panel/Close", Does = "close_panel", Panel = "RacerWorkshop/Panel" },
		{ Path = "Panel/Buy", Does = "remote", Remote = "WorkshopUpgrade", Arg = "none" },
	},
}
UiSpec.Guis.RacerWelcome = {
	Source = "Client/ProgressionUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Panel/Close", Does = "close_panel", Panel = "RacerWelcome/Panel" },
		-- Client/WelcomeStyle: Claim closes the panel like Close (the credit is already in Speed).
		{ Path = "Panel/Claim", Does = "close_panel", Panel = "RacerWelcome/Panel" },
		-- docs/OFFLINE_DOUBLE_SPEC.md section 5: visible only while OfflineDoubleOpen; ProductId 0 = "COMING SOON",
		-- inactive, a click does nothing; ProductId > 0 = PromptProductPurchase (Roblox's prompt, no game remote).
		{ Path = "Panel/Double", Does = "local", Effect = "prompt_purchase_or_nothing" },
	},
}
-- Offline reward double (docs/OFFLINE_DOUBLE_SPEC.md, owner 2026-10-28). Judged by ui_offline_double
-- (Progression.FixtureChecks, setup offline_welcome) and the offline_double_click click.
UiSpec.OfflineDouble = {
	Panel = "RacerWelcome/Panel",
	Button = "RacerWelcome/Panel/Double",
	Price = "RacerWelcome/Panel/Double/Price",
	Earnings = "RacerWelcome/Panel/Earnings",
	ComingSoon = "COMING SOON", -- section 5, ProductId == 0
	PriceFormat = "%d ROBUX", -- section 5, ProductId > 0
	EarningsFormat = "+%s SPEED", -- section 5, HudFormat.SpeedText(OfflineSpeed + OfflineDoubled)
	-- The Double button never intersects these (the button row vs the Away line and the amount)
	NoOverlap = { "RacerWelcome/Panel/Claim", "RacerWelcome/Panel/Away", "RacerWelcome/Panel/Earnings" },
}
UiSpec.Progression = {
	-- Owner 2026-10-26 (UPGRADE_TREE_SPEC section 5): the click box is 100 x 106 (NODE_HEIGHT = STEP_Y), so
	-- neighbouring tiles' click areas never overlap.
	TileSize = Vector2.new(100, 106),
	AffordableColour = Color3.fromRGB(60, 255, 60), -- section 5: an affordable price is green
	Canvas = "RacerUpgrades/Panel/Canvas",
	TreeWorld = "RacerUpgrades/Panel/Canvas/TreeWorld",
	UpgradeEntry = "HudChrome/UpgradeSlot/Upgrade",
	UpgradeBadge = "HudChrome/UpgradeSlot/Upgrade/Badge",
	WorkshopRateStep = 0.05,
}
for _, name in { "Upgrades", "Workshop", "Welcome" } do
	local path = "Racer" .. name .. "/Panel"
	UiSpec.PanelSwitch.Names[path] = name
	table.insert(CLOSED, path)
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Money" })
end
table.insert(UiSpec.ClientScripts, "ProgressionUi")
-- RemoteFunctions the UI invokes. ServerSetup progression_spy replaces every one with a logging proxy that returns
-- false, "money" (the real handlers never run): Rebirth, UseBoost and DailyClaim would change saved state.
UiSpec.RemoteFunctions = {
	"BuyUpgrade",
	"WorkshopUpgrade",
	"Rebirth",
	"UseBoost",
	"DailyClaim",
	"QuestClaim",
	-- Market (Client/MarketUi Detail/Action) and Shop codes (Client/ShopUi Redeem)
	"MarketPurchase",
	"MarketEquip",
	"RedeemCode",
	-- Checkpoints (Client/CheckpointUi Detail/Start) and gifting (Client/GiftPicker Confirm): the checkpoint_* and
	-- gift_* clicks Intercept them, so progression_spy must proxy them too
	"SetCheckpoint",
	"PrepareGift",
}
table.insert(UiSpec.Remotes, "WorkshopOpen")
for _, item in
	{
		{
			Id = "progression_spy",
			What = "Intercepts BuyUpgrade and WorkshopUpgrade RFs, logs args, returns false, money; real handlers never run. Snapshot first; restore always.",
		},
		{
			Id = "progression_buyable",
			What = "Unsaved fixture: empty tree, Money 100000, BestTrack 0; refresh badge. Snapshot required.",
		},
		{ Id = "progression_no_money", What = "Same tree fixture, Money 0. Snapshot required." },
		{ Id = "workshop_open", What = "Fires WorkshopOpen only to the owner; no purchase." },
		{
			Id = "offline_welcome",
			What = "OfflineSeconds=3661, OfflineSpeed=1234; no credit added. Snapshot required.",
		},
		{
			Id = "offline_double_open",
			What = "OfflineSeconds=3661, OfflineSpeed=1234, OfflineDoubleOpen=true, OfflineDoubled=nil; no credit added, no receipt. Snapshot required.",
		},
	}
do
	item.When = "before the corresponding progression scenario/click; restore afterwards"
	table.insert(UiSpec.ServerSetup, item)
end
for _, name in { "Upgrades", "Workshop", "Welcome" } do
	local path = "Racer" .. name .. "/Panel"
	table.insert(UiSpec.Clicks, {
		Id = "close_" .. string.lower(name),
		Gui = "Racer" .. name,
		Path = name == "Upgrades" and "Close/Face" or "Panel/Close",
		Prepare = only(path),
		NeedSetup = { "spy" },
		Expect = { Panels = { [path] = false }, Remote = false },
	})
end
table.insert(UiSpec.Clicks, {
	Id = "claim_welcome",
	Gui = "RacerWelcome",
	Path = "Panel/Claim",
	Prepare = only("RacerWelcome/Panel"),
	NeedSetup = { "spy", "offline_welcome" },
	Expect = { Panels = { ["RacerWelcome/Panel"] = false }, Remote = false },
})
-- OFFLINE_DOUBLE_SPEC section 5. ProductId 0: nothing happens (panel and button stay, no game remote, no purchase
-- prompt; ui-tester also confirms on screen that no Roblox purchase prompt opened). ProductId > 0: the Roblox
-- product prompt opens (ui-tester closes it without buying).
table.insert(UiSpec.Clicks, {
	Id = "offline_double_click",
	Gui = "RacerWelcome",
	Path = "Panel/Double",
	Prepare = only("RacerWelcome/Panel"),
	NeedSetup = { "spy", "offline_double_open" },
	Expect = {
		Panels = { ["RacerWelcome/Panel"] = true },
		Remote = false,
		After = { "offline_double_click_result" },
	},
	Note = "ProductId 0: no purchase prompt may appear. ProductId > 0: the prompt for that product appears; cancel it.",
})
table.insert(UiSpec.Clicks, {
	Id = "exit_upgrades",
	Gui = "RacerUpgrades",
	Path = "ZoomTools/Exit/Face",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = false }, Remote = false },
})
-- + then - (run in this order, so the tree zoom ends where it started): the RacerUpgrades attribute TreeZoom
-- (UpgradeTreeView zoom()) rises after + and falls after -, the panel stays open, nothing is sent to the server.
for _, zoom in { "in", "out" } do
	table.insert(UiSpec.Clicks, {
		Id = "tree_zoom_" .. zoom,
		Gui = "RacerUpgrades",
		Path = zoom == "in" and "ZoomTools/ZoomIn/Face" or "ZoomTools/ZoomOut/Face",
		Prepare = only("RacerUpgrades/Panel"),
		NeedSetup = { "spy" },
		Expect = {
			Panels = { ["RacerUpgrades/Panel"] = true },
			Remote = false,
			After = { "tree_zoomed_" .. zoom },
		},
	})
end
table.insert(UiSpec.Clicks, {
	Id = "upgrade_start_inert",
	Gui = "RacerUpgrades",
	Path = "Panel/Canvas/TreeWorld/Start",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "on_foot", "spy", "progression_spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = true }, Remote = false, After = { "progression_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "open_upgrades",
	Gui = "HudChrome",
	Path = "UpgradeSlot/Upgrade",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = true }, Remote = false },
})
-- No toggle_upgrades_closed click: the tree is a full-screen overlay that need not leave the HUD tiles clickable
-- (docs/UPGRADE_TREE_SPEC.md section 5, HUD_LAYOUT_SPEC.md sections 1 and 6, owner 2026-10-26); it closes through
-- its own Close (close_upgrades) and EXIT (exit_upgrades) buttons.
-- The weather Card toggles on a click (tap): the first click shows it, the second hides it, even while the pointer
-- still rests on the icon (hover shows it again only on the next MouseEnter). Run the two in this order.
for _, open in { true, false } do
	table.insert(UiSpec.Clicks, {
		Id = open and "weather_card_open" or "weather_card_close",
		Gui = "RacerProgression",
		Path = "WeatherIcon",
		Prepare = { Closed = CLOSED, Showcase = false },
		NeedSetup = { "weather_rain", "spy" },
		Expect = { Remote = false, After = { open and "weather_card_shown" or "weather_card_hidden" } },
	})
end
table.insert(UiSpec.Clicks, {
	Id = "buy_upgrade",
	Gui = "RacerUpgrades",
	Path = "Panel/Canvas/TreeWorld/money_1",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "on_foot", "progression_buyable", "spy", "progression_spy" },
	Expect = { Remote = { Name = "BuyUpgrade", Arg = "upgrade_id" }, After = { "progression_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "upgrade_no_money",
	Gui = "RacerUpgrades",
	Path = "Panel/Canvas/TreeWorld/money_1",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "on_foot", "progression_no_money", "spy", "progression_spy" },
	Expect = { Remote = false, After = { "progression_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "buy_workshop",
	Gui = "RacerWorkshop",
	Path = "Panel/Buy",
	Prepare = only("RacerWorkshop/Panel"),
	NeedSetup = { "on_foot", "progression_buyable", "spy", "progression_spy" },
	Expect = {
		Remote = { Name = "WorkshopUpgrade", Arg = "none" },
		After = { "progression_not_optimistic", "workshop_rejection_shown" },
	},
})

-- Workshop Showcase (docs/WORKSHOP_SPEC.md "5b. Showcase", owner 2026-10-22). Client/ProgressionUi keeps Level,
-- Price, Rate, Result and Buy in the LEFT part of RacerWorkshop/Panel and adds the frame Panel/Showcase on the right:
--   Multi (TextLabel): contains MultiFormat of the player attribute ShowcaseMulti ("SHOWCASE x1.37 Speed gain");
--   Best3 (TextButton): invokes SetShowcase({ the min(3, owned) owned rollable ids with the highest
--     GachaConfig.SlotBonus(spec, copies) }), copies = attribute Copies on player.GachaData.<id> (missing = 0);
--   Slot1..Slot3 (Frame): Name (TextLabel: the car's name, or EmptyText) and Clear (TextButton, shown only while the
--     slot holds a car; invokes SetShowcase(the shown ids without that car));
--   List (ScrollingFrame): one row Car_<id> per owned rollable car (never the starter or gamepass cars), sorted by
--     slot bonus, highest first; each row has Name (TextLabel) and Show (TextButton: ShowText when not shown,
--     ShownText when shown; a click invokes SetShowcase with the id added / removed; Active false and fires nothing
--     when 3 cars are shown and this one is not one of them).
-- Shown ids: player attribute Showcase (ids joined by ","); slot i shows the i-th id. The labels follow the server's
-- attributes, never the click. ProgressionUi must look Remotes.SetShowcase up when clicked (as WorkshopUpgrade), so
-- the showcase_spy proxy sees the call. Checks: ui_workshop_showcase (UiProgression) and the showcase_* clicks.
UiSpec.WorkshopShowcase = {
	Panel = "RacerWorkshop/Panel",
	Root = "RacerWorkshop/Panel/Showcase",
	Slots = 3, -- GachaConfig.SHOWCASE_SLOTS
	EmptyText = "EMPTY",
	ShowText = "SHOW",
	ShownText = "SHOWN",
	-- ShowcaseMulti as HudFormat.Multi ("x1.37", trailing zeros dropped; docs/HUD_LAYOUT_SPEC.md section 8, owner
	-- 2026-10-27, was "x%.2f"), somewhere in the Multi text and not followed by another digit
	MultiFormat = "HudFormat.Multi", -- label "SHOWCASE  " .. HudFormat.Multi(ShowcaseMulti) .. " Speed gain"
	RowPrefix = "Car_",
	-- The old controls: in the left part of the panel (right edge <= LeftShare of its width; brief "~42%", bound
	-- 45%) and never on the Showcase frame. Close keeps its own place but may not touch any showcase control.
	LeftControls = { "Level", "Price", "Rate", "Result", "Buy" },
	LeftShare = 0.45,
	ShowcaseMinStart = 0.4, -- the Showcase frame starts at >= 40% of the panel width
	MultiTolerance = 0.005, -- ShowcaseMulti vs GachaConfig.ShowcaseMulti of the shown cars
	AnswerWait = 3, -- s: the server's Showcase attribute and the panel follow a click within this
	Remote = "SetShowcase", -- RemoteFunction(ids) -> ok, reason
}
table.insert(UiSpec.Remotes, "SetShowcase")
for _, button in
	{
		{ Path = "Panel/Showcase/Best3", Does = "remote", Remote = "SetShowcase", Arg = "showcase_best3" },
		{ Path = "Panel/Showcase/Slot1/Clear", Does = "remote", Remote = "SetShowcase", Arg = "showcase_clear:1" },
		-- Slot2 / Slot3 run the same handler as Slot1 (clicked); their state is checked by ui_workshop_showcase
		{
			Path = "Panel/Showcase/Slot2/Clear",
			Does = "remote",
			Remote = "SetShowcase",
			Arg = "showcase_clear:2",
			ClickCoverage = "ui_workshop_showcase",
		},
		{
			Path = "Panel/Showcase/Slot3/Clear",
			Does = "remote",
			Remote = "SetShowcase",
			Arg = "showcase_clear:3",
			ClickCoverage = "ui_workshop_showcase",
		},
		{
			Path = "Panel/Showcase/List/*/Show",
			Does = "remote",
			Remote = "SetShowcase",
			Arg = "showcase_show|showcase_hide",
			Count = "dynamic", -- one per owned rollable car (ui_workshop_showcase counts them)
		},
	}
do
	table.insert(UiSpec.Guis.RacerWorkshop.Buttons, button)
end
for _, item in
	{
		{
			Id = "showcase_owned",
			What = "Snapshot required (GachaService.Snapshot keeps Cars, Copies, Showcase). Unsaved: the player owns "
				.. "every car it owned plus the first 5 of CarCatalog.Rollable(); those 5 get Copies 0, 3, 7, 1, 12 in "
				.. "that order (slot bonuses differ, so BEST 3 is not just the rarest 3); Showcase '' and ShowcaseMulti "
				.. "1 set through GachaService (no SetShowcase cooldown left).",
		},
		{
			Id = "showcase_filled",
			What = "showcase_owned, then shows the 3 owned rollable cars with the LOWEST slot bonus (Showcase / "
				.. "ShowcaseMulti through GachaService); run ui_workshop_showcase (3 shown: other rows' Show disabled).",
		},
		{
			Id = "showcase_spy",
			What = "Needs spy. Renames Remotes.SetShowcase to UiTestOriginal_SetShowcase and adds a same-name "
				.. "RemoteFunction proxy (attribute UiTestSpied = true) that logs { user, args } into the UiTestSpy attribute "
				.. "SetShowcase, then returns "
				.. "GachaService.SetShowcase(player, ...) (the REAL validation and cooldown; it only changes state the "
				.. "snapshot restores). restore removes the proxy.",
		},
	}
do
	item.When = "before the showcase_* clicks / the ui_workshop_showcase fixture run; restore afterwards"
	table.insert(UiSpec.ServerSetup, item)
end
local function showcaseOpen(extra)
	local prep = only("RacerWorkshop/Panel")
	for key, value in extra do
		prep[key] = value
	end
	return prep
end
-- Run in this order (each starts from the state the one before left). WaitSeconds > GachaConfig.SHOWCASE_COOLDOWN.
for _, click in
	{
		{
			Id = "showcase_best3",
			Path = "Panel/Showcase/Best3",
			Prepare = showcaseOpen({ AttrIs = { Showcase = "" } }),
			NeedSetup = { "showcase_owned", "spy", "showcase_spy" },
			Expect = {
				Remote = { Name = "SetShowcase", Arg = "showcase_best3" },
				After = { "showcase_attr_follows", "showcase_ui_follows" },
			},
		},
		{
			Id = "showcase_clear_slot1",
			Path = "Panel/Showcase/Slot1/Clear",
			Prepare = showcaseOpen({ AttrNot = { Showcase = "" }, WaitSeconds = 1 }),
			NeedSetup = { "spy", "showcase_spy" },
			Expect = {
				Remote = { Name = "SetShowcase", Arg = "showcase_clear:1" },
				After = { "showcase_attr_follows", "showcase_ui_follows" },
			},
		},
		{
			-- {showcase_unshown}: the highest-bonus owned rollable car that is not shown (resolved by RunClick)
			Id = "showcase_show_row",
			Path = "Panel/Showcase/List/{showcase_unshown}/Show",
			Prepare = showcaseOpen({ ScrollIntoView = true, LabelIs = "SHOW", WaitSeconds = 1 }),
			-- The list re-renders its rows (a roll changes Copies): one press was lost on 2026-10-28 (fired nothing)
			Retries = 1,
			RetryLostPress = true,
			NeedSetup = { "spy", "showcase_spy" },
			Expect = {
				Remote = { Name = "SetShowcase", Arg = "showcase_show" },
				After = { "showcase_attr_follows", "showcase_ui_follows" },
			},
		},
		{
			-- 3 shown now (showcase_owned gives >= 5 cars): another car's Show is disabled and fires nothing
			Id = "showcase_show_full_disabled",
			Path = "Panel/Showcase/List/{showcase_unshown}/Show",
			Prepare = showcaseOpen({ ScrollIntoView = true, LabelIs = "SHOW", WaitSeconds = 1 }),
			NeedSetup = { "spy", "showcase_spy" },
			Expect = { Remote = false, After = { "showcase_unchanged", "showcase_ui_follows" } },
		},
		{
			-- {showcase_shown}: the first id of the Showcase attribute; its Show button (SHOWN) removes it
			Id = "showcase_unshow_row",
			Path = "Panel/Showcase/List/{showcase_shown}/Show",
			Prepare = showcaseOpen({ ScrollIntoView = true, LabelIs = "SHOWN", WaitSeconds = 1 }),
			-- The same re-rendering list as showcase_show_row (bug 8495ae70: one lost press, passed alone)
			Retries = 1,
			RetryLostPress = true,
			NeedSetup = { "spy", "showcase_spy" },
			Expect = {
				Remote = { Name = "SetShowcase", Arg = "showcase_hide" },
				After = { "showcase_attr_follows", "showcase_ui_follows" },
			},
		},
	}
do
	click.Gui = "RacerWorkshop"
	table.insert(UiSpec.Clicks, click)
end
for _, item in
	{
		{
			Id = "workshop_owner_prompt",
			What = "Moves the test avatar to its owned UpgradePad. E must open only RacerWorkshop.",
		},
		{
			Id = "workshop_foreign_prompt",
			What = "Requires second player's owned plot; moves test avatar to that UpgradePad. E must open no panel.",
		},
		{
			Id = "offline_zero",
			What = "OfflineSpeed=0, OfflineSeconds=0; ui_offline_zero must observe welcome hidden.",
		},
		{ Id = "weather_rain", What = "Replicates rain with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_night", What = "Replicates night with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_gold", What = "Replicates gold with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_aurora", What = "Replicates aurora with 180 seconds remaining; run ui_weather." },
		{
			Id = "weather_clear",
			What = "Replicates no event; run ui_weather: the icon stays, with the Clear icon and an empty Time.",
		},
		{
			Id = "weather_clear_event",
			What = "Replicates the weather id 'clear' with 180 seconds remaining; run ui_weather.",
		},
		-- Displayed odds (UiSpec.RollOdds): each plants two RollResults at the test client only (nothing is rolled,
		-- granted or paid) and turns AutoRoll off until 'restore'
		{
			Id = "roll_odds_luck2",
			What = "Plants a car with a Chance at luck 2; display remains base rarity; run ui_roll_odds.",
		},
		{ Id = "roll_odds_round", What = "Same car at luck 3; display remains base rarity; run ui_roll_odds." },
		{ Id = "roll_odds_clamp", What = "Same car at extreme luck; display remains base rarity; run ui_roll_odds." },
		{ Id = "roll_odds_luck1", What = "Same car at luck 1 (base odds); run ui_roll_odds." },
		{ Id = "roll_odds_no_luck", What = "Same car with NO 6th argument (base odds); run ui_roll_odds." },
		{ Id = "roll_odds_catchall", What = "The catch-all car (Chance nil) at luck 2 ('1 in ?'); run ui_roll_odds." },
		{
			Id = "weather_rain_roll",
			What = "weather_rain, then plants the Rain car (else a car with a Chance) at the luck the server gives this "
				.. "player during Rain (GachaService.Luck x WeatherConfig rain Luck); run ui_weather.",
		},
	}
do
	item.When = "after a FRESH snapshot (restore consumes it); run stated scenario with UiTestScenario attribute, "
		.. "then restore. The world fixtures only report done once the avatar stayed at the spot (prompt fixtures: "
		.. "within the prompt's MaxActivationDistance) for 1 s; otherwise UiTestSetupError is set."
	table.insert(UiSpec.ServerSetup, item)
end
for _, own in { true, false } do
	table.insert(UiSpec.Clicks, {
		Id = own and "workshop_owner_e" or "workshop_foreign_e",
		Key = "E",
		-- Foreign E needs a second real player's plot: MANUAL (owner decision 2026-10-08)
		Manual = (not own) and "needs a second real player who owns a plot (a solo Studio session has only one)" or nil,
		NeedSetup = { own and "workshop_owner_prompt" or "workshop_foreign_prompt" },
		Expect = { WorkshopOpen = own },
	})
end
-- Required additional fixture runs: UiTestScenario invokes exactly one existing check without the long roll suite.
--[[
Fixture run protocol (ui-tester), per FixtureChecks entry, in order:
  1. SERVER datamodel: run Setup through the UiTestSetup protocol above (UiTestSetup / UiTestSetupDone, check
     UiTestSetupError).
  2. SERVER datamodel: ReplicatedStorage:SetAttribute("UiTestScenario", nil), then "UiTestScenario" = Scenario
     (ReplicatedStorage attributes replicate server -> client; the client harness listens for the change).
  3. Read the result on the CLIENT, never on the server: the harness prints "[UITEST] {json}" for the scenario in the
     console (Output) and sets the LocalPlayer attribute "UiTestScenarioResult" = that JSON. Client attribute changes
     do NOT replicate, so Players.<name>:GetAttribute("UiTestScenarioResult") read on the SERVER datamodel is always
     nil/stale: read it with execute_luau in the CLIENT datamodel (Players.LocalPlayer), or read the console line.
     The same holds for every result attribute the client harness sets on LocalPlayer: "UiTestResult" (full run),
     "UiTestClickResult" and "UiTestClickTarget" (clicks).
  4. Before step 2 of the next fixture, clear the stale result on the client (or compare the JSON's "scenario" and wait
     for a new value) so a previous run's result is not taken for this one.
  5. Restore the setup (snapshot restore) after the scenario's result arrived.
]]
UiSpec.Progression.FixtureChecks = {
	-- The speedometer at rest: on foot the needle reads 0 (docs/HUD_LAYOUT_SPEC.md section 9). The main run is
	-- auto_racing, where ui_speed_dial judges the racing needle.
	{ Setup = "on_foot", Scenario = "ui_speed_dial" },
	-- The Speed float sums real gains too: judged on foot only (HUD_LAYOUT_SPEC section 10; main run is auto_racing)
	{ Setup = "on_foot", Scenario = "ui_speed_float" },
	-- World billboards and the workshop modal read parts near the hub: with StreamingEnabled they exist only while the
	-- avatar stands there (on_foot = at the walk spawn in the hub), not while the main run races the chain
	{ Setup = "on_foot", Scenario = "ui_billboards" },
	{ Setup = "on_foot", Scenario = "ui_workshop_modal" },
	{ Setup = "offline_welcome", Scenario = "ui_offline_welcome" },
	{ Setup = "offline_welcome", Scenario = "ui_offline_double" },
	{ Setup = "offline_zero", Scenario = "ui_offline_zero" },
	{ Setup = "weather_rain", Scenario = "ui_weather" },
	{ Setup = "weather_night", Scenario = "ui_weather" },
	{ Setup = "weather_gold", Scenario = "ui_weather" },
	{ Setup = "weather_aurora", Scenario = "ui_weather" },
	{ Setup = "weather_clear", Scenario = "ui_weather" },
	{ Setup = "weather_clear_event", Scenario = "ui_weather" },
	{ Setup = "weather_rain_roll", Scenario = "ui_weather" },
	{ Setup = "roll_odds_luck2", Scenario = "ui_roll_odds" },
	{ Setup = "roll_odds_round", Scenario = "ui_roll_odds" },
	{ Setup = "roll_odds_clamp", Scenario = "ui_roll_odds" },
	{ Setup = "roll_odds_luck1", Scenario = "ui_roll_odds" },
	{ Setup = "roll_odds_no_luck", Scenario = "ui_roll_odds" },
	{ Setup = "roll_odds_catchall", Scenario = "ui_roll_odds" },
	{ Setup = "showcase_filled", Scenario = "ui_workshop_showcase" },
}

--[[
Displayed odds (docs/WEATHER_EVENTS_SPEC.md "Displayed odds"; docs/ROLL_ANIMATION_CONTRACT.md). RollResult's 6th
argument is the roll's server luck for compatibility, but both Odds labels (RollToast/Toast `Odds`; RollShowcase/Card
`ResultOdds` and its alias `Odds`) show the catalog rarity with `HudFormat.Odds(Chance)`. A catch-all car (Chance nil)
keeps "1 in ?". The Index and the roll announcement keep the base odds.

Each fixture sets the player attribute Attr = JSON { fixture, id, luck (absent when not sent), nonce }, waits for a
roll that may still be playing, then fires RollResult(id, false, 1, false, 0, luck) (compact) and, one animation
later, RollResult(id, false, 1, true, 0, luck) (emphasized: plays on the enlarged card). 'restore' clears Attr.
]]
UiSpec.RollOdds = {
	Attr = "UiTestRollOdds",
	Wait = 30, -- s for both planted rolls to land (the fixture first waits out the longest roll animation)
	-- The luck each fixture must send. Luck = that number; ChanceTimes = the car's Chance x it; NoLuck = no 6th
	-- argument; Event = at least that WeatherConfig event's Luck. CatchAll = the car has no Chance.
	Fixtures = {
		roll_odds_luck2 = { Luck = 2 },
		roll_odds_round = { Luck = 3 },
		roll_odds_clamp = { ChanceTimes = 4 },
		roll_odds_luck1 = { Luck = 1 },
		roll_odds_no_luck = { NoLuck = true },
		roll_odds_catchall = { Luck = 2, CatchAll = true },
		weather_rain_roll = { Event = "rain" },
	},
}

---------------------------------------------------------------------------------------------------------------
-- Rebirth clicks (gap closed 2026-10-13). progression_spy intercepts the Rebirth RemoteFunction, so no click here can
-- really rebirth; Prepare.Intercept refuses to publish the click otherwise.
for _, item in
	{
		{
			Id = "rebirth_eligible",
			What = "Player attribute Level = RebirthConfig.Requirements(RebirthLevel).Level (the RebirthButton turns "
				.. "enabled). Snapshot required; restore puts Level back.",
		},
		{
			Id = "rebirth_not_eligible",
			What = "Player attribute Level = that requirement - 1 (the RebirthButton is disabled). Snapshot required.",
		},
	}
do
	item.When =
		"before the rebirth_* click of the same name, after 'snapshot', 'spy' and 'progression_spy'; restore after"
	table.insert(UiSpec.ServerSetup, item)
end
local function rebirthPrepare(active)
	local prep = only("RacerRebirth/Panel")
	prep.Intercept = "Rebirth"
	prep.TargetActive = active
	return prep
end
table.insert(UiSpec.Clicks, {
	Id = "rebirth_disabled_fires_nothing",
	Gui = "RacerRebirth",
	Path = "Panel/Face/RebirthButton/Face",
	Prepare = rebirthPrepare(false),
	NeedSetup = { "rebirth_not_eligible", "spy", "progression_spy" },
	Expect = { Remote = false, After = { "rebirth_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "rebirth_asks_server",
	Gui = "RacerRebirth",
	Path = "Panel/Face/RebirthButton/Face",
	Prepare = rebirthPrepare(true),
	NeedSetup = { "rebirth_eligible", "spy", "progression_spy" },
	Expect = { Remote = { Name = "Rebirth", Arg = "none" }, After = { "rebirth_not_optimistic" } },
})

---------------------------------------------------------------------------------------------------------------
-- Daily rewards and quests share one PanelSwitch panel. Their persistent entry
-- buttons live in HudChrome; this ScreenGui owns only the panel and status.
UiSpec.Guis.DailyBoosts = {
	Source = "Client/BoostDailyUi",
	AlwaysOn = { "Status" },
	Readouts = { "Status" },
	NonInteractiveParts = { "Status" },
	Panels = { "ModalBackdrop" },
	Buttons = {
		{
			Path = "ModalBackdrop/Modal/Close",
			Does = "close_panel",
			Panel = "DailyBoosts/ModalBackdrop",
			Text = "×",
		},
		{
			Path = "ModalBackdrop/Modal/QuestTabs/Daily",
			Does = "local",
			Effect = "daily_quest_category",
			Text = "DAILY",
		},
		{
			Path = "ModalBackdrop/Modal/QuestTabs/Weekly",
			Does = "local",
			Effect = "weekly_quest_category",
			Text = "WEEKLY",
		},
		{
			Path = "ModalBackdrop/Modal/Content/*",
			Does = "local",
			Effect = "select_quest",
			Count = "dynamic",
		},
		{
			Path = "ModalBackdrop/Modal/Content/*/Claim",
			Does = "remote",
			Remote = "QuestClaim",
			Arg = "quest_id",
			Count = "dynamic",
			DisabledWhen = "incomplete_or_claimed",
		},
		{
			Path = "ModalBackdrop/Modal/Content/Claim",
			Does = "remote",
			Remote = "DailyClaim",
			Arg = "none",
			Count = "dynamic", -- Daily view only: exactly one (daily_shows_server_streak)
			DisabledWhen = "claimed_today",
		},
	},
}
-- Panels whose toggled Frame is a see-through, click-through dimmer: the overlap / top-control checks use this child
-- (the drawn, opaque panel) instead of the full-screen dimmer.
UiSpec.PanelBody = {
	["DailyBoosts/ModalBackdrop"] = "Modal",
	["MarketUi/Backdrop"] = "Panel",
	["ShopUi/Backdrop"] = "Panel",
}
table.insert(UiSpec.AllowOverlap, { "DailyBoosts/ModalBackdrop", "RacerHud/Speed" })
table.insert(UiSpec.AllowOverlap, { "DailyBoosts/ModalBackdrop", "RacerHud/Money" })
-- Full-screen dimmers of the Shop, Market and Daily panels (owner 2026-10-20, docs/HUD_LAYOUT_SPEC.md section 6 and
-- docs/GAMEPASS_SHOP_SPEC.md): never a GuiButton, Active = false, so the HUD tiles behind stay clickable
-- (button_topmost_at_centre_shop_open / market_open / daily_boosts_open) and only their PanelBody takes clicks.
UiSpec.ClickThroughBackdrops = { "ShopUi/Backdrop", "MarketUi/Backdrop", "DailyBoosts/ModalBackdrop" }
UiSpec.EmptyClickStep = 40 -- px grid for ClickAt = "empty"
UiSpec.DailyBoosts = {
	Daily = "HudChrome/TopRight/Daily",
	Quests = "HudChrome/TopRight/Quests",
	Status = "DailyBoosts/Status",
	Panel = "DailyBoosts/ModalBackdrop",
	Title = "DailyBoosts/ModalBackdrop/Modal/Title",
	Close = "DailyBoosts/ModalBackdrop/Modal/Close",
	Content = "DailyBoosts/ModalBackdrop/Modal/Content",
	QuestTabs = "DailyBoosts/ModalBackdrop/Modal/QuestTabs",
	QuestDetail = "DailyBoosts/ModalBackdrop/Modal/QuestDetail",
	DailyTitle = "DAILY REWARDS",
	QuestTitle = "QUESTS",
	DailyText = { [false] = "Daily", [true] = "%d:%02d:%02d" },
	TimerTolerance = 2, -- s between the shown timer and 86400 - os.time() % 86400
	DayRow = "Day%d", -- one reward card per DailyLoginConfig.Rewards entry with descendant text "DAY <n>"
	DayText = "DAY %d",
	DoneMark = "✓",
	ClaimText = { [false] = "CLAIM DAY %d", [true] = "CLAIMED TODAY" }, -- [claimed today]; %d = min(streak + 1, 7)
	PhoneMaxHeight = 500,
	FixtureBoost = "LuckI", -- retained for the shared click snapshot helper; Backpack owns potion presentation
}
table.insert(CLOSED, "DailyBoosts/ModalBackdrop")
for _, item in
	{
		{ Id = "daily_unclaimed", What = "DailyLast = -1: today's reward can be claimed (the modal may auto-open)." },
		{ Id = "daily_claimed", What = "DailyLast = today's UTC day: CLAIMED TODAY, the button counts down." },
	}
do
	item.When = "before the daily_* click that names it, after 'snapshot'; restore puts the attributes back"
	table.insert(UiSpec.ServerSetup, item)
end
local DAILY = "DailyBoosts/ModalBackdrop"
table.insert(UiSpec.Clicks, {
	Id = "open_backpack",
	Gui = "HudChrome",
	Path = "ItemsSlot/Items",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerBackpack/Panel"] = true }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "close_backpack",
	Gui = "RacerBackpack",
	Path = "Panel/Header/Close",
	Prepare = only("RacerBackpack/Panel"),
	Expect = { Panels = { ["RacerBackpack/Panel"] = false }, Remote = false },
})
-- Cars last: the Backpack keeps the Cars view for the backpack_equip_car* clicks below.
for _, tab in { "Misc", "Trails", "Auras", "Cars" } do
	table.insert(UiSpec.Clicks, {
		Id = "backpack_" .. string.lower(tab),
		Gui = "RacerBackpack",
		Path = "Panel/Tabs/" .. tab .. "Tab",
		Prepare = only("RacerBackpack/Panel"),
		Expect = {
			Panels = { ["RacerBackpack/Panel"] = true },
			Remote = false,
			After = tab == "Cars" and { "backpack_cars_grid" } or nil,
		},
	})
end
-- Backpack Cars tiles (owner 2026-10-20): a non-equipped tile fires EquipCar with THAT tile's car id and the
-- server's EquippedCar follows; the equipped tile fires nothing. Both start from the Cars view (click backpack_cars).
table.insert(UiSpec.Clicks, {
	Id = "backpack_equip_car",
	Gui = "RacerBackpack",
	Path = "Panel/Items/{discovered_unequipped}",
	Prepare = {
		Open = { "RacerBackpack/Panel" },
		Closed = only("RacerBackpack/Panel").Closed,
		Showcase = false,
		ScrollIntoView = true,
	},
	NeedSetup = { "spy", "index_states" },
	Expect = {
		Remote = { Name = "EquipCar", Arg = "tile_id" },
		After = { "equipped_is_tile", "backpack_tile_shows_equipped", "backpack_cars_grid" },
	},
})
table.insert(UiSpec.Clicks, {
	Id = "backpack_equipped_car",
	Gui = "RacerBackpack",
	Path = "Panel/Items/{equipped}",
	Prepare = {
		Open = { "RacerBackpack/Panel" },
		Closed = only("RacerBackpack/Panel").Closed,
		Showcase = false,
		ScrollIntoView = true,
	},
	NeedSetup = { "spy", "index_states" },
	Expect = { Remote = false, After = { "backpack_tile_shows_equipped", "backpack_cars_grid" } },
})
table.insert(UiSpec.Clicks, {
	Id = "close_daily_modal",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Close",
	Prepare = { Open = { DAILY }, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { [DAILY] = false }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "open_daily",
	Gui = "HudChrome",
	Path = "TopRight/Daily",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "daily_unclaimed", "spy", "progression_spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false, After = { "daily_rewards_view" } },
})
table.insert(UiSpec.Clicks, {
	Id = "daily_claim",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/Claim",
	Prepare = { Open = { DAILY }, Showcase = false, Intercept = "DailyClaim", TargetActive = true },
	NeedSetup = { "daily_unclaimed", "spy", "progression_spy" },
	Expect = {
		Remote = { Name = "DailyClaim", Arg = "none" },
		After = { "daily_not_optimistic", "daily_rewards_view" },
	},
})
table.insert(UiSpec.Clicks, {
	Id = "open_daily_claimed",
	Gui = "HudChrome",
	Path = "TopRight/Daily",
	-- Starts closed (the Daily pill toggles: pressing it with Daily open closes it), then the click opens it
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "daily_claimed", "spy", "progression_spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false, After = { "daily_rewards_view" } },
})
table.insert(UiSpec.Clicks, {
	Id = "daily_claim_claimed_fires_nothing",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/Claim",
	Prepare = { Open = { DAILY }, Showcase = false, Intercept = "DailyClaim", TargetActive = false },
	NeedSetup = { "daily_claimed", "spy", "progression_spy" },
	Expect = { Remote = false, After = { "daily_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "open_quests",
	Gui = "HudChrome",
	Path = "TopRight/Quests",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false, After = { "quests_daily_view" } },
})
for _, category in { "Weekly", "Daily" } do
	table.insert(UiSpec.Clicks, {
		Id = "quests_" .. string.lower(category) .. "_tab",
		Gui = "DailyBoosts",
		Path = "ModalBackdrop/Modal/QuestTabs/" .. category,
		Prepare = { Open = { DAILY }, Showcase = false },
		NeedSetup = { "spy" },
		Expect = {
			Panels = { [DAILY] = true },
			Remote = false,
			After = { "quests_" .. string.lower(category) .. "_view" },
		},
	})
end
table.insert(UiSpec.Clicks, {
	Id = "select_daily_quest",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/daily_races",
	Prepare = { Open = { DAILY }, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false, After = { "quest_detail_selected" } },
})
-- docs/QUESTS_SPEC.md: the server decides progress and claims. quest_incomplete / quest_complete set today's
-- daily_races quest (UiSpec.ServerSetup); Intercept keeps the real claim (a potion reward) from ever running.
for _, item in
	{
		{ Id = "quest_incomplete", What = "Today's daily_races quest unclaimed at progress 0: its Claim is disabled." },
		{ Id = "quest_complete", What = "Today's daily_races quest unclaimed at its Target: its Claim is enabled." },
	}
do
	item.When = "before the quest_claim_* click that names it, after 'snapshot'; restore applies the quest snapshot"
	table.insert(UiSpec.ServerSetup, item)
end
table.insert(UiSpec.Clicks, {
	Id = "quest_claim_disabled_fires_nothing",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/daily_races/Claim",
	Prepare = { Open = { DAILY }, Showcase = false, Intercept = "QuestClaim", TargetActive = false },
	NeedSetup = { "quest_incomplete", "spy", "progression_spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false },
})
-- A completable quest's Claim asks the server for THAT quest: QuestClaim(weekly = false, "daily_races"), once
table.insert(UiSpec.Clicks, {
	Id = "quest_claim_asks_server",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/daily_races/Claim",
	Prepare = { Open = { DAILY }, Showcase = false, Intercept = "QuestClaim", TargetActive = true },
	NeedSetup = { "quest_complete", "spy", "progression_spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = { Name = "QuestClaim", Args = { false, "daily_races" } } },
})

---------------------------------------------------------------------------------------------------------------
-- Duels (docs/DUEL_SPEC.md section 3, Client/DuelUi; written 2026-10-13 BEFORE the UI exists: red until it is built).
-- ScreenGui DuelUi (IgnoreGuiInset): PickPanel (Title, Opponent, Tracks/Track<n>, Close), InvitePanel (Title, Text,
-- Accept, Decline), Countdown and Toast (TextLabels, never Active). The server drives it with ONE table argument on
-- Remotes.Duel.OnClientEvent; the buttons answer with Remotes.Duel:FireServer("Pick", n) / ("Respond", boolean).
UiSpec.Guis.DuelUi = {
	Source = "Client/DuelUi",
	AlwaysOn = { "Toast" }, -- its place is kept free of every always-on element even while it is hidden
	Readouts = { "Toast" },
	NonInteractiveParts = { "Countdown", "Toast" },
	Panels = { "PickPanel", "InvitePanel" },
	Buttons = {
		{ Path = "PickPanel/Close", Does = "close_panel", Panel = "DuelUi/PickPanel", Text = "X" },
		{
			Path = "PickPanel/Tracks/*",
			Does = "remote",
			Remote = "Duel",
			Args = "Pick, <that button's track number>",
			Count = "duel_tracks",
			Label = "TRACK <n>",
		},
		{ Path = "InvitePanel/Accept", Does = "remote", Remote = "Duel", Args = "Respond, true", Text = "ACCEPT" },
		{ Path = "InvitePanel/Decline", Does = "remote", Remote = "Duel", Args = "Respond, false", Text = "DECLINE" },
	},
}
UiSpec.Duel = {
	Gui = "DuelUi",
	Remote = "Duel",
	Pick = "DuelUi/PickPanel",
	Invite = "DuelUi/InvitePanel",
	Countdown = "DuelUi/Countdown",
	Toast = "DuelUi/Toast",
	PickTitle = "PICK A TRACK",
	OpponentText = "vs %s",
	TrackName = "Track%d", -- DuelUi/PickPanel/Tracks/<TrackName>
	TrackText = "TRACK %d",
	CloseText = "X",
	InviteTitle = "DUEL REQUEST",
	InviteText = "%s challenges you on Track %d",
	AcceptText = "ACCEPT",
	DeclineText = "DECLINE",
	GoText = "GO!", -- from ServerStart (workspace:GetServerTimeNow()); before it the whole seconds left: 3, 2, 1
	GoSeconds = 1, -- the Countdown hides about this long after GO!
	ResultText = { Win = "YOU WIN!", Lose = "YOU LOSE", Draw = "DRAW" },
	CancelText = {
		Declined = "DUEL DECLINED",
		InviteTimeout = "NO ANSWER",
		PickTimeout = "DUEL CANCELLED",
		Left = "OPPONENT LEFT",
		NotOnFoot = "PLAYER IS RACING",
		Busy = "PLAYER IS BUSY",
		Cooldown = "WAIT A MOMENT",
		NotLoaded = "PLAYER NOT READY",
	},
	CancelDefault = "DUEL CANCELLED", -- any other Reason
	ToastSeconds = 3, -- the Toast hides this long after a Result / Cancelled
	ShowGrace = 0.3, -- s after a message for the UI to show its state
	Grace = 0.75, -- s around the "about 1 s" / "3 s" hide times
	BoundaryGuard = 0.25, -- s around each whole second of the countdown where either text is accepted
	-- The panels ui_layout places like the other panels: centred horizontally, top at least UiSpec.PanelTopMargin
	-- below the Race button, bottom at least that far above the TURBO LUCK bar (the rule the progression panels
	-- already have; no new number). <prefix>_centred_x / _below_autorace / _above_turbo at every viewport.
	Panels = { ["DuelUi/PickPanel"] = "duel_pick_panel", ["DuelUi/InvitePanel"] = "duel_invite_panel" },
	-- The server fixtures' message content (UiTestSetup duel_*)
	Fixture = { Opponent = "UiTestRival", Tracks = { 1, 2, 3 }, Track = 2, SecondTracks = { 2 } },
	PrepAttr = "UiTestDuelPrep", -- player attribute "<PanelSwitch name>:<nonce>": the harness opens that panel first
	ProbeField = "UiTestPanelProbe", -- extra message field (ignored by the game): the harness opens that panel
	ProbeAt = 1, -- s after the message
}
for path, name in { ["DuelUi/PickPanel"] = "DuelPick", ["DuelUi/InvitePanel"] = "DuelInvite" } do
	UiSpec.PanelSwitch.Names[path] = name
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Money" })
end
table.insert(CLOSED, "DuelUi/PickPanel")
table.insert(CLOSED, "DuelUi/InvitePanel")
UiSpec.HiddenWhilePanelOpen["DuelUi/Toast"] = "any" -- contract: the result toast hides when a panel opens
table.insert(UiSpec.ClientScripts, "DuelUi")
do
	local what = {
		duel_pick = "PickTrack { Opponent, Tracks = Fixture.Tracks }.",
		duel_pick_replaced = "PickTrack with Fixture.Tracks, then PickTrack with Fixture.SecondTracks (old buttons go).",
		duel_pick_over_index = "Asks the harness to open the Index panel (PrepAttr), then PickTrack.",
		duel_invite = "Invite { Opponent, Track = Fixture.Track }.",
		duel_invite_over_stats = "Asks the harness to open the Stats panel (PrepAttr), then Invite.",
		duel_invite_over_pick = "PickTrack, then Invite: the two duel panels are never open together.",
		duel_countdown = "Invite, then Countdown { Track, ServerStart = now + DuelConfig.COUNTDOWN }.",
		duel_result_win = "PickTrack, then Result Win.",
		duel_result_lose = "PickTrack, then Result Lose.",
		duel_result_draw = "PickTrack, then Result Draw.",
		duel_toast_panel = "Result Win with ProbeField = 'Index': the harness opens Index while the toast shows.",
		duel_cancel_unknown = "Invite, then Cancelled with a Reason the UI does not know.",
	}
	for reason in UiSpec.Duel.CancelText do
		what["duel_cancel_" .. string.lower(reason)] = "Invite, then Cancelled { Reason = '" .. reason .. "' }."
	end
	local ids = {}
	for id in what do
		table.insert(ids, id)
	end
	table.sort(ids)
	-- Fixture run protocol as UiSpec.Progression.FixtureChecks: Setup, then UiTestScenario = Scenario, read the result
	-- on the client. No snapshot needed (the fixtures only fire Remotes.Duel at the test client). ui_duel judges the
	-- LATEST duel message the client received, from samples its recorder took by itself, so a slow trigger is fine;
	-- wait for the result (up to 12 s: the countdown and the 3 s toast are watched to their end).
	UiSpec.Duel.FixtureChecks = {}
	for _, id in ids do
		table.insert(UiSpec.ServerSetup, {
			Id = id,
			When = "then run ui_duel with UiTestScenario (UiSpec.Duel.FixtureChecks)",
			What = "Fires Remotes.Duel at the test client only (0.6 s between messages): " .. what[id],
		})
		table.insert(UiSpec.Duel.FixtureChecks, { Setup = id, Scenario = "ui_duel" })
	end
	-- With the real Track buttons present (a script can not create them), the generic geometry rules again
	table.insert(UiSpec.Duel.FixtureChecks, { Setup = "duel_pick", Scenario = "ui_inventory" })
	table.insert(UiSpec.Duel.FixtureChecks, { Setup = "duel_pick", Scenario = "ui_layout" })
	table.insert(UiSpec.Duel.FixtureChecks, { Setup = "duel_pick", Scenario = "ui_hitboxes" })
end
local function duelClick(click)
	if not click.Key then
		click.Gui = click.Gui or "DuelUi"
	end
	click.Prepare = click.Prepare or { Showcase = false, RequireShown = true } -- the fixture opened it, never forced
	table.insert(UiSpec.Clicks, click)
end
duelClick({
	Id = "duel_pick_track",
	Path = "PickPanel/Tracks/Track2",
	NeedSetup = { "spy", "duel_pick" },
	Expect = { Panels = { ["DuelUi/PickPanel"] = false }, Remote = { Name = "Duel", Args = { "Pick", 2 } } },
})
duelClick({
	Id = "duel_pick_close",
	Path = "PickPanel/Close",
	NeedSetup = { "spy", "duel_pick" },
	Expect = { Panels = { ["DuelUi/PickPanel"] = false }, Remote = false },
})
duelClick({
	Id = "duel_accept",
	Path = "InvitePanel/Accept",
	NeedSetup = { "spy", "duel_invite" },
	Expect = { Panels = { ["DuelUi/InvitePanel"] = false }, Remote = { Name = "Duel", Args = { "Respond", true } } },
})
duelClick({
	Id = "duel_decline",
	Path = "InvitePanel/Decline",
	NeedSetup = { "spy", "duel_invite" },
	Expect = { Panels = { ["DuelUi/InvitePanel"] = false }, Remote = { Name = "Duel", Args = { "Respond", false } } },
})
-- Mutually exclusive through the real buttons: a HUD panel button stays reachable over a duel panel and closes it
duelClick({
	Id = "open_index_while_duel_pick_open",
	Gui = "HudChrome",
	Path = "Grid/Index",
	Prepare = only("DuelUi/PickPanel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerIndex/Panel"] = true, ["DuelUi/PickPanel"] = false }, Remote = false },
})
duelClick({
	Id = "open_settings_while_duel_invite_open",
	Gui = "HudChrome",
	Path = "TopRight/Settings",
	Prepare = only("DuelUi/InvitePanel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerSettings/Panel"] = true, ["DuelUi/InvitePanel"] = false }, Remote = false },
})
for _, panel in { "PickPanel", "InvitePanel" } do
	duelClick({
		Id = "escape_closes_duel_" .. string.lower((string.gsub(panel, "Panel", ""))),
		Key = "Escape",
		Manual = ESCAPE_MANUAL,
		Prepare = only("DuelUi/" .. panel),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["DuelUi/" .. panel] = false }, Remote = false },
	})
end
-- Owner-approved 2026-10-20 contracts. Existing limits and click contracts above stay intact.
-- Backpack (docs/HUD_LAYOUT_SPEC.md section 3, owner 2026-10-20) and car icons (docs/CAR_EXPANSION_SPEC.md "Car icons
-- and model detail"). Checked by ui_backpack_cars and ui_car_icons (UiContracts) and the backpack_* clicks.
-- ui_backpack_cars measures the live engine rects and tags its geometry checks with the live variant (_desktop, or
-- _phone at ViewportSize.Y <= PhoneMaxHeight): ui-tester runs it at a desktop size AND at phone landscape
-- (UiSpec.LegacyControls.ResizeProtocol sizes); both sets of check names must appear and pass.
UiSpec.Backpack = {
	Panel = "RacerBackpack/Panel",
	Tabs = "RacerBackpack/Panel/Tabs",
	Items = "RacerBackpack/Panel/Items",
	Empty = "RacerBackpack/Panel/Empty",
	TabOrder = { "Misc", "Trails", "Auras", "Cars" }, -- top to bottom; button <Name>Tab, label text <Name>
	CarsTab = "RacerBackpack/Panel/Tabs/CarsTab",
	-- Least rare first (the spec's list, not read from GachaConfig), then catalog Order.
	RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" },
	PhoneMaxHeight = 500,
	MaxDecimals = 6, -- digits after the point in a tile's "x<SpeedMulti>" (no float noise)
	ModelWait = 5, -- s for a tile's ViewportFrame to receive its Car model (CarModels replicate late)
	-- Tile border (the tile's UIStroke): green on the equipped car, never green on the others.
	Green = function(c)
		return c.G > c.R + 0.25 and c.G > c.B + 0.25
	end,
	IndexGallery = "RacerIndex/Panel/Face/GridHost/Gallery",
}

UiSpec.Expansion = {
	Module = "CarExpansionManifest",
	Count = 100,
	Rarities = { Uncommon = 18, Rare = 24, Epic = 22, Legendary = 17, Mythic = 11, Secret = 8 },
	Families = { "city_utility", "offroad_rally", "track_hyper", "futuristic_hover", "fantasy_novelty" },
	PerFamily = 20,
	Fields = { "Id", "Name", "Rarity", "Chance", "SpeedMulti", "Order", "Model" },
}

UiSpec.Guis.CheckpointUi = {
	Source = "Client/CheckpointUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Panel/Header/Close", Does = "close_panel", Panel = "CheckpointUi/Panel", Text = "X" },
		-- CHECKPOINT_SPEC section 4 (owner 2026-10-27): a card click (locked ones too) only shows its track in Detail
		{ Path = "Panel/Cards/*", Does = "local", Count = "tracks" },
		-- Detail/Start: "START HERE" (open, not current) calls SetCheckpoint(the shown track); "SELECTED" / "LOCKED"
		-- are disabled (Active false) and fire nothing
		{
			Path = "Panel/Detail/Start",
			Does = "remote",
			Remote = "SetCheckpoint",
			Arg = "detail_track",
			DisabledWhen = "locked_or_selected",
		},
	},
}
UiSpec.Checkpoints = {
	Panel = "CheckpointUi/Panel",
	Cards = "CheckpointUi/Panel/Cards",
	LockTransparency = 0.4,
	Prompt = "OpenCheckpoints",
	PanelTheme = "Checkpoints", -- PanelFrame.Attach theme (owner 2026-10-20)
	-- Detail pane (CHECKPOINT_SPEC section 4, owner 2026-10-27): Preview (ViewportFrame), Title "TRACK n · NAME",
	-- Biome (upper case), RecSpeed, YourSpeed, Status, Cash, Start (TextButton)
	Detail = "CheckpointUi/Panel/Detail",
	RecPrefix = "REC. SPEED ", -- .. HudFormat.SpeedText(RaceConfig.StatFor(NpcConfig.For(n).Speed))
	YourPrefix = "YOUR SPEED ", -- .. HudFormat.SpeedText(leaderstats.Speed)
	-- CHECKPOINT_SPEC section 4 "the payout": labelled like REC. SPEED / YOUR SPEED (Client/CheckpointUi)
	CashPrefix = "PAYOUT ", -- .. HudFormat.MoneyText(TrackBuilder.CashFor(n))
	Ready = "READY",
	NeedFormat = "NEED %s MORE", -- %s = HudFormat.SpeedText(rec - speed)
	StartOpen = "START HERE",
	StartSelected = "SELECTED",
	StartLocked = "LOCKED",
}
table.insert(CLOSED, UiSpec.Checkpoints.Panel)
for _, fixture in
	{
		{ Id = "checkpoint_locked", What = "Unsaved Checkpoint=1, BestTrack=0; Track 2 locked. Pause racing/rolls." },
		{ Id = "checkpoint_open", What = "Unsaved Checkpoint=1, BestTrack=2; Track 2 selectable. Pause racing/rolls." },
	}
do
	fixture.When = "After snapshot; restore all attributes afterwards. Owned by server fixture writer."
	table.insert(UiSpec.ServerSetup, fixture)
end
local CHECKPOINT_TRACK2 = (function()
	local chain =
		require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("TrackRegistry")).Chain()
	return chain[2] and ("TRACK 2 · " .. string.upper(chain[2].Name)) or "TRACK 2"
end)()
-- Checkpoint clicks (CHECKPOINT_SPEC section 4), run in this order: a card click shows its track in Detail and never
-- calls SetCheckpoint; Detail/Start does the pick. LeavePanels / KeepPanels keep the Detail pane a card click set up
-- for the Start click right after it (a reopen would show the current checkpoint again).
for _, case in
	{
		-- Selected card: shows Track 1, Start "SELECTED"
		{
			Id = "checkpoint_selected_no_remote",
			Path = "Panel/Cards/Track_1",
			Best = 0,
			Setup = "checkpoint_locked",
			After = { "checkpoint_detail_shows_card", "checkpoint_not_optimistic" },
		},
		-- Locked card: clickable, shows Track 2 with Start "LOCKED"
		{
			Id = "checkpoint_locked_no_remote",
			Path = "Panel/Cards/Track_2",
			Best = 0,
			Setup = "checkpoint_locked",
			Leave = true,
			After = { "checkpoint_detail_shows_card" },
		},
		{
			Id = "checkpoint_start_locked_no_remote",
			Path = "Panel/Detail/Start",
			Best = 0,
			Setup = "checkpoint_locked",
			Keep = true,
			Label = "LOCKED",
			Active = false,
			After = { "checkpoint_not_optimistic" },
		},
		-- Freshly opened: Detail shows the current checkpoint (Track 1), Start "SELECTED"
		{
			Id = "checkpoint_start_selected_no_remote",
			Path = "Panel/Detail/Start",
			Best = 0,
			Setup = "checkpoint_locked",
			Label = "SELECTED",
			Active = false,
			After = { "checkpoint_not_optimistic" },
		},
		-- Open card: shows Track 2, Start "START HERE"
		{
			Id = "checkpoint_card_shows_detail",
			Path = "Panel/Cards/Track_2",
			Best = 2,
			Setup = "checkpoint_open",
			Leave = true,
			After = { "checkpoint_detail_shows_card" },
		},
		{
			Id = "checkpoint_select_track",
			Path = "Panel/Detail/Start",
			Best = 2,
			Setup = "checkpoint_open",
			Keep = true,
			Label = "START HERE",
			Active = true,
			Remote = { Name = "SetCheckpoint", Args = { 2 } },
			After = { "checkpoint_not_optimistic" },
		},
	}
do
	local prepare = {
		Open = not case.Keep and { UiSpec.Checkpoints.Panel } or nil,
		KeepPanels = case.Keep,
		LeavePanels = case.Leave,
		Showcase = false,
		AttrIs = { Checkpoint = 1, BestTrack = case.Best },
		Intercept = "SetCheckpoint", -- refuse the click unless the server logging proxy is installed
		ScrollIntoView = not case.Keep and string.find(case.Path, "Cards", 1, true) ~= nil or nil,
		LabelIs = case.Label,
		TargetActive = case.Active,
		TextIs = case.Keep and { [UiSpec.Checkpoints.Detail .. "/Title"] = CHECKPOINT_TRACK2 } or nil,
	}
	table.insert(UiSpec.Clicks, {
		Id = case.Id,
		Gui = "CheckpointUi",
		Path = case.Path,
		Prepare = prepare,
		NeedSetup = { case.Setup, "spy", "progression_spy" },
		Expect = {
			Panels = { [UiSpec.Checkpoints.Panel] = true },
			Remote = case.Remote or false,
			After = case.After,
		},
	})
end
table.insert(UiSpec.Clicks, {
	Id = "checkpoint_close",
	Gui = "CheckpointUi",
	Path = "Panel/Header/Close",
	Prepare = only(UiSpec.Checkpoints.Panel),
	NeedSetup = { "spy" },
	Expect = { Panels = { [UiSpec.Checkpoints.Panel] = false }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "checkpoint_switch_to_index",
	Gui = "HudChrome",
	Path = "Grid/Index",
	Prepare = only(UiSpec.Checkpoints.Panel),
	NeedSetup = { "spy" },
	Expect = { Panels = { [UiSpec.Checkpoints.Panel] = false, ["RacerIndex/Panel"] = true }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "checkpoint_escape",
	Key = "Escape",
	Manual = ESCAPE_MANUAL,
	Prepare = only(UiSpec.Checkpoints.Panel),
	NeedSetup = { "spy" },
	Expect = { Panels = { [UiSpec.Checkpoints.Panel] = false }, Remote = false },
})

-- Header/Icon/Title and a single Close. Daily/Quests and Shop keep their public Close path.
-- Daily/Quests share the same modal, so both actions must be inspected, not just whichever opened last.
UiSpec.SharedFrames = {
	{
		Action = "Daily",
		Panel = "DailyBoosts/ModalBackdrop/Modal",
		Close = "Close",
		Title = "DAILY REWARDS",
		Colour = "red",
	},
	{
		Action = "Quests",
		Panel = "DailyBoosts/ModalBackdrop/Modal",
		Close = "Close",
		Title = "QUESTS",
		Colour = "blue",
	},
	{ Action = "Shop", Panel = "ShopUi/Backdrop/Panel", Close = "Close", Title = "Shop", Colour = "purple" },
	{
		Action = "Market",
		Panel = "MarketUi/Backdrop/Panel",
		Close = "Header/Close",
		Title = "Market",
		Colour = "orange",
	},
}

-- Potion cards and Bundle use separate gift product IDs. Account-bound/server-wide cards still explain why
-- gifting is disabled. The scenario counts one Gift per card, independently of the wildcard inventory.
table.insert(UiSpec.Guis.ShopUi.Buttons, {
	Path = "Backdrop/Panel/Items/**/Gift",
	Does = "local",
	Effect = "gift_recipient_picker_or_disabled_reason",
	Count = "dynamic",
})
UiSpec.Gifts = {
	Button = "Gift",
	Reasons = { Account = "account", Server = "server", Unavailable = "unavailable" },
}
table.insert(UiSpec.Clicks, {
	Id = "gift_account_bound_disabled",
	Gui = "ShopUi",
	Path = "Backdrop/Panel/Items/Featured/**/ember_wyvern/Gift",
	Prepare = {
		Open = { "ShopUi/Backdrop" },
		Showcase = false,
		TargetActive = false,
		ScrollIntoView = true,
		Intercept = "PrepareGift",
	},
	NeedSetup = { "spy", "progression_spy" },
	Expect = { Remote = false, After = { "shop_no_purchase_prompt" } },
})

-- Index header (reconcile 2026-10-27, Isaac's INVENTORY tabs, ccea607). docs/HUD_LAYOUT_SPEC.md sections 1 and 3:
-- Index opens its existing panel and stays the discovery gallery of every car; consumables live in the Backpack's
-- Misc tab (the old Bag is gone). The generated header keeps one visible tab, CarsTab, which shows the car gallery
-- and asks the server nothing; the CONSUMABLES tab and its host stay hidden (ui_index index_no_consumables_view).
UiSpec.IndexTabs = {
	CarsTab = "RacerIndex/Panel/Face/Header/Face/CarsTab",
	ConsumablesTab = "RacerIndex/Panel/Face/Header/Face/ConsumablesTab",
	GridHost = "RacerIndex/Panel/Face/GridHost",
	ConsumablesHost = "RacerIndex/Panel/Face/ConsumablesHost",
}
table.insert(UiSpec.Guis.RacerIndex.Buttons, {
	Path = "Panel/Face/Header/Face/CarsTab/Face",
	Does = "local",
	Effect = "index_gallery_shown",
})
table.insert(UiSpec.Clicks, {
	Id = "index_cars_tab",
	Gui = "RacerIndex",
	Path = "Panel/Face/Header/Face/CarsTab/Face",
	Prepare = only("RacerIndex/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerIndex/Panel"] = true }, Remote = false, After = { "index_gallery_shown" } },
})

-- Motion, safe area and gamepad (docs/HUD_LAYOUT_SPEC.md section 7, owner 2026-10-26; design doc "Owner decision,
-- 2026-10-26 (accessibility and devices)"). Scenarios: ui_reduced_motion, ui_safe_insets, ui_panel_focus (in
-- UiScenarios.Names) and the manual ui_safe_insets_notch / ui_gamepad_focus (UiSpec.ManualScenarios).
UiSpec.Accessibility = {
	MotionModule = "UiMotion", -- ModuleScript in StarterPlayerScripts.Client; Reduced() is the one check
	ReduceAttr = "ReduceEffects", -- the in-game REDUCED EFFECTS toggle (LocalPlayer attribute, set by the client)
	ProbeSeconds = 2, -- the probe tween's length when motion is NOT reduced
	RollWait = 20, -- s to wait for the next auto roll while motion is reduced (ROLL_INTERVAL 3 s + one animation)
	ReelStill = 1, -- px a reel tile or streak may move during Spin while motion is reduced ("skips its spin")
	-- Full-screen ScreenGuis that may bleed under a notch (section 7 "Exempt"); every other player ScreenGui uses
	-- ScreenInsets = DeviceSafeInsets
	FullBleed = { PanelDim = true, LoserScreen = true, RollShowcase = true },
	ProbeGui = "UiTestInsetProbe", -- a ScreenGui the test adds to PlayerGui for one frame (late guis get insets too)
	-- Gamepad focus: a HUD button selected before a panel opens; closing must give the selection back to it
	RestoreTarget = "HudChrome/Grid/Index",
	-- Transparent full-screen click-catchers are not "visible buttons" (HUD_LAYOUT_SPEC section 6)
	NotFocusable = { Backdrop = true },
	FocusFrames = 4, -- rendered frames after Toggle before the selection is judged (PanelSwitch defers it)
	ButtonB = Enum.KeyCode.ButtonB,
}
-- Speed gain float (docs/HUD_LAYOUT_SPEC.md section 10, owner 2026-10-27): when leaderstats.Speed grows, the gain is
-- summed per 0.25 s window, one UiMotion.Float TextLabel MotionFloat with "+" .. HudFormat.GainText(gain)
-- rises in Speed yellow above the Speed number, inside SpeedValue's parent (like the Money "+$" float).
UiSpec.SpeedFloat = {
	Label = "MotionFloat",
	Host = "RacerHud/Speed", -- SpeedValue.Parent (UiSpec.Hud.SpeedValue)
	SpeedValue = "RacerHud/Speed/SpeedValue",
	Money = "RacerHud/Money", -- the Money float's host: a Speed gain must not float there
	Color = Color3.fromRGB(255, 232, 30), -- UiTheme Speed (section 8)
	ColorTolerance = 2 / 255,
	Gain = 12345, -- one local growth of leaderstats.Speed (client-side only, restored)
	FracGain = 0.5, -- a fractional growth: floats as "+0.5" (HudFormat.GainText, one decimal below 10)
	FracText = "+0.5",
	Quiet = 0.5, -- s with no growth before a probe, so the 0.25 s window has flushed
	Wait = 0.6, -- s a float may take to appear after the growth (summing may delay it up to 0.25 s)
	BurstStep = 7, -- each of BurstCount growths, BurstEvery s apart (shorter than 0.25 s, so growths are summed)
	BurstCount = 20, -- 20 x 0.05 s = about 1 s of growth
	BurstEvery = 0.05,
	BurstMinFloats = 3, -- about 1 s of growth floats about every 0.25 s, not once per second
	MinGap = 0.2, -- s between two floats (0.25 s cadence, 0.05 s frame slack)
}
UiSpec.ManualScenarios = UiSpec.ManualScenarios or {}
table.insert(UiSpec.ManualScenarios, {
	Name = "ui_safe_insets_notch",
	Manual = "needs a phone with a notch / rounded corners in Studio's Device Simulator (e.g. iPhone 14 landscape): "
		.. "a desktop window has no unsafe area, so the safe-area rect equals the screen there",
})
table.insert(UiSpec.ManualScenarios, {
	Name = "ui_gamepad_focus",
	Manual = "needs UserInputService.PreferredInput = Gamepad (Studio Controller Emulator on, one gamepad input "
		.. "sent first); scripts and the MCP can not make the preferred input a gamepad",
})
-- Gamepad presses (Key protocol; ui-tester's MCP sends no gamepad input, so MANUAL): with the Controller Emulator on,
-- the owner opens the panel with the gamepad, then presses the button.
local GAMEPAD_MANUAL = "needs a gamepad button press (Studio Controller Emulator); MCP and scripts can not send one"
table.insert(UiSpec.Clicks, {
	Id = "gamepad_b_closes_index",
	Key = "ButtonB",
	Manual = GAMEPAD_MANUAL,
	Prepare = only("RacerIndex/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerIndex/Panel"] = false }, Remote = false },
})
-- Selection trap: DPadUp from the panel's top-left button would leave the panel toward the Race button above it;
-- the panel stays open and the selection stays inside it (After gamepad_selection_in_panel).
table.insert(UiSpec.Clicks, {
	Id = "gamepad_dpad_up_stays_in_index",
	Key = "DPadUp",
	Manual = GAMEPAD_MANUAL,
	Prepare = only("RacerIndex/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerIndex/Panel"] = true }, Remote = false, After = { "gamepad_selection_in_panel" } },
})

-- UI visual pass (owner 2026-10-27): docs/HUD_LAYOUT_SPEC.md sections 8-10, docs/NPC_RACER_SPEC.md "Loser screen",
-- docs/RACE_PROGRESS_MAP_SPEC.md "Look". Numbers are measurement tolerances, not layout values.
UiSpec.SpeedDial = {
	SampleSeconds = 0.6, -- ui_speed_dial measures the car's real speed (seat path distance / time) over this window
	TeleportStep = 60, -- studs: a single-frame seat step longer than this is a teleport, not driving
	Tolerance = 3, -- studs/s: DialValue and DialSpeed vs the measured car speed ...
	RelTolerance = 0.15, -- ... or this share of it, whichever is larger
	CarWait = 5, -- s: while AutoRacing the avatar must sit in its car's seat within this
}
-- Every TextLabel / TextButton in the game's ScreenGuis (not UiSpec.IgnoreGuis, not the UiTest's own) uses this font
-- family (section 8: FredokaOne everywhere; Enum.Font.FredokaOne's FontFace family is ".../FredokaOne.json").
UiSpec.Theme = {
	FontFamily = "Fredoka",
	-- Every multiplier token is HudFormat.Multi style: "x" + digits, at most 2 decimals, no trailing zero after the
	-- point; never the old "25x" (number before x). Labels that show a multi (ui_theme theme_multi_format):
	MultiLabels = {
		{ Gui = "RollShowcase", Name = "SpeedMulti" }, -- the card's "x25 SPEED" and its contract alias "Speed x25"
		{ Gui = "RacerIndex", Name = "Info", Under = "Panel/Face/GridHost/Gallery" }, -- index tiles "Rare · x1.5"
		{ Gui = "RacerBackpack", Name = "Multi", Under = "Panel/Items" }, -- Backpack Cars tiles
	},
}
-- The loser recap (docs/NPC_RACER_SPEC.md "Loser screen (owner 2026-10-27)"): TextLabels anywhere under LoserScreen.
UiSpec.Loser = {
	RecapAt = 1.2, -- s after the Result Lose: the rows have appeared (they appear one after another); < LOSE_SCREEN_SECONDS
	Banner = { Name = "Banner", Text = "YOU LOST" }, -- the banner's text contains this
	Labels = { "Banner", "NpcName", "TrackTitle", "YourTime", "NpcTime", "Gap", "Pb", "BackTo" },
	Time = "%d%d:%d%d%.%d%d", -- mm:ss.cc inside YourTime / NpcTime (RaceProgressMap.FormatTime of the Result's times)
	Gap = "^%+%d+%.%d%ds$", -- "+1.32s"
	GapTolerance = 0.011, -- s: the gap vs Result PlayerTime - NpcTime
	Pb = { "^PB %-%-$", "^PB %d%d:%d%d%.%d%d$" },
	Countdown = "Countdown", -- Frame with child Fill
	Generic = "The NPC", -- never shown when NpcConfig.Tracks has the track
}
-- docs/RACE_PROGRESS_MAP_SPEC.md "Look": Path2D route lines (UiRaceProgressMap).
UiSpec.RaceMapLook = {
	Lines = { "RouteOutline", "RouteDriven", "RouteAhead" },
	FadeGroup = "RouteFade", -- optional CanvasGroup inside the canvas that holds the lines
	Status = { "^AHEAD %d+%.%ds$", "^BEHIND %d+%.%ds$", "^EVEN$" },
}

return UiSpec
