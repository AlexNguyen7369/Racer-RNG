--!nonstrict
-- VFX showcase area (docs/ADMIN_COMMANDS_SPEC.md, owner 2026-10-26): a flat testing floor far east of the track
-- chain, reached only with `/tp vfxarea`. Client/VfxShowcase drives one local car per Market trail / aura here.
local VfxArea = {}

VfxArea.CENTER = Vector3.new(1600, 0, 0) -- the world's parts end near x = 700
VfxArea.FLOOR_SIZE = Vector3.new(280, 1, 140)
VfxArea.SHOW_RADIUS = 400 -- the client builds the showcase while its avatar is this close to CENTER
VfxArea.LANE_GAP = 38 -- studs between showcase loops, along x
VfxArea.Items = { -- kind, Market item id; one lane each, left to right
	{ "Trail", "rainbow_trail" },
	{ "Trail", "solar_trail" },
	{ "Trail", "void_trail" },
	{ "Aura", "azure_aura" },
	{ "Aura", "ember_aura" },
	{ "Aura", "galaxy_aura" },
	{ "Aura", "ascended_aura" }, -- draft, not sold (design doc "Draft aura")
}

local FLOOR_TOP = VfxArea.CENTER.Y + 0.5

-- Where `/tp vfxarea` puts the avatar: the near edge of the floor, facing the lanes.
function VfxArea.SpawnCFrame()
	local at = VfxArea.CENTER + Vector3.new(0, 0.5 + 3, VfxArea.FLOOR_SIZE.Z / 2 - 12)
	return CFrame.lookAt(at, Vector3.new(VfxArea.CENTER.X, at.Y, VfxArea.CENTER.Z))
end

-- Centre of lane i's loop, on the floor.
function VfxArea.LaneCentre(i)
	return Vector3.new(
		VfxArea.CENTER.X + (i - (#VfxArea.Items + 1) / 2) * VfxArea.LANE_GAP,
		FLOOR_TOP,
		VfxArea.CENTER.Z - 10
	)
end

function VfxArea.Build()
	local model = Instance.new("Model")
	model.Name = "VfxArea"
	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored, floor.Size = true, VfxArea.FLOOR_SIZE
	floor.Position = VfxArea.CENTER
	floor.Color, floor.Material = Color3.fromRGB(120, 130, 150), Enum.Material.SmoothPlastic -- the track road colour
	floor.TopSurface, floor.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	floor.Parent = model
	local sign = Instance.new("BillboardGui")
	sign.Name = "Sign"
	sign.Size, sign.StudsOffset = UDim2.fromOffset(320, 60), Vector3.new(0, 12, -VfxArea.FLOOR_SIZE.Z / 2 + 6)
	sign.MaxDistance = VfxArea.SHOW_RADIUS
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Text, text.TextScaled, text.Font = "VFX SHOWCASE  ·  /tp home", true, Enum.Font.GothamBlack
	text.TextColor3, text.TextStrokeTransparency = Color3.new(1, 1, 1), 0
	text.Parent = sign
	sign.Parent = floor
	model.PrimaryPart = floor
	return model
end

return VfxArea
