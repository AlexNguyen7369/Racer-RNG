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
		["RacerHud/Navigation"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Speed"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Money"] = { Desktop = 1, Phone = 1 },
		["RacerHud/Turbo"] = { Desktop = 1, Phone = 1 },
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
-- RacerUiController moves the Speed group horizontally every frame to centre its visible icon + text (X is live on the
-- live viewport; Model.SpeedGroup applies the same rule at a simulated one).
Model.DynamicX = { ["RacerHud/Speed"] = true }

-- The generated per-height k of a zoom-1 node (the generated fit(), also used by RacerUiController.fitPanels).
function Model.K(viewport)
	local fit = viewport.Y <= Model.PHONE_MAX_HEIGHT and Model.Phone or Model.Desktop
	return math.clamp(viewport.Y / fit.Ref, fit.Min, fit.Max)
end

-- RacerUiController (owner decision 2026-10-08, R3 clearSpeedOfToast + the centring above), every Heartbeat:
--  X: Position = UDim2(0.5, (group width - visible width) / 2, ...), so the visible icon + left-aligned number are
--     centred on the screen (AnchorPoint 0.5: the icon's left edge is screen centre - visible width / 2).
--  Y: after centring the group moves DOWN by max(0, min(need, room)), need = Toast bottom + SPEED_TOAST_GAP - group
--     top, room = Turbo top - SPEED_TURBO_GAP - group bottom. The Toast keeps its rect while hidden.
Model.SpeedRule = { ToastGap = 4, TurboGap = 2 }
-- `group` is the generated rect (ScaledHudRect), `visibleWidth` the icon + number width at that viewport, `toast` and
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

-- RacerUiController.fitPanels (owner decision 2026-10-08, R2), every Heartbeat, for each Racer panel's outer Frame:
--   band top = Race Face bottom + Gap, band bottom = RacerHud/Turbo top - Gap (screen pixels, inset included),
--   side = column right + Gap, where column right = the max right edge of RacerHud/Navigation and every GuiObject
--   descendant of it whose own Visible is true (the STATS PointsBadge sticks out; Model.ColumnRight),
--   width = viewport X - 2 * side, height = bottom - top;
--   its UIScale = max(MinScale, min(k, width / Size.X.Offset, height / Size.Y.Offset)) (Size = generated variant size);
--   AnchorPoint (0.5, 0.5), Position UDim2(0.5, 0, 0, top + height / 2).
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

-- deps = { Race = rect, Turbo = rect, Navigation = rect, NavigationParts = { rect, ... } }; size = the panel's
-- generated variant Size (UDim2). Returns { AnchorPoint, Position, Size, Scale, Band = { top, bottom, side } }.
function Model.RacerPanelFit(viewport, deps, size)
	local gap = Model.RacerPanels.Gap
	local top = deps.Race.y + deps.Race.h + gap
	local bottom = deps.Turbo.y - gap
	local side = Model.ColumnRight(deps.Navigation, deps.NavigationParts) + gap
	local width, height = viewport.X - 2 * side, bottom - top
	local scale = Model.K(viewport)
	if size.X.Offset > 0 and size.Y.Offset > 0 then
		scale = math.max(Model.RacerPanels.MinScale, math.min(scale, width / size.X.Offset, height / size.Y.Offset))
	end
	return {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0, top + height / 2),
		Size = size,
		Scale = scale,
		Band = { top = top, bottom = bottom, side = side },
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

-- ProgressionUi's Heartbeat fit rules. Model input only: panel clearance and overlap limits remain in UiSpec.
function Model.Progression(path, viewport, dependencies)
	if path == "RacerUpgrades/Panel" or path == "RacerWorkshop/Panel" or path == "RacerWelcome/Panel" then
		local toast = assert(dependencies and dependencies.Toast, "virtual Toast rectangle required")
		local turbo = assert(dependencies.Turbo, "virtual Turbo rectangle required")
		local top = toast.y + toast.h + 8
		local bottom = turbo.y - 8
		-- Non-phone: the base width, then narrowed so the centred panel clears the Navigation column (badge
		-- included, Model.ColumnRight) + 8 on the left and the mirrored band on the right; never under 100.
		local baseWidth = viewport.Y > 700 and math.min(700, viewport.X - 284) or math.min(700, viewport.X * 0.82)
		local navigation = assert(dependencies.Navigation, "virtual Navigation rectangle required")
		local columnRight = Model.ColumnRight(navigation, dependencies.NavigationParts)
		local width = math.max(100, math.min(baseWidth, viewport.X - 2 * (columnRight + 8)))
		if viewport.Y <= 500 then
			local entry = assert(dependencies.UpgradeButton, "virtual UpgradeButton rectangle required")
			local right = toast.x + toast.w + 12
			local sideWidth = math.max(100, math.min(300, viewport.X - right - 16))
			top = entry.y + entry.h + 8
			return {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, -16, 0, top),
				Size = UDim2.fromOffset(sideWidth, math.max(112, bottom - top)),
			}
		end
		return {
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, top),
			Size = UDim2.fromOffset(width, math.max(112, bottom - top)),
		}
	elseif path == "RacerProgression/WorkshopRate" then
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
	elseif path == "RacerProgression/WeatherBanner" then
		return {
			AnchorPoint = Vector2.zero,
			Position = UDim2.fromOffset(16, 12),
			Size = UDim2.fromOffset(math.min(220, viewport.X * 0.28), 42),
		}
	end
	return nil
end

return Model
