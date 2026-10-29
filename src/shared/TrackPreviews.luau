--!nonstrict
-- Checkpoint card previews (docs/CHECKPOINT_SPEC.md section 4): the server copies the real scenery around each
-- track's start gate into ReplicatedStorage.TrackPreviews, so every client can show it in a ViewportFrame even
-- while streaming has the track itself unloaded. Presentation only: nothing here collides, touches or moves.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TrackPreviews = {}

TrackPreviews.RADIUS = 90 -- studs around the gate that make the shot (placeholder)
TrackPreviews.MAX_PARTS = 350 -- per track, nearest first: bounds what every client downloads (placeholder)

local KEEP = { "SpecialMesh", "Decal", "Texture", "SurfaceAppearance", "UICorner" }

local function strip(part)
	for _, child in part:GetChildren() do
		if not table.find(KEEP, child.ClassName) then
			child:Destroy()
		end
	end
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
end

-- Copies the start-gate surroundings of every track model ({ Model, Name }) into ReplicatedStorage.TrackPreviews.
-- Each copy is a Model named after its track with attribute Focus (CFrame of the gate).
function TrackPreviews.Bake(trackModels)
	local folder = ReplicatedStorage:FindFirstChild("TrackPreviews") or Instance.new("Folder")
	folder.Name = "TrackPreviews"
	folder:ClearAllChildren()
	for _, model in trackModels do
		local gate = model:FindFirstChild("Gate", true) or model:FindFirstChild("Start", true)
		if gate then
			local focus = gate:IsA("Model") and gate:GetPivot() or gate.CFrame
			local near = {}
			for _, part in model:GetDescendants() do
				if part:IsA("BasePart") and part.Transparency < 1 then
					local reach = (part.Position - focus.Position).Magnitude - part.Size.Magnitude / 2
					if reach <= TrackPreviews.RADIUS then
						table.insert(near, { Part = part, Reach = reach })
					end
				end
			end
			table.sort(near, function(a, b)
				return a.Reach < b.Reach
			end)
			local copy = Instance.new("Model")
			copy.Name = model.Name
			copy:SetAttribute("Focus", focus)
			for i = 1, math.min(#near, TrackPreviews.MAX_PARTS) do
				local ok, clone = pcall(function()
					return near[i].Part:Clone()
				end)
				if ok and clone then
					strip(clone)
					clone.Parent = copy
				end
			end
			copy.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
	return folder
end

return TrackPreviews
