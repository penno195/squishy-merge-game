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
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local SQUASH = 0.09
local SQUASH_SPEED = 2.2

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

-- The idle: units squash and stretch on the spot with their base planted on
-- the floor. Scaling the mesh alone would lift them off it and sink them
-- through it in turn, since a part scales about its centre.
local function animate(now: number)
	for _, instance in CollectionService:GetTagged(UnitVisuals.Tag) do
		local model = instance :: Model
		-- Leave falling items to their tween, and carried ones to their weld.
		if not model.Parent or model:GetAttribute("Carried") or not model:GetAttribute("Landed") then
			continue
		end
		local rest = restPose(model)
		if not rest then
			continue
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
			-- A theme model with no squishable body just sits where it landed.
			model:PivotTo(rest)
		end
	end
end

local function playMergeEffect(position: Vector3, tier: number)
	local def = Config.Theme.Units[tier]
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

	local soundId = Config.Theme.Sounds.Merge
	if soundId then
		local sound = Instance.new("Sound")
		sound.SoundId = soundId
		sound.RollOffMaxDistance = 120
		sound.Parent = origin
		sound:Play()
	end

	Debris:AddItem(origin, 2)
end

function EffectsController.start()
	RunService.Heartbeat:Connect(function()
		animate(Workspace:GetServerTimeNow())
	end)
	Net.event("MergeEffect").OnClientEvent:Connect(playMergeEffect)
end

return EffectsController
