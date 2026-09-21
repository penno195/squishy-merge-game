--!strict
-- Bounces the player off the squishy props.
--
-- The props are already the softest-looking things on the map -- the client
-- squashes and stretches them on the spot, the same idle the units get -- and
-- until now walking onto one felt like walking onto a rock. A thing that looks
-- like a cushion should behave like one.
--
-- Done on the client because the client owns its own character's physics:
-- setting the root's velocity here replicates outward on its own, and going
-- through the server would only add a round trip to something that has to land
-- on the same frame as the footstep to feel like a bounce at all.
--
-- Nothing is trusted from it either way. The bounce moves the player who
-- touched it and nothing else -- no currency, no state -- so the worst a
-- tampered client can do is launch itself, which it could already do.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local PropVisuals = require(ReplicatedStorage.Shared.PropVisuals)
local Sound = require(script.Parent.Parent.UI.Sound)

local BounceController = {}

-- Studs per second upward. A Roblox jump is 50, so this is a good deal more
-- than the player can manage on their own -- the point of standing on one.
local BOUNCE_SPEED = 72

-- Touched fires many times a second while a limb rests on a part, so without
-- this a prop would hold the player in the air rather than throw them off it.
-- Long enough to clear the contact, short enough that landing back on the same
-- prop bounces again, which is the toy.
local COOLDOWN = 0.35

-- Walking upward out of a bounce still counts as touching the prop, so a
-- player already on the way up is left alone.
local RISING = 5

-- The tagged Model a touched part belongs to, or nil. Props are built as models
-- with the tag on the model rather than the parts, so the touch has to walk up.
local function squishyPropOf(part: BasePart): Model?
	local instance: Instance? = part
	while instance and instance ~= Workspace do
		if instance:IsA("Model") and CollectionService:HasTag(instance, PropVisuals.SquishTag) then
			return instance
		end
		instance = instance.Parent
	end
	return nil
end

function BounceController.start()
	local player = Players.LocalPlayer
	local lastBounce = 0

	local function watch(character: Model)
		local humanoid = character:WaitForChild("Humanoid", 10)
		local root = character:WaitForChild("HumanoidRootPart", 10)
		if not (humanoid and humanoid:IsA("Humanoid")) then
			return
		end
		if not (root and root:IsA("BasePart")) then
			return
		end

		humanoid.Touched:Connect(function(hit: BasePart)
			local now = os.clock()
			if now - lastBounce < COOLDOWN then
				return
			end
			local velocity = root.AssemblyLinearVelocity
			if velocity.Y > RISING then
				return
			end
			-- Above the middle of whatever was touched, so brushing past the
			-- side of a tall prop doesn't fire it. The props worth standing on
			-- are all several studs tall, which puts their centre well above a
			-- player standing beside them on the floor.
			if root.Position.Y < hit.Position.Y then
				return
			end
			local prop = squishyPropOf(hit)
			if not prop then
				return
			end

			lastBounce = now
			-- Sideways momentum is kept, so a bounce taken at a run carries the
			-- player onward rather than straight up out of their own jump.
			root.AssemblyLinearVelocity = Vector3.new(velocity.X, BOUNCE_SPEED, velocity.Z)
			Sound.at(prop:GetPivot().Position, Config.Theme.Sounds.Bounce)
		end)
	end

	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
end

return BounceController
