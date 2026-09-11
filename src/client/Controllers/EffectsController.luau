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

local BOB_HEIGHT = 0.25
local BOB_SPEED = 2.2
local SQUASH = 0.06

local EffectsController = {}

-- Where each unit rests, captured before any local animation moves it.
local homes: { [Model]: CFrame } = setmetatable({}, { __mode = "k" }) :: any

function EffectsController.home(model: Model): CFrame
	local home = homes[model]
	if not home then
		home = model:GetPivot()
		homes[model] = home
	end
	return home
end

local function animate(now: number)
	for _, instance in CollectionService:GetTagged(UnitVisuals.Tag) do
		local model = instance :: Model
		-- Leave falling items to their tween, and carried ones to their weld.
		if not model.Parent or model:GetAttribute("Carried") or not model:GetAttribute("Landed") then
			continue
		end
		local home = EffectsController.home(model)
		-- Offset each item's phase so a garden full of them doesn't pulse in lockstep.
		local phase = now * BOB_SPEED + (model:GetAttribute("Tier") or 0) :: number + home.Position.X % 6.28
		model:PivotTo(home * CFrame.new(0, math.abs(math.sin(phase)) * BOB_HEIGHT, 0))

		local body = model:FindFirstChild("Body")
		local mesh = body and body:FindFirstChildOfClass("SpecialMesh")
		if mesh then
			local squash = math.sin(phase * 2) * SQUASH
			mesh.Scale = Vector3.new(1 + squash, 1 - squash, 1 + squash)
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
