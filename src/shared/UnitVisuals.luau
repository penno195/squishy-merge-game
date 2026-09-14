--!strict
-- Builds the model for a unit tier. A theme can supply real models under
-- ReplicatedStorage.ThemeAssets.Units (matched by UnitDef.Model); anything
-- missing falls back to a procedural squishy blob in the unit's colour.
-- Models are pivoted at their bottom centre so they rest on the ground.
--
-- Every blob has a face. On top of that a unit can name `Features` -- ears, a
-- snout, a tail, a ring -- so a thing called a Pup has something dog about it
-- and a thing called a Cat doesn't look identical to it. Those are split the
-- same way scenery is: the vocabulary of shapes is shared and lives here, and
-- which of them a unit wears is theme data. A new skin gets dog ears by
-- writing "DogEars", not by modelling one, and a shape nobody has built yet is
-- added here once and every theme can then use it.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Theme = Config.Theme

-- Roblox ships this one, so a sparkle glitters without the theme owning any art.
local SPARKLE_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"

local UnitVisuals = {}

UnitVisuals.Tag = "MergeUnit"

function UnitVisuals.blobHeight(tier: number): number
	return 2.6 + (tier - 1) * 0.18
end

local function findThemeModel(name: string?): Model?
	if not name then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
	local units = assets and assets:FindFirstChild("Units")
	local model = units and units:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end
	warn(`Theme model "{name}" not found in ReplicatedStorage.ThemeAssets.Units; using a blob`)
	return nil
end

-- Face parts, shared by the mouth and by anything a feature tints toward.
local DARK = Color3.fromRGB(35, 25, 45)
local PINK = Color3.fromRGB(255, 130, 165)
local WHITE = Color3.new(1, 1, 1)
local GOLD = Color3.fromRGB(255, 205, 70)

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	shape: Enum.PartType,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Balls are meshed rather than Ball parts because a mesh can be squashed, which
-- is what EffectsController does to the body every frame to make it breathe.
local function makeBall(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = makePart(name, size, cframe, color, Enum.PartType.Block, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- A cone built from shrinking discs, the way PropVisuals builds its trees. Ears
-- and beaks want a taper, and stacked cylinders get one without depending on
-- which way round a wedge happens to slope. It grows along `base`'s own +Y, so
-- a caller points it by turning the CFrame rather than by doing trigonometry.
local function addCone(model: Model, name: string, base: CFrame, length: number, radius: number, color: Color3)
	local layers = 3
	for index = 1, layers do
		local slice = length / layers
		local sliceRadius = radius * (1 - (index - 1) / layers * 0.8)
		makePart(
			`{name}{index}`,
			Vector3.new(slice, sliceRadius * 2, sliceRadius * 2),
			-- A Cylinder's flat faces are on its local X, so a quarter turn
			-- about Z stands it up along the base's +Y.
			base * CFrame.new(0, (index - 0.5) * slice, 0) * CFrame.Angles(0, 0, math.pi / 2),
			color,
			Enum.PartType.Cylinder,
			model
		)
	end
end

-- The mouth is an arc of overlapping segments rather than one part. A single
-- flattened ball is a straight slot, and a straight slot on a round face reads
-- as a grimace whatever size it is: the curve is the whole difference between a
-- squishy that looks pleased to see you and one that looks like it is holding
-- its breath.
--
-- `spread` is half how wide the mouth is, `curve` how far the corners lift above
-- the middle. Each segment is laid on the body's own surface and turned to the
-- slope of the arc under it, so the smile bends around the cheeks instead of
-- floating flat in front of them, and the end segments round the corners off.
local SMILE_SEGMENTS = 5

local function addSmile(model: Model, width: number, height: number, spread: number, curve: number)
	local thickness = height * 0.075
	local depth = width * 0.07
	local segment = spread * 2 / (SMILE_SEGMENTS - 1) * 1.45

	for index = 1, SMILE_SEGMENTS do
		local across = (index - 1) / (SMILE_SEGMENTS - 1) * 2 - 1
		local x = spread * across
		local y = height * 0.36 + curve * across * across
		-- The body is an ellipsoid `width` across and `height` tall centred at
		-- half its height, so this is where its front surface sits under (x, y).
		-- Sunk by a third of its own depth, which leaves the segment proud of
		-- the face without a gap opening behind it at the corners.
		local inside = 1 - (2 * x / width) ^ 2 - ((2 * y - height) / height) ^ 2
		local surface = -width / 2 * math.sqrt(math.max(inside, 0))
		makeBall(
			"Mouth",
			Vector3.new(segment, thickness, depth),
			CFrame.new(x, y, surface + depth * 0.3) * CFrame.Angles(0, 0, math.atan2(2 * curve * across, spread)),
			DARK,
			model
		)
	end
end

-- Every segment is named "Mouth", so moving the mouth means moving all of them.
-- The features run after the face is built, which is what lets a muzzle take the
-- smile out onto the end of it rather than leave it behind on the cheek.
local function moveMouth(model: Model, offset: Vector3)
	for _, child in model:GetChildren() do
		if child.Name == "Mouth" and child:IsA("BasePart") then
			child.CFrame = child.CFrame + offset
		end
	end
end

-- The two mouths, as fractions of the blob. "WideMouth" is a name in the feature
-- vocabulary like any other, but it is read when the face is built rather than
-- run afterwards: an arc has to be laid out in one go, and rebuilding one that a
-- snout had already moved would put it back on the cheek.
local SMILES = {
	Default = { Spread = 0.19, Curve = 0.06 },
	Wide = { Spread = 0.3, Curve = 0.1 },
}

-- The namesake vocabulary. Each one is handed the blob's width and height and
-- the unit's colour, and builds in the model's own space: the body is a ball of
-- `width` across and `height` tall centred at (0, height / 2, 0), and -Z is the
-- front. Anything sitting on the crown overlaps the head rather than resting on
-- it, because the body squashes underneath it and a gap would open every bounce.
export type Feature = (model: Model, width: number, height: number, color: Color3) -> ()

local Features: { [string]: Feature } = {}

-- Ears, in the four shapes that cover most of what a merge ladder is named
-- after: floppy, pointed, long and round.
Features.DogEars = function(model, width, height, color)
	for _, side in { -1, 1 } do
		makeBall(
			"Ear",
			Vector3.new(width * 0.2, height * 0.44, width * 0.17),
			CFrame.new(side * width * 0.42, height * 0.6, -width * 0.02) * CFrame.Angles(0, 0, side * math.rad(14)),
			color:Lerp(DARK, 0.22),
			model
		)
	end
end

Features.CatEars = function(model, width, height, color)
	for _, side in { -1, 1 } do
		addCone(
			model,
			"Ear",
			CFrame.new(side * width * 0.24, height * 0.88, 0) * CFrame.Angles(0, 0, -side * math.rad(18)),
			height * 0.34,
			width * 0.13,
			color
		)
	end
end

Features.BunnyEars = function(model, width, height, color)
	for _, side in { -1, 1 } do
		local ear = CFrame.new(side * width * 0.15, height * 1.15, 0) * CFrame.Angles(0, 0, -side * math.rad(10))
		makeBall("Ear", Vector3.new(width * 0.17, height * 0.8, width * 0.13), ear, color, model)
		makeBall(
			"EarInner",
			Vector3.new(width * 0.09, height * 0.56, width * 0.07),
			ear * CFrame.new(0, 0, -width * 0.05),
			PINK,
			model
		)
	end
end

Features.RoundEars = function(model, width, height, color)
	for _, side in { -1, 1 } do
		makeBall(
			"Ear",
			Vector3.one * width * 0.26,
			CFrame.new(side * width * 0.3, height * 0.93, 0),
			color:Lerp(DARK, 0.15),
			model
		)
	end
end

-- A muzzle, which takes the mouth with it: left where it was it would be buried
-- under the snout, and a face with a hidden mouth reads as a face with none.
Features.Snout = function(model, width, height, color)
	makeBall(
		"Snout",
		Vector3.new(width * 0.36, height * 0.26, width * 0.24),
		CFrame.new(0, height * 0.42, -width * 0.42),
		color:Lerp(WHITE, 0.4),
		model
	)
	makeBall(
		"Nose",
		Vector3.new(width * 0.14, height * 0.09, width * 0.1),
		CFrame.new(0, height * 0.48, -width * 0.54),
		DARK,
		model
	)
	moveMouth(model, Vector3.new(0, -height * 0.02, -width * 0.12))
end

Features.Beak = function(model, width, height, _color)
	addCone(
		model,
		"Beak",
		-- Turned to grow forward out of the face, nose-down by a few degrees.
		CFrame.new(0, height * 0.44, -width * 0.38) * CFrame.Angles(-math.pi / 2 - math.rad(12), 0, 0),
		height * 0.28,
		width * 0.12,
		Color3.fromRGB(255, 190, 80)
	)
end

Features.Whiskers = function(model, width, height, _color)
	for _, side in { -1, 1 } do
		for _, lift in { 1, -1 } do
			makePart(
				"Whisker",
				Vector3.new(width * 0.34, height * 0.022, height * 0.022),
				CFrame.new(side * width * 0.32, height * (0.4 + lift * 0.035), -width * 0.32)
					* CFrame.Angles(0, 0, side * math.rad(10) * lift),
				WHITE,
				Enum.PartType.Cylinder,
				model
			)
		end
	end
end

-- Dark rings behind the eyes. A disc laid flat against a curved face, the same
-- trick the props use for blush: the rim clips into the cheek, which is what
-- makes it read as a marking rather than as a badge stuck on the front.
Features.Patches = function(model, width, height, _color)
	for _, side in { -1, 1 } do
		makePart(
			"Patch",
			Vector3.new(width * 0.05, width * 0.34, width * 0.34),
			CFrame.new(side * width * 0.18, height * 0.6, -width * 0.44) * CFrame.Angles(0, math.pi / 2, 0),
			DARK,
			Enum.PartType.Cylinder,
			model
		)
	end
end

-- Three balls curling up and back.
Features.Tail = function(model, width, height, color)
	local y, z, size = height * 0.34, width * 0.46, width * 0.16
	for index = 1, 3 do
		makeBall(`Tail{index}`, Vector3.one * size, CFrame.new(0, y, z), color, model)
		y += size * 0.5
		z += size * 0.42
		size *= 0.82
	end
end

-- A whale's tail: two flats meeting in a V off the back.
Features.Fluke = function(model, width, height, color)
	for _, side in { -1, 1 } do
		makeBall(
			"Fluke",
			Vector3.new(width * 0.34, height * 0.07, width * 0.26),
			CFrame.new(side * width * 0.2, height * 0.46, width * 0.52) * CFrame.Angles(0, 0, -side * math.rad(30)),
			color:Lerp(DARK, 0.15),
			model
		)
	end
end

Features.Fins = function(model, width, height, color)
	for _, side in { -1, 1 } do
		makeBall(
			"Fin",
			Vector3.new(width * 0.3, height * 0.09, width * 0.24),
			CFrame.new(side * width * 0.44, height * 0.32, width * 0.04)
				* CFrame.Angles(0, side * math.rad(18), -side * math.rad(22)),
			color:Lerp(DARK, 0.12),
			model
		)
	end
end

-- The fronds an axolotl wears behind its head, fanned so the three read as
-- separate rather than as one lump.
Features.Frills = function(model, width, height, color)
	for _, side in { -1, 1 } do
		for index = -1, 1 do
			makeBall(
				"Frill",
				Vector3.new(width * 0.26, height * 0.09, width * 0.09),
				CFrame.new(side * width * 0.46, height * (0.62 + index * 0.13), width * 0.06)
					* CFrame.Angles(0, 0, -side * math.rad(index * 22)),
				PINK:Lerp(color, 0.3),
				model
			)
		end
	end
end

-- A skirt of short arms under the body, splayed so the tips are wider than the
-- roots.
Features.Tentacles = function(model, width, height, color)
	local ring = width * 0.34
	for index = 1, 6 do
		local theta = (index - 0.5) / 6 * math.pi * 2
		local x, z = math.sin(theta) * ring, math.cos(theta) * ring
		makeBall(
			"Tentacle",
			Vector3.new(width * 0.15, height * 0.26, width * 0.15),
			CFrame.new(x, height * 0.14, z) * CFrame.Angles(-math.rad(14) * (z / ring), 0, math.rad(14) * (x / ring)),
			color:Lerp(DARK, 0.1),
			model
		)
	end
end

Features.Legs = function(model, width, height, color)
	local leg = color:Lerp(DARK, 0.12)
	for _, side in { -1, 1 } do
		makeBall(
			"Haunch",
			Vector3.new(width * 0.26, height * 0.28, width * 0.34),
			CFrame.new(side * width * 0.42, height * 0.26, width * 0.08),
			leg,
			model
		)
		makeBall(
			"Foot",
			Vector3.new(width * 0.22, height * 0.08, width * 0.3),
			CFrame.new(side * width * 0.32, height * 0.06, -width * 0.34),
			leg,
			model
		)
	end
end

-- Wool over the crown, which falls far enough forward to read as a fringe.
Features.Fluff = function(model, width, height, color)
	for index = 1, 5 do
		local theta = (index - 0.5) / 5 * math.pi * 2
		makeBall(
			"Fluff",
			Vector3.one * width * 0.3,
			CFrame.new(math.sin(theta) * width * 0.3, height * 0.88, math.cos(theta) * width * 0.3),
			color:Lerp(WHITE, 0.35),
			model
		)
	end
end

Features.Wings = function(model, width, height, color)
	for _, side in { -1, 1 } do
		makeBall(
			"Wing",
			Vector3.new(width * 0.16, height * 0.52, width * 0.34),
			CFrame.new(side * width * 0.44, height * 0.48, width * 0.06)
				* CFrame.Angles(0, -side * math.rad(14), side * math.rad(8)),
			color:Lerp(DARK, 0.2),
			model
		)
	end
end

Features.Crown = function(model, width, height, _color)
	makePart(
		"CrownBand",
		Vector3.new(height * 0.1, width * 0.52, width * 0.52),
		CFrame.new(0, height * 0.97, 0) * CFrame.Angles(0, 0, math.pi / 2),
		GOLD,
		Enum.PartType.Cylinder,
		model
	)
	for index = 1, 4 do
		local theta = (index - 0.5) / 4 * math.pi * 2
		makeBall(
			"Spike",
			Vector3.one * width * 0.11,
			CFrame.new(math.sin(theta) * width * 0.24, height * 1.06, math.cos(theta) * width * 0.24),
			GOLD,
			model
		)
	end
end

-- A planet's ring, and the one shape here that's a single part: a disc wider
-- than the body, tilted. Its middle is buried inside the ball, so what shows is
-- a ring without anything having to be built as one.
--
-- Half again as wide as the body and no wider. A real planet's rings are more
-- than twice its diameter, and at that size a top-tier unit would be 17 studs
-- across where `Drop.Spacing` lands them 6.5 apart -- every ring in the garden
-- would be sitting in a neighbour.
Features.Ring = function(model, width, height, color)
	local ring = makePart(
		"Ring",
		Vector3.new(height * 0.04, width * 1.5, width * 1.5),
		CFrame.new(0, height * 0.52, 0)
			* CFrame.Angles(0, math.rad(20), math.rad(22))
			* CFrame.Angles(0, 0, math.pi / 2),
		color:Lerp(WHITE, 0.5),
		Enum.PartType.Cylinder,
		model
	)
	ring.Material = Enum.Material.Neon
end

-- Three crossed spokes above the head. Crossed rather than a flat five-pointed
-- star because a unit is walked around, and a flat star disappears edge-on.
Features.Star = function(model, width, height, _color)
	local centre = CFrame.new(0, height * 1.2, 0)
	local long, thin = width * 0.46, width * 0.09
	for _, size in
		{
			Vector3.new(long, thin, thin),
			Vector3.new(thin, long, thin),
			Vector3.new(thin, thin, long),
		}
	do
		local spoke = makeBall("Spoke", size, centre, Color3.fromRGB(255, 235, 140), model)
		spoke.Material = Enum.Material.Neon
	end
end

-- The one name here that builds nothing. A wider, deeper grin for the things
-- whose whole look is it -- a frog, an axolotl, a quokka -- laid out with the
-- rest of the face from `SMILES` above. It stays in the vocabulary so that it is
-- spelled and checked like every other feature.
Features.WideMouth = function() end

UnitVisuals.Features = Features

-- One warning per unknown name rather than one per unit built: a typo in a
-- theme would otherwise fill the output every time a garden fills up.
local warnedFeatures: { [string]: boolean } = {}

local function addFeatures(model: Model, def: Types.UnitDef, width: number, height: number)
	local names: { string } = def.Features or {}
	for _, name in names do
		local feature = Features[name]
		if feature then
			feature(model, width, height, def.Color)
		elseif not warnedFeatures[name] then
			warnedFeatures[name] = true
			warn(`Unit "{def.Name}" asks for feature "{name}", which UnitVisuals doesn't know; skipping it`)
		end
	end
end

local function buildBlob(def: Types.UnitDef, tier: number): Model
	local model = Instance.new("Model")
	local color = def.Color
	local height = UnitVisuals.blobHeight(tier)
	local width = height * 1.25

	local body = makeBall("Body", Vector3.new(width, height, width), CFrame.new(0, height / 2, 0), color, model)
	model.PrimaryPart = body

	-- Eyes on the -Z (front) face, each with a small highlight.
	local eyeSize = width * 0.14
	for _, side in { -1, 1 } do
		local eye = CFrame.new(side * width * 0.18, height * 0.6, -width * 0.44)
		makeBall("Eye", Vector3.one * eyeSize, eye, DARK, model)
		makeBall(
			"Shine",
			Vector3.one * eyeSize * 0.35,
			eye * CFrame.new(eyeSize * 0.2, eyeSize * 0.2, -eyeSize * 0.35),
			WHITE,
			model
		)
	end

	-- A smile under them. Eyes alone read as a face only straight on; from any
	-- other angle a pair of dots on a ball is just a pair of dots, and the mouth
	-- is what fixes that -- so long as it curves.
	local names: { string } = def.Features or {}
	local smile = if table.find(names, "WideMouth") then SMILES.Wide else SMILES.Default
	addSmile(model, width, height, width * smile.Spread, height * smile.Curve)

	addFeatures(model, def, width, height)

	return model
end

-- What makes a sparkle look like one: the body lit from inside, a glow around
-- it and a slow drift of glitter. Applied on top of whatever the model already
-- is, so it works the same on a procedural blob and on a theme's own model.
-- Variants that ask for it get the same treatment in their own colour.
local function addShine(model: Model, color: Color3)
	local body = model:FindFirstChild("Body")
	if body and body:IsA("BasePart") then
		body.Material = Enum.Material.Neon
	end

	local adornee = UnitVisuals.primaryPart(model)
	if not adornee then
		return
	end
	local _, size = model:GetBoundingBox()

	local light = Instance.new("PointLight")
	light.Color = color
	light.Brightness = 2
	light.Range = math.max(size.Y * 3, 8)
	light.Parent = adornee

	local glitter = Instance.new("ParticleEmitter")
	glitter.Texture = SPARKLE_TEXTURE
	glitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	glitter.LightEmission = 1
	glitter.Size = NumberSequence.new(size.Y * 0.22, 0)
	glitter.Transparency = NumberSequence.new(0.1, 1)
	glitter.Lifetime = NumberRange.new(0.7, 1.3)
	glitter.Rate = 9
	glitter.Speed = NumberRange.new(0.6, 1.6)
	glitter.SpreadAngle = Vector2.new(180, 180)
	glitter.Rotation = NumberRange.new(0, 360)
	glitter.RotSpeed = NumberRange.new(-60, 60)
	glitter.Parent = adornee
end

-- Pivot at the bottom centre, so placing an item rests it on the ground
-- instead of burying it to the waist. Model.WorldPivot is ignored once a
-- PrimaryPart exists, so the offset has to go on the part itself.
local function setBottomPivot(model: Model)
	local boxCFrame, boxSize = model:GetBoundingBox()
	local bottomCentre = CFrame.new(boxCFrame.Position.X, boxCFrame.Position.Y - boxSize.Y / 2, boxCFrame.Position.Z)
	local primary = model.PrimaryPart
	if primary then
		primary.PivotOffset = primary.CFrame:Inverse() * bottomCentre
	else
		model.WorldPivot = bottomCentre
	end
end

local function addLabel(model: Model, name: string, tier: number, sparkle: boolean?)
	local adornee = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if not adornee then
		return
	end
	local boxCFrame, boxSize = model:GetBoundingBox()
	local top = boxCFrame.Position.Y + boxSize.Y / 2

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Adornee = adornee
	billboard.Size = UDim2.fromScale(6, 1.6)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, top - adornee.Position.Y + 1.1, 0)
	billboard.MaxDistance = 80
	billboard.LightInfluence = 0

	local function makeText(text: string, color: Color3, position: UDim2, size: UDim2)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = position
		label.Size = size
		label.FontFace = Theme.Font
		label.Text = text
		label.TextColor3 = color
		label.TextScaled = true
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Theme.Palette.Background
		stroke.Parent = label
		label.Parent = billboard
	end
	makeText(name, Theme.Palette.Text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.6))
	-- A sparkle has no tier to speak of: it sits off the end of the ladder and
	-- can't be merged, so it's labelled by what it is instead.
	makeText(
		if sparkle then Theme.Text.Sparkle else `Lv. {tier}`,
		Theme.Palette.Accent,
		UDim2.fromScale(0, 0.6),
		UDim2.fromScale(1, 0.4)
	)

	billboard.Parent = adornee
end

function UnitVisuals.primaryPart(model: Model): BasePart?
	return model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
end

-- Binds a model to a part (a character's root) so it rides along without the
-- server moving it every frame. Welded parts must be unanchored.
function UnitVisuals.attachTo(model: Model, target: BasePart, offset: CFrame)
	local primary = UnitVisuals.primaryPart(model)
	if not primary then
		return
	end
	model:PivotTo(target.CFrame * offset)
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanQuery = false
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = primary
			end
		end
	end
	local carryWeld = Instance.new("WeldConstraint")
	carryWeld.Part0 = primary
	carryWeld.Part1 = target
	carryWeld.Parent = primary
	model:SetAttribute("Carried", true)
end

-- Takes any unit index: a tier on the merge ladder, or one of the theme's
-- sparkles on the end of it.
function UnitVisuals.build(tier: number): Model
	local def = Config.Units[tier]
	local template = findThemeModel(def.Model)

	local model: Model
	if template then
		model = template:Clone()
		if def.Scale then
			model:ScaleTo(def.Scale)
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = false
				descendant.CanTouch = false
			end
		end
	else
		-- Features are only for the built blob. A supplied model already is the
		-- artwork, and bolting procedural ears onto it would fight it.
		model = buildBlob(def, def.Tier or tier)
	end

	if def.Sparkle or def.Shine then
		addShine(model, def.Color)
	end

	setBottomPivot(model)
	model.Name = def.Name
	model:SetAttribute("Tier", tier)
	addLabel(model, def.Name, def.Tier or tier, def.Sparkle)
	CollectionService:AddTag(model, UnitVisuals.Tag)
	return model
end

return UnitVisuals
