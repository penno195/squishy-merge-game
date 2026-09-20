--!strict
-- The Taco Rain event: tacos fall out of the sky, land, sit there a moment and
-- fade, under a disco ball over every garden and a ring of coloured lights, while
-- the theme's taco song plays.
--
-- All of it is the local player's own. Nothing is replicated, nothing is told to
-- the server, and no two players see the same taco -- the event is a mood, not a
-- mechanic, so there is no reason for it to cost the server an instance or the
-- network a single part. It also makes "you can't interact with them" true by
-- construction rather than by remembering to switch off CanTouch on something that
-- exists on the server.
--
-- The rain follows the camera, not the character: it should be wherever you are
-- looking, and there is always a camera even while a character is respawning. The
-- balls hang over the gardens instead, because that is where the players are.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Parent.UI.Sound)
local State = require(script.Parent.Parent.State)

local Theme = Config.Theme

local EVENT_ID = "TacoRain"

local SPAWN_RADIUS = 70
local SPAWN_HEIGHT = 90
local FALL_SPEED = 55
-- Tacos a second, per point of strength: a light drizzle at x1, a downpour at x3.
local RATE = 5
-- The ceiling matters more than the rate. A taco is a handful of parts and all of
-- them are moved every frame, so this is what keeps a long event off the frame
-- budget.
local MAX_TACOS = 60
-- How long a landed taco sits before it starts to go.
local LINGER = 3
local FADE = 0.7
-- Clear of the ground, so a taco doesn't sink into the grass it lands on.
local GROUND_OFFSET = 0.55
-- Nothing below this ever catches a taco: it fell down a hole in the map, and
-- letting it fall forever would leak one of the sixty slots.
local FLOOR = -200
-- How wide a taco ends up, whatever size the model it came from was drawn at.
local TACO_SIZE = 3

-- The ring of lights that follows the camera. These were four times this bright
-- over twice the range, which stacked five overlapping pools on the ground and
-- blew the floor out to white. Dimmer and shorter ranged, with the colour carried
-- by something you can actually see in the air instead.
local DISCO_LIGHTS = 5
local DISCO_RANGE = 34
local DISCO_BRIGHTNESS = 1.1
local ORBIT_RADIUS = 26
local ORBIT_HEIGHT = 24
-- The orb each light sits inside. Neon, so it reads as a light hanging in the air
-- rather than as a ball someone left up there.
local ORB_SIZE = 1.9
-- Radians a second the ring turns, cycles a second the colours run, and flashes a
-- second. Kept apart so the lights never quite line up: three things drifting
-- against each other reads as a room, one rate reads as a machine.
local ORBIT_SPEED = 1.1
local HUE_SPEED = 0.33
local FLASH_SPEED = 2.5
-- The wash over the whole picture. Small: this is the other half of what was
-- blowing the ground out, and a tint is meant to be felt rather than seen.
local TINT_STRENGTH = 0.08

-- A ball over the middle of each garden, on a short rope.
local BALL_SIZE = 4.5
local BALL_HEIGHT = 26
local ROPE_LENGTH = 7
local BALL_SPIN = 0.9
local BALL_LIGHT_RANGE = 30
local BALL_LIGHT_BRIGHTNESS = 1.2
-- Beams do the job the lights cannot: a shaft of colour in the air, visible from
-- the side, that never touches the floor.
local BEAMS_PER_BALL = 6
local BEAM_LENGTH = 22
local BEAM_DROP = 0.45
local BEAM_NEAR_WIDTH = 0.4
local BEAM_FAR_WIDTH = 4.5
-- Colours step rather than slide: ten times a second is a disco, sixty times a
-- second is a smooth gradient and a ColorSequence per beam per frame.
local COLOUR_HZ = 10

local SHELL = Color3.fromRGB(232, 184, 96)
local LETTUCE = Color3.fromRGB(122, 194, 96)
local FILLING = Color3.fromRGB(198, 74, 58)
local BALL_COLOUR = Color3.fromRGB(196, 202, 214)
local ROPE_COLOUR = Color3.fromRGB(45, 45, 52)

local TacoController = {}

type Taco = {
	Model: Model,
	Parts: { BasePart },
	Position: Vector3,
	Rotation: CFrame,
	-- Radians a second about each axis while it is falling.
	Spin: Vector3,
	GroundY: number,
	-- os.clock() when it landed; nil while it is still in the air.
	Rest: number?,
}

type Ball = {
	Rig: Folder,
	Ball: BasePart,
	Light: PointLight,
	Beams: { Beam },
	Pivot: Vector3,
}

local folder: Folder? = nil
local template: Model? = nil
-- True once the catalogue model has been found and made into the template, so the
-- lookup stops happening on every spawn.
local catalogueReady = false
local tacos: { Taco } = {}
local song: Sound? = nil
local orbs: { BasePart } = {}
local balls: { Ball } = {}
local correction: ColorCorrectionEffect? = nil
local discoClock = 0
local colourClock = 0
-- Workspace:GetServerTimeNow() when the event ends; nil when nothing is running.
local endsAt: number? = nil
local strength = 1
local spawnDebt = 0

local function newPart(size: Vector3, colour: Color3, offset: CFrame, shape: Enum.PartType, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Size = size
	part.Color = colour
	part.Shape = shape
	part.CFrame = offset
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- The fallback taco, for when the catalogue model has not arrived: a taco seen
-- end-on. A cylinder's flat faces point along its X axis, so a wide, thin one
-- stands up like a wheel, which is the shape a taco makes from that angle.
local function buildTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "Taco"
	local shell = newPart(Vector3.new(0.5, 3, 3), SHELL, CFrame.new(), Enum.PartType.Cylinder, model)
	newPart(Vector3.new(0.85, 0.45, 2.4), LETTUCE, CFrame.new(0, 0.55, 0), Enum.PartType.Block, model)
	newPart(Vector3.new(0.8, 0.35, 2), FILLING, CFrame.new(0, 0.25, 0), Enum.PartType.Block, model)
	model.PrimaryPart = shell
	return model
end

-- The catalogue model TacoService fetches, sized to match the built one. It can
-- turn up at any point -- it is a web call on the server -- so this is asked again
-- until it does.
local function catalogueTemplate(): Model?
	local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
	local effects = assets and assets:FindFirstChild("Effects")
	local found = effects and effects:FindFirstChild("Taco")
	if not found or not found:IsA("Model") then
		return nil
	end
	local model = found:Clone()
	local size = model:GetExtentsSize()
	local widest = math.max(size.X, size.Y, size.Z)
	if widest > 0 then
		model:ScaleTo(TACO_SIZE / widest)
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.CastShadow = false
		end
	end
	return model
end

local function groundBelow(from: Vector3): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = {}
	if folder then
		table.insert(ignore, folder)
	end
	for _, player in Players:GetPlayers() do
		local character = player.Character
		if character then
			table.insert(ignore, character)
		end
	end
	params.FilterDescendantsInstances = ignore
	local hit = Workspace:Raycast(from, Vector3.new(0, -(SPAWN_HEIGHT + 400), 0), params)
	return if hit then hit.Position.Y + GROUND_OFFSET else FLOOR
end

local function spawnTaco()
	local camera = Workspace.CurrentCamera
	if not camera or not folder then
		return
	end
	if not catalogueReady then
		local catalogue = catalogueTemplate()
		if catalogue then
			if template then
				template:Destroy()
			end
			template = catalogue
			catalogueReady = true
		end
	end
	local source = template
	if not source then
		return
	end

	local origin = camera.CFrame.Position
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * SPAWN_RADIUS
	local start = Vector3.new(
		origin.X + math.cos(angle) * distance,
		origin.Y + SPAWN_HEIGHT,
		origin.Z + math.sin(angle) * distance
	)

	local model = source:Clone()
	model.Parent = folder
	local parts: { BasePart } = {}
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	local taco: Taco = {
		Model = model,
		Parts = parts,
		Position = start,
		Rotation = CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28),
		Spin = Vector3.new(math.random() * 4 - 2, math.random() * 4 - 2, math.random() * 4 - 2),
		GroundY = groundBelow(start),
		Rest = nil,
	}
	model:PivotTo(CFrame.new(start) * taco.Rotation)
	table.insert(tacos, taco)
end

local function retire(taco: Taco)
	local tween = TweenInfo.new(FADE, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in taco.Parts do
		TweenService:Create(part, tween, { Transparency = 1 }):Play()
	end
	local model = taco.Model
	task.delay(FADE, function()
		model:Destroy()
	end)
end

local function step(delta: number)
	local now = os.clock()
	for index = #tacos, 1, -1 do
		local taco = tacos[index]
		if taco.Rest then
			if now - taco.Rest >= LINGER then
				table.remove(tacos, index)
				retire(taco)
			end
		else
			local fallen = taco.Position - Vector3.new(0, FALL_SPEED * delta, 0)
			if fallen.Y <= taco.GroundY then
				-- Landed: stand it at a random angle, rather than leaving it embedded
				-- in the ground at whatever angle it was spinning at.
				taco.Position = Vector3.new(fallen.X, taco.GroundY, fallen.Z)
				taco.Rotation = CFrame.Angles(0, math.random() * 6.28, 0)
				taco.Rest = now
			else
				taco.Position = fallen
				taco.Rotation = taco.Rotation
					* CFrame.Angles(taco.Spin.X * delta, taco.Spin.Y * delta, taco.Spin.Z * delta)
			end
			taco.Model:PivotTo(CFrame.new(taco.Position) * taco.Rotation)
		end
	end
end

-- Everything still on screen when the event ends fades out where it is, rather
-- than a field of tacos blinking out together.
local function clear()
	for index = #tacos, 1, -1 do
		local taco = tacos[index]
		table.remove(tacos, index)
		retire(taco)
	end
end

-- The disco -------------------------------------------------------------------

-- Every garden the world has built. Each is a Model carrying its own `Origin`, so
-- the middle of a player's area is known without measuring anything.
local function gardens(): { Model }
	local found: { Model } = {}
	local world = Workspace:FindFirstChild("World")
	local holder = world and world:FindFirstChild("Gardens")
	if not holder then
		return found
	end
	for _, child in holder:GetChildren() do
		if child:IsA("Model") and typeof(child:GetAttribute("Origin")) == "CFrame" then
			table.insert(found, child)
		end
	end
	return found
end

local function buildBall(origin: Vector3, parent: Instance): Ball
	local pivot = origin + Vector3.new(0, BALL_HEIGHT, 0)
	local rig = Instance.new("Folder")
	rig.Name = "DiscoBall"
	rig.Parent = parent

	newPart(
		Vector3.new(1.8, 0.35, 1.8),
		ROPE_COLOUR,
		CFrame.new(pivot + Vector3.new(0, ROPE_LENGTH, 0)),
		Enum.PartType.Block,
		rig
	)
	newPart(
		Vector3.new(0.18, ROPE_LENGTH, 0.18),
		ROPE_COLOUR,
		CFrame.new(pivot + Vector3.new(0, ROPE_LENGTH / 2, 0)),
		Enum.PartType.Block,
		rig
	)
	local ball =
		newPart(Vector3.new(BALL_SIZE, BALL_SIZE, BALL_SIZE), BALL_COLOUR, CFrame.new(pivot), Enum.PartType.Ball, rig)
	ball.Material = Enum.Material.Foil
	ball.Reflectance = 0.35

	local light = Instance.new("PointLight")
	light.Range = BALL_LIGHT_RANGE
	light.Brightness = BALL_LIGHT_BRIGHTNESS
	light.Shadows = false
	light.Parent = ball

	-- Both ends of every beam hang off the ball itself, so spinning the ball swings
	-- all six beams with it for the cost of one CFrame.
	local hub = Instance.new("Attachment")
	hub.Parent = ball

	local beams: { Beam } = {}
	for index = 1, BEAMS_PER_BALL do
		local angle = (index - 1) / BEAMS_PER_BALL * math.pi * 2
		local far = Instance.new("Attachment")
		far.Position = Vector3.new(math.cos(angle), -BEAM_DROP, math.sin(angle)).Unit * BEAM_LENGTH
		far.Parent = ball

		local beam = Instance.new("Beam")
		beam.Attachment0 = hub
		beam.Attachment1 = far
		beam.Width0 = BEAM_NEAR_WIDTH
		beam.Width1 = BEAM_FAR_WIDTH
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.FaceCamera = true
		beam.Segments = 1
		-- Solid at the ball, gone by the far end: a shaft of light thins out, and a
		-- hard edge in mid-air is what gives a beam away as a flat triangle.
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.45),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Parent = ball
		table.insert(beams, beam)
	end

	return { Rig = rig, Ball = ball, Light = light, Beams = beams, Pivot = pivot }
end

local function discoStart()
	if correction or not folder then
		return
	end
	local effect = Instance.new("ColorCorrectionEffect")
	effect.Name = "TacoDisco"
	effect.Saturation = 0.25
	effect.Contrast = 0.05
	effect.Parent = Lighting
	correction = effect

	for index = 1, DISCO_LIGHTS do
		local orb = newPart(
			Vector3.new(ORB_SIZE, ORB_SIZE, ORB_SIZE),
			Color3.new(1, 1, 1),
			CFrame.new(),
			Enum.PartType.Ball,
			folder
		)
		orb.Name = `DiscoOrb{index}`
		orb.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Range = DISCO_RANGE
		light.Brightness = DISCO_BRIGHTNESS
		-- Shadows off: moving shadow-casting lights is the one thing here that would
		-- actually cost frames on a phone.
		light.Shadows = false
		light.Parent = orb
		table.insert(orbs, orb)
	end

	for _, garden in gardens() do
		local origin = garden:GetAttribute("Origin") :: CFrame
		table.insert(balls, buildBall(origin.Position, folder))
	end
end

local function discoStop()
	if correction then
		correction:Destroy()
		correction = nil
	end
	for _, orb in orbs do
		orb:Destroy()
	end
	table.clear(orbs)
	for _, ball in balls do
		ball.Rig:Destroy()
	end
	table.clear(balls)
end

local function discoStep(delta: number)
	if not correction then
		return
	end
	discoClock += delta
	colourClock += delta
	local steppingColour = colourClock >= 1 / COLOUR_HZ
	if steppingColour then
		colourClock = 0
	end

	local camera = Workspace.CurrentCamera
	local centre = if camera then camera.CFrame.Position else Vector3.zero
	-- One flash shared by everything, so the whole place pulses together.
	local flash = 0.55 + 0.45 * math.abs(math.sin(discoClock * math.pi * FLASH_SPEED))

	for index, orb in orbs do
		local share = (index - 1) / DISCO_LIGHTS
		local angle = discoClock * ORBIT_SPEED + share * math.pi * 2
		orb.Position = centre
			+ Vector3.new(math.cos(angle) * ORBIT_RADIUS, ORBIT_HEIGHT, math.sin(angle) * ORBIT_RADIUS)
		if steppingColour then
			local colour = Color3.fromHSV((discoClock * HUE_SPEED + share) % 1, 1, 1)
			orb.Color = colour
			local light = orb:FindFirstChildOfClass("PointLight")
			if light then
				light.Color = colour
				light.Brightness = DISCO_BRIGHTNESS * flash
			end
		end
	end

	for _, ball in balls do
		ball.Ball.CFrame = CFrame.new(ball.Pivot) * CFrame.Angles(0, discoClock * BALL_SPIN, 0)
		if steppingColour then
			for index, beam in ball.Beams do
				local share = (index - 1) / BEAMS_PER_BALL
				beam.Color = ColorSequence.new(Color3.fromHSV((discoClock * HUE_SPEED * 1.4 + share) % 1, 1, 1))
			end
			ball.Light.Color = Color3.fromHSV((discoClock * HUE_SPEED * 1.4) % 1, 1, 1)
			ball.Light.Brightness = BALL_LIGHT_BRIGHTNESS * flash
		end
	end

	if steppingColour then
		local tint = Color3.fromHSV((discoClock * HUE_SPEED) % 1, 1, 1)
		correction.TintColor = Color3.new(
			1 - TINT_STRENGTH + tint.R * TINT_STRENGTH,
			1 - TINT_STRENGTH + tint.G * TINT_STRENGTH,
			1 - TINT_STRENGTH + tint.B * TINT_STRENGTH
		)
	end
end

local function setRunning(running: boolean)
	if running then
		if not song then
			song = Sound.loop(Theme.Sounds.TacoRain, 0.4)
		end
		discoClock = 0
		colourClock = 0
		discoStart()
	else
		if song then
			song:Destroy()
			song = nil
		end
		spawnDebt = 0
		discoStop()
		clear()
	end
end

function TacoController.start()
	local holder = Instance.new("Folder")
	holder.Name = "TacoRain"
	holder.Parent = Workspace
	folder = holder
	template = buildTemplate()

	State.onChange(function(snapshot)
		local found: { [string]: any }? = nil
		for _, entry in snapshot.Events or {} do
			if entry.Id == EVENT_ID then
				found = entry
			end
		end
		local wasRunning = endsAt ~= nil
		if found then
			endsAt = found.EndsAt
			strength = math.max(tonumber(found.Strength) or 1, 1)
		else
			endsAt = nil
		end
		if (endsAt ~= nil) ~= wasRunning then
			setRunning(endsAt ~= nil)
		end
	end)

	RunService.Heartbeat:Connect(function(delta: number)
		local finish = endsAt
		if finish and Workspace:GetServerTimeNow() >= finish then
			-- The state update that ends it can be a moment behind the clock, and a
			-- taco that keeps falling after the chip says "over" is the one thing
			-- players would notice.
			endsAt = nil
			setRunning(false)
			finish = nil
		end
		if finish then
			spawnDebt += delta * RATE * strength
			while spawnDebt >= 1 do
				spawnDebt -= 1
				if #tacos < MAX_TACOS then
					spawnTaco()
				end
			end
			discoStep(delta)
		end
		step(delta)
	end)
end

return TacoController
