--!strict
-- Draws the upgrade UI onto the screen at the back of the player's own
-- garden. Built client-side, so each player only ever sees their own board.
--
-- The board spans the full width of the fence and is divided into one tile per
-- upgrade, so everything worth buying is readable from across the garden
-- without opening a menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Format = require(ReplicatedStorage.Shared.Format)
local State = require(script.Parent.Parent.State)
local Types = require(ReplicatedStorage.Shared.Types)
local UpgradeList = require(script.Parent.UpgradeList)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local SURFACE_NAME = "UpgradeSurface"
local HEADER_HEIGHT = 96

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

		local surface: SurfaceGui = Components.surface({
			Name = SURFACE_NAME,
			PixelsPerStud = 40,
			MaxDistance = 140,
			Active = true,
			Parent = board,
		})

		local background: Frame = Components.new("Frame", {
			BackgroundColor3 = Palette.Background,
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = surface,
		})
		Components.padding(16).Parent = background

		-- Header: what this is, and the two balances the tiles spend.
		local header: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),
			Parent = background,
		})
		Components.label({
			Text = `{Theme.Text.Unit} Upgrades`,
			Size = UDim2.fromScale(0.5, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Accent,
			MaxTextSize = 64,
			Stroke = 3,
			Parent = header,
		})

		local cashPill = Components.pill({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -252, 0.5, 0),
			Size = UDim2.fromOffset(240, 72),
		}, Theme.Icons.Currency or "", Palette.Text)
		cashPill.Instance.Parent = header

		local gemPill = Components.pill({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Size = UDim2.fromOffset(240, 72),
		}, Theme.Icons.Gems or "", Palette.Secondary)
		gemPill.Instance.Parent = header

		local body: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, HEADER_HEIGHT + 10),
			Size = UDim2.new(1, 0, 1, -(HEADER_HEIGHT + 10)),
			Parent = background,
		})

		local tiles = UpgradeList.tiles(body, UpgradeList.BoardIds)
		update = function(snapshot: { [string]: any })
			local data: Types.PlayerData = snapshot.Data
			cashPill.setText(Format.number(data.Cash))
			gemPill.setText(Format.number(data.Gems))
			tiles.update(snapshot)
		end

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
