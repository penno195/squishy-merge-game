--!strict
-- Puts the theme's sky up and sets the light under it.
--
-- Lighting replicates from the server, so this runs once here rather than in
-- every client. Everything is optional: a theme that says nothing keeps the
-- place's own lighting, and a theme that names one value changes only that.
--
-- The sky is a tent seen from the inside, which is why the celestial bodies go
-- off with it. A sun sliding across canvas is the detail that would give the
-- whole thing away, and a moon under a big top is worse.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme

local LightingService = {}

function LightingService.init()
	local sky = Theme.Sky
	if sky then
		local existing = Lighting:FindFirstChildOfClass("Sky")
		if existing then
			existing:Destroy()
		end
		local instance = Instance.new("Sky")
		instance.SkyboxUp = sky.Up
		instance.SkyboxDn = sky.Dn
		instance.SkyboxLf = sky.Lf
		instance.SkyboxRt = sky.Rt
		instance.SkyboxFt = sky.Ft
		instance.SkyboxBk = sky.Bk
		-- Nothing in the real sky belongs in a tent.
		instance.CelestialBodiesShown = false
		instance.StarCount = 0
		instance.Parent = Lighting
	end

	local settings = Theme.Lighting
	if not settings then
		return
	end
	-- Written out rather than looped over the table: the names differ from the
	-- field names in two places, and a loop that sets properties by string is a
	-- typo away from silently doing nothing.
	if settings.ClockTime then
		Lighting.ClockTime = settings.ClockTime
	end
	if settings.Brightness then
		Lighting.Brightness = settings.Brightness
	end
	if settings.Ambient then
		Lighting.Ambient = settings.Ambient
	end
	if settings.OutdoorAmbient then
		Lighting.OutdoorAmbient = settings.OutdoorAmbient
	end
	if settings.ColorShiftTop then
		Lighting.ColorShift_Top = settings.ColorShiftTop
	end
	if settings.FogColor then
		Lighting.FogColor = settings.FogColor
	end
	if settings.FogStart then
		Lighting.FogStart = settings.FogStart
	end
	if settings.FogEnd then
		Lighting.FogEnd = settings.FogEnd
	end
	if settings.ExposureCompensation then
		Lighting.ExposureCompensation = settings.ExposureCompensation
	end
end

return LightingService
