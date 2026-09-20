--!strict
-- The middle of the map: the pad players spawn on, the moving walkway that rings
-- it, the paths out to each garden gate, and the four stations -- the crafting
-- machine, the prize wheel, the leaderboard and the egg pads -- stood around the
-- rim of the hub pad.
--
-- Everything is on the rim and the middle is left open. A landmark in the centre is
-- something to walk round rather than up to, and with four of them the middle was
-- becoming a maze; on the rim each one has a face turned inward, so a player
-- standing anywhere in the hub can see all four at once and walk straight at the one
-- they want.
--
-- Built after GardenService, which owns the World folder and decides how far
-- out the gardens sit.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local GardenService = require(script.Parent.GardenService)
local Types = require(ReplicatedStorage.Shared.Types)

local Balance = Config.Balance
local Garden = Balance.Garden
local Hub = Balance.Hub
local Theme = Config.Theme

local PAD_THICKNESS = 1
local KERB_HEIGHT = 1.4
local KERB_WIDTH = 1.2
-- Segments overlap slightly so the walkway has no seams to trip on.
local SEGMENT_OVERLAP = 1.06

-- The wheel: about 10 studs across, twice a player's height, which is big enough to
-- read its own face from across the open middle. The disc's bottom edge stays put as
-- the radius changes, so the centre is the radius plus that clearance. Where it
-- stands is STATION_GAPS' business, not a constant here.
local WHEEL_RADIUS = 5.2
local WHEEL_CENTRE_Y = 8.2
local WHEEL_THICKNESS = 1.25
-- How much of the disc behind shows as a rim around the drawn face.
local FACE_INSET = 0.94

-- The crafting station. The deepest of the four stations, which is what sets
-- STATION_INSET.
local MACHINE_WIDTH = 14
local MACHINE_HEIGHT = 8
local MACHINE_DEPTH = 7
local MACHINE_PLINTH = 1.2
-- How much of the frame shows around the screen on the front of it.
local SCREEN_EDGE = 1

-- The leaderboard, mirroring the wheel across the machine. Raised on a post so the
-- reading surface sits at eye level rather than at the ankles.
--
-- One face, one ranking. A board nobody can see both sides of at once can't be
-- compared, and a combined score of cash and rebirths is a number no player can
-- act on. So it ranks the one thing that's always moving -- total earned -- and
-- carries each player's rebirth count as a badge on their row, which is both
-- facts in one ranking. A second metric, if it ever wants ranking properly,
-- belongs on a second board standing beside this one.
local BOARD_WIDTH = 14
local BOARD_HEIGHT = 11
local BOARD_THICKNESS = 1.2
local BOARD_POST = 4
local BOARD_EDGE = 0.7
-- Enough that a name is legible from the middle of the hub, about 30 studs away.
local BOARD_PIXELS_PER_STUD = 34
-- The saved field the board ranks.
local BOARD_STAT = "TotalEarned"

-- Egg pads, stood around the rim of the hub pad rather than in a row: the middle
-- belongs to the crafting station and the two flanks to the wheel and the
-- leaderboard, and the rim is the one part of the hub nothing else uses.
--
-- They go in the *gaps* between the paths out to the gardens. Six paths leave the
-- ring at even angles, and a pad in front of one would be standing in the way of
-- everyone walking home.
local EGG_PLINTH = 1.6
-- Three of these have to fit across one gap, which at the station radius is about
-- 29 studs of clear arc once the path width is taken off it.
local EGG_PLINTH_WIDTH = 7
local EGG_SPACING = 9.5
-- Studs tall, and an egg is taller than it is wide. Big enough to read the sign
-- over it from the machine, small enough not to hide what's behind it.
local EGG_HEIGHT = 5
local EGG_WIDTH = 3.6
local EGG_SIGN_HEIGHT = 3
local EGG_PIXELS_PER_STUD = 40

local HubService = {}

local machinePosition: Vector3? = nil
-- Where each egg pad stands, by egg Id. PetService checks a hatch against these
-- rather than trusting the prompt: a ProximityPrompt is driven by the client, and
-- the distance it claims to enforce is the client's claim.
local eggPositions: { [string]: Vector3 } = {}
local eggPrompts: { [string]: ProximityPrompt } = {}
-- Row labels for each face of the leaderboard, filled in by LeaderboardService.
local boardRows: { [string]: { { Name: TextLabel, Value: TextLabel, Badge: TextLabel } } } = {}

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

-- Sweets laid over a path slab, with a kerb down each side. They sit on the slab
-- rather than replacing it, so what shows in the grouting between them is the
-- slab's own colour.
--
-- Laid square and butted up, not scattered. A path is *made*, and what keeps a
-- grid from reading as a repeat is the colours being mixed and every other row
-- being shifted half a tile, the way paving is laid -- not the tiles being
-- crooked. The row that the shift pushes over the edge is dropped rather than
-- left hanging over the grass.
local function tilePath(
	parent: Instance,
	centre: Vector3,
	direction: Vector3,
	length: number,
	width: number,
	tiles: { Color3 }
)
	local tile = Hub.PathTile
	local across = Vector3.new(-direction.Z, 0, direction.X)
	local step = tile.Size + tile.Gap
	-- The tiles fill the space between the kerbs, not the whole slab, or the
	-- outermost row would be laid underneath them.
	local paved = width - tile.KerbWidth * 2
	-- Rounded, not floored: the tile size is what a tile should look like, and
	-- the path is whatever width it is. Flooring 2.8 tiles' worth of room to two
	-- lays them half a stud wider than they were meant to be, which is the
	-- difference between a paved path and a row of slabs.
	local rows = math.max(math.round(length / step), 1)
	local columns = math.max(math.round(paved / step), 1)
	local rowStep = length / rows
	local columnStep = paved / columns

	for row = 1, rows do
		local shift = if row % 2 == 0 then columnStep / 2 else 0
		for column = 1, columns do
			local along = (row - 0.5) * rowStep - length / 2
			local side = (column - 0.5) * columnStep - paved / 2 + shift
			if math.abs(side) > paved / 2 - columnStep / 2 then
				continue
			end
			-- Both ends of the look have to be at the tile's own height. Aiming
			-- a raised eye at a target on the ground tips the part by the angle
			-- between them, which over one stud of direction and a stud of lift
			-- is most of a right angle -- tiles stood on their edges.
			local spot = centre + direction * along + across * side + Vector3.new(0, PAD_THICKNESS + tile.Rise / 2, 0)
			local sweet = makePart(
				"PathTile",
				Vector3.new(columnStep - tile.Gap, tile.Rise, rowStep - tile.Gap),
				CFrame.lookAt(spot, spot + direction),
				tiles[math.random(#tiles)],
				Theme.World.PathMaterial,
				parent
			)
			-- A third of a stud proud of the slab: walk over them, don't trip.
			sweet.CanCollide = false
			sweet.CastShadow = false
		end
	end

	-- The kerb framing both sides, which is what turns a field of tiles into a
	-- path. It runs the full length, including past the last row, so the path
	-- ends square rather than frayed.
	if not Theme.World.PathKerb then
		return
	end
	for _, side in { -1, 1 } do
		local spot = centre
			+ across * (side * (width / 2 - tile.KerbWidth / 2))
			+ Vector3.new(0, PAD_THICKNESS + tile.KerbHeight / 2, 0)
		local kerb = makePart(
			"PathKerb",
			Vector3.new(tile.KerbWidth, tile.KerbHeight, length),
			CFrame.lookAt(spot, spot + direction),
			Theme.World.PathKerb,
			Theme.World.PathMaterial,
			parent
		)
		kerb.CanCollide = false
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

	local tiles = Theme.World.PathTiles

	for index = 1, Balance.PlotCount do
		local angle = (index - 1) / Balance.PlotCount * math.pi * 2
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local centre = direction * (inner + length / 2)
		local position = centre + Vector3.new(0, PAD_THICKNESS / 2, 0)
		makePart(
			"Path",
			Vector3.new(Garden.GateWidth, PAD_THICKNESS, length),
			CFrame.lookAt(position, position + direction),
			Theme.World.Path,
			Theme.World.PathMaterial,
			paths
		)
		if tiles and #tiles > 0 then
			tilePath(paths, centre, direction, length, Garden.GateWidth, tiles)
		end
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

-- One pad per egg in Balance.Pets.Eggs: a plinth, an egg sat on it, and a sign
-- saying what it costs. The prompt is the whole interaction -- hatching is instant,
-- so there is nothing to open a panel for; the panel is for the inventory.
-- Where a station can stand. The paths out to the gardens leave at
-- `(i - 1) / PlotCount` of a turn, so the midpoint between two of them is at
-- `(i - 0.5) / PlotCount` -- those gaps are the only angles anything can stand at
-- without being in the way of somebody walking home.
local function gapAngle(gap: number): number
	local gaps = Balance.PlotCount
	return ((gap - 0.5) % gaps) / gaps * math.pi * 2
end

-- Shared with CanopyService, whose poles stand in those same gaps: a tent pole
-- in front of a path would be the one thing in the hub standing where everybody
-- walks.
HubService.gapAngle = gapAngle

-- Shortest way round between two angles, so 350 degrees and 10 are 20 apart.
local function separation(a: number, b: number): number
	local turn = math.pi * 2
	local delta = math.abs((a - b) % turn)
	return math.min(delta, turn - delta)
end

-- The gap the spawn pad points at. Everything else is placed relative to it, so the
-- arrangement holds whatever PlotCount is and wherever the spawn ends up.
local function spawnGap(): number
	local spawnAngle = math.atan2(-Hub.SpawnOffset, 0)
	local best, bestGap = math.huge, 1
	for gap = 1, Balance.PlotCount do
		local distance = separation(gapAngle(gap), spawnAngle)
		if distance < best then
			best, bestGap = distance, gap
		end
	end
	return bestGap
end

-- Which gap each station takes, counted round from the spawn pad's own gap. Written
-- as offsets rather than angles so the layout survives a change to PlotCount.
--
-- Gap 0 -- the spawn's own -- stays clear: it is where players arrive and walk in,
-- and a building there would be the first thing they bump into. The machine goes
-- opposite it, so it is what you see on arrival, with the wheel and the leaderboard
-- flanking it the way they always did. The eggs take the gap beside the spawn,
-- because a shop by the entrance is a shop people find.
local STATION_GAPS: { [string]: number } = {
	Eggs = 1,
	Wheel = 2,
	Machine = 3,
	Board = 4,
}
-- How far in from the walkway's inner edge a station stands. Enough to clear the
-- deepest of them -- the machine's plinth, at nine studs -- with room to walk round
-- the back.
local STATION_INSET = 9

local function buildEggPads(parent: Instance, origin: CFrame)
	local eggs = Balance.Pets.Eggs :: { Types.PetEggDef }
	if #eggs == 0 then
		return
	end
	local pads = Instance.new("Folder")
	pads.Name = "EggPads"
	pads.Parent = parent

	for index, egg in eggs do
		-- Side by side across the station, spread along its own tangent, so the three
		-- read as one shop rather than three landmarks. Cheapest on the left, which
		-- is the order Balance lists them in.
		local offsetX = (index - (#eggs + 1) / 2) * EGG_SPACING
		local base = origin * CFrame.new(offsetX, 0, 0)
		local model = Instance.new("Model")
		model.Name = `EggPad_{egg.Id}`
		model.Parent = pads

		local plinth = makePart(
			"Plinth",
			Vector3.new(EGG_PLINTH, EGG_PLINTH_WIDTH, EGG_PLINTH_WIDTH),
			base * CFrame.new(0, PAD_THICKNESS + EGG_PLINTH / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
			Theme.World.Border,
			Enum.Material.SmoothPlastic,
			model
		)
		plinth.Shape = Enum.PartType.Cylinder

		-- A ball stretched upward is an egg, near enough, and it costs one part.
		local tone = (Theme.Palette :: { [string]: Color3 })[egg.Tone] or Theme.Palette.Surface
		local eggY = PAD_THICKNESS + EGG_PLINTH + EGG_HEIGHT / 2
		local shell = makePart(
			"Egg",
			Vector3.new(EGG_WIDTH, EGG_HEIGHT, EGG_WIDTH),
			base * CFrame.new(0, eggY, 0),
			tone,
			Enum.Material.SmoothPlastic,
			model
		)
		shell.Shape = Enum.PartType.Ball
		model.PrimaryPart = shell

		-- The sign over it. A SurfaceGui on a part rather than a billboard, so it
		-- stays part of the scenery instead of turning to follow every player.
		local signY = eggY + EGG_HEIGHT / 2 + EGG_SIGN_HEIGHT / 2 + 0.6
		local sign = makePart(
			"Sign",
			Vector3.new(EGG_SPACING - 1.5, EGG_SIGN_HEIGHT, 0.4),
			base * CFrame.new(0, signY, 0),
			Theme.Palette.Background,
			Enum.Material.SmoothPlastic,
			model
		)
		sign.CanCollide = false

		local surface = Instance.new("SurfaceGui")
		surface.Face = Enum.NormalId.Front
		surface.PixelsPerStud = EGG_PIXELS_PER_STUD
		surface.Parent = sign
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.FontFace = Theme.Font
		-- The name and the price, and nothing else. The odds and what each pet does
		-- are a wall of text at this size, and they belong where the decision is
		-- actually made -- in the panel the prompt opens, which has room to lay them
		-- out and is read standing still.
		label.Text = `{egg.Name}\n{Format.number(egg.Cost)} {Theme.Text.Currency}`
		label.TextColor3 = Theme.Palette.Text
		label.TextScaled = true
		label.Parent = surface

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "EggPrompt"
		prompt.ActionText = "Look"
		prompt.ObjectText = egg.Name
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = Balance.Pets.PadRadius
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("Egg", egg.Id)
		prompt.Parent = shell

		eggPositions[egg.Id] = (base * CFrame.new(0, eggY, 0)).Position
		eggPrompts[egg.Id] = prompt
	end
end

-- One face of the leaderboard: a title and a column of rows, drawn onto a
-- screen inset into the board the same way the machine's is. The rows are built
-- empty and kept, so refreshing the board is setting text rather than rebuilding
-- a surface every minute.
local function buildBoardFace(model: Model, origin: CFrame, stat: string, title: string)
	-- A part's Front face is its -Z, which is the side looking at the spawn pad.
	local screen = makePart(
		`Screen{stat}`,
		Vector3.new(BOARD_WIDTH - BOARD_EDGE * 2, BOARD_HEIGHT - BOARD_EDGE * 2, 0.3),
		origin * CFrame.new(0, 0, -(BOARD_THICKNESS / 2 + 0.08)),
		Theme.Palette.Background,
		Enum.Material.SmoothPlastic,
		model
	)
	screen.CanCollide = false

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = BOARD_PIXELS_PER_STUD
	surface.LightInfluence = 0
	surface.Parent = screen

	local function label(props: { [string]: any }): TextLabel
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.FontFace = Theme.Font
		text.TextScaled = false
		text.TextColor3 = Theme.Palette.Text
		for key, value in props do
			(text :: any)[key] = value
		end
		text.Parent = surface
		return text
	end

	local rowCount = Balance.Leaderboard.BoardRows
	local headerHeight = 0.16
	local rowHeight = (1 - headerHeight) / rowCount

	label({
		Text = title,
		Size = UDim2.fromScale(1, headerHeight),
		TextColor3 = Theme.Palette.Accent,
		TextSize = math.floor(BOARD_HEIGHT * headerHeight * BOARD_PIXELS_PER_STUD * 0.8),
	})

	local rows = {}
	for rank = 1, rowCount do
		local y = headerHeight + (rank - 1) * rowHeight
		local size = math.floor(BOARD_HEIGHT * rowHeight * BOARD_PIXELS_PER_STUD * 0.72)
		rows[rank] = {
			Name = label({
				Text = "",
				Position = UDim2.fromScale(0.04, y),
				Size = UDim2.fromScale(0.62, rowHeight),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextSize = size,
				TextTruncate = Enum.TextTruncate.AtEnd,
			}),
			Value = label({
				Text = "",
				Position = UDim2.fromScale(0.58, y),
				Size = UDim2.fromScale(0.26, rowHeight),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.Palette.Accent,
				TextSize = size,
			}),
			-- The second fact, carried rather than ranked.
			Badge = label({
				Text = "",
				Position = UDim2.fromScale(0.86, y),
				Size = UDim2.fromScale(0.12, rowHeight),
				TextXAlignment = Enum.TextXAlignment.Right,
				TextColor3 = Theme.Palette.TextMuted,
				TextSize = size,
			}),
		}
	end
	boardRows[stat] = rows
end

-- The leaderboard itself: a post and a board, turned to face the spawn pad the
-- same way the wheel is. Server-built, like the plinths and the garden name
-- boards, because the whole point of a ranking is that everyone can read it.
local function buildLeaderboard(parent: Instance, origin: CFrame)
	local board = Instance.new("Model")
	board.Name = "Leaderboard"
	board.Parent = parent

	makePart(
		"Post",
		Vector3.new(1.8, BOARD_POST, 1.8),
		origin * CFrame.new(0, PAD_THICKNESS + BOARD_POST / 2, 0),
		Theme.World.Border,
		Enum.Material.SmoothPlastic,
		board
	)

	local bodyY = PAD_THICKNESS + BOARD_POST + BOARD_HEIGHT / 2
	makePart(
		"Body",
		Vector3.new(BOARD_WIDTH, BOARD_HEIGHT, BOARD_THICKNESS),
		origin * CFrame.new(0, bodyY, 0),
		Theme.World.Fence,
		Theme.World.FenceMaterial,
		board
	)

	buildBoardFace(board, origin * CFrame.new(0, bodyY, 0), BOARD_STAT, `Top {Theme.Text.Currency}`)
end

-- Where the crafting station stands, for the range check on feeding it.
function HubService.machinePosition(): Vector3?
	return machinePosition
end

function HubService.eggPosition(eggId: string): Vector3?
	return eggPositions[eggId]
end

function HubService.eggPrompts(): { [string]: ProximityPrompt }
	return eggPrompts
end

-- Fills one face of the leaderboard. Entries are already ranked and formatted;
-- rows past the end of the list are blanked, so a board that shrinks doesn't
-- leave a stale name on the bottom row.
function HubService.setLeaderboard(stat: string, entries: { { Name: string, Value: string, Badge: string } })
	local rows = boardRows[stat]
	if not rows then
		return
	end
	for rank, row in rows do
		local entry = entries[rank]
		row.Name.Text = if entry then `{rank}. {entry.Name}` else ""
		row.Value.Text = if entry then entry.Value else ""
		row.Badge.Text = if entry then entry.Badge else ""
	end
	-- An empty board should say so rather than sit blank and look broken.
	if #entries == 0 and rows[1] then
		rows[1].Name.Text = "No one yet — be the first!"
	end
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

	-- Every station on the rim, in a gap between the paths, turned to face the middle
	-- of the hub. Facing inward rather than at the spawn pad is what the move buys:
	-- a flat face -- the wheel's dial, the board's rows, the machine's screen -- is a
	-- hard read at an angle, and from the rim the whole open middle is square on to
	-- all four of them.
	local radius = padDiameter / 2 - STATION_INSET
	local centre = Vector3.new(0, 0, 0)
	local function station(name: string): CFrame
		local angle = gapAngle(spawnGap() + STATION_GAPS[name])
		local spot = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		return CFrame.lookAt(spot, centre)
	end

	buildMachine(hub, station("Machine"))
	buildWheel(hub, station("Wheel"))
	buildLeaderboard(hub, station("Board"))
	buildEggPads(hub, station("Eggs"))
end

return HubService
