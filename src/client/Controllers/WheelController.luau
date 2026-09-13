--!strict
-- Spins the prize wheel. The server decides the prize and sends the segment;
-- this turns every drawn face to land that segment under the ticker.
--
-- Two faces are drawn from the same module: one in the Wheel panel, one on the
-- wheel standing in the hub. Both are registered here, so they turn together
-- and a player watching the panel sees the same result as anyone looking at
-- the wheel in the world.
--
-- The spin is local. The wheel is server-built but only this client turns it,
-- so two players spinning at once each watch their own result rather than
-- fighting over one shared animation.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.UI.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)
local WheelFace = require(script.Parent.Parent.UI.WheelFace)

local Wheel = Config.Balance.Wheel

-- Full turns before it settles, so a spin always looks like a spin even when
-- the result is the segment it was already on.
local TURNS = 5
local SURFACE_NAME = "WheelSurface"

local WheelController = {}

local faces: { WheelFace.Face } = {}
local listeners: { (index: number, description: string) -> () } = {}
local spinning = false
-- Degrees, kept across spins so the wheel carries on from where it stopped.
local angle = 0
local latest: { [string]: any }? = nil

local function requestSpin()
	if spinning then
		return
	end
	Net.event("Spin"):FireServer()
end

-- Whether the hub button should answer a press: a spin to spend, and nothing
-- already turning.
function WheelController.spinReady(): boolean
	local snapshot = latest
	if not snapshot or spinning then
		return false
	end
	local data: Types.PlayerData = snapshot.Data
	return (snapshot.SpinsAvailable or Economy.spinsAvailable(data, os.time())) > 0
end

-- Every drawn face is driven from here rather than by whoever built it. The
-- wheel out in the hub has no panel watching state on its behalf, so when the
-- panel owned this the hub's own button was switched off at the start of the
-- first spin and never switched back on -- which looked exactly like bought
-- spins not counting.
local function refreshFaces()
	local ready = WheelController.spinReady()
	for _, face in faces do
		face.setSpinEnabled(ready)
	end
end

-- Panels register the face they draw so it turns with the rest.
function WheelController.register(face: WheelFace.Face)
	table.insert(faces, face)
	face.setRotation(angle)
	face.setSpinEnabled(WheelController.spinReady())
end

function WheelController.requestSpin()
	requestSpin()
end

function WheelController.onResult(listener: (index: number, description: string) -> ())
	table.insert(listeners, listener)
end

function WheelController.isSpinning(): boolean
	return spinning
end

-- Draws a face onto the wheel standing in the hub, once the server's parts have
-- replicated. Same drawing as the panel's, at whatever resolution the surface
-- gives it.
local function mountWorldFace()
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local stand = hub and hub:FindFirstChild("PrizeWheel")
	local plate = stand and stand:FindFirstChild("Face")
	if not (plate and plate:IsA("BasePart")) or plate:FindFirstChild(SURFACE_NAME) then
		return false
	end

	local surface: SurfaceGui = Components.surface({
		Name = SURFACE_NAME,
		-- The wheel in the hub is about 10 studs across, so the face needs the
		-- pixels to keep eight segment labels legible on it.
		PixelsPerStud = 90,
		MaxDistance = 130,
		Active = true,
		Parent = plate,
	})

	local face = WheelFace.create({ Size = UDim2.fromScale(1, 1), Parent = surface }, requestSpin)
	WheelController.register(face)
	return true
end

local function setRotation(value: number)
	for _, face in faces do
		face.setRotation(value)
	end
end

local function announce(index: number, description: string)
	for _, listener in listeners do
		task.spawn(listener, index, description)
	end
end

local function spinTo(index: number, description: string)
	local segments = #Wheel.Prizes
	-- Segment 1 is centred at the top at rest and the rest run clockwise from
	-- it, so bringing segment n under the ticker means turning back by its
	-- share of the circle. Always forward, so it never jerks backwards.
	local target = (-(index - 1) * 360 / segments) % 360
	local from = angle % 360
	angle = angle - from + target + TURNS * 360

	spinning = true
	refreshFaces()

	local driver = Instance.new("NumberValue")
	driver.Value = from
	driver.Changed:Connect(setRotation)

	local tween = TweenService:Create(
		driver,
		TweenInfo.new(Wheel.SpinSeconds, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
		{ Value = angle }
	)
	tween.Completed:Connect(function()
		driver:Destroy()
		spinning = false
		refreshFaces()
		announce(index, description)
	end)
	tween:Play()
end

function WheelController.start()
	Net.event("SpinResult").OnClientEvent:Connect(spinTo)

	State.onChange(function(snapshot)
		latest = snapshot
		refreshFaces()
	end)

	-- The hub replicates some time after the client starts, so keep looking
	-- until it's there. Characters respawning don't affect it.
	task.spawn(function()
		while not mountWorldFace() do
			task.wait(1)
		end
	end)
end

return WheelController
