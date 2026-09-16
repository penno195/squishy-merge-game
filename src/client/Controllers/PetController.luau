--!strict
-- Walks every pet along behind its player. The server puts each pet in the
-- world, anchored, and never moves it again; every client moves all of them
-- locally, every frame. That is what makes it smooth: a pet the server moved
-- would only ever be as smooth as replication, and one welded to the character
-- went up with every jump and swung round with every turn.
--
-- Each client's pets are its own copy, so nothing here is authoritative -- a pet
-- is scenery, and nothing on the server asks where one is.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

-- How far behind the player the pet walks, from the root's centre to the pet's
-- nearest edge. A running foot swings about a stud and a half behind the root,
-- so this leaves roughly a stud of clear floor between the back foot and the pet.
local HEEL_CLEARANCE = 2.5
-- How quickly a pet closes the gap, per second. Along the ground it is lazy on
-- purpose -- the lag is what reads as following rather than being carried. Up and
-- down it is quick, so a step or a ramp doesn't leave it hanging in the air or
-- sunk into the floor.
local FOLLOW_RATE = 9
local CLIMB_RATE = 20
-- Turning, per second. Quick enough to face where it's going before it gets
-- there.
local TURN_RATE = 10
-- Further than this from where it should be and it jumps there instead: a
-- respawn or a teleport home shouldn't be followed by a pet sliding across the map.
local SNAP_DISTANCE = 60
-- The little hop it makes as it goes. Scaled by how fast it's moving, so a pet
-- settling into place doesn't bounce.
local HOP_HEIGHT = 0.45
local HOP_RATE = 14
local HOP_FULL_SPEED = 16
-- R6 legs are a fixed two studs and its HipHeight is 0, so its floor can't be
-- read off the humanoid the way R15's can. Only used when there's no floor under
-- the pet to find -- over a gap, say.
local R6_LEG_LENGTH = 2
-- How far down to look for the floor, from just above the root.
local FLOOR_PROBE = 40

type Follower = {
	Model: Model,
	-- Measured once, at rest, so a squashing or hopping pet isn't re-measured.
	Depth: number,
	Position: Vector3?,
	Yaw: number,
	HopPhase: number,
}

local PetController = {}

local followers: { [Model]: Follower } = {}
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
-- Garden units are CanCollide off, so the floor check walks the pet across the
-- ground under them rather than up onto their heads.
rayParams.RespectCanCollide = true

local function track(instance: Instance)
	if not instance:IsA("Model") or followers[instance] then
		return
	end
	local _, size = instance:GetBoundingBox()
	followers[instance] = { Model = instance, Depth = size.Z, Position = nil, Yaw = 0, HopPhase = 0 }
end

-- The angle a model is turned about Y to face along `direction`. A model faces
-- down -Z, the same way a character does.
local function yawFacing(direction: Vector3): number
	return math.atan2(-direction.X, -direction.Z)
end

-- The shortest way round from one angle to another, so a pet facing just past
-- south doesn't turn the long way to face just before it.
local function turnToward(from: number, to: number, alpha: number): number
	local delta = (to - from + math.pi) % (2 * math.pi) - math.pi
	return from + delta * alpha
end

local function floorUnder(root: BasePart, humanoid: Humanoid?, at: Vector3): number
	local origin = Vector3.new(at.X, root.Position.Y + 1, at.Z)
	local hit = Workspace:Raycast(origin, Vector3.new(0, -FLOOR_PROBE, 0), rayParams)
	if hit then
		return hit.Position.Y
	end
	local legs = if humanoid and humanoid.RigType == Enum.HumanoidRigType.R15 then humanoid.HipHeight else R6_LEG_LENGTH
	return root.Position.Y - root.Size.Y / 2 - legs
end

local function step(dt: number)
	-- Every character is left out of the floor check, not just the owner's, so a
	-- pet never climbs onto the player walking past it.
	local characters: { Instance } = {}
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(characters, player.Character)
		end
	end
	rayParams.FilterDescendantsInstances = characters

	local follow = 1 - math.exp(-FOLLOW_RATE * dt)
	local climb = 1 - math.exp(-CLIMB_RATE * dt)
	local turn = 1 - math.exp(-TURN_RATE * dt)

	for model, follower in followers do
		local ownerId = model:GetAttribute("OwnerId")
		local owner = if typeof(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
		local character = owner and owner.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- No one to follow yet, or they're streamed out: it waits where it is.
		if not (character and root and root:IsA("BasePart")) then
			continue
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")

		-- The root faces down -Z, so behind it is +Z.
		local behind = (root.CFrame * CFrame.new(0, 0, HEEL_CLEARANCE + follower.Depth / 2)).Position
		local target = Vector3.new(behind.X, floorUnder(root, humanoid, behind), behind.Z)

		local previous = follower.Position
		local position: Vector3
		if not previous or (previous - target).Magnitude > SNAP_DISTANCE then
			position = target
			follower.Yaw = yawFacing(root.CFrame.LookVector)
		else
			local flat = Vector3.new(previous.X, 0, previous.Z):Lerp(Vector3.new(target.X, 0, target.Z), follow)
			position = Vector3.new(flat.X, previous.Y + (target.Y - previous.Y) * climb, flat.Z)
		end

		-- Faces where it's heading while it moves, and the way its player faces
		-- once it has caught up, so a pet stood still isn't staring sideways.
		local moved = if previous
			then Vector3.new(position.X - previous.X, 0, position.Z - previous.Z)
			else Vector3.zero
		local speed = if dt > 0 then moved.Magnitude / dt else 0
		local facing = if speed > 1 then moved.Unit else root.CFrame.LookVector
		follower.Yaw = turnToward(follower.Yaw, yawFacing(facing), turn)

		local moving = math.clamp(speed / HOP_FULL_SPEED, 0, 1)
		if moving > 0.05 then
			follower.HopPhase += dt * HOP_RATE
		else
			follower.HopPhase = 0
		end
		local hop = math.abs(math.sin(follower.HopPhase)) * HOP_HEIGHT * moving

		follower.Position = position
		model:PivotTo(CFrame.new(position + Vector3.new(0, hop, 0)) * CFrame.Angles(0, follower.Yaw, 0))
	end
end

function PetController.start()
	for _, instance in CollectionService:GetTagged(UnitVisuals.PetTag) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(UnitVisuals.PetTag):Connect(track)
	CollectionService:GetInstanceRemovedSignal(UnitVisuals.PetTag):Connect(function(instance)
		followers[instance :: Model] = nil
	end)
	-- Before the frame is drawn, and after the character has moved, so the pet is
	-- placed against where its player is in the frame being drawn.
	RunService.PreRender:Connect(step)
end

return PetController
