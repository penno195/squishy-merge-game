--!strict
-- Builds the model for a unit tier. A theme can supply real models under
-- ReplicatedStorage.ThemeAssets.Units (matched by UnitDef.Model); anything
-- missing falls back to a procedural squishy blob in the unit's colour.
-- Models are pivoted at their bottom centre so they rest on the ground.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(script.Parent.Config)

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

local function makeBall(name: string, size: Vector3, position: Vector3, color: Color3, parent: Instance): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Material = Enum.Material.SmoothPlastic
	part.Size = size
	part.CFrame = CFrame.new(position)
	part.Color = color
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return part
end

local function buildBlob(tier: number, color: Color3): Model
	local model = Instance.new("Model")
	local height = UnitVisuals.blobHeight(tier)
	local width = height * 1.25

	local body = makeBall("Body", Vector3.new(width, height, width), Vector3.new(0, height / 2, 0), color, model)
	model.PrimaryPart = body

	-- Eyes on the -Z (front) face, each with a small highlight.
	local eyeSize = width * 0.14
	for _, side in { -1, 1 } do
		local eyePosition = Vector3.new(side * width * 0.18, height * 0.6, -width * 0.44)
		makeBall("Eye", Vector3.one * eyeSize, eyePosition, Color3.fromRGB(35, 25, 45), model)
		local shinePosition = eyePosition + Vector3.new(eyeSize * 0.2, eyeSize * 0.2, -eyeSize * 0.35)
		makeBall("Shine", Vector3.one * eyeSize * 0.35, shinePosition, Color3.new(1, 1, 1), model)
	end

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
		model = buildBlob(def.Tier or tier, def.Color)
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
