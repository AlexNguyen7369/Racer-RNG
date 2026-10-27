--!nonstrict
-- BRIEF: docs/CAR_REDESIGN_SPEC.md sections 2, 4, 5 and 7 (owner, 2026-10-20) + docs/VEHICLE_SKINS_SPEC.md:
-- every redesigned car is a MeshPart skin from RedesignCarModels that wins in CarModels (attribute Redesign),
-- non-colliding and massless, inside |x| <= 1.95, |z| <= 3.3, y >= 0, named by material group with all four
-- Wheel_* or none, shown in its reference colours (no catalog Tint), and the three event cars use their own model.
-- Update (owner, 2026-10-20, section 2): ALL catalog cars except starter and ember_wyvern are redesigned; part names
-- are a base group name plus an optional number (Light2, Accent3); Light* is Neon, Glass* Glass, Metal* Metal;
-- Singularity has a bright neon-gold Light* part.
-- Update (owner, 2026-10-27, sections 1 and 9): only starter is excluded; ember_wyvern is a special-case ride whose
-- part names may also be Wing_L / Wing_R (each with its PivotOffset on the flap hinge) and whose textured parts carry
-- a SurfaceAppearance with ColorMap + NormalMap.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local H = require(script.Parent.AcceptanceSupport)
local Tests = {}

-- Every catalog car (index + gamepass) must be redesigned, except these (no reference image, spec section 1).
local NOT_REDESIGNED = { starter = true }
-- Special-case rides (spec section 9): may add the skin spec's animated parts and use textures.
local SPECIAL_CASE = { ember_wyvern = true }
local WING_NAMES = { Wing_L = true, Wing_R = true }
-- Wave 1 (spec section 6): a documented subset of the required set; each must also be in the derived list.
local WAVE_1 = {
	"rusty_hatchback",
	"wooden_car",
	"go_kart",
	"midnight_kart",
	"street_racer",
	"rain_runner",
	"rocket_car",
	"golden_racer",
	"hover_car",
	"void_racer",
	"singularity",
}
local OWN_MODEL = { "midnight_kart", "golden_racer", "rain_runner" } -- spec section 5
local BASE_NAMES = { Body = true, Trim = true, Accent = true, Glass = true, Metal = true, Light = true }
local WHEEL_NAMES = { Wheel_FL = true, Wheel_FR = true, Wheel_RL = true, Wheel_RR = true }
-- Group a part name belongs to ("Light2" -> "Light"), or nil when the name is not allowed.
-- Wing_L / Wing_R are allowed only on special-case rides.
local function groupOf(name, special)
	if WHEEL_NAMES[name] or (special and WING_NAMES[name]) then
		return name
	end
	local base = string.match(name, "^(%a+)%d*$")
	return base and BASE_NAMES[base] and base or nil
end
local GROUP_MATERIAL = { Light = Enum.Material.Neon, Glass = Enum.Material.Glass, Metal = Enum.Material.Metal }
local function isNeonGold(part)
	local c = part.Color
	return part.Material == Enum.Material.Neon and c.R >= 0.9 and c.G >= 0.55 and c.G <= 0.85 and c.B <= 0.35
end
local WHEELS = { "Wheel_FL", "Wheel_FR", "Wheel_RL", "Wheel_RR" }
local MAX_X, MAX_Z, MIN_Y, TOLERANCE = 1.95, 3.3, -0.01, 0.02

-- Extent of the template's parts in its own pivot space (the "identity pivot" view), from every part corner.
local function bounds(model)
	local pivot = model:GetPivot()
	local maxX, maxZ, minY = 0, 0, math.huge
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			local cf = pivot:ToObjectSpace(part.CFrame)
			local h = part.Size / 2
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					for _, sz in { -1, 1 } do
						local p = cf:PointToWorldSpace(Vector3.new(sx * h.X, sy * h.Y, sz * h.Z))
						maxX = math.max(maxX, math.abs(p.X))
						maxZ = math.max(maxZ, math.abs(p.Z))
						minY = math.min(minY, p.Y)
					end
				end
			end
		end
	end
	return maxX, maxZ, minY
end

local function sameColour(a, b)
	return math.abs(a.R - b.R) < 1e-3 and math.abs(a.G - b.G) < 1e-3 and math.abs(a.B - b.B) < 1e-3
end

local function baseParts(root)
	local out = {}
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(out, part)
		end
	end
	return out
end

function Tests.car_redesign()
	local r, flag = H.report("car_redesign")
	local catalog = H.module(Shared, "CarCatalog")
	local appearance = H.module(Shared, "CarAppearance")
	local factory = H.module(Shared, "CarFactory")
	local bodyConfig = H.module(Shared, "CarConfig")
	local api = catalog and appearance and factory and bodyConfig
	flag("redesign_api_exists", api ~= nil and api ~= false)
	if not api then
		return r
	end
	local cleanup = {}
	local ok, err = pcall(function()
		local source = ReplicatedStorage:FindFirstChild("RedesignCarModels")
		local templates = ReplicatedStorage:FindFirstChild("CarModels")
		flag("redesign_folder_exists", source ~= nil)
		flag("redesign_car_models_exists", templates ~= nil)
		-- Delivered = every child of RedesignCarModels, plus every required id (which must be delivered).
		local required, isRequired = {}, {}
		for _, list in { catalog.All(), catalog.Passes and catalog.Passes() or {} } do
			for _, spec in list do
				if not NOT_REDESIGNED[spec.Id] and not isRequired[spec.Id] then
					isRequired[spec.Id] = true
					table.insert(required, spec.Id)
				end
			end
		end
		flag("redesign_required_count", #required >= 112, #required, 112)
		for _, id in WAVE_1 do
			flag("redesign_wave1_required_" .. id, isRequired[id] == true)
		end
		local names, delivered = {}, {}
		for _, child in (source and source:GetChildren() or {}) do
			if not delivered[child.Name] then
				delivered[child.Name] = true
				table.insert(names, child.Name)
			end
		end
		for _, id in required do
			flag("redesign_delivered_" .. id, source ~= nil and source:FindFirstChild(id) ~= nil)
			if not delivered[id] then
				delivered[id] = true
				table.insert(names, id)
			end
		end
		table.sort(names)

		local singularityGold = false -- also red when the singularity template is missing
		for _, name in names do
			local template = templates and templates:FindFirstChild(name)
			local isModel = template ~= nil and template:IsA("Model")
			-- 1. Wins in CarModels and is MeshParts only, each with a MeshId.
			flag("redesign_template_" .. name, isModel and template:GetAttribute("Redesign") == true)
			if not isModel then
				continue
			end
			local parts = baseParts(template)
			local meshes, safe, namesOk = #parts > 0, #parts > 0, #parts > 0
			local lightNeon, groupMaterial, neonGold = true, true, false
			local present = {}
			for _, part in parts do
				meshes = meshes and part:IsA("MeshPart") and part.MeshId ~= ""
				-- 2. Cosmetic only.
				safe = safe and not part.CanCollide and not part.CanTouch and not part.CanQuery and part.Massless
				-- 4. Material-group names only.
				local group = groupOf(part.Name, SPECIAL_CASE[name] == true)
				namesOk = namesOk and group ~= nil
				-- Neon rule and group materials (spec section 2).
				if string.sub(part.Name, 1, 5) == "Light" then
					lightNeon = lightNeon and part.Material == Enum.Material.Neon
					neonGold = neonGold or isNeonGold(part)
				end
				if group and GROUP_MATERIAL[group] then
					groupMaterial = groupMaterial and part.Material == GROUP_MATERIAL[group]
				end
				present[part.Name] = true
			end
			flag("redesign_meshparts_" .. name, meshes, #parts)
			flag("redesign_cosmetic_flags_" .. name, safe)
			flag("redesign_part_names_" .. name, namesOk)
			flag("redesign_light_is_neon_" .. name, lightNeon)
			flag("redesign_group_material_" .. name, groupMaterial)
			if name == "singularity" then
				singularityGold = neonGold
			end
			local wheels = 0
			for _, wheel in WHEELS do
				wheels += present[wheel] and 1 or 0
			end
			flag("redesign_wheels_all_or_none_" .. name, wheels == 0 or wheels == 4, wheels, 4)
			-- 3. Bounds (spec section 2).
			local maxX, maxZ, minY = bounds(template)
			flag("redesign_bounds_x_" .. name, maxX <= MAX_X + TOLERANCE, maxX, MAX_X)
			flag("redesign_bounds_z_" .. name, maxZ <= MAX_Z + TOLERANCE, maxZ, MAX_Z)
			flag("redesign_bounds_floor_" .. name, minY >= MIN_Y - TOLERANCE, minY, MIN_Y)
			-- Special-case rides (spec section 9): textured parts carry a SurfaceAppearance, wings hinge on a pivot.
			if SPECIAL_CASE[name] then
				local textured, texturedCount = true, 0
				for _, part in parts do
					if string.sub(part.Name, 1, 5) ~= "Light" and not WHEEL_NAMES[part.Name] then
						texturedCount += 1
						local sa = part:FindFirstChildOfClass("SurfaceAppearance")
						-- ColorMap / NormalMap are plugin-only for game scripts: require the maps non-empty only
						-- when one of the two property forms can be read; an unreadable property is not a failure.
						local mapsSet = sa ~= nil
						if sa then
							local readOk, maps = pcall(function()
								return sa.ColorMap ~= "" and sa.NormalMap ~= ""
							end)
							if not readOk then
								readOk, maps = pcall(function()
									local c, n = sa.ColorMapContent, sa.NormalMapContent
									return c.SourceType ~= Enum.ContentSourceType.None
										and n.SourceType ~= Enum.ContentSourceType.None
								end)
							end
							mapsSet = not readOk or maps == true
						end
						textured = textured and mapsSet
					end
				end
				flag("redesign_surface_appearance_" .. name, texturedCount > 0 and textured, texturedCount)
				for _, wing in { "Wing_L", "Wing_R" } do
					local part = template:FindFirstChild(wing, true)
					local hinged = part ~= nil and part:IsA("BasePart") and part.PivotOffset.Position.Magnitude > 1e-3
					flag("redesign_wing_pivot_" .. wing .. "_" .. name, hinged)
				end
			end
		end

		flag("redesign_singularity_neon_gold", singularityGold)

		-- Spec section 7: every required catalog car resolves to a redesigned template.
		for _, id in required do
			local spec = catalog.Get(id)
			local template = spec and templates and templates:FindFirstChild(spec.Model or id)
			flag("redesign_catalog_resolves_" .. id, template ~= nil and template:GetAttribute("Redesign") == true)
		end

		-- 6. Un-shared models (spec section 5).
		for _, id in OWN_MODEL do
			local spec = catalog.Get(id)
			flag("redesign_own_model_" .. id, spec ~= nil and spec.Model == id, spec and tostring(spec.Model) or "nil")
		end

		-- 5. Applied skins keep the template's colours (no Tint) for every catalog car on a delivered redesign.
		local checked, tintedChecked, checkedIds = 0, 0, {}
		local everyCar = table.clone(catalog.All())
		for _, spec in (catalog.Passes and catalog.Passes() or {}) do
			table.insert(everyCar, spec)
		end
		for _, spec in everyCar do
			local model = spec.Model
			local template = model and delivered[model] and templates and templates:FindFirstChild(model)
			if template and template:IsA("Model") and template:GetAttribute("Redesign") == true then
				local rig = factory.build(bodyConfig)
				table.insert(cleanup, rig) -- never parent a physics rig into the live world
				local applied = appearance.Apply(rig, spec.Id, bodyConfig)
				local skin = rig:FindFirstChild("EquippedVisual")
				local want, got = baseParts(template), skin and baseParts(skin) or {}
				local same = applied == true and #want > 0 and #want == #got
				for i, part in want do
					same = same and got[i].Name == part.Name and sameColour(got[i].Color, part.Color)
				end
				flag("redesign_untinted_" .. spec.Id, same)
				checked += 1
				checkedIds[spec.Id] = true
				tintedChecked += spec.Tint and 1 or 0
				rig:Destroy()
			end
		end
		flag("redesign_untinted_checked", checked > 0, checked, 1)
		flag("redesign_untinted_go_kart_or_tinted", tintedChecked > 0 or checkedIds.go_kart == true)
	end)
	for _, object in cleanup do
		object:Destroy()
	end
	flag("redesign_no_error", ok, ok and 1 or tostring(err))
	return r
end

return Tests
