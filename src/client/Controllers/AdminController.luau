--!strict
-- The half of an admin command a client has to carry out itself. A player's own
-- client owns their character's physics, so a shove the server applied would be
-- overwritten a frame later; the server sends the command here instead and this
-- client shoves its own character. Squishy Rain comes here too, to every client:
-- each one rains around its own player, locally, so a server full of falling
-- squishies costs the server nothing.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PropVisuals = require(ReplicatedStorage.Shared.PropVisuals)
local UnitVisuals = require(ReplicatedStorage.Shared.UnitVisuals)

local LocalPlayer = Players.LocalPlayer

local FLING_SPEED = 110
local FLING_LIFT = 70
local FLING_SPIN = 25
-- Long enough to land before getting up; a fling has no duration of its own.
local FLING_RECOVER = 2.5
local ROCKET_SPEED = 170
local TRIP_PUSH = 14

-- The rain: a squishy every so often, somewhere around the player, falling
-- from high enough to be seen coming.
local RAIN_INTERVAL = 0.15
local RAIN_RADIUS = 45
local RAIN_HEIGHT = 55
local RAIN_SIZE_MIN = 2
local RAIN_SIZE_MAX = 5
local RAIN_LIFETIME = 5

local AdminController = {}

local function ownBody(): (BasePart?, Humanoid?)
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
		return root, humanoid
	end
	return nil, nil
end

-- Knocked over for a while, then back up. PlatformStand is what lets the body
-- tumble: while it's on, the humanoid stops holding itself upright.
local function knockDown(humanoid: Humanoid, seconds: number)
	humanoid.PlatformStand = true
	task.delay(seconds, function()
		if humanoid.Parent then
			humanoid.PlatformStand = false
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end

local function fling(root: BasePart, humanoid: Humanoid)
	local angle = math.random() * math.pi * 2
	local away = Vector3.new(math.cos(angle), 0, math.sin(angle))
	knockDown(humanoid, FLING_RECOVER)
	root.AssemblyLinearVelocity = away * FLING_SPEED + Vector3.new(0, FLING_LIFT, 0)
	root.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5).Unit
		* FLING_SPIN
end

local function rocket(root: BasePart, humanoid: Humanoid)
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	root.AssemblyLinearVelocity = Vector3.new(0, ROCKET_SPEED, 0)
end

local function trip(root: BasePart, humanoid: Humanoid, seconds: number)
	knockDown(humanoid, seconds)
	-- Forward and over: a push the way they were going, and a turn about their
	-- own right-hand side that tips them onto their face.
	root.AssemblyLinearVelocity = root.CFrame.LookVector * TRIP_PUSH + Vector3.new(0, 6, 0)
	root.AssemblyAngularVelocity = -root.CFrame.RightVector * 6
end

-- One falling squishy, from the theme's own creature in one of the ladder's
-- colours, as a single physical body so it bounces and rolls when it lands.
local function dropSquishy(folder: Folder, around: Vector3)
	local angle = math.random() * math.pi * 2
	local distance = math.sqrt(math.random()) * RAIN_RADIUS
	local spot = around + Vector3.new(math.cos(angle) * distance, RAIN_HEIGHT, math.sin(angle) * distance)
	local unit = Config.Units[math.random(#Config.Units)]
	local model = PropVisuals.build({
		Model = Config.Theme.CreatureModel,
		Shape = "Blob",
		Height = RAIN_SIZE_MIN + math.random() * (RAIN_SIZE_MAX - RAIN_SIZE_MIN),
		Color = unit.Color,
	}, CFrame.new(spot) * CFrame.Angles(0, angle, 0), folder)

	local primary = UnitVisuals.primaryPart(model)
	if not primary then
		model:Destroy()
		return
	end
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.CanQuery = false
			descendant.CanTouch = false
			descendant.Anchored = false
			if descendant ~= primary then
				local weld = Instance.new("WeldConstraint")
				weld.Part0 = primary
				weld.Part1 = descendant
				weld.Parent = primary
			end
		end
	end
	primary.AssemblyAngularVelocity = Vector3.new(math.random() - 0.5, 0, math.random() - 0.5) * 6
	Debris:AddItem(model, RAIN_LIFETIME)
end

local function rain(seconds: number)
	local folder = Instance.new("Folder")
	folder.Name = "SquishyRain"
	folder.Parent = Workspace
	local stopAt = os.clock() + seconds
	task.spawn(function()
		while os.clock() < stopAt do
			local root = ownBody()
			local around = if root then root.Position else Workspace.CurrentCamera.CFrame.Position
			dropSquishy(folder, around)
			task.wait(RAIN_INTERVAL)
		end
		Debris:AddItem(folder, RAIN_LIFETIME)
	end)
end

local function onEffect(commandId: string, seconds: number)
	if commandId == "Rain" then
		rain(seconds)
		return
	end
	local root, humanoid = ownBody()
	if not (root and humanoid) then
		return
	end
	if commandId == "Fling" then
		fling(root, humanoid)
	elseif commandId == "Rocket" then
		rocket(root, humanoid)
	elseif commandId == "Trip" then
		trip(root, humanoid, seconds)
	end
end

function AdminController.start()
	Net.event("AdminEffect").OnClientEvent:Connect(onEffect)
end

-- Fired by the panel. The server checks everything, so this is only the ask.
function AdminController.run(commandId: string, targetUserId: number?)
	Net.event("AdminCommand"):FireServer(commandId, targetUserId)
end

return AdminController
