--!nonstrict
-- The world's lighting baseline (docs/RENDERING_SPEC.md section 1). Every number is a placeholder (tunable).
-- Server/Main calls Apply before WeatherService.Start, so weather events snapshot and restore this baseline.
local Lighting = game:GetService("Lighting")

local rgb = Color3.fromRGB
local LightingConfig = {}

LightingConfig.Lighting = {
	Brightness = 2.8,
	Ambient = rgb(40, 42, 52),
	OutdoorAmbient = rgb(112, 118, 136),
	ShadowSoftness = 0.12,
	EnvironmentDiffuseScale = 1,
	EnvironmentSpecularScale = 1,
	ExposureCompensation = 0,
	ClockTime = 14.5,
	GlobalShadows = true,
}

-- { ClassName, Name, props }: made when missing, found by name otherwise
LightingConfig.Effects = {
	{
		"ColorCorrectionEffect",
		"Grade",
		{ Saturation = 0.18, Contrast = 0.15, Brightness = 0.01, TintColor = rgb(255, 250, 244) },
	},
	{ "BloomEffect", "Bloom", { Intensity = 0.7, Size = 28, Threshold = 1.4 } },
	{ "SunRaysEffect", "SunRays", { Intensity = 0.06, Spread = 0.6 } },
	{
		"Atmosphere",
		"Atmosphere",
		{
			Density = 0.28,
			Offset = 0.2,
			Haze = 0.3,
			Glare = 0.1,
			Color = rgb(190, 206, 232),
			Decay = rgb(110, 120, 140),
		},
	},
}

function LightingConfig.Apply()
	for prop, value in LightingConfig.Lighting do
		Lighting[prop] = value
	end
	for _, effect in LightingConfig.Effects do
		local className, name, props = effect[1], effect[2], effect[3]
		local inst = Lighting:FindFirstChild(name)
		if not (inst and inst:IsA(className)) then
			-- Lighting holds one Atmosphere only: reuse it whatever its name
			inst = className == "Atmosphere" and Lighting:FindFirstChildOfClass(className) or Instance.new(className)
			inst.Name = name
			inst.Parent = Lighting
		end
		for prop, value in props do
			inst[prop] = value
		end
	end
end

return LightingConfig
