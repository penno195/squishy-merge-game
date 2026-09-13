--!strict
-- The middle of the map: the pad players spawn on, the moving walkway that
-- rings it, the paths out to each garden gate, the crafting station in the
-- middle and the prize wheel beside it.
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

-- The wheel is a side attraction now that the crafting station has the middle,
-- so it's stood off to one side rather than looming over the hub -- but big
-- enough to read its own face from the spawn pad: about 10 studs across, twice
-- a player's height. The disc's bottom edge stays put as the radius changes,
-- so the centre is the radius plus that clearance.
local WHEEL_RADIUS = 5.2
local WHEEL_CENTRE_Y = 8.2
local WHEEL_THICKNESS = 1.25
local WHEEL_OFFSET = 19
-- How much of the disc behind shows as a rim around the drawn face.
local FACE_INSET = 0.94

-- The crafting station, facing the spawn pad from the middle of the hub.
local MACHINE_WIDTH = 14
local MACHINE_HEIGHT = 8
local MACHINE_DEPTH = 7
local MACHINE_PLINTH = 1.2
-- How much of the frame shows around the screen on the front of it.
local SCREEN_EDGE = 1

local HubService = {}

local machinePosition: Vector3? = nil

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
local function buildWheel(parent: Instance, origin: CFrame)
	local prizes = Balance.Wheel.Prizes
	local centre = CFrame.new(0, WHEEL_CENTRE_Y, 0)

	local stand = Instance.new("Model")
	stand.Name = "PrizeWheel"
	stand:SetAttribute("Segments", #prizes)
	stand.Parent = parent

	makePart(
		"Base",
		Vector3.new(7, 1.2, 7),
		origin * CFrame.new(0, PAD_THICKNESS + 0.6, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		stand
	)

	-- Behind the disc, not through it: the wheel faces -Z.
	local postHeight = WHEEL_CENTRE_Y - PAD_THICKNESS
	local post = makePart(
		"Post",
		Vector3.new(2, postHeight, 2),
		origin * CFrame.new(0, PAD_THICKNESS + postHeight / 2, WHEEL_THICKNESS / 2 + 0.9),
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
		origin * centre * CFrame.Angles(0, math.pi / 2, 0),
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
		origin * centre * CFrame.new(0, 0, -(WHEEL_THICKNESS / 2 + 0.1)),
		Theme.World.Hub,
		Enum.Material.SmoothPlastic,
		stand
	)
	face.CanCollide = false
	face.Transparency = 1

	-- Hung under the disc rather than on the post, which stands directly behind
	-- the middle of it: a prompt there floats over the prizes and covers the
	-- half of them a player most wants to read before spinning.
	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "PromptAnchor"
	promptAnchor.Position = Vector3.new(0, -(postHeight / 2) + 1.6, -(WHEEL_RADIUS + 1))
	promptAnchor.Parent = post

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "SpinPrompt"
	prompt.ActionText = "Spin"
	prompt.ObjectText = "Prize Wheel"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptAnchor
end

-- The crafting station. Like the upgrade board and the wheel, the server builds
-- the cabinet and a blank screen, and each player's own client draws their own
-- craft onto it -- so two players stood at the same machine each see their own
-- slots and their own clock.
local function buildMachine(parent: Instance, origin: CFrame)
	local machine = Instance.new("Model")
	machine.Name = "CraftMachine"
	machine.Parent = parent

	local plinthY = PAD_THICKNESS + MACHINE_PLINTH / 2
	makePart(
		"Plinth",
		Vector3.new(MACHINE_WIDTH + 2, MACHINE_PLINTH, MACHINE_DEPTH + 2),
		origin * CFrame.new(0, plinthY, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		machine
	)

	local bodyY = PAD_THICKNESS + MACHINE_PLINTH + MACHINE_HEIGHT / 2
	makePart(
		"Body",
		Vector3.new(MACHINE_WIDTH, MACHINE_HEIGHT, MACHINE_DEPTH),
		origin * CFrame.new(0, bodyY, 0),
		Theme.World.Fence,
		Theme.World.FenceMaterial,
		machine
	)

	-- The screen, inset into the front so the body shows as a frame around it.
	-- A part's Front face is its -Z, which is the side looking at the spawn pad.
	local screen = makePart(
		"Screen",
		Vector3.new(MACHINE_WIDTH - SCREEN_EDGE * 2, MACHINE_HEIGHT - SCREEN_EDGE * 2, 0.4),
		origin * CFrame.new(0, bodyY, -(MACHINE_DEPTH / 2 + 0.1)),
		Theme.Palette.Background,
		Enum.Material.SmoothPlastic,
		machine
	)
	screen.CanCollide = false

	-- One intake tube per slot along the top, so what the machine wants is
	-- readable before anyone opens a menu.
	local slots = Balance.Craft.Slots
	local spacing = (MACHINE_WIDTH - 3) / math.max(slots, 1)
	for index = 1, slots do
		local offsetX = (index - (slots + 1) / 2) * spacing
		local tube = makePart(
			"Intake",
			Vector3.new(2.2, 1.8, 1.8),
			origin
				* CFrame.new(offsetX, PAD_THICKNESS + MACHINE_PLINTH + MACHINE_HEIGHT + 0.9, 0)
				* CFrame.Angles(0, 0, math.pi / 2),
			Theme.World.Border,
			Enum.Material.SmoothPlastic,
			machine
		)
		tube.Shape = Enum.PartType.Cylinder
		tube.CanCollide = false
	end

	-- The dome over the top, lit from inside: the bit that reads as "something
	-- is happening in there".
	local dome = makePart(
		"Dome",
		Vector3.one * 5,
		origin * CFrame.new(0, PAD_THICKNESS + MACHINE_PLINTH + MACHINE_HEIGHT + 1.6, 0),
		Theme.Palette.Primary,
		Enum.Material.Neon,
		machine
	)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.35
	dome.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = Theme.Palette.Primary
	light.Brightness = 2.5
	light.Range = 26
	light.Parent = dome

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CraftPrompt"
	prompt.ActionText = "Use"
	prompt.ObjectText = Theme.Text.Machine
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Balance.Craft.Radius
	prompt.RequiresLineOfSight = false
	prompt.Parent = screen

	machinePosition = (origin * CFrame.new(0, bodyY, 0)).Position
end

-- Where the crafting station stands, for the range check on feeding it.
function HubService.machinePosition(): Vector3?
	return machinePosition
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
	buildMachine(hub, CFrame.identity)
	-- Turned to look at the spawn pad rather than left facing -Z like the
	-- machine it stands beside. A flat disc 19 studs to one side of a pad 22
	-- studs out is viewed at about 41 degrees, and a circle seen at 41 degrees
	-- is an ellipse three quarters as wide as it is tall -- which reads as a
	-- warped wheel rather than an angled one.
	local wheelPosition = Vector3.new(-WHEEL_OFFSET, 0, 0)
	buildWheel(hub, CFrame.lookAt(wheelPosition, Vector3.new(0, 0, -Hub.SpawnOffset)))
end

return HubService
