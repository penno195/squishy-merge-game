--!strict
-- Makes units feel squishy: a constant idle bob and squash, plus the pop when
-- two of them merge.

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PropVisuals = require(ReplicatedStorage.Shared.PropVisuals)
local Sound = require(script.Parent.Parent.UI.Sound)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local SQUASH = 0.09
local SQUASH_SPEED = 2.2
-- A supplied model squashes by resizing every one of its parts, which costs far
-- more than a blob's single mesh scale. Past this many studs from the camera it
-- holds still instead: too far off to see a 9% squash, and a full garden of
-- models on the far side of the map would otherwise be most of the frame.
local SQUASH_DISTANCE = 140
-- Scenery is giant, so it breathes slower and a little shallower -- a big soft
-- thing wobbling at a small one's pace reads as vibrating -- and is seen from
-- much further off. There are only a handful of them, so the distance can be.
local PROP_SQUASH = 0.06
local PROP_SQUASH_SPEED = 1.3
local PROP_SQUASH_DISTANCE = 500

local EffectsController = {}

-- Where a unit rests. The server sets this before the model is ever parented,
-- so it's known even mid-fall. Reading the replicated pivot instead used to
-- strand items in mid-air: the landing position and the "Landed" attribute
-- replicate on separate paths, so an item could be treated as landed while its
-- position was still part-way down the drop.
local function restPose(model: Model): CFrame?
	local rest = model:GetAttribute("Rest")
	return if typeof(rest) == "CFrame" then rest else nil
end

-- A supplied model's parts as they stand at rest, in the model's own space, so
-- each frame can stretch them from there rather than from last frame's squash.
-- Taken the first time a model is animated, which is before anything here has
-- moved it, and measured from the model's pivot rather than from `Rest`: the
-- model can still be part-way down its drop when "Landed" arrives, and offsets
-- taken against where it will end up would leave it hanging there.
type Rig = {
	Parts: { BasePart },
	Offsets: { CFrame },
	Sizes: { Vector3 },
	-- Where the model stood when the rig was taken. A prop never moves, so this
	-- is its rest pose; a unit's comes from its "Rest" attribute instead.
	Pivot: CFrame,
	-- How tall the model stands at rest, so distance checks needn't measure a
	-- squashing model every frame.
	Height: number,
	Squashed: boolean,
}

-- Not a weak table. A weak key is the Lua handle for the model, not the model,
-- and Roblox lets that handle be collected while the model is still standing
-- there. The rig then went at every collection and was taken again mid-squash,
-- so whatever squash it was caught at became its rest shape: a visible snap
-- about once a second, drifting further from the real shape each time. Rigs
-- are dropped when their model leaves the game instead, in `start`.
local rigs: { [Model]: Rig } = {}

local function rigFor(model: Model): Rig
	local existing = rigs[model]
	if existing then
		return existing
	end
	local pivot = model:GetPivot()
	local _, size = model:GetBoundingBox()
	local rig: Rig = { Parts = {}, Offsets = {}, Sizes = {}, Pivot = pivot, Height = size.Y, Squashed = false }
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(rig.Parts, descendant)
			table.insert(rig.Offsets, pivot:ToObjectSpace(descendant.CFrame))
			table.insert(rig.Sizes, descendant.Size)
		end
	end
	rigs[model] = rig
	return rig
end

-- Stretches the whole model about its base: `stretch` is the scale along the
-- model's own axes. A part turned inside the model -- a tilted ear -- takes the
-- stretch along its own axes instead, which is how much each of them is
-- lengthened by the model's, so it deforms with the body rather than across it.
local function squashRig(rig: Rig, rest: CFrame, stretch: Vector3)
	local frames = table.create(#rig.Parts)
	for index, part in rig.Parts do
		local offset = rig.Offsets[index]
		local size = rig.Sizes[index]
		part.Size = Vector3.new(
			size.X * (offset.RightVector * stretch).Magnitude,
			size.Y * (offset.UpVector * stretch).Magnitude,
			size.Z * (offset.LookVector * stretch).Magnitude
		)
		frames[index] = rest * (CFrame.new(offset.Position * stretch) * offset.Rotation)
	end
	Workspace:BulkMoveTo(rig.Parts, frames, Enum.BulkMoveMode.FireCFrameChanged)
end

-- Back to rest size. Positions too, unless something else owns them now: a
-- carried unit is welded to the player, and moving its parts would fight that --
-- picking one up has the server pivot it, which puts its parts back in place.
local function settleRig(rig: Rig, rest: CFrame?)
	if not rig.Squashed then
		return
	end
	rig.Squashed = false
	if rest then
		squashRig(rig, rest, Vector3.one)
	else
		for index, part in rig.Parts do
			part.Size = rig.Sizes[index]
		end
	end
end

-- The idle: units squash and stretch on the spot with their base planted on
-- the floor. Scaling the mesh alone would lift them off it and sink them
-- through it in turn, since a part scales about its centre.
local function animate(now: number)
	local camera = Workspace.CurrentCamera
	local cameraPosition = if camera then camera.CFrame.Position else Vector3.zero
	for _, instance in CollectionService:GetTagged(UnitVisuals.Tag) do
		local model = instance :: Model
		-- Leave falling items to their tween, and carried ones to their weld.
		if not model.Parent or model:GetAttribute("Carried") or not model:GetAttribute("Landed") then
			local rig = rigs[model]
			if rig then
				settleRig(rig, nil)
			end
			continue
		end
		local rest = restPose(model)
		if not rest then
			continue
		end
		-- A trophy on a plinth turns on the spot. Turning the rest pose rather
		-- than the model is what keeps it compatible with the squash below,
		-- which builds every frame from that pose.
		local spin = model:GetAttribute("Spin")
		if typeof(spin) == "number" then
			rest *= CFrame.Angles(0, now * spin, 0)
		end

		-- Offset each unit's phase by where it stands, so a garden full of them
		-- doesn't pulse in lockstep.
		local phase = now * SQUASH_SPEED + rest.Position.X + rest.Position.Z
		local squash = math.sin(phase) * SQUASH

		local body = model:FindFirstChild("Body")
		local mesh = body and body:FindFirstChildOfClass("SpecialMesh")
		if mesh and body and body:IsA("BasePart") then
			mesh.Scale = Vector3.new(1 + squash, 1 - squash, 1 + squash)
			model:PivotTo(rest * CFrame.new(0, -body.Size.Y * squash / 2, 0))
		else
			-- A supplied model has no one mesh to scale, so every part is
			-- stretched and moved instead. Not Model:ScaleTo, which scales
			-- uniformly and rebuilds far more than this needs.
			local rig = rigFor(model)
			if (rest.Position - cameraPosition).Magnitude > SQUASH_DISTANCE then
				settleRig(rig, rest)
			else
				rig.Squashed = true
				squashRig(rig, rest, Vector3.new(1 + squash, 1 - squash, 1 + squash))
			end
		end
	end

	-- Scenery that asked to squash. A prop is placed once and never moves, so
	-- where it stood when its rig was taken is where it rests. Taller things
	-- are further from the camera at the same footprint, so the distance is
	-- measured to the prop's middle rather than to its base.
	for _, instance in CollectionService:GetTagged(PropVisuals.SquishTag) do
		local model = instance :: Model
		if not model.Parent then
			continue
		end
		local rig = rigFor(model)
		local rest = rig.Pivot
		local middle = rest.Position + Vector3.new(0, rig.Height / 2, 0)
		if (middle - cameraPosition).Magnitude > PROP_SQUASH_DISTANCE then
			settleRig(rig, rest)
			continue
		end
		local phase = now * PROP_SQUASH_SPEED + rest.Position.X + rest.Position.Z
		local squash = math.sin(phase) * PROP_SQUASH
		rig.Squashed = true
		squashRig(rig, rest, Vector3.new(1 + squash, 1 - squash, 1 + squash))
	end
end

-- A unit landing in the garden. Variants and sparkles get their own sound where
-- the theme names one, because those are the drops worth looking up for.
local function playSpawnEffect(position: Vector3, tier: number)
	local def = Config.Units[tier]
	local sounds = Config.Theme.Sounds
	Sound.at(position, if def.Variant or def.Sparkle then sounds.SpawnShiny or sounds.Spawn else sounds.Spawn)
end

local function playMergeEffect(position: Vector3, tier: number)
	local def = Config.Units[tier]
	local origin = Instance.new("Part")
	origin.Anchored = true
	origin.CanCollide = false
	origin.CanQuery = false
	origin.Transparency = 1
	origin.Size = Vector3.one
	origin.CFrame = CFrame.new(position)
	origin.Parent = Workspace

	local particles = Instance.new("ParticleEmitter")
	particles.Color = ColorSequence.new(def.Color)
	particles.Lifetime = NumberRange.new(0.35, 0.6)
	particles.Speed = NumberRange.new(10, 16)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rate = 0
	particles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.4),
		NumberSequenceKeypoint.new(1, 0),
	})
	particles.Parent = origin
	particles:Emit(28)

	Sound.at(position, Config.Theme.Sounds.Merge)

	Debris:AddItem(origin, 2)
end

function EffectsController.start()
	RunService.Heartbeat:Connect(function()
		animate(Workspace:GetServerTimeNow())
	end)
	for _, tag in { UnitVisuals.Tag, PropVisuals.SquishTag } do
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
			rigs[instance :: Model] = nil
		end)
	end
	Net.event("MergeEffect").OnClientEvent:Connect(playMergeEffect)
	Net.event("SpawnEffect").OnClientEvent:Connect(playSpawnEffect)
end

return EffectsController
