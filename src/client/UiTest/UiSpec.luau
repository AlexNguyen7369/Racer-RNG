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
-- name (one Equip button per index tile, one "+" per stat row).

local UiSpec = {}

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
--              Does = "toggle_panel" | "close_panel" | "remote" | "open_overlay" | "close_overlay" | "local"
--              Count = exact number expected for "*" patterns; Label = the text it must show
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
			"Navigation/Index/Face",
			"Navigation/Stats/Face",
			"Navigation/Stats/Face/PointsBadge",
			"Navigation/Rebirth/Face",
			"Settings/Face",
			"Speed",
			"Money",
			"Turbo",
		},
		Readouts = { "Speed", "Money", "Turbo", "Navigation/Stats/Face/PointsBadge" },
		NonInteractiveParts = { "Speed", "Money", "Turbo" },
		Buttons = {
			{
				Path = "Race/Face",
				Does = "remote",
				Remote = "SetAutoRace",
				Arg = "not_attr:AutoRacing", -- the opposite of the current AutoRacing attribute
				Label = "upper(HudFormat.AutoButtonText(AutoRacing))", -- "AUTO RACE" / "STOP AUTO"
			},
			{ Path = "Navigation/Index/Face", Does = "toggle_panel", Panel = "RacerIndex/Panel", Text = "INDEX" },
			{ Path = "Navigation/Stats/Face", Does = "toggle_panel", Panel = "RacerStats/Panel", Text = "STATS" },
			{ Path = "Navigation/Rebirth/Face", Does = "toggle_panel", Panel = "RacerRebirth/Panel", Text = "REBIRTH" },
			{ Path = "Settings/Face", Does = "toggle_panel", Panel = "RacerSettings/Panel" }, -- gear icon, no text
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
	-- SETTINGS modal (ui/specs/RacerSettings.ui.json): local preferences only.
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
	-- REBIRTH modal (ui/specs/RacerRebirth.ui.json): "COMING SOON", only a Close button
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
	SoundText = { [true] = "ON", [false] = "OFF" }, -- [sound on]
	EffectsText = { [true] = "ON", [false] = "OFF" }, -- [ReduceEffects]
	ProbeVolume = 0.5, -- the test's own Sound (created and destroyed by the sound clicks) must follow the toggle
}
UiSpec.Rebirth = { Title = "REBIRTH", Text = "COMING SOON" }

-- The HUD (ui/specs/RacerHud.ui.json). Gaps are the spec's offsets (they are not scaled by the UIScale k).
UiSpec.Hud = {
	Race = "RacerHud/Race/Face",
	RaceLabel = "RacerHud/Race/Face/RaceLabel",
	RaceTop = 72, -- px from the screen top (IgnoreGuiInset) to the Race button's top edge, below the top bar
	NavButtons = {
		"RacerHud/Navigation/Index/Face",
		"RacerHud/Navigation/Stats/Face",
		"RacerHud/Navigation/Rebirth/Face",
	},
	NavLabels = { "INDEX", "STATS", "REBIRTH" }, -- stacked top to bottom on the LEFT edge
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
	Settings = "RacerHud/Settings/Face",
	PointsBadge = "RacerHud/Navigation/Stats/Face/PointsBadge",
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
	FallbackMulti = 5, -- UpgradeConfig.BASE_TURBO.Multi (no Turbo tier owned)
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
	},
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
	Navigation = "RacerHud/Navigation",
}

-- Always-on elements that are HIDDEN while a pop-up panel is open (owner decision 2026-10-08 and CLAUDE.md "UI
-- tests"): they are left out of the overlap lists in that state, and ui_panels / ui_toast prove they really are hidden
-- (Visible false) then. When = "any": any PanelSwitch panel open; "other_than:<panel>": any panel but that one.
UiSpec.HiddenWhilePanelOpen = {
	["RollToast/Toast"] = "any", -- RollToast refreshToast: show requires not PanelSwitch.AnyOpen()
	["RacerProgression/WorkshopRate"] = "any", -- ProgressionUi: rate.Visible = not AnyOpen()
	["RacerProgression/UpgradeButton"] = "other_than:RacerUpgrades/Panel", -- ProgressionUi: hidden over other panels
	["RacerProgression/UpgradeButton/Badge"] = "other_than:RacerUpgrades/Panel", -- inside UpgradeButton
}
-- ProgressionUi applies its visibility on a 0.25 s poll: the checks wait up to this long for it.
UiSpec.HiddenWhilePanelOpenWait = 1

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
	FlyTarget = "RacerHud/Navigation/Index/Face", -- until the Garage button exists
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
UiSpec.Remotes = { "SetAutoRace", "SetAutoRoll", "EquipCar", "AllocateStat", "RollResult", "RollAnnounce", "NpcRace" }

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
	WorkshopRate = {
		Path = "Workshop/Zone/Rate", -- only on an owned plot
		Outside = "^Stand here: %+([%d%.]+) Speed/s$", -- the owner is not in the zone
		Inside = "^%+([%d%.]+) Speed/s$", -- the owner stands in it: the number is the WorkshopRate attribute
		Step = 0.05, -- one formatting step ("%.1f")
		MaxDistance = "WorkshopConfig.SIGN_DISTANCE",
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
			.. "walk spawn for ~2 s: the world fixtures (workshop_*_prompt, upgrade_world_*) re-place the avatar until "
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
 LabelIs        the target's label text before the click (else state_missing: the previous click did not land)
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
 After    = post-conditions once the server / UI answered
]]
local CLOSED = {
	"RacerIndex/Panel",
	"RacerStats/Panel",
	"RacerSettings/Panel",
	"RacerRebirth/Panel",
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
	-- Panels: each opens with its HUD button, closes with a second click and with its X
	{
		Id = "open_index",
		Gui = "RacerHud",
		Path = "Navigation/Index/Face",
		Prepare = { Closed = CLOSED, Showcase = false },
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerIndex/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_index_closed",
		Gui = "RacerHud",
		Path = "Navigation/Index/Face",
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
		Gui = "RacerHud",
		Path = "Navigation/Stats/Face",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerStats/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_stats_closed",
		Gui = "RacerHud",
		Path = "Navigation/Stats/Face",
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
		Gui = "RacerHud",
		Path = "Settings/Face",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerSettings/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_settings_closed",
		Gui = "RacerHud",
		Path = "Settings/Face",
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
		Id = "open_rebirth",
		Gui = "RacerHud",
		Path = "Navigation/Rebirth/Face",
		Prepare = { Closed = CLOSED, Showcase = false },
		Expect = { Panels = { ["RacerRebirth/Panel"] = true }, Remote = false },
	},
	{
		Id = "toggle_rebirth_closed",
		Gui = "RacerHud",
		Path = "Navigation/Rebirth/Face",
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
		Gui = "RacerHud",
		Path = "Navigation/Stats/Face",
		Prepare = only("RacerIndex/Panel"),
		Expect = { Panels = { ["RacerStats/Panel"] = true, ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_index_while_stats_open",
		Gui = "RacerHud",
		Path = "Navigation/Index/Face",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerIndex/Panel"] = true, ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_settings_while_stats_open",
		Gui = "RacerHud",
		Path = "Settings/Face",
		Prepare = only("RacerStats/Panel"),
		Expect = { Panels = { ["RacerSettings/Panel"] = true, ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_rebirth_while_settings_open",
		Gui = "RacerHud",
		Path = "Navigation/Rebirth/Face",
		Prepare = only("RacerSettings/Panel"),
		Expect = { Panels = { ["RacerRebirth/Panel"] = true, ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "open_index_while_rebirth_open",
		Gui = "RacerHud",
		Path = "Navigation/Index/Face",
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
			After = { "showcase_blur_off", "view_compact", "normal_view_back" },
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
			After = { "showcase_blur_off", "view_compact", "toast_shows_auto_off", "normal_view_back" },
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
		ClickAt = "RacerHud/Navigation/Index/Face",
		Prepare = { Showcase = true },
		NeedSetup = { "spy" },
		Expect = {
			Showcase = false,
			Panels = { ["RacerIndex/Panel"] = false },
			Remote = false,
			After = { "showcase_blur_off", "view_compact", "normal_view_back" },
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
			After = { "showcase_blur_off", "view_compact", "normal_view_back" },
		},
	},
}

-- Progression contract agreed with main, 2026-10-07. These are additions to the Racer UI gate.
UiSpec.Guis.RacerProgression = {
	Source = "Client/ProgressionUi",
	AlwaysOn = { "UpgradeButton", "UpgradeButton/Badge", "WorkshopRate", "WeatherBanner" },
	Readouts = { "UpgradeButton/Badge", "WorkshopRate", "WeatherBanner" },
	NonInteractiveParts = { "WorkshopRate", "WeatherBanner" },
	Buttons = { { Path = "UpgradeButton", Does = "toggle_panel", Panel = "RacerUpgrades/Panel", Text = "UPGRADES" } },
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
	UpgradeButtonSize = Vector2.new(110, 40),
	UpgradeButtonTop = 0.22,
	UpgradeButtonRight = 16,
	WorkshopRateStep = 0.05,
	WorldPadWait = 1.5, -- s: ProgressionUi polls the pad every 0.25 s and the fixture's teleport must replicate
}
for _, name in { "Upgrades", "Workshop", "Welcome" } do
	local path = "Racer" .. name .. "/Panel"
	UiSpec.PanelSwitch.Names[path] = name
	table.insert(CLOSED, path)
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { path, "RacerHud/Money" })
end
table.insert(UiSpec.ClientScripts, "ProgressionUi")
UiSpec.RemoteFunctions = { "BuyUpgrade", "WorkshopUpgrade" }
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
	Gui = "RacerProgression",
	Path = "UpgradeButton",
	Prepare = { Closed = CLOSED, Showcase = false },
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = true }, Remote = false },
})
table.insert(UiSpec.Clicks, {
	Id = "toggle_upgrades_closed",
	Gui = "RacerProgression",
	Path = "UpgradeButton",
	Prepare = only("RacerUpgrades/Panel"),
	NeedSetup = { "spy" },
	Expect = { Panels = { ["RacerUpgrades/Panel"] = false }, Remote = false },
})
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
			Id = "upgrade_world_enter",
			What = "Moves avatar onto spawn UpgradePad; ui_progression_world must observe only Upgrades open.",
		},
		{
			Id = "upgrade_world_leave",
			What = "Moves avatar off spawn UpgradePad; ui_progression_world must observe Upgrades closed.",
		},
		{
			Id = "offline_zero",
			What = "OfflineSpeed=0, OfflineSeconds=0; ui_offline_zero must observe welcome hidden.",
		},
		{ Id = "weather_rain", What = "Replicates rain with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_night", What = "Replicates night with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_gold", What = "Replicates gold with 180 seconds remaining; run ui_weather." },
		{ Id = "weather_clear", What = "Replicates no event; run ui_weather, banner must hide." },
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
	{ Setup = "upgrade_world_enter", Scenario = "ui_progression_world" },
	{ Setup = "upgrade_world_leave", Scenario = "ui_progression_world" },
	{ Setup = "offline_welcome", Scenario = "ui_offline_welcome" },
	{ Setup = "offline_zero", Scenario = "ui_offline_zero" },
	{ Setup = "weather_rain", Scenario = "ui_weather" },
	{ Setup = "weather_night", Scenario = "ui_weather" },
	{ Setup = "weather_gold", Scenario = "ui_weather" },
	{ Setup = "weather_clear", Scenario = "ui_weather" },
}
return UiSpec
