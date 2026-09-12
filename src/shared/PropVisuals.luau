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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(script.Parent.Types)

local PropVisuals = {}

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
}

local function findThemeModel(name: string?): Model?
	if not name then
		return nil
	end
	local assets = ReplicatedStorage:FindFirstChild("ThemeAssets")
	local props = assets and assets:FindFirstChild("Props")
	local model = props and props:FindFirstChild(name)
	if model and model:IsA("Model") then
		return model
	end
	warn(`Theme prop "{name}" not found in ReplicatedStorage.ThemeAssets.Props; building a shape instead`)
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
		end
		for _, descendant in model:GetDescendants() do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		-- Supplied models are pivoted wherever the modeller left them, so drop
		-- the model by however far its lowest point sits below the pivot.
		local boxCFrame, boxSize = model:GetBoundingBox()
		local drop = boxCFrame.Position.Y - boxSize.Y / 2 - model:GetPivot().Position.Y
		model:PivotTo(base * CFrame.new(0, -drop, 0))
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
