--!strict
-- Builds the world (ground, hub, fenced gardens), assigns a garden to each
-- player, and answers where items may land inside one.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local Balance = Config.Balance
local Garden = Balance.Garden
local Theme = Config.Theme

local FLOOR_HEIGHT = 1
local RAIL_HEIGHTS = { 1.8, 3.4 }
local RAIL_THICKNESS = 0.35
local POST_SPACING = 6
local POST_SIZE = 0.6
local PLOT_GAP = 16
local HUB_CLEARANCE = 34

local GardenService = {}

local plots: { Model } = {}
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

-- Far enough out that neighbouring gardens and the hub never overlap.
local function plotRadius(): number
	local count = Balance.PlotCount
	local fromHub = HUB_CLEARANCE + Garden.Depth / 2
	if count <= 1 then
		return fromHub
	end
	return math.max(fromHub, (Garden.Width + PLOT_GAP) / (2 * math.sin(math.pi / count)))
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

-- A big screen standing over the back wall. The owner's client draws the
-- upgrade UI onto its front face.
local function buildUpgradeBoard(plot: Model, origin: CFrame)
	local width = Garden.BoardWidth
	local height = Garden.BoardHeight
	local bottom = FLOOR_HEIGHT + Garden.FenceHeight - 1
	local centreY = bottom + height / 2
	local backZ = Garden.Depth / 2

	-- The part's Front face (-Z) looks into the garden.
	local screen = makePart(
		"UpgradeBoard",
		Vector3.new(width, height, 0.6),
		origin * CFrame.new(0, centreY, backZ - 0.5),
		Theme.Palette.Background,
		Enum.Material.SmoothPlastic,
		plot
	)
	screen.CanCollide = false

	local frame = makePart(
		"BoardFrame",
		Vector3.new(width + 1.6, height + 1.6, 0.4),
		origin * CFrame.new(0, centreY, backZ - 0.1),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		plot
	)
	frame.CanCollide = false

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

	local radius = plotRadius()
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
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.new(0, 0.5, 0)
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
	local x = (math.random() * 2 - 1) * halfWidth
	local z = (math.random() * 2 - 1) * halfDepth
	local restY = FLOOR_HEIGHT + Balance.Drop.RestLift
	return origin * CFrame.new(x, restY, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
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
	local x = math.clamp(localPosition.X, -(Garden.Width / 2 - padding), Garden.Width / 2 - padding)
	local z = math.clamp(localPosition.Z, -(Garden.Depth / 2 - padding), Garden.Depth / 2 - padding)
	local restY = FLOOR_HEIGHT + Balance.Drop.RestLift
	return origin * CFrame.new(x, restY, z) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
end

return GardenService
