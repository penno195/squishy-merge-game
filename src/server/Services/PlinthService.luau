--!strict
-- The sparkle plinths: a row of pedestals outside each garden's side fences,
-- holding whatever their owner has crafted.
--
-- Unlike the upgrade board and the crafting station's screen, these are built
-- and filled by the server, because the whole point of a trophy is that other
-- people can see it.
--
-- Odd-numbered sparkles stand down the left wall and even-numbered ones down
-- the right, each plinth a little taller than the one in front of it. So each
-- row climbs toward the back of the garden, and reading the pair rows across
-- climbs too -- the rarer the sparkle, the higher it stands.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)
local GardenService = require(script.Parent.GardenService)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local Garden = Config.Balance.Garden
local Theme = Config.Theme

local FLOOR_HEIGHT = 1
-- How far out from the fence line the pedestals stand. Outside it on purpose:
-- nothing can ever land on them, and the garden keeps every stud of its floor.
local SIDE_GAP = 4
local COLUMN_WIDTH = 2.6
local CAP_HEIGHT = 0.5
local CAP_OVERHANG = 0.9
-- The front pair's height, and what each pair adds over the one in front.
local BASE_HEIGHT = 2.5
local HEIGHT_STEP = 0.7
-- Sparkle units are the biggest models in the game; on a pedestal they want to
-- read as an ornament rather than loom over the fence.
local TROPHY_SCALE = 0.45
local TROPHY_LIGHT_RANGE = 9
-- How far the nameplates carry. Sixty gardens' worth of them legible from the
-- middle of the map turns the skyline into a wall of text, so they reach far
-- enough to read your own collection from your gate (44 studs to the furthest
-- one) or a neighbour's from the path outside it, and no further -- the hub is
-- 80 studs out, which puts them comfortably past it.
local PLATE_DISTANCE = 55

local PlinthService = {}

type Plinth = {
	-- Where the trophy stands, and what it's called when nothing does.
	Anchor: CFrame,
	Display: Folder,
	Name: TextLabel,
	Count: TextLabel,
}

local plinths: { [Model]: { Plinth } } = {}

local function makePart(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	material: Enum.Material,
	parent: Instance
): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Sparkle `position` in the theme's list decides everything about where its
-- plinth stands: which side, how far back, and how tall.
local function placement(position: number, perSide: number): (number, number, number)
	local side = if position % 2 == 1 then -1 else 1
	local row = math.ceil(position / 2)
	local x = side * (Garden.Width / 2 + SIDE_GAP)
	-- Evenly spread along the depth, with the front of the garden at -Z.
	local z = -Garden.Depth / 2 + Garden.Depth * row / (perSide + 1)
	local height = BASE_HEIGHT + (position - 1) * HEIGHT_STEP
	return x, z, height
end

local function buildPlinth(parent: Instance, origin: CFrame, position: number, perSide: number): Plinth
	local sparkle = Config.Sparkles[position]
	local x, z, height = placement(position, perSide)

	local model = Instance.new("Model")
	model.Name = `Plinth{position}`
	model.Parent = parent

	makePart(
		"Column",
		Vector3.new(COLUMN_WIDTH, height, COLUMN_WIDTH),
		origin * CFrame.new(x, FLOOR_HEIGHT + height / 2, z),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		model
	)
	local cap = makePart(
		"Cap",
		Vector3.new(COLUMN_WIDTH + CAP_OVERHANG, CAP_HEIGHT, COLUMN_WIDTH + CAP_OVERHANG),
		origin * CFrame.new(x, FLOOR_HEIGHT + height + CAP_HEIGHT / 2, z),
		Theme.World.Fence,
		Theme.World.FenceMaterial,
		model
	)

	local display = Instance.new("Folder")
	display.Name = "Display"
	display.Parent = model

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Plate"
	billboard.Size = UDim2.fromScale(9, 2.4)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	billboard.MaxDistance = PLATE_DISTANCE
	billboard.LightInfluence = 0
	billboard.Parent = cap

	local function line(color: Color3, position2: UDim2, size: UDim2): TextLabel
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = position2
		label.Size = size
		label.FontFace = Theme.Font
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = ""
		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Color = Theme.Palette.Background
		stroke.Parent = label
		label.Parent = billboard
		return label
	end

	local nameLabel = line(Theme.Palette.Text, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.62))
	local countLabel = line(Theme.Palette.Accent, UDim2.fromScale(0, 0.62), UDim2.fromScale(1, 0.38))
	nameLabel.Text = sparkle.Name

	return {
		Anchor = origin * CFrame.new(x, FLOOR_HEIGHT + height + CAP_HEIGHT, z),
		Display = display,
		Name = nameLabel,
		Count = countLabel,
	}
end

-- An empty plinth says what belongs on it but keeps the name greyed out, so
-- the gap in a collection is as legible as what's in it.
local function setEmpty(plinth: Plinth, name: string)
	plinth.Display:ClearAllChildren()
	plinth.Name.Text = name
	plinth.Name.TextColor3 = Theme.Palette.TextMuted
	plinth.Count.Text = "???"
	plinth.Count.TextColor3 = Theme.Palette.TextMuted
end

local function setTrophy(plinth: Plinth, index: number, count: number)
	plinth.Display:ClearAllChildren()

	local model = UnitVisuals.build(index)
	model:ScaleTo(TROPHY_SCALE)
	-- The unit's own floating name would fight the plinth's nameplate.
	local label = model:FindFirstChild("Label", true)
	if label then
		label:Destroy()
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("PointLight") then
			descendant.Range = TROPHY_LIGHT_RANGE
		end
	end
	model:PivotTo(plinth.Anchor)
	-- The idle squash the garden's units have, for free: the client animates
	-- anything tagged that knows where it rests.
	model:SetAttribute("Rest", plinth.Anchor)
	model:SetAttribute("Landed", true)
	model.Parent = plinth.Display

	plinth.Name.Text = Config.Units[index].Name
	plinth.Name.TextColor3 = Theme.Palette.Text
	plinth.Count.Text = if count > 1 then `Made x{count}` else "Made"
	plinth.Count.TextColor3 = Theme.Palette.Accent
end

-- Re-reads a player's collection onto their garden's plinths.
function PlinthService.refresh(player: Player)
	local plot = GardenService.getPlot(player)
	local data = DataService.get(player)
	local row = if plot then plinths[plot] else nil
	if not (row and data) then
		return
	end
	for position, plinth in row do
		local sparkle = Config.Sparkles[position]
		local count = data.Sparkles[sparkle.Id] or 0
		if count > 0 then
			setTrophy(plinth, Config.MaxTier + position, count)
		else
			setEmpty(plinth, sparkle.Name)
		end
	end
end

-- Empties a garden's plinths when its owner leaves, so the next player to be
-- given it doesn't inherit someone else's trophies.
function PlinthService.clear(player: Player)
	local plot = GardenService.getPlot(player)
	local row = if plot then plinths[plot] else nil
	if not row then
		return
	end
	for position, plinth in row do
		setEmpty(plinth, Config.Sparkles[position].Name)
	end
end

function PlinthService.init()
	local count = #Config.Sparkles
	if count == 0 then
		return
	end
	local perSide = math.ceil(count / 2)

	for _, plot in GardenService.plots() do
		local origin = plot:GetAttribute("Origin") :: CFrame
		local folder = Instance.new("Folder")
		folder.Name = "Plinths"
		folder.Parent = plot

		local row: { Plinth } = {}
		for position = 1, count do
			row[position] = buildPlinth(folder, origin, position, perSide)
			setEmpty(row[position], Config.Sparkles[position].Name)
		end
		plinths[plot] = row
	end
end

return PlinthService
