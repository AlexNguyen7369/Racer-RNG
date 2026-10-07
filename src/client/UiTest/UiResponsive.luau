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
-- 53ff23d7d9f8, RacerSettings f7eec9b472c5, RacerRebirth 872eec02bc4b, RollShowcase 1039b947bbd9). RacerHud/Settings
-- has a UIScale but no layout row: its UDim2 is the baked one at every viewport.

local Model = {}

-- The generated fit(): phone = ViewportSize.Y <= PHONE_MAX_HEIGHT;
-- k = phone and clamp(Y / 390, 0.85, 1.15) or clamp(Y / 720, 0.6, 1.4); UIScale.Scale = k x the node's zoom.
Model.PHONE_MAX_HEIGHT = 500
Model.Desktop = { Ref = 720, Min = 0.6, Max = 1.4 }
Model.Phone = { Ref = 390, Min = 0.85, Max = 1.15 }

local generated = {
	Scales = {
		["RacerHud/Race"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Navigation"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Speed"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Money"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Turbo"] = { Desktop = 1, Phone = 1 },
		["RacerHud/RollControls"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Settings"] = { Desktop = 1, Phone = 1 },
		["RacerIndex/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerStats/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerSettings/Panel"] = { Desktop = 1, Phone = 1 },
		["RacerRebirth/Panel"] = { Desktop = 1, Phone = 1 },
		["RollShowcase/Card"] = { Desktop = 1, Phone = 1 },
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
		["RacerHud/Navigation"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 22, 0.45, 0),
				Size = UDim2.fromOffset(160, 206),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 12, 0.44, 0),
				Size = UDim2.fromOffset(118, 184),
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
				Position = UDim2.fromOffset(0, 74),
				Size = UDim2.fromOffset(160, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 66),
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
				Position = UDim2.fromOffset(0, 148),
				Size = UDim2.fromOffset(160, 54),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 132),
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
		["RacerHud/Speed/SpeedIcon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(88, 88),
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(64, 64),
				Visible = true,
			},
		},
		["RacerHud/Speed/SpeedValue"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(100, 33),
				Size = UDim2.fromOffset(206, 42),
				TextSize = 34,
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(76, 23),
				Size = UDim2.fromOffset(174, 34),
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
				Visible = true,
			},
			Phone = {
				AnchorPoint = Vector2.new(1, 1),
				Position = UDim2.new(1, -12, 1, -16),
				Size = UDim2.fromOffset(194, 48),
				Visible = true,
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
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
			},
		},
		["RacerIndex/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(756, 64),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
			},
		},
		["RacerIndex/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(650, 64),
				TextSize = 34,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(382, 48),
				TextSize = 25,
			},
		},
		["RacerIndex/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(692, 6),
				Size = UDim2.fromOffset(52, 52),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
			},
		},
		["RacerIndex/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
			},
		},
		["RacerIndex/Panel/Face/IndexProgress"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 92),
				Size = UDim2.fromOffset(748, 26),
				TextSize = 21,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 72),
				Size = UDim2.fromOffset(476, 22),
				TextSize = 18,
			},
		},
		["RacerIndex/Panel/Face/GridHost"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 134),
				Size = UDim2.fromOffset(748, 374),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 100),
				Size = UDim2.fromOffset(476, 168),
			},
		},
		["RacerStats/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(680, 472),
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
			},
		},
		["RacerStats/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(656, 64),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
			},
		},
		["RacerStats/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(230, 64),
				TextSize = 34,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(200, 48),
				TextSize = 25,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(592, 6),
				Size = UDim2.fromOffset(52, 52),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
			},
		},
		["RacerStats/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
			},
		},
		["RacerStats/Panel/Face/Header/Face/Points"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(258, 20),
				Size = UDim2.fromOffset(310, 26),
				TextSize = 22,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(220, 15),
				Size = UDim2.fromOffset(184, 22),
				TextSize = 18,
			},
		},
		["RacerStats/Panel/Face/StatsHost"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 98),
				Size = UDim2.fromOffset(648, 358),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 76),
				Size = UDim2.fromOffset(476, 192),
			},
		},
		["RacerSettings/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(600, 362),
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
			},
		},
		["RacerSettings/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(576, 64),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(470, 64),
				TextSize = 34,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(382, 48),
				TextSize = 25,
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(512, 6),
				Size = UDim2.fromOffset(52, 52),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
			},
		},
		["RacerSettings/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
			},
		},
		["RacerSettings/Panel/Face/SoundRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 100),
				Size = UDim2.fromOffset(568, 60),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 74),
				Size = UDim2.fromOffset(476, 50),
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
			},
		},
		["RacerSettings/Panel/Face/SoundRow/Face/SoundToggle/Face/SoundToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 178),
				Size = UDim2.fromOffset(568, 60),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 142),
				Size = UDim2.fromOffset(476, 50),
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
			},
		},
		["RacerSettings/Panel/Face/EffectsRow/Face/EffectsToggle/Face/EffectsToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
			},
		},
		["RacerSettings/Panel/Face/AutoRow"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(16, 256),
				Size = UDim2.fromOffset(568, 60),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 210),
				Size = UDim2.fromOffset(476, 50),
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(400, 60),
				TextSize = 25,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(338, 50),
				TextSize = 20,
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoToggle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(436, 6),
				Size = UDim2.fromOffset(116, 48),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(356, 1),
				Size = UDim2.fromOffset(108, 48),
			},
		},
		["RacerSettings/Panel/Face/AutoRow/Face/AutoToggle/Face/AutoToggleLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 23,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 21,
			},
		},
		["RacerRebirth/Panel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.55, 0.52),
				Size = UDim2.fromOffset(600, 362),
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.62, 0.56),
				Size = UDim2.fromOffset(500, 280),
			},
		},
		["RacerRebirth/Panel/Face/Header"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(576, 64),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 8),
				Size = UDim2.fromOffset(484, 48),
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Title"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 0),
				Size = UDim2.fromOffset(470, 64),
				TextSize = 34,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 0),
				Size = UDim2.fromOffset(382, 48),
				TextSize = 25,
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Close"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(512, 6),
				Size = UDim2.fromOffset(52, 52),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(428, 0),
				Size = UDim2.fromOffset(48, 48),
			},
		},
		["RacerRebirth/Panel/Face/Header/Face/Close/Face/CloseLabel"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 26,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromScale(1, 1),
				TextSize = 24,
			},
		},
		["RacerRebirth/Panel/Face/ComingSoon"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.6),
				Size = UDim2.fromOffset(450, 80),
				TextSize = 40,
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.6),
				Size = UDim2.fromOffset(400, 70),
				TextSize = 32,
			},
		},
		["RollShowcase/Card"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(760, 320),
			},
			Phone = {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.46),
				Size = UDim2.fromOffset(540, 224),
			},
		},
		["RollShowcase/Card/CardBody"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(760, 320),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(540, 224),
			},
		},
		["RollShowcase/Card/CardBody/Face/RollHeader"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 12),
				Size = UDim2.fromOffset(736, 54),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(10, 10),
				Size = UDim2.fromOffset(520, 44),
			},
		},
		["RollShowcase/Card/CardBody/Face/RollHeader/Face/RollTitle"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(12, 5),
				Size = UDim2.fromOffset(330, 44),
				TextSize = 28,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 2),
				Size = UDim2.fromOffset(280, 38),
				TextSize = 24,
			},
		},
		["RollShowcase/Card/CardBody/Face/PreviewCar"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(18, 84),
				Size = UDim2.fromOffset(300, 220),
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(8, 68),
				Size = UDim2.fromOffset(220, 144),
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultName"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 88),
				Size = UDim2.fromOffset(406, 46),
				TextSize = 32,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 72),
				Size = UDim2.fromOffset(294, 30),
				TextSize = 26,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultSpeed"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 150),
				Size = UDim2.fromOffset(406, 32),
				TextSize = 23,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 112),
				Size = UDim2.fromOffset(294, 26),
				TextSize = 18,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultRarity"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 198),
				Size = UDim2.fromOffset(406, 32),
				TextSize = 25,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 150),
				Size = UDim2.fromOffset(294, 26),
				TextSize = 20,
			},
		},
		["RollShowcase/Card/CardBody/Face/ResultOdds"] = {
			Desktop = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(334, 242),
				Size = UDim2.fromOffset(406, 26),
				TextSize = 19,
			},
			Phone = {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(236, 184),
				Size = UDim2.fromOffset(294, 24),
				TextSize = 17,
			},
		},
	},
}

-- UIScale (named "UIScale", the generated one) on each node: zoom per variant
Model.Scales = generated.Scales
-- Layout props per variant (AnchorPoint, Position, Size, TextSize, Visible when present)
Model.Nodes = generated.Nodes

-- Runtime changes the scripts make on top of the generated layout:
-- RacerUiController moves the Speed group horizontally every frame to centre its visible icon + text (X is live).
Model.DynamicX = { ["RacerHud/Speed"] = true }
-- Client/RollToast copies PreviewCar's Position / Size into these enlarged-card parts (fitRollArt, on every viewport
-- change).
Model.Follow = {
	["RollShowcase/Card/CardBody/Face/Glow"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Ring"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Reel"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
	["RollShowcase/Card/CardBody/Face/Viewport"] = "RollShowcase/Card/CardBody/Face/PreviewCar",
}
-- Client/RollToast places the compact roll's top edge RollAnimConfig.COMPACT_GAP px under the Race button
-- (fitCompact, on every viewport change): Y offset = Race Face AbsolutePosition.Y + AbsoluteSize.Y + COMPACT_GAP.
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
-- floor((GridHost design width - Inset - (columns - 1) * Gap) / columns), columns 4 on desktop and 3 on a phone.
Model.Grids = {
	["RacerIndex/Panel/Face/GridHost/Gallery"] = {
		Host = "RacerIndex/Panel/Face/GridHost",
		Inset = 14,
		Gap = 12,
		Columns = { Desktop = 4, Phone = 3 },
	},
}

return Model
