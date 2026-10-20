--!nonstrict
-- Builds biome prop meshes from Shared/BiomeMeshData (docs/BIOME_DRESSING_SPEC.md "Assets").
-- Data is base64 of: u16 vertex count, u16 index count, then per vertex int16 x,y,z (1/256 stud) + u16 u,v,
-- then u16 triangle indices. Written by blender/biomes/export_biome_props.py.

local AssetService = game:GetService("AssetService")

local BiomeMeshCodec = {}

local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local LOOKUP = {}
for i = 1, #ALPHABET do
	LOOKUP[string.byte(ALPHABET, i)] = i - 1
end

function BiomeMeshCodec.Decode(text)
	local n = #text
	local pad = (string.sub(text, -2) == "==" and 2) or (string.sub(text, -1) == "=" and 1) or 0
	local out = buffer.create(n // 4 * 3 - pad)
	local o = 0
	for i = 1, n, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local v = LOOKUP[a] * 262144 + LOOKUP[b] * 4096 + (LOOKUP[c] or 0) * 64 + (LOOKUP[d] or 0)
		buffer.writeu8(out, o, v // 65536)
		if c ~= 61 then
			buffer.writeu8(out, o + 1, v // 256 % 256)
		end
		if d ~= 61 then
			buffer.writeu8(out, o + 2, v % 256)
		end
		o += 3
	end
	return out
end

-- A fixed-size EditableMesh with flat (per-face) normals, or nil and the error if the device has no mesh budget left.
function BiomeMeshCodec.Build(data)
	local ok, mesh = pcall(AssetService.CreateEditableMesh, AssetService)
	if not ok or not mesh then
		return nil, mesh
	end
	local blob = BiomeMeshCodec.Decode(data)
	local vertexCount, indexCount = buffer.readu16(blob, 0), buffer.readu16(blob, 2)
	local points = table.create(vertexCount)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for i = 0, vertexCount - 1 do
		local at = 4 + i * 10
		local p = Vector3.new(buffer.readi16(blob, at), buffer.readi16(blob, at + 2), buffer.readi16(blob, at + 4))
			/ 256
		points[i + 1] = p
		lo, hi = lo:Min(p), hi:Max(p)
	end
	-- The baked origin is the prop's base, but a MeshPart made from this mesh keeps that origin as its centre,
	-- so centre the geometry on its box: Client/BiomeMeshes puts the part's centre at MeshBounds' centre.
	local centre = (lo + hi) / 2
	local verts, uvs = table.create(vertexCount), table.create(vertexCount)
	for i = 0, vertexCount - 1 do
		local at = 4 + i * 10
		verts[i + 1] = mesh:AddVertex(points[i + 1] - centre)
		uvs[i + 1] = mesh:AddUV(Vector2.new(buffer.readu16(blob, at + 6), buffer.readu16(blob, at + 8)) / 65535)
	end
	local base = 4 + vertexCount * 10
	for t = 0, indexCount // 3 - 1 do
		local a = buffer.readu16(blob, base + t * 6) + 1
		local b = buffer.readu16(blob, base + t * 6 + 2) + 1
		local c = buffer.readu16(blob, base + t * 6 + 4) + 1
		local pa, pb, pc = mesh:GetPosition(verts[a]), mesh:GetPosition(verts[b]), mesh:GetPosition(verts[c])
		local cross = (pb - pa):Cross(pc - pa)
		if cross.Magnitude > 1e-9 then
			local face = mesh:AddTriangle(verts[a], verts[b], verts[c])
			mesh:SetFaceUVs(face, { uvs[a], uvs[b], uvs[c] })
			local normal = mesh:AddNormal(cross.Unit)
			mesh:SetFaceNormals(face, { normal, normal, normal })
		end
	end
	-- A fixed-size copy uses much less of the client's editable memory budget than the growable original.
	local okCopy, fixed = pcall(function()
		return AssetService:CreateEditableMeshAsync(Content.fromObject(mesh), { FixedSize = true })
	end)
	if okCopy and fixed then
		mesh:Destroy()
		return fixed
	end
	return mesh
end

return BiomeMeshCodec
