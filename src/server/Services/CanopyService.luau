--!strict
-- The big top over the hub: banded poles standing in the gaps between the garden
-- paths, a striped roof resting on them, a scalloped hem under its eaves, and
-- strings of bulbs swagged from pole to pole.
--
-- It is a roof, not a room. The hub's whole arrangement rests on being able to
-- stand anywhere in the middle and see all four stations at once, so this has no
-- walls and nothing in the centre: the poles stand outside the walkway, in the
-- same gaps the stations use, which are the only angles in the map nobody is
-- ever walking through. Everything that was in the hub before is still where it
-- was, and now it is indoors.
--
-- Two properties do most of the work of making a tent pleasant rather than
-- oppressive, and both are easy to lose in a later edit:
--
--   CanQuery = false    The camera decides how close to pull in by raycasting at
--                       the player, and a roof is exactly what it would hit.
--                       Without this, walking under the tent yanks the camera in
--                       to the back of the player's head. Off, the ray passes
--                       through and the camera never learns the roof is there.
--   CastShadow = false  A closed cone over the whole hub otherwise drops the
--                       four stations into shade, and the hub is where all the
--                       colour in the map is.
--
-- The poles are the exception to both: they are thin, they are something you
-- walk around rather than under, and a pole that the camera and the light ignore
-- reads as a decal rather than a post holding up a tent.
--
-- Built after HubService, whose gaps it stands in.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GardenService = require(script.Parent.GardenService)
local HubService = require(script.Parent.HubService)
local Types = require(ReplicatedStorage.Shared.Types)

local Balance = Config.Balance
local Canopy = Balance.Canopy
local Theme = Config.Theme

-- The cord the bulbs hang on. Thin enough to read as a wire from the ground,
-- thick enough not to disappear entirely at the far side of the hub.
local CORD_WIDTH = 0.28
-- How far under the pole's finial a string is tied on.
local STRING_DROP = 2
-- The pennant on a pole and on the spire.
local FLAG_LENGTH = 5
local FLAG_HEIGHT = 2.6
local FLAG_THICKNESS = 0.3

local CanopyService = {}

-- Canopy parts are scenery in the strongest sense: nothing collides with them,
-- the camera can't see them, and they cast no shadow. `solid` opts a part back
-- into being a real object, which only the poles want.
local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	solid: boolean?
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.CanCollide = solid == true
	part.CanQuery = solid == true
	part.CastShadow = solid == true
	part.Parent = parent
	return part
end

-- A Roblox cylinder lies along its X axis, so every upright one in here is a
-- size of (height, width, width) turned a quarter turn onto its end.
local function makeColumn(
	name: string,
	height: number,
	width: number,
	base: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance,
	solid: boolean?
): Part
	local part = makePart(
		name,
		Vector3.new(height, width, width),
		CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		color,
		material,
		parent,
		solid
	)
	part.Shape = Enum.PartType.Cylinder
	return part
end

local function makeBall(
	name: string,
	diameter: number,
	centre: Vector3,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = makePart(name, Vector3.new(diameter, diameter, diameter), CFrame.new(centre), color, material, parent)
	part.Shape = Enum.PartType.Ball
	return part
end

-- A pennant, flying off one side of whatever it is pinned to.
local function makeFlag(at: Vector3, facing: Vector3, color: Color3, parent: Instance)
	local position = at + facing * (FLAG_LENGTH / 2)
	makePart(
		"Pennant",
		Vector3.new(FLAG_LENGTH, FLAG_HEIGHT, FLAG_THICKNESS),
		CFrame.lookAt(position, position + facing:Cross(Vector3.yAxis)),
		color,
		Enum.Material.SmoothPlastic,
		parent
	)
end

-- One pole, banded like a stick of rock. The bands are what make it read as
-- fairground rather than as scaffolding, and they cost one part each.
local function buildPole(parent: Instance, angle: number, radius: number, def: Types.CanopyDef)
	local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local foot = outward * radius
	-- Up to the eaves, plus enough to carry a finial clear of the roof.
	local height = Canopy.EavesHeight + Canopy.PoleWidth * 2
	local band = height / Canopy.PoleBands

	for index = 1, Canopy.PoleBands do
		makeColumn(
			"PoleBand",
			band,
			Canopy.PoleWidth,
			foot + Vector3.new(0, (index - 1) * band, 0),
			if index % 2 == 0 then def.PoleBand else def.Pole,
			Enum.Material.SmoothPlastic,
			parent,
			true
		)
	end

	local top = foot + Vector3.new(0, height, 0)
	makeBall("PoleFinial", Canopy.PoleWidth * 1.5, top, def.Trim, Enum.Material.SmoothPlastic, parent)
	makeFlag(top + Vector3.new(0, Canopy.PoleWidth, 0), outward, def.Flag or def.Trim, parent)
end

-- The roof. Each gore runs from the eaves up to the crown, and is built as a
-- short stack of segments rather than as one rectangle, because a gore is a
-- triangle: the arc it has to cover shrinks the whole way up, and one rectangle
-- wide enough for the eaves ends up three times wider than its share of the
-- crown, so the top of the roof becomes a jumble of overlapping flaps. Sizing
-- each segment to the arc at its own radius gives a clean cone, tapered stripes,
-- and a faceted edge that is exactly what a tent looks like from below.
local function buildRoof(parent: Instance, radius: number, def: Types.CanopyDef)
	local count = Canopy.Panels
	local steps = Canopy.PanelSteps
	local rise = Canopy.CrownHeight - Canopy.EavesHeight
	local run = radius - Canopy.CrownRadius
	local length = math.sqrt(run * run + rise * rise) / steps

	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		-- From the eaves to the crown in one step: inward and up.
		local along = (-outward * run + Vector3.yAxis * rise).Unit
		local color = if index % 2 == 0 then def.Stripe else def.StripeAlt

		for step = 1, steps do
			-- The middle of this segment, as a fraction of the way up the gore.
			local at = (step - 0.5) / steps
			local segmentRadius = radius - run * at
			local position = outward * segmentRadius + Vector3.yAxis * (Canopy.EavesHeight + rise * at)
			-- Its share of the arc at its own radius, with a little slack so
			-- neighbouring gores meet rather than leave a seam.
			local chord = 2 * segmentRadius * math.sin(math.pi / count) * Canopy.PanelOverlap
			-- The segment's length runs along `along` and its width along the
			-- tangent, so its own up is what's left: fromMatrix takes the first
			-- two and crosses them for the third.
			makePart(
				"Gore",
				Vector3.new(chord, Canopy.PanelThickness, length * Canopy.PanelOverlap),
				CFrame.fromMatrix(position, tangent, along:Cross(tangent)),
				color,
				Enum.Material.SmoothPlastic,
				parent
			)
		end
	end
end

-- The hem: a band round the eaves with a row of scallops hanging under it. The
-- scallops are balls half-hidden behind the band, which is the cheapest thing
-- that reads as cloth rather than as a cut edge.
local function buildHem(parent: Instance, radius: number, def: Types.CanopyDef)
	local count = Canopy.Scallops
	local spacing = 2 * math.pi * radius / count
	local eaves = Canopy.EavesHeight

	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local outward = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
		local position = outward * radius + Vector3.yAxis * (eaves - Canopy.HemDepth / 2)
		makePart(
			"HemBand",
			Vector3.new(Canopy.PanelThickness * 2, Canopy.HemDepth, spacing * Canopy.PanelOverlap),
			CFrame.lookAt(position, position + tangent),
			def.Trim,
			Enum.Material.SmoothPlastic,
			parent
		)
		makeBall(
			"Scallop",
			spacing * 1.02,
			outward * radius + Vector3.yAxis * (eaves - Canopy.HemDepth),
			if index % 2 == 0 then def.Stripe else def.StripeAlt,
			Enum.Material.SmoothPlastic,
			parent
		)
	end
end

-- Where the gores meet, and the spire standing on them. There is no mast: a pole
-- through the middle of the hub would be the one thing standing where everybody
-- walks, and from the ground nobody audits how a tent holds itself up.
local function buildCrown(parent: Instance, def: Types.CanopyDef)
	local crown = Vector3.new(0, Canopy.CrownHeight, 0)
	makeColumn(
		"Crown",
		Canopy.PanelThickness * 4,
		Canopy.CrownRadius * 2,
		crown - Vector3.yAxis * (Canopy.PanelThickness * 2),
		def.Trim,
		Enum.Material.SmoothPlastic,
		parent
	)
	makeColumn("Spire", Canopy.SpireHeight, Canopy.PoleWidth, crown, def.Trim, Enum.Material.SmoothPlastic, parent)

	local tip = crown + Vector3.new(0, Canopy.SpireHeight, 0)
	makeBall("SpireFinial", Canopy.PoleWidth * 2, tip, def.Trim, Enum.Material.SmoothPlastic, parent)
	makeFlag(tip, Vector3.new(0, 0, -1), def.Flag or def.Trim, parent)
end

-- A lamp: a bulb you can see, with the light inside it. A light with no source
-- reads as a mistake, and under a tent the source is half the look.
local function hangLamp(parent: Instance, at: Vector3, range: number, brightness: number, def: Types.CanopyDef)
	local lights = Balance.Lights
	local bulb = makePart("Lamp", Vector3.one * lights.LampSize, CFrame.new(at), def.Trim, Enum.Material.Neon, parent)
	bulb.Shape = Enum.PartType.Ball

	local light = Instance.new("PointLight")
	light.Color = def.Trim
	light.Brightness = brightness
	light.Range = range
	light.Parent = bulb
end

-- Bulbs on a sagging string between each pair of poles. Neon rather than a light
-- source: sixty point lights in one place is a frame rate, and at this distance
-- the difference is invisible anyway.
--
-- The chord between two poles crosses over the walkway, which is why the sag is
-- measured from a height well above head height rather than from the eaves.
local function buildBunting(parent: Instance, angles: { number }, radius: number, def: Types.CanopyDef)
	if #def.Bulbs == 0 then
		return
	end

	local height = Canopy.EavesHeight + Canopy.PoleWidth * 2 - STRING_DROP
	local steps = Canopy.BulbsPerSpan + 1
	local bulb = 0

	for index = 1, #angles do
		local from = angles[index]
		local to = angles[index % #angles + 1]
		local start = Vector3.new(math.cos(from) * radius, height, math.sin(from) * radius)
		local finish = Vector3.new(math.cos(to) * radius, height, math.sin(to) * radius)

		-- A parabola is near enough a hanging cord at this span, and it is one
		-- multiply rather than a cosh.
		local function pointAt(t: number): Vector3
			return start:Lerp(finish, t) - Vector3.yAxis * (Canopy.BuntingSag * 4 * t * (1 - t))
		end

		local previous = start
		for step = 1, steps do
			local point = pointAt(step / steps)
			local span = point - previous
			local middle = previous + span / 2
			makePart(
				"Cord",
				Vector3.new(CORD_WIDTH, CORD_WIDTH, span.Magnitude),
				CFrame.lookAt(middle, middle + span.Unit),
				def.Trim,
				Enum.Material.SmoothPlastic,
				parent
			)
			if step < steps then
				bulb += 1
				makeBall(
					"Bulb",
					Canopy.BulbSize,
					point - Vector3.yAxis * (Canopy.BulbSize / 2),
					def.Bulbs[(bulb - 1) % #def.Bulbs + 1],
					Enum.Material.Neon,
					parent
				)
			end
			previous = point
		end
	end
end

function CanopyService.init()
	local def = Theme.Canopy
	if not def then
		return
	end

	local world = GardenService.world()
	if not world then
		warn("CanopyService.init ran before the world existed; skipping the canopy")
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Canopy"
	folder.Parent = world

	local radius = GardenService.plotRadius() * Canopy.Radius
	local angles = {}
	for gap = 1, Balance.PlotCount do
		local angle = HubService.gapAngle(gap)
		table.insert(angles, angle)
		buildPole(folder, angle, radius, def)
	end

	buildRoof(folder, radius, def)
	buildHem(folder, radius, def)
	buildCrown(folder, def)
	buildBunting(folder, angles, radius, def)

	-- The inside of the tent, lit. One hung under the crown for the middle, and
	-- one on each pole for the rim, because a single light capped at sixty studs
	-- of range cannot reach a tent a hundred and thirty wide.
	local lights = Balance.Lights
	hangLamp(folder, Vector3.new(0, Canopy.CrownHeight - 8, 0), lights.CanopyRange, lights.CanopyBrightness, def)
	for _, angle in angles do
		local at = Vector3.new(math.cos(angle) * radius * 0.82, Canopy.EavesHeight - 4, math.sin(angle) * radius * 0.82)
		hangLamp(folder, at, lights.PoleRange, lights.PoleBrightness, def)
	end
end

return CanopyService
