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
-- (Client/RollToast/Ui/RacerMotion, 1.035 on hover, 0.97 while pressed). Geometry is measured with them at 1x.
UiSpec.TransientScales = { HoverScale = true }

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
				-- (Active false, fires nothing) below the level milestone and at RebirthConfig.MAX_LEVEL.
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
-- docs/REBIRTH_SPEC.md "Panel"). Numbers come from Shared/RebirthConfig (LUCK_GAIN_PER_LEVEL, GAIN_PER_LEVEL,
-- POINTS_PER_REBIRTH, MAX_LEVEL), Shared/LevelConfig.RebirthLevelRequirement(RebirthLevel) and the player's Level /
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
	-- Caption = Format with the RebirthConfig number (Percent: the fraction as a whole percent): the NEXT rebirth's gain.
	Tiles = {
		{ Name = "LuckReward", Config = "LUCK_GAIN_PER_LEVEL", Percent = true, Format = "+%d%% Luck" },
		{ Name = "SpeedReward", Config = "GAIN_PER_LEVEL", Percent = true, Format = "+%d%% Speed Gain" },
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
		"Maximum rebirth",
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
	SpeedIcon = "RacerHud/Speed/SpeedIcon",
	SpeedValue = "RacerHud/Speed/SpeedValue",
	SpeedSuffix = " SPEED",
	SpeedCentreTolerance = 2, -- px: the visible icon + number are centred on the screen (brief 2026-10-06: Speed centred; CLAUDE.md still says left)
	Money = "RacerHud/Money",
	MoneyValue = "RacerHud/Money/MoneyValue",
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
	},
}

-- Money market (Client/MarketUi; docs/HUD_LAYOUT_SPEC.md section 2 "Market", owner 2026-10-16: the Backpack look).
-- Backdrop is the full-screen dim TextButton (a click off the panel closes it); Panel holds Header (square red X),
-- side Tabs (one per MarketConfig.Items kind), the tile Grid of the selected kind and the Detail pane of the selected
-- tile. UiSpec.Market holds the parts; ui_market and the market_* clicks check them.
UiSpec.Guis.MarketUi = {
	Source = "Client/MarketUi",
	Panels = { "Backdrop" },
	Buttons = {
		{ Path = "Backdrop", Does = "close_panel", Panel = "MarketUi/Backdrop", Text = "" },
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
		{
			Path = "Panel/Items/*",
			Does = "remote",
			Remote = "UseBoost|MarketEquip",
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
		{ Path = "Backdrop", Does = "close_panel", Panel = "ShopUi/Backdrop", Text = "" },
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
	Owned = "Owned", -- an owned gamepass car (attribute Pass_<carId>)
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
		{ Name = "Price", Class = "TextLabel" },
		{ Name = "Description", Class = "TextLabel" },
		{ Name = "Action", Class = "TextButton" },
	},
	-- Action label for the shown item: potions are always BUY (consumables)
	ActionText = { Buy = "BUY", Equip = "EQUIP", Equipped = "EQUIPPED" },
	-- The tile the market_select_tile click picks (a potion: shown to every player, never owned-only); not the first
	-- potion, so selecting it really changes Detail.
	SelectKind = "Potion",
	SelectId = "SpeedII",
}

-- Panels fitted by Client/PanelBand.Fit (docs/HUD_LAYOUT_SPEC.md: between the left grid and the Shop column, below the
-- Race button, above the TURBO LUCK bar and the Money read-out). Value = the panel's max width (mirrored from the
-- client's Band.Fit call; the band rule itself is the spec). The layout solver fits them like PanelBand does.
UiSpec.BandPanels = {
	["ShopUi/Backdrop/Panel"] = 900,
	["MarketUi/Backdrop/Panel"] = 900,
}
UiSpec.Band = {
	Race = "RacerHud/Race",
	Turbo = "RacerHud/Turbo",
	Grid = "HudChrome/Grid",
	ShopColumn = "HudChrome/ShopColumn",
	Money = "RacerHud/Money",
	Gap = 8,
	MinSize = Vector2.new(240, 160),
}

-- CLAUDE.md: panels open BELOW the Race (Auto Race) button and end ABOVE the bottom TURBO LUCK bar. The progression
-- panels (Upgrades / Workshop / Welcome) keep their rule: below the Race button and the compact roll's rect by this
-- margin, and this far above the TURBO bar (ui_progression_layout).
UiSpec.PanelTopMargin = 4

-- The four Racer panels (owner decision 2026-10-08, RacerUiController.fitPanels): centred in the band between the
-- Race button and the TURBO LUCK bar, Gap px below the Race Face's bottom, Gap px above the TURBO bar's top and at
-- least Gap px right of the INDEX / STATS / REBIRTH column (the same margin on the right), their UIScale shrinking
-- below the generated k only when the band is too small. ui_layout <panel>_centred_x / _below_autorace /
-- _above_turbo / _clear_of_nav / _band_centred_y check it at every viewport.
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
}
-- ProgressionUi applies its visibility on a 0.25 s poll: the checks wait up to this long for it.
UiSpec.HiddenWhilePanelOpenWait = 1

-- Every persistent HUD layer gets a non-interactive tint while a PanelSwitch
-- panel is open. The controls remain drawn underneath it; the overlay is visual
-- feedback, not a replacement for hiding controls.
UiSpec.PanelDimmers = {
	Paths = {
		"HudChrome/PanelDimmer",
		"RacerHud/PanelDimmer",
		"RollToast/PanelDimmer",
		"RacerProgression/PanelDimmer",
	},
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
	Highlight = "RacerHoverHighlight",
	HighlightColour = Color3.new(1, 1, 1),
	HighlightThickness = 3,
}

-- Overlaps that are allowed: a modal panel may cover a read-out (Speed, Money), never a button or the TURBO bar.
UiSpec.AllowOverlap = {}
for _, panel in { "RacerIndex/Panel", "RacerStats/Panel", "RacerSettings/Panel", "RacerRebirth/Panel" } do
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Money" })
end

-- A PanelSwitch panel (every entry of UiSpec.PanelSwitch.Names, incl. the progression panels) AND everything inside it
-- may overlap these read-outs (not interactive), but ONLY where the panel really draws over them (ui_layout verifies
-- it for every such overlap, panel and button alike): the panel's ScreenGui has a higher DisplayOrder than the
-- read-out's, and the overlap lies inside the panel's opaque, shown surface (Panel/<Surface>, or the Panel itself when
-- it has no <Surface>) whose BackgroundTransparency is at most MaxSurfaceTransparency, with no CanvasGroup fading it.
-- A read-out drawn above a panel button is never allowed.
UiSpec.PanelCoversReadouts = {
	-- Money (and MoneyValue / Unbanked inside it) is a display-only read-out like Speed (2026-10-08, gate run 5).
	Readouts = { "RacerHud/Speed", "RacerHud/Money" },
	Surface = "Face",
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
	ContentParts = { "Viewport", "ResultName", "ResultSpeed", "ResultRarity", "ResultOdds", "NewBadge", "TurboBadge" },
	SpeedText = "x%s SPEED MULTIPLIER", -- %s = the car's SpeedMulti (Racer UI; the old contract said "25x Speed")
	TurboBadgeText = "TURBO x%s", -- %s = the roll's turbo multi
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
	WinText = { Tag = "WinPad", Label = "Amount", MaxDistance = "TrackBuilder.WIN_TEXT_DISTANCE", Text = "$<Cash>" },
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
ClickAt: where to click when it is not the target's centre: "corner" (UiSpec.Showcase.CornerInset px in from the
 bottom-right corner, off the card) or a "<Gui>/<Path>" whose centre is used. The target must be topmost there.
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
		Id = "close_market_backdrop",
		Gui = "MarketUi",
		Path = "Backdrop",
		ClickAt = "corner",
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
		Prepare = only("MarketUi/Backdrop"),
		Expect = { Panels = { ["MarketUi/Backdrop"] = true }, Remote = false, After = { "market_detail_shows_tile" } },
	},
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
		Id = "close_shop_backdrop",
		Gui = "ShopUi",
		Path = "Backdrop",
		ClickAt = "corner",
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
		Id = "shop_featured_coming_soon",
		Gui = "ShopUi",
		Path = "Backdrop/Panel/Items/Featured/**/ember_wyvern/Buy",
		Prepare = (function()
			local p = only("ShopUi/Backdrop")
			p.LabelHas = "Coming soon"
			p.ScrollIntoView = true
			return p
		end)(),
		Expect = { Panels = { ["ShopUi/Backdrop"] = true }, Remote = false, After = { "shop_no_purchase_prompt" } },
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
		Expect = {
			Panels = { ["ShopUi/Backdrop"] = true },
			Remote = false,
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
UiSpec.Guis.RacerUpgrades = {
	Source = "Client/ProgressionUi",
	Panels = { "Panel" },
	Buttons = {
		{ Path = "Panel/Close", Does = "close_panel", Panel = "RacerUpgrades/Panel" },
		{ Path = "Panel/Canvas/*", Does = "remote", Remote = "BuyUpgrade", Arg = "upgrade_id", Count = "upgrades" },
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
	Buttons = { { Path = "Panel/Close", Does = "close_panel", Panel = "RacerWelcome/Panel" } },
}
UiSpec.Progression = {
	TileSize = Vector2.new(100, 88),
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
		Path = "Panel/Close",
		Prepare = only(path),
		NeedSetup = { "spy" },
		Expect = { Panels = { [path] = false }, Remote = false },
	})
end
table.insert(UiSpec.Clicks, {
	Id = "open_upgrades",
	Gui = "HudChrome",
	Path = "UpgradeSlot/Upgrade",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = true }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "toggle_upgrades_closed",
	Gui = "HudChrome",
	Path = "UpgradeSlot/Upgrade",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = false }, Remote = false },
})
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
	Path = "Panel/Canvas/money_1",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "progression_buyable", "spy", "progression_spy" },
	Expect = { Remote = { Name = "BuyUpgrade", Arg = "upgrade_id" }, After = { "progression_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "upgrade_no_money",
	Gui = "RacerUpgrades",
	Path = "Panel/Canvas/money_1",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "progression_no_money", "spy", "progression_spy" },
	Expect = { Remote = false, After = { "progression_not_optimistic" } },
})
table.insert(UiSpec.Clicks, {
	Id = "buy_workshop",
	Gui = "RacerWorkshop",
	Path = "Panel/Buy",
	Prepare = only("RacerWorkshop/Panel"),
	NeedSetup = { "progression_buyable", "spy", "progression_spy" },
	Expect = {
		Remote = { Name = "WorkshopUpgrade", Arg = "none" },
		After = { "progression_not_optimistic", "workshop_rejection_shown" },
	},
})
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
	{ Setup = "offline_welcome", Scenario = "ui_offline_welcome" },
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
	DayRow = "Day%d", -- one TextLabel per DailyLoginConfig.Rewards entry, text "DAY <n>", "✓" up to DailyStreak
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
for _, tab in { "Misc", "Trails", "Auras" } do
	table.insert(UiSpec.Clicks, {
		Id = "backpack_" .. string.lower(tab),
		Gui = "RacerBackpack",
		Path = "Panel/Tabs/" .. tab .. "Tab",
		Prepare = only("RacerBackpack/Panel"),
		Expect = { Panels = { ["RacerBackpack/Panel"] = true }, Remote = false },
	})
end
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
	Prepare = { Open = { DAILY }, Showcase = false },
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
table.insert(UiSpec.Clicks, {
	Id = "quest_claim_disabled_fires_nothing",
	Gui = "DailyBoosts",
	Path = "ModalBackdrop/Modal/Content/daily_races/Claim",
	Prepare = { Open = { DAILY }, Showcase = false, Intercept = "QuestClaim", TargetActive = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { [DAILY] = true }, Remote = false },
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
return UiSpec
