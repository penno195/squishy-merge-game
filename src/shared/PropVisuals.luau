--!strict
-- Builds a piece of scenery. A theme can supply real models under
-- ReplicatedStorage.ThemeAssets.Props (matched by PropDef.Model); anything
-- missing is built from parts in the theme's own colours, the same way
-- UnitVisuals falls back to a blob.
--
-- The point of the fallback is that a new skin looks dressed before anyone has
-- modelled or bought a single asset for it. Swap a real model in later by
-- dropping it into ThemeAssets.Props and naming it in the theme -- nothing
-- here or in the placement code changes.
--
-- Every shape is built with its base at y = 0 of the CFrame it's given, so
-- callers just hand over a spot on the ground.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Tint = require(script.Parent.Tint)
local Types = require(script.Parent.Types)

local PropVisuals = {}

-- Props that squash in place the way units do. The client animates them;
-- nothing on the server treats them any differently.
PropVisuals.SquishTag = "SquishyProp"

type Builder = (Model, CFrame, Types.PropDef, number, Color3) -> ()

local DEFAULT_HEIGHT = 14

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
	part.Shape = shape
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- A Cylinder's flat faces are on its local X axis, so standing one upright is a
-- quarter turn about Z.
local function upright(cframe: CFrame): CFrame
	return cframe * CFrame.Angles(0, 0, math.pi / 2)
end

-- A striped stick with a hook on top. The stripes are stacked bands rather than
-- a texture, which needs no artwork and reads correctly from any angle.
local function buildCane(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local radius = height * 0.045
	local shaft = height * 0.72
	local hookRadius = height * 0.13
	local bands = 9

	for index = 1, bands do
		local bandHeight = shaft / bands
		local y = (index - 0.5) * bandHeight
		makePart(
			`Band{index}`,
			Vector3.new(bandHeight, radius * 2, radius * 2),
			upright(base * CFrame.new(0, y, 0)),
			if index % 2 == 0 then accent else def.Color,
			Enum.PartType.Cylinder,
			model
		)
	end

	-- The hook sweeps a half circle from the top of the shaft up and over.
	local segments = 6
	local centre = Vector3.new(hookRadius, shaft, 0)
	local length = (math.pi * hookRadius / segments) * 1.2
	for index = 1, segments do
		local theta = (index - 0.5) / segments * math.pi
		local point = centre + Vector3.new(-math.cos(theta) * hookRadius, math.sin(theta) * hookRadius, 0)
		local tangent = Vector3.new(math.sin(theta), math.cos(theta), 0)
		makePart(
			`Hook{index}`,
			Vector3.new(length, radius * 2, radius * 2),
			-- lookAt puts -Z along the tangent; the quarter turn swings the
			-- cylinder's own axis onto it.
			base * CFrame.lookAt(point, point + tangent) * CFrame.Angles(0, math.pi / 2, 0),
			if index % 2 == 0 then accent else def.Color,
			Enum.PartType.Cylinder,
			model
		)
	end
end

-- A disc on a stick, facing whichever way the prop was placed.
local function buildLollipop(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local stickHeight = height * 0.62
	makePart(
		"Stick",
		Vector3.new(stickHeight, height * 0.045, height * 0.045),
		upright(base * CFrame.new(0, stickHeight / 2, 0)),
		accent,
		Enum.PartType.Cylinder,
		model
	)

	local headRadius = height * 0.21
	local headCentre = base * CFrame.new(0, stickHeight + headRadius * 0.8, 0)
	makePart(
		"Head",
		Vector3.new(height * 0.05, headRadius * 2, headRadius * 2),
		headCentre * CFrame.Angles(0, math.pi / 2, 0),
		def.Color,
		Enum.PartType.Cylinder,
		model
	)
	-- A smaller disc just proud of the face, standing in for a swirl.
	makePart(
		"Swirl",
		Vector3.new(height * 0.055, headRadius, headRadius),
		headCentre * CFrame.new(0, 0, -height * 0.004) * CFrame.Angles(0, math.pi / 2, 0),
		accent,
		Enum.PartType.Cylinder,
		model
	)
end

-- Stacked discs tapering to a point: a tree, a gumdrop, a party hat.
local function buildCone(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local layers = 8
	local baseRadius = height * 0.34
	for index = 1, layers do
		local top = (index - 1) / layers
		local radius = baseRadius * (1 - top * 0.92)
		local layerHeight = height / layers
		makePart(
			`Layer{index}`,
			Vector3.new(layerHeight, radius * 2, radius * 2),
			upright(base * CFrame.new(0, (index - 0.5) * layerHeight, 0)),
			if index % 2 == 0 then def.Color:Lerp(accent, 0.25) else def.Color,
			Enum.PartType.Cylinder,
			model
		)
	end
end

-- Balls of shrinking size piled up: a bush, a cupcake, a snowman.
local function buildStack(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local balls = 3
	local y = 0
	for index = 1, balls do
		local radius = height * (0.3 - (index - 1) * 0.07)
		y += radius
		makePart(
			`Ball{index}`,
			Vector3.one * radius * 2,
			base * CFrame.new(0, y, 0),
			if index == balls then accent else def.Color,
			Enum.PartType.Ball,
			model
		)
		-- Sink each ball into the one below so the pile reads as one lump.
		y += radius * 0.45
	end
end

-- Units are built from meshed balls rather than Ball parts so they can be
-- squashed, and a giant squishy has to match them or it reads as a different
-- kind of object standing in the same world.
local function makeBall(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local part = makePart(name, size, cframe, color, Enum.PartType.Block, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Eyes, a mouth, shines and blush on the front, which is the side facing the
-- middle of the map. A giant prop with a face reads as one of the things the
-- game is about; the same prop without one reads as furniture.
--
-- `spread` is half the gap between the eyes, `front` how far the face is from
-- the body's centre, and `lift` where the eyes sit above it.
local function addFace(model: Model, centre: CFrame, spread: number, front: number, eyeSize: number, lift: number)
	for _, side in { -1, 1 } do
		local eye = centre * CFrame.new(side * spread, lift, -front)
		makePart("Eye", Vector3.one * eyeSize, eye, Color3.fromRGB(35, 25, 45), Enum.PartType.Ball, model)
		makePart(
			"Shine",
			Vector3.one * eyeSize * 0.34,
			eye * CFrame.new(eyeSize * 0.18, eyeSize * 0.2, -eyeSize * 0.3),
			Color3.new(1, 1, 1),
			Enum.PartType.Ball,
			model
		)
		-- A disc laid flat against the face: a cylinder's axis is its local X,
		-- so the quarter turn points it at the viewer.
		makePart(
			"Blush",
			Vector3.new(eyeSize * 0.3, eyeSize * 1.25, eyeSize * 1.25),
			centre * CFrame.new(side * spread * 1.9, lift - eyeSize * 1.15, -front) * CFrame.Angles(0, math.pi / 2, 0),
			Color3.fromRGB(255, 150, 180),
			Enum.PartType.Cylinder,
			model
		)
	end

	-- A smile below them, built as an arc of segments the way the units' is, so
	-- a giant one reads as the same creature scaled up rather than as a relative
	-- of it. A straight slot would read as a grimace at this size most of all.
	local segments = 5
	local smileSpread = spread * 1.6
	local smileCurve = eyeSize * 0.8
	for index = 1, segments do
		local across = (index - 1) / (segments - 1) * 2 - 1
		makeBall(
			"Mouth",
			Vector3.new(smileSpread * 2 / (segments - 1) * 1.45, eyeSize * 0.42, eyeSize * 0.5),
			centre
				* CFrame.new(
					smileSpread * across,
					lift - eyeSize * 2.4 + smileCurve * across * across,
					-front - eyeSize * 0.1
				)
				* CFrame.Angles(0, 0, math.atan2(2 * smileCurve * across, smileSpread)),
			Color3.fromRGB(35, 25, 45),
			model
		)
	end
end

-- A giant version of the thing the player spends all day merging: a squashed
-- ball with a face, wider than it is tall so it looks soft.
local function buildBlob(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local width = height * 1.18
	local centre = base * CFrame.new(0, height / 2, 0)
	makeBall("Body", Vector3.new(width, height, width * 0.94), centre, def.Color, model)
	-- A pale highlight over the crown, which is what stops a big flat colour
	-- reading as a balloon.
	makeBall(
		"Sheen",
		Vector3.new(width * 0.5, height * 0.3, width * 0.34),
		centre * CFrame.new(-width * 0.16, height * 0.3, -width * 0.28),
		def.Color:Lerp(accent, 0.55),
		model
	)
	addFace(model, centre, width * 0.19, width * 0.47, width * 0.11, height * 0.09)
end

-- A stick of butter with the wrapper still half on. The squishy shop staple,
-- and a shape nothing else in the vocabulary covers.
local function buildButter(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local width = height * 1.55
	local depth = height * 0.82
	local centre = base * CFrame.new(0, height / 2, 0)

	makePart("Stick", Vector3.new(width, height, depth), centre, def.Color, Enum.PartType.Block, model)
	-- The paper, folded over one end and standing a shade proud of the butter.
	makePart(
		"Wrapper",
		Vector3.new(width * 0.44, height * 1.05, depth * 1.05),
		centre * CFrame.new(-width * 0.28, 0, 0),
		accent,
		Enum.PartType.Block,
		model
	)
	-- A pat cut off the open end, sitting on top.
	makePart(
		"Pat",
		Vector3.new(width * 0.24, height * 0.18, depth * 0.62),
		centre * CFrame.new(width * 0.28, height * 0.59, 0),
		def.Color:Lerp(Color3.new(1, 1, 1), 0.15),
		Enum.PartType.Block,
		model
	)
	addFace(model, centre, width * 0.13, depth * 0.5, height * 0.15, height * 0.08)
end

-- A ring of balls stood on its edge, iced over the top half the way one is
-- dipped, with sprinkles scattered across the icing.
local function buildDonut(model: Model, base: CFrame, def: Types.PropDef, height: number, accent: Color3)
	local tube = height * 0.17
	local ring = height / 2 - tube
	local centre = base * CFrame.new(0, ring + tube, 0)
	local segments = 20

	for index = 1, segments do
		local theta = (index - 0.5) / segments * math.pi * 2
		local point = Vector3.new(math.cos(theta) * ring, math.sin(theta) * ring, 0)
		local iced = math.sin(theta) > -0.15
		makePart(
			`Ring{index}`,
			Vector3.one * tube * 2,
			centre * CFrame.new(point),
			if iced then accent else def.Color,
			Enum.PartType.Ball,
			model
		)
	end

	for index = 1, 9 do
		local theta = (index / 10) * math.pi * 0.9 + math.pi * 0.05
		local point = Vector3.new(math.cos(theta) * ring, math.sin(theta) * ring, 0)
		makePart(
			`Sprinkle{index}`,
			Vector3.new(tube * 0.5, tube * 0.16, tube * 0.16),
			centre * CFrame.new(point) * CFrame.new(0, tube * 0.55, -tube * 0.5) * CFrame.Angles(0, 0, theta),
			if index % 2 == 0 then Color3.new(1, 1, 1) else def.Color,
			Enum.PartType.Block,
			model
		)
	end
end

local function buildSphere(model: Model, base: CFrame, def: Types.PropDef, height: number, _accent: Color3)
	local radius = height / 2
	makePart("Ball", Vector3.one * radius * 2, base * CFrame.new(0, radius, 0), def.Color, Enum.PartType.Ball, model)
end

local SHAPES: { [string]: Builder } = {
	Cane = buildCane,
	Lollipop = buildLollipop,
	Cone = buildCone,
	Stack = buildStack,
	Sphere = buildSphere,
	Blob = buildBlob,
	Butter = buildButter,
	Donut = buildDonut,
}

-- Props first, then Units: a giant version of a creature from the garden is
-- the same model stood somewhere else, and shouldn't need a second copy kept
-- in step with the first.
local function findThemeModel(name: string?): Model?
	if not name then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
	for _, folderName in { "Props", "Units" } do
		local folder = assets and assets:FindFirstChild(folderName)
		local model = folder and folder:FindFirstChild(name)
		if model and model:IsA("Model") then
			return model
		end
	end
	warn(`Theme prop "{name}" not found in ReplicatedStorage.ThemeAssets.Props or .Units; building a shape instead`)
	return nil
end

-- `base` is a spot on the ground; the prop is built standing on it, facing the
-- way the CFrame faces.
function PropVisuals.build(def: Types.PropDef, base: CFrame, parent: Instance): Model
	local template = findThemeModel(def.Model)
	if template then
		local model = template:Clone()
		if def.Scale then
			model:ScaleTo(def.Scale)
		elseif def.Height then
			local _, size = model:GetBoundingBox()
			model:ScaleTo(def.Height / size.Y)
		end
		-- Solid, like the built shapes, whose parts collide by default. A theme
		-- model often arrives with collision off, because the same file also
		-- serves as a unit that players walk over.
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
				descendant.CanCollide = true
			end
		end
		Tint.apply(model, def.Color)
		-- Supplied models are pivoted wherever the modeller left them, so drop
		-- the model by however far its lowest point sits below the pivot.
		local boxCFrame, boxSize = model:GetBoundingBox()
		local drop = boxCFrame.Position.Y - boxSize.Y / 2 - model:GetPivot().Position.Y
		model:PivotTo(base * CFrame.new(0, -drop, 0))
		if def.Squish then
			CollectionService:AddTag(model, PropVisuals.SquishTag)
		end
		model.Parent = parent
		return model
	end

	local model = Instance.new("Model")
	model.Name = def.Shape or "Prop"
	-- Annotated: the lookup and the fallback are the same signature, but Luau
	-- won't collapse the union on its own.
	local build: Builder = SHAPES[def.Shape or ""] or buildCone
	build(model, base, def, def.Height or DEFAULT_HEIGHT, def.Accent or Color3.new(1, 1, 1))
	model.Parent = parent
	return model
end

return PropVisuals
