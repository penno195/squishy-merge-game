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
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Theme = Config.Theme

local LightingService = {}

function LightingService.init()
	local settings = Theme.Lighting
	local sky = Theme.Sky

	-- Whatever the place was made from brings its own weather with it, and an
	-- Atmosphere or a bank of Terrain clouds is drawn *in front of* the skybox:
	-- at midnight both render as flat black, so the sky goes out and anything
	-- behind it is never seen.
	for _, thing in Lighting:GetChildren() do
		if thing:IsA("Sky") or thing:IsA("Atmosphere") then
			thing:Destroy()
		end
	end
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		clouds:Destroy()
	end

	-- A fresh Sky is Roblox's own: its skybox, its sun and moon, and its stars,
	-- which twinkle. Only the faces a theme actually supplies are painted over,
	-- so a theme with no `Sky` gets the stock night sky rather than nothing.
	--
	-- Painted stars were tried first and never appeared, on assets that are
	-- Approved, Active and decode cleanly -- so whatever the reason, it is not
	-- one this code can see. Roblox's own cannot fail to load, and they move.
	local instance = Instance.new("Sky")
	if sky then
		instance.SkyboxUp = sky.Up
		instance.SkyboxDn = sky.Dn
		instance.SkyboxLf = sky.Lf
		instance.SkyboxRt = sky.Rt
		instance.SkyboxFt = sky.Ft
		instance.SkyboxBk = sky.Bk
	end
	if settings then
		instance.StarCount = settings.StarCount or 3000
		instance.CelestialBodiesShown = settings.CelestialBodies == true
	end
	instance.Parent = Lighting

	if not settings then
		return
	end

	-- Bloom is what turns a Neon part into a white blot. The default spills from
	-- anything bright at all; raising the threshold means only something really
	-- bright blooms, and dropping the intensity means it glows rather than
	-- swallowing whatever it is attached to.
	local bloom = Lighting:FindFirstChildOfClass("BloomEffect") or Instance.new("BloomEffect")
	bloom.Intensity = settings.BloomIntensity or 0.4
	bloom.Threshold = settings.BloomThreshold or 1.6
	bloom.Size = 20
	bloom.Parent = Lighting
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
