--!nonstrict
-- Layout model input for the UI tests (owned by ui-test-writer): the desktop / phone layout of every generated node of
-- the baked Racer UI, copied from the Bind() sections of src/client/RollToast/Ui/*.luau (themselves generated from
-- ui/specs/*.ui.json). Those modules switch every node to its Phone props when the camera viewport is at most
-- PHONE_MAX_HEIGHT px tall and scale each UIScale'd node by k (below), so the solver needs both variants to place the
-- UI at a viewport the Studio window is not at.
-- This is NOT a limit: it describes the implementation so other viewports can be simulated. ui_layout checks it
-- against the live properties on the current viewport (responsive_model_matches_live) and fails when the UI changes
-- without this file being regenerated (python3 over the Bind() sections; ui-test-writer does it).
-- Regenerated 2026-10-06 from the Racer UI (spec hashes RacerHud 20a92c4ea76e, RacerIndex ab7f1fe08591, RacerStats
-- 53ff23d7d9f8, RacerSettings f7eec9b472c5, RollShowcase 1039b947bbd9); RacerRebirth rows regenerated 2026-10-15
-- from the rebuilt panel (spec hash e3e844a47fa5; its Fill has no layout row: scale-only, the same at every
-- variant). RacerHud/Settings has a UIScale but no layout row: its UDim2 is the baked one at every viewport.
-- Regenerated 2026-10-26 (ui-test-writer) from the Bind() sections of RacerHud 8087703805de, RacerIndex 80e4155a1165,
-- RacerStats d5878e28e2b7, RacerSettings 7c95f76829b1, RacerRebirth be16091fd518, RollShowcase 461182e58416 and
-- Client/Ui/RacerUpgrades 5c3ab6a967ca (adds Level, RaceMap, RollControls, the Index tabs and the tree chrome).
-- Client/HudChrome's runtime layout (not generated) is modelled by hand below (Model.HudChrome).
-- The solver (UiScenarios simRect) uses a node's variant props from Nodes only at a viewport of the OTHER variant than
-- the live one (on the live variant it reads the live properties, so a live deviation still shows), and the generated
-- UIScale (ScaleAt) at every simulated viewport; hover / press UIScales (UiSpec.TransientScales) count as 1.

local Model = {}

-- The generated fit(): phone = ViewportSize.Y <= PHONE_MAX_HEIGHT;
-- k = phone and clamp(Y / 390, 0.85, 1.15) or clamp(Y / 720, 0.6, 1.4); UIScale.Scale = k x the node's zoom.
Model.PHONE_MAX_HEIGHT = 500
Model.Desktop = { Ref = 720, Min = 0.6, Max = 1.4 }
Model.Phone = { Ref = 390, Min = 0.85, Max = 1.15 }

local generated = {
	Scales = {
		["RacerHud/Race"] = { Desktop = 1, Phone = 1 },
		["RacerHud/RaceMap"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Navigation"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Speed"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Money"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Level"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Turbo"] = { Desktop = 1, Phone = 1 },
		["RacerHud/RollControls"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Settings"] = { Desktop = 1, Phone = 1 },
		["RacerIndex/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerStats/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerSettings/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerRebirth/Panel"] = { Desktop = 1, Phone = 1 },
		["RollShowcase/Card"] = { Desktop = 1, Phone = 1 },
		["RacerUpgrades/TreeTitle"] = { Desktop = 1, Phone = 1 },
		["RacerUpgrades/Close"] = { Desktop = 1, Phone = 1 },
		["RacerUpgrades/ZoomTools"] = { Desktop = 1, Phone = 1 },
		["RacerUpgrades/Details"] = { Desktop = 1, Phone = 1 },
		["RacerUpgrades/Balance"] = { Desktop = 1, Phone = 1 },
	},
	Nodes = {
		["RacerHud/Race"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 72),
				Size = UDim2.fromOffset(180, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 72),
				Size = UDim2.fromOffset(160, 48),
				Visible = true,
			},
		},
		["RacerHud/Race/Face/RaceLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerHud/RaceMap"] = {
			Desktop = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -20, 0, 68),
				Size = UDim2.fromOffset(360, 260),
				Visible = false,
			},
			Phone = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -10, 0, 64),
				Size = UDim2.fromOffset(250, 184),
				Visible = false,
			},
		},
		["RacerHud/RaceMap/RaceMapTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 2),
				Size = UDim2.fromOffset(344, 22),
				TextSize = 16,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 2),
				Size = UDim2.fromOffset(234, 18),
				TextSize = 12,
				Visible = true,
			},
		},
		["RacerHud/RaceMap/RaceMapStatus"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 25),
				Size = UDim2.fromOffset(344, 18),
				TextSize = 14,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 25),
				Size = UDim2.fromOffset(234, 16),
				TextSize = 11,
				Visible = true,
			},
		},
		["RacerHud/RaceMap/RaceMapCanvas"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(10, 44),
				Size = UDim2.fromOffset(340, 196),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 38),
				Size = UDim2.fromOffset(234, 132),
				Visible = true,
			},
		},
		["RacerHud/RaceMap/RaceMapTime"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 236),
				Size = UDim2.fromOffset(170, 22),
				TextSize = 13,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 166),
				Size = UDim2.fromOffset(112, 16),
				TextSize = 10,
				Visible = true,
			},
		},
		["RacerHud/RaceMap/RaceMapPB"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(180, 236),
				Size = UDim2.fromOffset(164, 22),
				TextSize = 13,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(124, 166),
				Size = UDim2.fromOffset(118, 16),
				TextSize = 10,
				Visible = true,
			},
		},
		["RacerHud/Navigation"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 22, 0.45, 0),
				Size = UDim2.fromOffset(160, 226),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.44, 0),
				Size = UDim2.fromOffset(118, 200),
				Visible = true,
			},
		},
		["RacerHud/Navigation/Index"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(160, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(118, 48),
				Visible = true,
			},
		},
		["RacerHud/Navigation/Index/Face/IndexLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 27,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
		},
		["RacerHud/Navigation/Stats"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 84),
				Size = UDim2.fromOffset(160, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 74),
				Size = UDim2.fromOffset(118, 48),
				Visible = true,
			},
		},
		["RacerHud/Navigation/Stats/Face/StatsLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 27,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
		},
		["RacerHud/Navigation/Rebirth"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 168),
				Size = UDim2.fromOffset(160, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 148),
				Size = UDim2.fromOffset(118, 48),
				Visible = true,
			},
		},
		["RacerHud/Navigation/Rebirth/Face/RebirthLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 27,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
		},
		["RacerHud/Speed"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 26, 0.78, 0),
				Size = UDim2.fromOffset(306, 108),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.new(0.5, 22, 0.73, 0),
				Size = UDim2.fromOffset(250, 90),
				Visible = true,
			},
		},
		-- Speedometer layout (owner brief 2026-10-27, docs/HUD_LAYOUT_SPEC.md section 9): dial on the left, the icon is
		-- its hub (ZIndex above the dial), the Speed stat on the right; the group keeps its authored place and size.
		["RacerHud/Speed/SpeedDial"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(108, 108),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(90, 90),
				Visible = true,
			},
		},
		["RacerHud/Speed/SpeedIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(34, 30),
				Size = UDim2.fromOffset(40, 40),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(28, 25),
				Size = UDim2.fromOffset(34, 34),
				Visible = true,
			},
		},
		["RacerHud/Speed/SpeedValue"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(116, 33),
				Size = UDim2.fromOffset(190, 42),
				TextSize = 34,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(96, 23),
				Size = UDim2.fromOffset(154, 34),
				TextSize = 28,
				Visible = true,
			},
		},
		["RacerHud/Money"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 22, 1, -22),
				Size = UDim2.fromOffset(282, 120),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(0, 12, 1, -16),
				Size = UDim2.fromOffset(200, 92),
				Visible = true,
			},
		},
		["RacerHud/Money/MoneyIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(90, 90),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(56, 56),
				Visible = true,
			},
		},
		-- Money plate behind MoneyValue and Unbanked (owner brief 2026-10-27, HUD spec section 9)
		["RacerHud/Money/MoneyPlate"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(94, 22),
				Size = UDim2.fromOffset(188, 92),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(62, 12),
				Size = UDim2.fromOffset(138, 72),
				Visible = true,
			},
		},
		["RacerHud/Money/MoneyValue"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(102, 31),
				Size = UDim2.fromOffset(180, 42),
				TextSize = 40,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(68, 17),
				Size = UDim2.fromOffset(132, 34),
				TextSize = 32,
				Visible = true,
			},
		},
		["RacerHud/Money/Unbanked"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(102, 80),
				Size = UDim2.fromOffset(180, 24),
				TextSize = 20,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(68, 58),
				Size = UDim2.fromOffset(132, 20),
				TextSize = 16,
				Visible = true,
			},
		},
		["RacerHud/Level"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -60),
				Size = UDim2.fromOffset(250, 32),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -52),
				Size = UDim2.fromOffset(200, 30),
				Visible = true,
			},
		},
		["RacerHud/Level/Face/LevelLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(250, 32),
				TextSize = 18,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(200, 30),
				TextSize = 16,
				Visible = true,
			},
		},
		["RacerHud/Turbo"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -22),
				Size = UDim2.fromOffset(250, 32),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.fromOffset(200, 30),
				Visible = true,
			},
		},
		["RacerHud/Turbo/Face/TurboLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(250, 32),
				TextSize = 20,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(200, 30),
				TextSize = 18,
				Visible = true,
			},
		},
		["RacerHud/RollControls"] = {
			Desktop = {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -22, 1, -22),
				Size = UDim2.fromOffset(220, 54),
				Visible = false,
			},
			Phone = {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -16),
				Size = UDim2.fromOffset(194, 48),
				Visible = false,
			},
		},
		["RacerHud/RollControls/RollView"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(104, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(90, 48),
				Visible = true,
			},
		},
		["RacerHud/RollControls/RollView/Face/RollViewLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 22,
				Visible = true,
			},
		},
		["RacerHud/RollControls/AutoRoll"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(124, 0),
				Size = UDim2.fromOffset(96, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(108, 0),
				Size = UDim2.fromOffset(86, 48),
				Visible = true,
			},
		},
		["RacerHud/RollControls/AutoRoll/Face/AutoRollLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerIndex/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(780, 524),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(756, 64),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/CarsTab"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(18, 8),
				Size = UDim2.fromOffset(190, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(140, 48),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/CarsTab/Face/CarsTabLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 22,
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/ConsumablesTab"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(228, 8),
				Size = UDim2.fromOffset(270, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(168, 0),
				Size = UDim2.fromOffset(214, 48),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/ConsumablesTab/Face/ConsumablesTabLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(692, 6),
				Size = UDim2.fromOffset(52, 52),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/IndexProgress"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 92),
				Size = UDim2.fromOffset(748, 26),
				TextSize = 21,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 72),
				Size = UDim2.fromOffset(476, 22),
				TextSize = 18,
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/GridHost"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 134),
				Size = UDim2.fromOffset(748, 374),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 100),
				Size = UDim2.fromOffset(476, 168),
				Visible = true,
			},
		},
		["RacerIndex/Panel/Face/ConsumablesHost"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 134),
				Size = UDim2.fromOffset(748, 374),
				Visible = false,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 100),
				Size = UDim2.fromOffset(476, 168),
				Visible = false,
			},
		},
		["RacerStats/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(680, 472),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(656, 64),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(230, 64),
				TextSize = 34,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(200, 48),
				TextSize = 25,
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(592, 6),
				Size = UDim2.fromOffset(52, 52),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Points"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(258, 20),
				Size = UDim2.fromOffset(310, 26),
				TextSize = 22,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(220, 15),
				Size = UDim2.fromOffset(184, 22),
				TextSize = 18,
				Visible = true,
			},
		},
		["RacerStats/Panel/Face/StatsHost"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 98),
				Size = UDim2.fromOffset(648, 358),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 76),
				Size = UDim2.fromOffset(476, 192),
				Visible = true,
			},
		},
		["RacerSettings/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(600, 362),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(576, 64),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(470, 64),
				TextSize = 34,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(382, 48),
				TextSize = 25,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(512, 6),
				Size = UDim2.fromOffset(52, 52),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/SoundRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 100),
				Size = UDim2.fromOffset(568, 60),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 74),
				Size = UDim2.fromOffset(476, 50),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundToggle/Face/SoundToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 178),
				Size = UDim2.fromOffset(568, 60),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 142),
				Size = UDim2.fromOffset(476, 50),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsToggle/Face/EffectsToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/AutoRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 256),
				Size = UDim2.fromOffset(568, 60),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 210),
				Size = UDim2.fromOffset(476, 50),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
				Visible = true,
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoToggle/Face/AutoToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
				Visible = true,
			},
		},
		["RacerRebirth/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(600, 414),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 276),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(576, 64),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(470, 64),
				TextSize = 34,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(382, 48),
				TextSize = 25,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(512, 6),
				Size = UDim2.fromOffset(52, 52),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Warning"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 84),
				Size = UDim2.fromOffset(576, 82),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 58),
				Size = UDim2.fromOffset(484, 50),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Warning/WarningTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(576, 30),
				TextSize = 28,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(484, 20),
				TextSize = 18,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Warning/WarningText"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 32),
				Size = UDim2.fromOffset(576, 48),
				TextSize = 19,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 20),
				Size = UDim2.fromOffset(484, 30),
				TextSize = 12,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 170),
				Size = UDim2.fromOffset(576, 148),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 110),
				Size = UDim2.fromOffset(484, 100),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/RewardsTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(576, 30),
				TextSize = 26,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(484, 20),
				TextSize = 16,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/LuckReward"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 34),
				Size = UDim2.fromOffset(176, 112),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 22),
				Size = UDim2.fromOffset(150, 76),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/LuckReward/Face/LuckRewardIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(62, 62),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(40, 40),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/LuckReward/Face/LuckRewardCaption"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(6, 76),
				Size = UDim2.fromOffset(164, 28),
				TextSize = 18,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(4, 48),
				Size = UDim2.fromOffset(142, 22),
				TextSize = 14,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/SpeedReward"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(200, 34),
				Size = UDim2.fromOffset(176, 112),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(167, 22),
				Size = UDim2.fromOffset(150, 76),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/SpeedReward/Face/SpeedRewardIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(62, 62),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(40, 40),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/SpeedReward/Face/SpeedRewardCaption"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(6, 76),
				Size = UDim2.fromOffset(164, 28),
				TextSize = 18,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(4, 48),
				Size = UDim2.fromOffset(142, 22),
				TextSize = 14,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/PointReward"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(388, 34),
				Size = UDim2.fromOffset(176, 112),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(326, 22),
				Size = UDim2.fromOffset(150, 76),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/PointReward/Face/PointRewardIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 8),
				Size = UDim2.fromOffset(62, 62),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 4),
				Size = UDim2.fromOffset(40, 40),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Rewards/PointReward/Face/PointRewardCaption"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(6, 76),
				Size = UDim2.fromOffset(164, 28),
				TextSize = 18,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(4, 48),
				Size = UDim2.fromOffset(142, 22),
				TextSize = 14,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Requirements"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 324),
				Size = UDim2.fromOffset(376, 80),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 212),
				Size = UDim2.fromOffset(304, 58),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Requirements/RequirementsTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(376, 28),
				TextSize = 24,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(304, 18),
				TextSize = 15,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Requirements/Bar"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 36),
				Size = UDim2.fromOffset(360, 40),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 22),
				Size = UDim2.fromOffset(300, 34),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/Requirements/Bar/Face/BarText"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(360, 40),
				TextSize = 20,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(300, 34),
				TextSize = 16,
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/RebirthButton"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(400, 356),
				Size = UDim2.fromOffset(176, 48),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(320, 232),
				Size = UDim2.fromOffset(172, 38),
				Visible = true,
			},
		},
		["RacerRebirth/Panel/Face/RebirthButton/Face/RebirthButtonLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 20,
				Visible = true,
			},
		},
		["RollShowcase/Card"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(760, 320),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(540, 224),
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(760, 320),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(540, 224),
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/RollHeader"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(736, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(520, 44),
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/RollHeader/Face/RollTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 5),
				Size = UDim2.fromOffset(330, 44),
				TextSize = 28,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 2),
				Size = UDim2.fromOffset(280, 38),
				TextSize = 24,
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/PreviewCar"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(18, 84),
				Size = UDim2.fromOffset(300, 220),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 68),
				Size = UDim2.fromOffset(220, 144),
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 88),
				Size = UDim2.fromOffset(406, 46),
				TextSize = 32,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 72),
				Size = UDim2.fromOffset(294, 30),
				TextSize = 26,
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultSpeed"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 150),
				Size = UDim2.fromOffset(406, 32),
				TextSize = 23,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 112),
				Size = UDim2.fromOffset(294, 26),
				TextSize = 18,
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultRarity"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 198),
				Size = UDim2.fromOffset(406, 32),
				TextSize = 25,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 150),
				Size = UDim2.fromOffset(294, 26),
				TextSize = 20,
				Visible = true,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultOdds"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 242),
				Size = UDim2.fromOffset(406, 26),
				TextSize = 19,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 184),
				Size = UDim2.fromOffset(294, 24),
				TextSize = 17,
				Visible = true,
			},
		},
		["RacerUpgrades/TreeTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 68),
				Size = UDim2.fromOffset(250, 38),
				TextSize = 28,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 0, 62),
				Size = UDim2.fromOffset(200, 30),
				TextSize = 22,
				Visible = true,
			},
		},
		["RacerUpgrades/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -22, 0, 72),
				Size = UDim2.fromOffset(52, 52),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -12, 0, 64),
				Size = UDim2.fromOffset(48, 48),
				Visible = true,
			},
		},
		["RacerUpgrades/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 32,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 28,
				Visible = true,
			},
		},
		["RacerUpgrades/ZoomTools"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 22, 0.46, 0),
				Size = UDim2.fromOffset(120, 132),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.new(0, 12, 0.4, 0),
				Size = UDim2.fromOffset(120, 132),
				Visible = true,
			},
		},
		["RacerUpgrades/Details"] = {
			Desktop = {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -24, 1, -92),
				Size = UDim2.fromOffset(280, 146),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -78),
				Size = UDim2.fromOffset(220, 122),
				Visible = true,
			},
		},
		["RacerUpgrades/Details/Face/DetailTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 0, 30),
				TextSize = 21,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.new(1, -24, 0, 24),
				TextSize = 16,
				Visible = true,
			},
		},
		["RacerUpgrades/Details/Face/DetailBonus"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.new(1, -24, 0, 26),
				TextSize = 17,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 46),
				Size = UDim2.new(1, -24, 0, 22),
				TextSize = 14,
				Visible = true,
			},
		},
		["RacerUpgrades/Details/Face/DetailStatus"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 96),
				Size = UDim2.new(1, -24, 0, 28),
				TextSize = 19,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 82),
				Size = UDim2.new(1, -24, 0, 24),
				TextSize = 15,
				Visible = true,
			},
		},
		["RacerUpgrades/Balance"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -22),
				Size = UDim2.fromOffset(260, 42),
				TextSize = 28,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 1),
				Position = UDim2.new(0.5, 0, 1, -14),
				Size = UDim2.fromOffset(200, 34),
				TextSize = 22,
				Visible = true,
			},
		},
	},
}

-- UIScale (named "UIScale", the generated one) on each node: zoom per variant
Model.Scales = generated.Scales
-- Layout props per variant (AnchorPoint, Position, Size, TextSize, Visible when present)
Model.Nodes = generated.Nodes

-- Runtime changes the scripts make on top of the generated layout:
-- RacerUiController moves the Speed group horizontally every frame to centre its visible dial + text (SpeedDial's left
-- edge to SpeedValue's text end, HUD spec section 9) (X is live on the
-- live viewport; Model.SpeedGroup applies the same rule at a simulated one).
Model.DynamicX = { ["RacerHud/Speed"] = true }

-- The generated per-height k of a zoom-1 node (the generated fit(), also used by RacerUiController.fitPanels).
function Model.K(viewport)
	local fit = viewport.Y <= Model.PHONE_MAX_HEIGHT and Model.Phone or Model.Desktop
	return math.clamp(viewport.Y / fit.Ref, fit.Min, fit.Max)
end

-- RacerUiController (owner decision 2026-10-08, R3 clearSpeedOfToast + the centring above), every Heartbeat:
--  X: Position = UDim2(0.5, (group width - visible width) / 2, ...), so the visible dial + left-aligned number are
--     centred on the screen (AnchorPoint 0.5: the dial's left edge is screen centre - visible width / 2).
--  Y: after centring the group moves DOWN by max(0, min(need, room)), need = Toast bottom + SPEED_TOAST_GAP - group
--     top, room = Turbo top - SPEED_TURBO_GAP - group bottom. The Toast keeps its rect while hidden.
Model.SpeedRule = { ToastGap = 4, TurboGap = 2 }
-- `group` is the generated rect (ScaledHudRect), `visibleWidth` the dial + number width at that viewport, `toast` and
-- `turbo` the screen rects the rule reads. Returns the group's screen rect.
function Model.SpeedGroup(viewport, group, visibleWidth, toast, turbo)
	local r = { x = viewport.X / 2 - visibleWidth / 2, y = group.y, w = group.w, h = group.h }
	if toast and turbo then
		local need = toast.y + toast.h + Model.SpeedRule.ToastGap - r.y
		local room = turbo.y - Model.SpeedRule.TurboGap - (r.y + r.h)
		r.y += math.max(0, math.min(need, room))
	end
	return r
end

-- RacerUiController.fitPanels, every Heartbeat, for each Racer panel's outer Frame. Since the PanelBand merge it reads
-- Client/PanelBand.Rect (docs/HUD_LAYOUT_SPEC.md sections 1 and 6: below the Race button, above the TURBO LUCK bar
-- and the Money read-out, between the left grid and the Shop column), the same band as the Shop / Market:
--   band = { left, top, right, bottom } (UiShopMarket.Band, screen pixels, inset included),
--   width = right - left, height = bottom - top;
--   its UIScale = max(MinScale, min(k, width / Size.X.Offset, height / Size.Y.Offset)) (Size = generated variant size);
--   AnchorPoint (0.5, 0.5), Position UDim2.fromOffset((left + right) / 2, top + height / 2).
Model.RacerPanels = {
	Paths = { "RacerIndex/Panel", "RacerStats/Panel", "RacerSettings/Panel", "RacerRebirth/Panel" },
	Gap = 8,
	MinScale = 0.3,
}
function Model.IsRacerPanel(path)
	return table.find(Model.RacerPanels.Paths, path) ~= nil
end
-- The Navigation column's right edge as RacerUiController.fitPanels and ProgressionUi read it: Navigation's own rect
-- and the rects of its GuiObject descendants with Visible = true (the descendant's own flag, as the game reads it).
-- navigation = rect, parts = { rect, ... } (may be nil or empty).
function Model.ColumnRight(navigation, parts)
	local right = navigation.x + navigation.w
	for _, r in parts or {} do
		right = math.max(right, r.x + r.w)
	end
	return right
end

-- band = { left, top, right, bottom } (UiShopMarket.Band); size = the panel's generated variant Size (UDim2).
-- Returns { AnchorPoint, Position, Size, Scale, Band = { top, bottom, side } }.
function Model.RacerPanelFit(viewport, band, size)
	local left, top, right, bottom = band[1], band[2], band[3], band[4]
	local width, height = right - left, bottom - top
	local scale = Model.K(viewport)
	if size.X.Offset > 0 and size.Y.Offset > 0 then
		scale = math.max(Model.RacerPanels.MinScale, math.min(scale, width / size.X.Offset, height / size.Y.Offset))
	end
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((left + right) / 2, top + height / 2),
		Size = size,
		Scale = scale,
		Band = { top = top, bottom = bottom, side = left },
	}
end
-- Client/RollToast copies PreviewCar's Position / Size into these enlarged-card parts (fitRollArt, on every viewport
-- change).
Model.Follow = {
	["RollShowcase/Card/CardBody/Face/Glow"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Ring"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Reel"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Viewport"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
}
-- Client/RollToast places the compact roll's top edge RollAnimConfig.COMPACT_GAP px under the Race button
-- (fitCompact, on every viewport change): Y offset = Race Face bottom in screen pixels (AbsolutePosition.Y +
-- AbsoluteSize.Y + top-bar inset; RollToast ignores the inset) + COMPACT_GAP. The solver applies it to the live
-- properties at every simulated viewport (the live Y offset is the one fitCompact computed for the live screen).
Model.BelowRace = { ["RollToast/Toast"] = "RacerHud/Race/Face" }
-- The roll bodies animate (PopIn grows them from 0, LAND_POP, the compact Exit shrink); at rest (Hold / Idle) they
-- fill their card centred. The solver always places them at this rest geometry.
Model.Animated = {
	["RollShowcase/Card/CardBody/Face"] = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	},
	["RollToast/Toast/Body"] = {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	},
}
-- RollShowcase/Card is tweened from the compact roll's rect to its layout rect when the view opens (SWITCH) and
-- back when it closes; the solver places it at its layout rect (Nodes) once settled.
-- Components.BindIndex sizes the Index grid cells per viewport: cell width =
-- floor((GridHost design width - Inset - (columns - 1) * Gap) / columns), columns 4 on desktop and 3 on a phone, cell
-- height CellHeight (design pixels: the panel's generated UIScale applies on top).
Model.Grids = {
	["RacerIndex/Panel/Face/GridHost/Gallery"] = {
		Host = "RacerIndex/Panel/Face/GridHost",
		Inset = 14,
		Gap = 12,
		CellHeight = 208,
		Columns = { Desktop = 4, Phone = 3 },
	},
}

-- Which generated variant a viewport uses (the generated fit(): phone = ViewportSize.Y <= PHONE_MAX_HEIGHT).
function Model.VariantOf(viewport)
	return viewport.Y <= Model.PHONE_MAX_HEIGHT and "Phone" or "Desktop"
end

-- The generated UIScale.Scale of a node at a viewport (k x the node's zoom), or nil when the node has no generated
-- UIScale. UIScale scales a GuiObject about its AnchorPoint (Position stays) and its descendants with it.
function Model.ScaleAt(path, viewport)
	local zoom = Model.Scales[path]
	if not zoom then
		return nil
	end
	local variant = Model.VariantOf(viewport)
	local fit = variant == "Phone" and Model.Phone or Model.Desktop
	return math.clamp(viewport.Y / fit.Ref, fit.Min, fit.Max) * zoom[variant]
end

-- A UIScale'd top-level node's screen rect at a viewport: its generated variant UDim2 in `root` (default: the whole
-- viewport, an IgnoreGuiInset ScreenGui), its size scaled about its AnchorPoint. dynamicX replaces Position.X.
function Model.ScaledHudRect(path, viewport, dynamicX, root)
	root = root or { x = 0, y = 0, w = viewport.X, h = viewport.Y }
	local node = Model.Nodes[path][Model.VariantOf(viewport)]
	local scale = Model.ScaleAt(path, viewport) or 1
	local width = (root.w * node.Size.X.Scale + node.Size.X.Offset) * scale
	local height = (root.h * node.Size.Y.Scale + node.Size.Y.Offset) * scale
	local px = dynamicX or node.Position.X
	return {
		x = root.x + root.w * px.Scale + px.Offset - node.AnchorPoint.X * width,
		y = root.y + root.h * node.Position.Y.Scale + node.Position.Y.Offset - node.AnchorPoint.Y * height,
		w = width,
		h = height,
	}
end

-- Race Face fills the generated Race wrapper. Its UIScale changes at each hypothetical viewport,
-- independently of the live Studio camera, so dependent compact/panel geometry must use this rectangle.
function Model.RaceFaceRect(viewport)
	return Model.ScaledHudRect("RacerHud/Race", viewport)
end

-- The enlarged roll card (RollShowcase/Card) settled: the generated variant (Client/RollToast cardTargetSize() sets
-- the same Size per variant, CARD_POS the same Position) scaled by its generated UIScale about its centre.
function Model.CardRect(viewport, root)
	return Model.ScaledHudRect("RollShowcase/Card", viewport, nil, root)
end

-- Client/HudChrome refresh() (docs/HUD_LAYOUT_SPEC.md section 1), every 0.25 s and on every PanelSwitch change:
--   each tile holder (Grid, ShopColumn, ItemsSlot, UpgradeSlot) has a UIScale "Scale" = (phone and Phone or 1) x
--   (BottomScale for the bottom pair); TopRight's UIScale "Scale" = phone and BarPhone or 1 (phone = viewport height
--   <= PHONE_MAX_HEIGHT). Grid / ShopColumn take HolderPositions[variant]. ItemsSlot's Position =
--   fromOffset(left - SlotGap, gap), UpgradeSlot's = fromOffset(right + SlotGap, gap), where left / right are the
--   outer edges of RacerHud/Level and RacerHud/Turbo together and gap = (Level bottom + Turbo top) / 2, in screen
--   pixels (HudChrome ignores the inset). The pair is Visible only when Level and Turbo exist.
--   Owner 2026-10-28 (section 6): at viewport height <= StackMaxHeight the pair stacks ABOVE the bars instead:
--   AnchorPoint (1, 1) / (0, 1), bottom y = min(Level top, Money top) - StackGap, ItemsSlot x = min(left, Speed
--   left) - StackGap, UpgradeSlot x = max(right, Speed right) + StackGap (Money / Speed only when visible).
Model.HudChrome = {
	Phone = 0.68,
	BottomScale = 0.75,
	BarPhone = 0.8,
	SlotGap = 10,
	ScaleName = "Scale",
	HolderPositions = {
		["HudChrome/Grid"] = { Desktop = UDim2.new(0, 14, 0.5, -24), Phone = UDim2.new(0, 8, 0.5, -20) },
		["HudChrome/ShopColumn"] = { Desktop = UDim2.new(1, -14, 0.5, -24), Phone = UDim2.new(1, -8, 0.5, -20) },
	},
	Slots = { ["HudChrome/ItemsSlot"] = "left", ["HudChrome/UpgradeSlot"] = "right" },
	Level = "RacerHud/Level",
	Turbo = "RacerHud/Turbo",
	Bar = "HudChrome/TopRight",
	-- Owner 2026-10-28 (docs/HUD_LAYOUT_SPEC.md section 6): the bottom pair shrinks about its anchor until its cell
	-- (Cell x k, anchored at (1 | 0, IconMid)) clears every visible Blocker; steps of Step x base, floor Floor x base.
	Cell = Vector2.new(84, 94), -- HudChrome CELL = (TILE + 12, TILE + LABEL), TILE 72, LABEL 22
	IconMid = 36 / 94, -- ICON_MID = TILE / 2 / (TILE + LABEL)
	Step = 0.02,
	Floor = 0.3,
	Blockers = { "RacerHud/Money", "RacerHud/Speed" },
	StackMaxHeight = 400, -- HudChrome STACK_MAX_HEIGHT (phone_small, owner 2026-10-28)
	StackGap = 6,
	Money = "RacerHud/Money",
	Speed = "RacerHud/Speed",
}
-- HudChrome's UIScale "Scale" factor of the node at `path` at a viewport, or nil when it is not a HudChrome holder.
function Model.HudChromeScale(path, viewport)
	local cfg = Model.HudChrome
	local phone = viewport.Y <= Model.PHONE_MAX_HEIGHT
	if path == cfg.Bar then
		return phone and cfg.BarPhone or 1
	end
	if cfg.HolderPositions[path] or cfg.Slots[path] then
		return (phone and cfg.Phone or 1) * (cfg.Slots[path] and cfg.BottomScale or 1)
	end
	return nil
end
-- The bottom pair's unshrunk placement: { [slot path] = { Position = Vector2 (screen offsets), Anchor = Vector2 } }
-- from the Level / Turbo screen rects and `shown` = { [path] = rect } of the visible Blockers (Money, Speed).
function Model.HudChromePair(viewport, level, turbo, shown)
	local cfg = Model.HudChrome
	local left = math.min(level.x, turbo.x)
	local right = math.max(level.x + level.w, turbo.x + turbo.w)
	local out = {}
	if viewport.Y <= cfg.StackMaxHeight then
		local speed, money = shown[cfg.Speed], shown[cfg.Money]
		local y = math.min(level.y, money and money.y or math.huge) - cfg.StackGap
		for path, side in cfg.Slots do
			if side == "left" then
				out[path] = {
					Position = Vector2.new(math.min(left, speed and speed.x or left) - cfg.StackGap, y),
					Anchor = Vector2.new(1, 1),
				}
			else
				out[path] = {
					Position = Vector2.new(math.max(right, speed and speed.x + speed.w or right) + cfg.StackGap, y),
					Anchor = Vector2.new(0, 1),
				}
			end
		end
		return out
	end
	local gap = (level.y + level.h + turbo.y) / 2
	for path, side in cfg.Slots do
		if side == "left" then
			out[path] = { Position = Vector2.new(left - cfg.SlotGap, gap), Anchor = Vector2.new(1, cfg.IconMid) }
		else
			out[path] = { Position = Vector2.new(right + cfg.SlotGap, gap), Anchor = Vector2.new(0, cfg.IconMid) }
		end
	end
	return out
end
-- The bottom pair's shrunk UIScale (HudChrome refresh, owner 2026-10-28): the base pair scale lowered in Step
-- steps until both cells (about their anchors) clear every visible blocker rect, never below Floor x base.
function Model.HudChromePairScale(viewport, level, turbo, shown)
	local cfg = Model.HudChrome
	local base = (viewport.Y <= Model.PHONE_MAX_HEIGHT and cfg.Phone or 1) * cfg.BottomScale
	local pair = Model.HudChromePair(viewport, level, turbo, shown)
	local function clear(k)
		local w, h = cfg.Cell.X * k, cfg.Cell.Y * k
		for _, slot in pair do
			local x = slot.Position.X - slot.Anchor.X * w
			local y = slot.Position.Y - slot.Anchor.Y * h
			for _, b in shown do
				if x < b.x + b.w and x + w > b.x and y < b.y + b.h and y + h > b.y then
					return false
				end
			end
		end
		return true
	end
	local k = base
	while k > base * cfg.Floor and not clear(k) do
		k -= base * cfg.Step
	end
	return k
end
-- The bottom pair's Position (UDim2 screen offsets) and AnchorPoint, or nil for other paths.
function Model.HudChromeSlot(path, viewport, level, turbo, shown)
	if not Model.HudChrome.Slots[path] then
		return nil
	end
	local slot = Model.HudChromePair(viewport, level, turbo, shown)[path]
	return UDim2.fromOffset(slot.Position.X, slot.Position.Y), slot.Anchor
end
-- AutomaticSize nodes whose content does not depend on the viewport (fixed TextSize captions in HudChrome's pills):
-- the solver measures their size live (AbsoluteSize divided by the live UIScale factors, i.e. design pixels) and
-- applies the simulated viewport's UIScale factors to it. Patterns as in UiSpec button paths ("*" = one segment).
Model.LiveAutoSize = { "HudChrome/TopRight", "HudChrome/TopRight/*", "HudChrome/TopRight/*/Caption" }
-- UIScales that are player state, not viewport layout (UpgradeTreeView's TreeZoom: + / - buttons and the mouse
-- wheel): read live at every viewport.
Model.LiveScales = { TreeZoom = true }

-- ProgressionUi's Heartbeat fit rules. Model input only: panel clearance and overlap limits remain in UiSpec.
function Model.Progression(path, viewport, dependencies)
	if path == "RacerProgression/WorkshopRate" then
		-- R4 (owner decision 2026-10-08): centred 28 px above the Speed group's top; when that top would be above
		-- Toast bottom + 4 (inside the compact roll) it sits right of the Speed group instead: x = Speed right + 8,
		-- width max(60, viewport X - x - 12), height 24, vertically centred on Speed (TextSize 12, left aligned).
		local speed = assert(dependencies and dependencies.Speed, "virtual Speed rectangle required")
		local width = math.min(300, viewport.X - 24)
		local top = speed.y - 28
		local toast = dependencies.Toast
		if toast and top < toast.y + toast.h + 4 then
			local left = speed.x + speed.w + 8
			return {
				AnchorPoint = Vector2.zero,
				Position = UDim2.fromOffset(left, speed.y + speed.h / 2 - 12),
				Size = UDim2.fromOffset(math.max(60, viewport.X - left - 12), 24),
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
			}
		end
		return {
			AnchorPoint = Vector2.zero,
			Position = UDim2.new(0.5, -width / 2, 0, top),
			Size = UDim2.fromOffset(width, 24),
			TextSize = 16,
			TextXAlignment = Enum.TextXAlignment.Center,
		}
	elseif path == "RacerProgression/WeatherIcon" then
		-- It replaced WeatherBanner (owner 2026-10-13, docs/WEATHER_EVENTS_SPEC.md "Weather icon"): 44 x 44, 8 px
		-- from the right and bottom edges; on phones its right edge is 140 px in, left of the Market button.
		local phone = viewport.Y <= Model.PHONE_MAX_HEIGHT
		return {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, phone and -140 or -8, 1, -8),
			Size = UDim2.fromOffset(44, 44),
		}
	end
	return nil
end

return Model
