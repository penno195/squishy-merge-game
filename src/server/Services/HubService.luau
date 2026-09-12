--!strict
-- The middle of the map: the pad players spawn on, the moving walkway that
-- rings it, the paths out to each garden gate, and the prize wheel.
--
-- Built after GardenService, which owns the World folder and decides how far
-- out the gardens sit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GardenService = require(script.Parent.GardenService)

local Balance = Config.Balance
local Garden = Balance.Garden
local Hub = Balance.Hub
local Theme = Config.Theme

local PAD_THICKNESS = 1
local KERB_HEIGHT = 1.4
local KERB_WIDTH = 1.2
-- Segments overlap slightly so the walkway has no seams to trip on.
local SEGMENT_OVERLAP = 1.06

local WHEEL_RADIUS = 9
local WHEEL_CENTRE_Y = 15
local WHEEL_THICKNESS = 1.6
-- How much of the disc behind shows as a rim around the drawn face.
local FACE_INSET = 0.94

local HubService = {}

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

-- Whether a ring angle lines up with one of the garden paths.
local function crossesPath(angle: number, halfWidth: number): boolean
	for index = 1, Balance.PlotCount do
		local pathAngle = (index - 1) / Balance.PlotCount * math.pi * 2
		local delta = math.abs((angle - pathAngle + math.pi) % (math.pi * 2) - math.pi)
		if delta <= halfWidth then
			return true
		end
	end
	return false
end

-- The walkway. Anchored parts with a surface velocity are Roblox's conveyor:
-- the parts stay put and carry anything standing on them, which is far steadier
-- than sliding a platform around under the player's feet.
local function buildWalkway(parent: Instance, radius: number)
	local ring = Instance.new("Folder")
	ring.Name = "Walkway"
	ring.Parent = parent

	local count = Hub.RingSegments
	local length = (2 * math.pi * radius / count) * SEGMENT_OVERLAP

	for index = 1, count do
		local angle = (index - 0.5) / count * math.pi * 2
		local position = Vector3.new(math.cos(angle) * radius, PAD_THICKNESS / 2, math.sin(angle) * radius)
		-- Anticlockwise, so every segment pushes the same way round.
		local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))

		local segment = makePart(
			"WalkwaySegment",
			Vector3.new(Hub.RingWidth, PAD_THICKNESS, length),
			CFrame.lookAt(position, position + tangent),
			Theme.World.Path,
			Theme.World.PathMaterial,
			ring
		)
		segment.AssemblyLinearVelocity = tangent * Hub.RingSpeed
	end

	-- Kerbs on both edges, so the walkway reads as a track rather than a stripe.
	for _, side in { -1, 1 } do
		local kerbRadius = radius + side * (Hub.RingWidth / 2 + KERB_WIDTH / 2)
		local kerbLength = (2 * math.pi * kerbRadius / count) * SEGMENT_OVERLAP
		-- Half the angle a garden path subtends here, plus a little slack.
		local gap = math.atan((Garden.GateWidth / 2) / kerbRadius) + math.pi / count
		for index = 1, count do
			local angle = (index - 0.5) / count * math.pi * 2
			-- The outer kerb steps aside wherever a path leaves the ring, so
			-- players aren't walking over a rail to reach their garden.
			if side > 0 and crossesPath(angle, gap) then
				continue
			end
			local position =
				Vector3.new(math.cos(angle) * kerbRadius, PAD_THICKNESS + KERB_HEIGHT / 2, math.sin(angle) * kerbRadius)
			local tangent = Vector3.new(-math.sin(angle), 0, math.cos(angle))
			local kerb = makePart(
				"WalkwayKerb",
				Vector3.new(KERB_WIDTH, KERB_HEIGHT, kerbLength),
				CFrame.lookAt(position, position + tangent),
				Theme.World.Border,
				Enum.Material.SmoothPlastic,
				ring
			)
			kerb.CanCollide = false
		end
	end
end

-- A path from the walkway out to each garden gate, so it's obvious where to
-- step off.
local function buildPaths(parent: Instance, ringRadius: number, plotRadius: number)
	local paths = Instance.new("Folder")
	paths.Name = "Paths"
	paths.Parent = parent

	local inner = ringRadius + Hub.RingWidth / 2
	local outer = plotRadius - Garden.Depth / 2
	local length = outer - inner
	if length <= 0 then
		return
	end

	for index = 1, Balance.PlotCount do
		local angle = (index - 1) / Balance.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local position = direction * (inner + length / 2) + Vector3.new(0, PAD_THICKNESS / 2, 0)
		makePart(
			"Path",
			Vector3.new(Garden.GateWidth, PAD_THICKNESS, length),
			CFrame.lookAt(position, position + direction),
			Theme.World.Path,
			Theme.World.PathMaterial,
			paths
		)
	end
end

-- The wheel. The server builds the stand and a blank face; the client draws the
-- dial onto it, the same way the garden's upgrade board works. That keeps one
-- copy of the drawing shared with the Wheel panel.
local function buildWheel(parent: Instance)
	local prizes = Balance.Wheel.Prizes
	local centre = Vector3.new(0, WHEEL_CENTRE_Y, 0)

	local stand = Instance.new("Model")
	stand.Name = "PrizeWheel"
	stand:SetAttribute("Segments", #prizes)
	stand.Parent = parent

	makePart(
		"Base",
		Vector3.new(10, 1.5, 10),
		CFrame.new(0, PAD_THICKNESS + 0.75, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		stand
	)

	-- Behind the disc, not through it: the wheel faces -Z.
	local postHeight = WHEEL_CENTRE_Y - PAD_THICKNESS
	makePart(
		"Post",
		Vector3.new(2.4, postHeight, 2.4),
		CFrame.new(0, PAD_THICKNESS + postHeight / 2, WHEEL_THICKNESS / 2 + 1.4),
		Theme.World.Fence,
		Theme.World.FenceMaterial,
		stand
	)

	-- A Cylinder part's flat faces are on its local X axis, so turn it a quarter
	-- turn to stand the wheel up facing the spawn pad. This is the rim the drawn
	-- face sits inside.
	local disc = makePart(
		"Disc",
		Vector3.new(WHEEL_THICKNESS, WHEEL_RADIUS * 2, WHEEL_RADIUS * 2),
		CFrame.new(centre) * CFrame.Angles(0, math.pi / 2, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		stand
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.CanCollide = false

	-- Invisible: it exists only to hang the SurfaceGui on, just proud of the
	-- disc so the rim shows as a ring around the drawn face.
	local face = makePart(
		"Face",
		Vector3.new(WHEEL_RADIUS * 2 * FACE_INSET, WHEEL_RADIUS * 2 * FACE_INSET, 0.2),
		CFrame.new(centre) * CFrame.new(0, 0, -(WHEEL_THICKNESS / 2 + 0.1)),
		Theme.World.Hub,
		Enum.Material.SmoothPlastic,
		stand
	)
	face.CanCollide = false
	face.Transparency = 1

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Prize Wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 18
	prompt.RequiresLineOfSight = false
	prompt.Parent = stand:FindFirstChild("Post")
end

function HubService.init()
	local world = GardenService.world()
	if not world then
		warn("HubService.init ran before the world existed; skipping the hub")
		return
	end

	local hub = Instance.new("Folder")
	hub.Name = "Hub"
	hub.Parent = world

	local plotRadius = GardenService.plotRadius()
	local ringRadius = plotRadius * Hub.RingFraction

	-- Round, and sized to stop exactly at the walkway's inner edge, so the two
	-- meet without overlapping into a z-fight.
	local padDiameter = (ringRadius - Hub.RingWidth / 2) * 2
	local pad = makePart(
		"HubPad",
		Vector3.new(PAD_THICKNESS, padDiameter, padDiameter),
		CFrame.new(0, PAD_THICKNESS / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Theme.World.Hub,
		Enum.Material.SmoothPlastic,
		hub
	)
	pad.Shape = Enum.PartType.Cylinder

	buildWalkway(hub, ringRadius)
	buildPaths(hub, ringRadius, plotRadius)
	buildWheel(hub)
end

return HubService
