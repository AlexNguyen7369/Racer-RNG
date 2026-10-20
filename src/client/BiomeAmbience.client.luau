--!nonstrict
-- Local-only motion for biome props (docs/BIOME_DRESSING_SPEC.md "Ambient motion"):
-- models tagged BiomeSpin turn about their vertical axis, BiomeBob ones rock like a moored ship.
-- Only props near the camera move; the server's copies never change.

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local AMBIENCE_DISTANCE = 300 -- studs from the camera
local SPIN_SPEED = 0.6 -- radians per second
local BOB_HEIGHT = 1.2 -- studs
local BOB_RATE = 1.4 -- radians per second

local bases = {} -- model -> { Pivot, Kind }

local function track(kind)
	local function add(model)
		if model:IsA("Model") then
			bases[model] = { Pivot = model:GetPivot(), Kind = kind }
		end
	end
	for _, model in CollectionService:GetTagged(kind) do
		add(model)
	end
	CollectionService:GetInstanceAddedSignal(kind):Connect(add)
	CollectionService:GetInstanceRemovedSignal(kind):Connect(function(model)
		bases[model] = nil
	end)
end
track("BiomeSpin")
track("BiomeBob")

RunService.RenderStepped:Connect(function()
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local t = os.clock()
	for model, base in bases do
		if (base.Pivot.Position - eye).Magnitude < AMBIENCE_DISTANCE then
			if base.Kind == "BiomeSpin" then
				model:PivotTo(base.Pivot * CFrame.Angles(0, t * SPIN_SPEED, 0))
			else
				local phase = t * BOB_RATE + base.Pivot.Position.X * 0.01
				model:PivotTo(
					base.Pivot
						* CFrame.new(0, math.sin(phase) * BOB_HEIGHT, 0)
						* CFrame.Angles(0, 0, math.sin(phase * 0.7) * 0.05)
				)
			end
		end
	end
end)
