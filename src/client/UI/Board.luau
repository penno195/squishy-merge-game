--!strict
-- Draws the upgrade UI onto the screen at the back of the player's own
-- garden. Built client-side, so each player only ever sees their own board.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local State = require(script.Parent.Parent.State)
local UpgradeList = require(script.Parent.UpgradeList)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local SURFACE_NAME = "UpgradeSurface"

local Board = {}

local function findBoard(): BasePart?
	local index = LocalPlayer:GetAttribute("PlotIndex")
	if typeof(index) ~= "number" then
		return nil
	end
	local world = Workspace:FindFirstChild("World")
	local gardens = world and world:FindFirstChild("Gardens")
	local garden = gardens and gardens:FindFirstChild(`Garden{index}`)
	local board = garden and garden:FindFirstChild("UpgradeBoard")
	return if board and board:IsA("BasePart") then board else nil
end

function Board.start()
	local mountedOn: BasePart? = nil
	local update: (({ [string]: any }) -> ())? = nil

	local function mount()
		local board = findBoard()
		if not board or board == mountedOn then
			return
		end
		mountedOn = board

		local existing = board:FindFirstChild(SURFACE_NAME)
		if existing then
			existing:Destroy()
		end

		local surface: SurfaceGui = Components.new("SurfaceGui", {
			Name = SURFACE_NAME,
			Face = Enum.NormalId.Front,
			PixelsPerStud = 40,
			LightInfluence = 0,
			MaxDistance = 120,
			Active = true,
			Parent = board,
		})

		local background: Frame = Components.card({
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Palette.Background,
			Parent = surface,
		})
		Components.padding(16).Parent = background

		Components.label({
			Text = `{Theme.Text.Unit} Upgrades`,
			Size = UDim2.new(1, 0, 0, 60),
			TextColor3 = Palette.Accent,
			Parent = background,
		})
		local body: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 68),
			Size = UDim2.new(1, 0, 1, -68),
			Parent = background,
		})

		update = UpgradeList.create(body).update
		local snapshot = State.get()
		if update and snapshot then
			update(snapshot)
		end
	end

	-- The board only exists once the server has handed out a garden.
	LocalPlayer:GetAttributeChangedSignal("PlotIndex"):Connect(mount)
	mount()

	State.onChange(function(snapshot)
		if not mountedOn then
			mount()
		end
		if update then
			update(snapshot)
		end
	end)
end

return Board
