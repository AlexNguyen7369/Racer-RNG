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

-- Viewports the layout is checked at. "current" is the live Studio viewport (engine AbsolutePosition); the others
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
		DisabledStats = { Workshop = true }, -- the Racer UI shows the Workshop row as "COMING SOON": it fires nothing
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
	-- The compact roll (docs/ROLL_ANIMATION_CONTRACT.md): top centre, directly UNDER the Race button. Its area is
	-- always reserved (the overlap checks place it there even while hidden), it is a button only while shown
	-- (Visible = false at rest: no invisible hitbox; shown at rest only while AutoRoll is false, with "AUTO OFF").
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
	BottomGap = { Desktop = 22, Phone = 16 }, -- px: Money (bottom left) and RollControls (bottom right) bottom edges
	SideGap = { Desktop = 22, Phone = 12 }, -- px: Money's left / RollControls' right edge from the screen side
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

-- CLAUDE.md: panels open BELOW the Race (Auto Race) button and end ABOVE the bottom TURBO LUCK bar; owner decision 6
-- (docs/ROLL_ANIMATION_SPEC.md): where a panel overlaps the compact roll horizontally it starts this far below the
-- compact roll's bottom edge (the roll keeps playing while panels open, so the two never overlap).
UiSpec.PanelTopMargin = 4

-- Overlaps that are allowed: a modal panel may cover a read-out (Speed, Money), never a button or the TURBO bar.
UiSpec.AllowOverlap = {}
for _, panel in { "RacerIndex/Panel", "RacerStats/Panel", "RacerSettings/Panel", "RacerRebirth/Panel" } do
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Speed" })
	table.insert(UiSpec.AllowOverlap, { panel, "RacerHud/Money" })
end

-- The enlarged view (RollShowcase ScreenGui). Card parts are found by name anywhere in RollShowcase/Card.
UiSpec.Showcase = {
	Gui = "RollShowcase",
	Backdrop = "Backdrop", -- full-screen TextButton, no text, dark, BackgroundTransparency ~0.35
	BackdropTransparency = { Min = 0.2, Max = 0.5 },
	BackdropMaxLuminance = 0.3,
	Card = "Card", -- Frame, Active (a click on it does NOT close)
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
		ENLARGED_MAX = Vector2.new(780, 336),
		PANEL_TOP = 138, -- stale since the merge (old toggle geometry); presence only, see ui_layout
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
		"PANEL_TOP",
	},
	Vectors = { "ENLARGED_MAX" },
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

-- Created by Roblox, not the game.
UiSpec.IgnoreGuis = { Freecam = true, BubbleChat = true, Chat = true, TouchGui = true, RbxCameraUI = true }

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
		When = "ONCE, before UiTestRun and before any click (it is the baseline: never listed in a click's NeedSetup)",
		What = "Remembers the player's GachaService snapshot, AutoRacing and AutoRoll so 'restore' can put them back.",
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
		When = "before each allocate_* click that expects a fire (and allocate_workshop_disabled)",
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
		What = "Applies the 'snapshot', restores AutoRacing and AutoRoll and removes UiTestSpy.",
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
	-- A script can not send a key: ui-tester presses it (UiSpec.Clicks Key protocol above).
	{
		Id = "escape_closes_index",
		Key = "Escape",
		Prepare = only("RacerIndex/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerIndex/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_stats",
		Key = "Escape",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerStats/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_settings",
		Key = "Escape",
		Prepare = only("RacerSettings/Panel"),
		NeedSetup = { "spy" },
		Expect = { Panels = { ["RacerSettings/Panel"] = false }, Remote = false },
	},
	{
		Id = "escape_closes_rebirth",
		Key = "Escape",
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
	-- Stats: "+" fires AllocateStat with THAT row's stat; Workshop and "no points" fire nothing
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
		Id = "allocate_workshop_disabled",
		Gui = "RacerStats",
		Path = "Panel/Face/StatsHost/Rows/Workshop/Plus",
		Prepare = only("RacerStats/Panel"),
		NeedSetup = { "spy", "stat_points" }, -- even WITH free points the Workshop row fires nothing
		Expect = { Remote = false, After = { "alloc_unchanged", "points_unchanged" } },
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
	-- AUTO is intentionally only reachable from RollShowcase/AutoButton after
	-- clicking the compact top-centre RollToast animation.
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
	-- Compact roll -> enlarged view (docs/ROLL_ANIMATION_CONTRACT.md). Run these nine in this order, with
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

return UiSpec
