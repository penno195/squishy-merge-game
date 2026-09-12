--!strict
-- Builds the world (ground, hub, fenced gardens), assigns a garden to each
-- player, and answers where items may land inside one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Balance = Config.Balance
local Garden = Balance.Garden
local Hub = Balance.Hub
local Theme = Config.Theme

local FLOOR_HEIGHT = 1
local RAIL_HEIGHTS = { 1.8, 3.4 }
local RAIL_THICKNESS = 0.35
local POST_SPACING = 6
local POST_SIZE = 0.6
-- How much of the board's backing plate shows around the screen.
local BOARD_EDGE = 0.9
-- The bin sits in the front-left corner, tucked behind the item drop zone so
-- nothing ever lands on it and players only reach it on purpose.
local BIN_INSET = 3
local BIN_SIZE = 4
local BIN_HEIGHT = 4.5
-- Items keep this far clear of the bin's centre.
local BIN_CLEARANCE = 8

local GardenService = {}

local plots: { Model } = {}
local binPositions: { [Model]: Vector3 } = {}
local worldFolder: Folder? = nil
local owners: { [Player]: Model } = {}
local itemFolders: { [Model]: Folder } = {}
local signLabels: { [Model]: TextLabel } = {}
local characterConnections: { [Player]: RBXScriptConnection } = {}

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
	part.Size = size
	part.CFrame = cframe
	part.Color = color
	part.Material = material
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

-- Far enough out that neighbouring gardens and the hub never overlap. Hub.PlotGap
-- is the knob for how spread out the arena feels.
function GardenService.plotRadius(): number
	local count = Balance.PlotCount
	local fromHub = Hub.Clearance + Garden.Depth / 2
	if count <= 1 then
		return fromHub
	end
	return math.max(fromHub, (Garden.Width + Hub.PlotGap) / (2 * math.sin(math.pi / count)))
end

-- Two rails and a line of posts between two points in the garden's local space.
local function buildFenceRun(parent: Instance, origin: CFrame, fromLocal: Vector3, toLocal: Vector3)
	local delta = toLocal - fromLocal
	local length = delta.Magnitude
	if length < 0.5 then
		return
	end
	local direction = delta.Unit
	local middle = fromLocal + delta / 2

	for _, height in RAIL_HEIGHTS do
		local up = Vector3.new(0, FLOOR_HEIGHT + height, 0)
		makePart(
			"Rail",
			Vector3.new(RAIL_THICKNESS, RAIL_THICKNESS * 2.5, length),
			origin * CFrame.lookAt(middle + up, middle + up + direction),
			Theme.World.Fence,
			Theme.World.FenceMaterial,
			parent
		)
	end

	local postCount = math.max(math.floor(length / POST_SPACING), 1)
	for index = 0, postCount do
		local point = fromLocal + direction * (length * index / postCount)
		makePart(
			"Post",
			Vector3.new(POST_SIZE, Garden.FenceHeight, POST_SIZE),
			origin * CFrame.new(point + Vector3.new(0, FLOOR_HEIGHT + Garden.FenceHeight / 2, 0)),
			Theme.World.Fence,
			Theme.World.FenceMaterial,
			parent
		)
	end
end

-- Fence around all four sides, with a gap at the front for the gate.
local function buildFence(plot: Model, origin: CFrame)
	local halfWidth = Garden.Width / 2
	local halfDepth = Garden.Depth / 2
	local halfGate = Garden.GateWidth / 2

	local backLeft = Vector3.new(-halfWidth, 0, halfDepth)
	local backRight = Vector3.new(halfWidth, 0, halfDepth)
	local frontLeft = Vector3.new(-halfWidth, 0, -halfDepth)
	local frontRight = Vector3.new(halfWidth, 0, -halfDepth)

	buildFenceRun(plot, origin, backLeft, backRight)
	buildFenceRun(plot, origin, frontLeft, backLeft)
	buildFenceRun(plot, origin, frontRight, backRight)
	-- The front, split either side of the gateway.
	buildFenceRun(plot, origin, frontLeft, Vector3.new(-halfGate, 0, -halfDepth))
	buildFenceRun(plot, origin, Vector3.new(halfGate, 0, -halfDepth), frontRight)
end

-- A big screen standing over the back wall, spanning the full width of the
-- fence. The owner's client draws the upgrade UI onto its front face.
local function buildUpgradeBoard(plot: Model, origin: CFrame)
	local width = Garden.Width
	local height = Garden.BoardHeight
	local bottom = FLOOR_HEIGHT + Garden.FenceHeight - 1
	local centreY = bottom + height / 2
	local backZ = Garden.Depth / 2

	-- The backing plate is the full width; the screen is inset in front of it,
	-- so what's left showing around the edge reads as a border.
	local frame = makePart(
		"BoardFrame",
		Vector3.new(width, height, 0.4),
		origin * CFrame.new(0, centreY, backZ - 0.1),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		plot
	)
	frame.CanCollide = false

	-- The part's Front face (-Z) looks into the garden.
	local screen = makePart(
		"UpgradeBoard",
		Vector3.new(width - BOARD_EDGE * 2, height - BOARD_EDGE * 2, 0.6),
		origin * CFrame.new(0, centreY, backZ - 0.5),
		Theme.Palette.Background,
		Enum.Material.SmoothPlastic,
		plot
	)
	screen.CanCollide = false

	-- Legs down to the ground so it doesn't float.
	for _, side in { -1, 1 } do
		local leg = makePart(
			"BoardLeg",
			Vector3.new(0.8, bottom, 0.8),
			origin * CFrame.new(side * (width / 2 - 1.5), bottom / 2, backZ - 0.3),
			Theme.World.Fence,
			Theme.World.FenceMaterial,
			plot
		)
		leg.CanCollide = false
	end
end

-- Where the bin stands, in the garden's own space.
local function binOffset(): Vector3
	return Vector3.new(-(Garden.Width / 2 - BIN_INSET), 0, -(Garden.Depth / 2 - BIN_INSET))
end

-- Run into it carrying a unit and it's sold. CanCollide is off so players run
-- through it rather than getting stuck on the corner.
local function buildBin(plot: Model, origin: CFrame)
	local offset = binOffset()
	local bin = makePart(
		"Bin",
		Vector3.new(BIN_SIZE, BIN_HEIGHT, BIN_SIZE),
		origin * CFrame.new(offset.X, FLOOR_HEIGHT + BIN_HEIGHT / 2, offset.Z),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		plot
	)
	bin.CanCollide = false

	local rim = makePart(
		"BinRim",
		Vector3.new(BIN_SIZE + 0.7, 0.5, BIN_SIZE + 0.7),
		origin * CFrame.new(offset.X, FLOOR_HEIGHT + BIN_HEIGHT, offset.Z),
		Theme.World.Fence,
		Theme.World.FenceMaterial,
		plot
	)
	rim.CanCollide = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(10, 3)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, BIN_HEIGHT / 2 + 2, 0)
	billboard.MaxDistance = 90
	billboard.LightInfluence = 0
	billboard.Parent = bin

	local function line(text: string, color: Color3, position: UDim2, size: UDim2)
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
	line(Theme.Text.Bin, Theme.Palette.Accent, UDim2.fromScale(0, 0), UDim2.fromScale(1, 0.55))
	line(
		`Run in carrying a {Theme.Text.Unit} to sell it`,
		Theme.Palette.Text,
		UDim2.fromScale(0, 0.55),
		UDim2.fromScale(1, 0.45)
	)
end

local function buildSign(plot: Model, origin: CFrame): TextLabel
	local anchor = makePart(
		"SignAnchor",
		Vector3.one,
		-- Clear of the upgrade board standing over the back wall.
		origin * CFrame.new(0, FLOOR_HEIGHT + Garden.FenceHeight + Garden.BoardHeight + 4, Garden.Depth / 2),
		Color3.new(),
		Enum.Material.SmoothPlastic,
		plot
	)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromScale(24, 4)
	billboard.MaxDistance = 300
	billboard.LightInfluence = 0
	billboard.Parent = anchor

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Theme.Font
	label.TextScaled = true
	label.TextColor3 = Theme.Palette.Text
	label.Text = "Empty Garden"
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Theme.Palette.Background
	stroke.Parent = label
	label.Parent = billboard
	return label
end

local function buildGarden(index: number, origin: CFrame, parent: Instance): Model
	local plot = Instance.new("Model")
	plot.Name = `Garden{index}`
	plot:SetAttribute("PlotIndex", index)
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("Origin", origin)
	-- Outside the gate, facing in.
	plot:SetAttribute("SpawnCFrame", origin * CFrame.new(0, 4, -(Garden.Depth / 2 + 8)) * CFrame.Angles(0, math.pi, 0))

	makePart(
		"Border",
		Vector3.new(Garden.Width + 2.5, FLOOR_HEIGHT, Garden.Depth + 2.5),
		origin * CFrame.new(0, FLOOR_HEIGHT / 2 - 0.15, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		plot
	)
	makePart(
		"Floor",
		Vector3.new(Garden.Width, FLOOR_HEIGHT, Garden.Depth),
		origin * CFrame.new(0, FLOOR_HEIGHT / 2, 0),
		Theme.World.PlotBase,
		Theme.World.PlotMaterial,
		plot
	)
	buildFence(plot, origin)
	buildUpgradeBoard(plot, origin)
	buildBin(plot, origin)
	binPositions[plot] = (origin * CFrame.new(binOffset())).Position

	local items = Instance.new("Folder")
	items.Name = "Items"
	items.Parent = plot
	itemFolders[plot] = items

	signLabels[plot] = buildSign(plot, origin)
	plot.Parent = parent
	return plot
end

local function sendHome(player: Player, character: Model)
	local plot = owners[player]
	if not plot then
		return
	end
	-- Deferred so the default spawn placement doesn't override the move.
	task.defer(function()
		if character.Parent and owners[player] == plot then
			character:PivotTo(plot:GetAttribute("SpawnCFrame") :: CFrame)
		end
	end)
end

function GardenService.init()
	-- Our ground replaces the template baseplate if the place has one.
	local templateBaseplate = Workspace:FindFirstChild("Baseplate")
	if templateBaseplate then
		templateBaseplate:Destroy()
	end

	local world = Instance.new("Folder")
	world.Name = "World"

	local radius = GardenService.plotRadius()
	local groundSize = (radius + Garden.Depth) * 2 + 60
	makePart(
		"Ground",
		Vector3.new(groundSize, 2, groundSize),
		CFrame.new(0, -1, 0),
		Theme.World.Ground,
		Theme.World.GroundMaterial,
		world
	)

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Size = Vector3.new(12, 0.5, 12)
	-- Off-centre, because the prize wheel stands in the middle of the hub, and
	-- lifted to sit on the hub pad rather than inside it.
	spawn.CFrame = CFrame.new(0, FLOOR_HEIGHT + 0.25, -Hub.SpawnOffset)
	spawn.Color = Theme.Palette.Primary
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = world

	local gardens = Instance.new("Folder")
	gardens.Name = "Gardens"
	gardens.Parent = world

	for index = 1, Balance.PlotCount do
		local angle = (index - 1) / Balance.PlotCount * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		plots[index] = buildGarden(index, CFrame.lookAt(position, Vector3.zero), gardens)
	end

	world.Parent = Workspace
	worldFolder = world
end

function GardenService.world(): Folder?
	return worldFolder
end

function GardenService.assign(player: Player): Model?
	for _, plot in plots do
		if plot:GetAttribute("OwnerUserId") == 0 then
			owners[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			player:SetAttribute("PlotIndex", plot:GetAttribute("PlotIndex"))
			signLabels[plot].Text = `{player.DisplayName}'s Garden`
			characterConnections[player] = player.CharacterAdded:Connect(function(character)
				sendHome(player, character)
			end)
			if player.Character then
				sendHome(player, player.Character)
			end
			return plot
		end
	end
	return nil
end

function GardenService.release(player: Player)
	local plot = owners[player]
	if not plot then
		return
	end
	owners[player] = nil
	local connection = characterConnections[player]
	if connection then
		connection:Disconnect()
		characterConnections[player] = nil
	end
	plot:SetAttribute("OwnerUserId", 0)
	itemFolders[plot]:ClearAllChildren()
	signLabels[plot].Text = "Empty Garden"
end

function GardenService.getPlot(player: Player): Model?
	return owners[player]
end

function GardenService.itemsFolder(player: Player): Folder?
	local plot = owners[player]
	return if plot then itemFolders[plot] else nil
end

function GardenService.binPosition(player: Player): Vector3?
	local plot = owners[player]
	return if plot then binPositions[plot] else nil
end

-- Pushes a resting spot out of the bin's clearance. The bin is in a corner, so
-- "away from the bin" is always further into the garden.
local function clearOfBin(x: number, z: number): (number, number)
	local offset = binOffset()
	local dx, dz = x - offset.X, z - offset.Z
	local distance = math.sqrt(dx * dx + dz * dz)
	if distance >= BIN_CLEARANCE then
		return x, z
	end
	if distance < 1e-3 then
		dx, dz, distance = 1, 1, math.sqrt(2)
	end
	local scale = BIN_CLEARANCE / distance
	return offset.X + dx * scale, offset.Z + dz * scale
end

-- A resting spot somewhere inside the fence, with a random facing.
function GardenService.randomRestCFrame(player: Player): CFrame?
	local plot = owners[player]
	if not plot then
		return nil
	end
	local origin = plot:GetAttribute("Origin") :: CFrame
	local padding = Balance.Drop.EdgePadding
	local halfWidth = Garden.Width / 2 - padding
	local halfDepth = Garden.Depth / 2 - padding
	local x, z = clearOfBin((math.random() * 2 - 1) * halfWidth, (math.random() * 2 - 1) * halfDepth)
	x, z = math.clamp(x, -halfWidth, halfWidth), math.clamp(z, -halfDepth, halfDepth)
	return origin * CFrame.new(x, FLOOR_HEIGHT, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

-- The same, but as close as possible to a world position (used when a player
-- puts an item down at their feet).
function GardenService.restCFrameAt(player: Player, worldPosition: Vector3): CFrame?
	local plot = owners[player]
	if not plot then
		return nil
	end
	local origin = plot:GetAttribute("Origin") :: CFrame
	local localPosition = origin:PointToObjectSpace(worldPosition)
	local padding = Balance.Drop.EdgePadding
	local halfWidth = Garden.Width / 2 - padding
	local halfDepth = Garden.Depth / 2 - padding
	local x, z = clearOfBin(
		math.clamp(localPosition.X, -halfWidth, halfWidth),
		math.clamp(localPosition.Z, -halfDepth, halfDepth)
	)
	x, z = math.clamp(x, -halfWidth, halfWidth), math.clamp(z, -halfDepth, halfDepth)
	return origin * CFrame.new(x, FLOOR_HEIGHT, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

return GardenService
