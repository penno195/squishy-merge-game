--!strict
-- The crafting station's presence in the world: the screen on the front of the
-- cabinet, and the distance check the panel uses to know whether the player is
-- close enough to feed it.
--
-- The screen is drawn client-side, like the garden's upgrade board, so the
-- machine shows every player their own slots and their own clock even though
-- there is only one of it in the middle of the hub.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.UI.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local SURFACE_NAME = "CraftSurface"
local PIP_SIZE = 34

local CraftController = {}

local machine: Model? = nil
local listeners: { (index: number, sparkle: boolean) -> () } = {}
local latest: { [string]: any }? = nil

local function findMachine(): Model?
	local world = Workspace:FindFirstChild("World")
	local hub = world and world:FindFirstChild("Hub")
	local found = hub and hub:FindFirstChild("CraftMachine")
	return if found and found:IsA("Model") then found else nil
end

-- Whether the player is stood close enough to load the machine. The server
-- checks this too; this is only so the button can say so first.
function CraftController.atMachine(): boolean
	local stand = machine
	local character = LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (stand and root and root:IsA("BasePart")) then
		return false
	end
	local delta = stand:GetPivot().Position - root.Position
	return Vector2.new(delta.X, delta.Z).Magnitude <= Config.Balance.Craft.Radius
end

function CraftController.onResult(listener: (index: number, sparkle: boolean) -> ())
	table.insert(listeners, listener)
end

-- The screen on the cabinet: what's loaded, and how long is left.
local function mountScreen(): boolean
	local stand = findMachine()
	local plate = stand and stand:FindFirstChild("Screen")
	if not (plate and plate:IsA("BasePart")) then
		return false
	end
	machine = stand
	if plate:FindFirstChild(SURFACE_NAME) then
		return true
	end

	local surface: SurfaceGui = Components.surface({
		Name = SURFACE_NAME,
		PixelsPerStud = 40,
		MaxDistance = 150,
		Parent = plate,
	})

	local background: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Parent = surface,
	})
	Components.padding(14).Parent = background

	Components.label({
		Text = Theme.Text.Machine,
		Size = UDim2.new(1, 0, 0, 46),
		TextColor3 = Palette.Accent,
		MaxTextSize = 46,
		Stroke = 3,
		Parent = background,
	})

	local statusLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 74),
		Position = UDim2.fromOffset(0, 46),
		MaxTextSize = 72,
		Stroke = 3,
		Parent = background,
	})

	-- One pip per slot, filled in as units go in.
	local pipRow: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 126),
		Size = UDim2.fromOffset(Economy.craftSlots() * (PIP_SIZE + 10), PIP_SIZE),
		Parent = background,
	})
	Components.listLayout({ Padding = UDim.new(0, 10), FillDirection = Enum.FillDirection.Horizontal }).Parent = pipRow

	local pips: { Frame } = {}
	for index = 1, Economy.craftSlots() do
		local pip: Frame = Components.new("Frame", {
			BackgroundColor3 = Palette.Surface,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.fromOffset(PIP_SIZE, PIP_SIZE),
			Parent = pipRow,
		})
		Components.corner(PIP_SIZE // 2).Parent = pip
		Components.stroke(Palette.Text, 2).Parent = pip
		pips[index] = pip
	end

	local hintLabel = Components.label({
		Text = "",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.new(1, 0, 0, 34),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 32,
		Stroke = 2,
		Parent = background,
	})

	RunService.RenderStepped:Connect(function()
		local snapshot = latest
		if not snapshot or not surface.Parent then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		local inputs = data.Craft.Inputs

		for index, pip in pips do
			local tier = inputs[index]
			pip.BackgroundColor3 = if tier then Config.Units[tier].Color else Palette.Surface
		end

		if Economy.craftRunning(data) then
			local remaining = math.max((snapshot.CraftReadyAt or 0) - Workspace:GetServerTimeNow(), 0)
			if remaining <= 0 then
				statusLabel.Text = "Ready!"
				statusLabel.TextColor3 = Palette.Positive
				hintLabel.Text = "Come and collect it"
			else
				statusLabel.Text = Format.time(math.ceil(remaining))
				statusLabel.TextColor3 = Palette.Text
				hintLabel.Text = "Working..."
			end
		else
			statusLabel.Text = `{#inputs} / {Economy.craftSlots()}`
			statusLabel.TextColor3 = Palette.Text
			hintLabel.Text = `Bring a {Theme.Text.Unit} over`
		end
	end)

	return true
end

function CraftController.start()
	State.onChange(function(snapshot)
		latest = snapshot
	end)

	Net.event("CraftResult").OnClientEvent:Connect(function(index: number, sparkle: boolean)
		for _, listener in listeners do
			task.spawn(listener, index, sparkle)
		end
	end)

	-- The hub replicates some time after the client starts, so keep looking.
	task.spawn(function()
		while not mountScreen() do
			task.wait(1)
		end
	end)
end

return CraftController
