--!nonstrict
-- Draft only (test Studio, never synced): fetch the draft textures as base64 raw RGBA from a local
-- server and keep them as EditableImages in _G.TrailTex, so the preview needs no upload.
local HttpService = game:GetService("HttpService")
local AssetService = game:GetService("AssetService")
local BASE = "http://127.0.0.1:8767/"
local NAMES = {
	"CoreStreak.png", "Glint.png", "RainbowRibbon.png", "SoftBand.png",
	"VoidCrackle.png", "VoidWake.png", "VoidWisp.flipbook.png",
}
local LOOKUP = {}
local ALPHABET = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
for i = 1, 64 do
	LOOKUP[string.byte(ALPHABET, i)] = i - 1
end
local function decode(text, out)
	local o = 0
	for i = 1, #text - 3, 4 do
		local a, b, c, d = string.byte(text, i, i + 3)
		local n = LOOKUP[a] * 262144 + LOOKUP[b] * 4096 + (LOOKUP[c] or 0) * 64 + (LOOKUP[d] or 0)
		buffer.writeu8(out, o, bit32.rshift(n, 16))
		if c ~= 61 then
			buffer.writeu8(out, o + 1, bit32.band(bit32.rshift(n, 8), 255))
		end
		if d ~= 61 then
			buffer.writeu8(out, o + 2, bit32.band(n, 255))
		end
		o += 3
		if i % 400000 == 1 then
			task.wait()
		end
	end
end
HttpService.HttpEnabled = true
_G.TrailTex = _G.TrailTex or {}
local report = {}
for _, name in NAMES do
	local body = HttpService:GetAsync(BASE .. name .. ".b64")
	local newline = string.find(body, "\n")
	local size = tonumber(string.sub(body, 1, newline - 1))
	local pixels = buffer.create(size * size * 4)
	decode(string.sub(body, newline + 1), pixels)
	local image = AssetService:CreateEditableImage({ Size = Vector2.new(size, size) })
	image:WritePixelsBuffer(Vector2.zero, Vector2.new(size, size), pixels)
	_G.TrailTex[name] = image
	table.insert(report, name .. " " .. size)
end
return table.concat(report, ", ")
