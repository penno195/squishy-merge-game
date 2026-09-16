--!strict
-- The admin panel: pick a player, then pick what happens to them. Opened from the
-- Admin entry in the shop, which is where it's sold.
--
-- Three groups, in the order a troll reaches for them: things to do to someone
-- else, things to do to yourself, and the one that hits the whole server. The
-- panel only asks; AdminService decides, and says why when it won't.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminCommands = require(ReplicatedStorage.Shared.AdminCommands)
local AdminController = require(script.Parent.Parent.Parent.Controllers.AdminController)
local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Sound = require(script.Parent.Parent.Sound)

local LocalPlayer = Players.LocalPlayer
local Palette = Components.Palette
local Theme = Config.Theme

local PLAYER_BUTTON_WIDTH = 150
local PLAYER_ROW_HEIGHT = 58
local CELL_HEIGHT = 92
local SECTION_TITLE_HEIGHT = 28

local Admin = {}

function Admin.create(parent: Instance)
	local panel = Components.panel("Admin Panel", UDim2.fromOffset(540, 600), parent)
	local list = Components.scroller({ Size = UDim2.fromScale(1, 1), Parent = panel.Content })
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	-- Shown instead of working buttons to anyone who opens this without the pass.
	-- The shop only opens it for admins, so this is for the server saying no.
	local locked = Components.label({
		Text = "Buy the Admin Panel in the Shop to use these.",
		Size = UDim2.new(1, -12, 0, 30),
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		LayoutOrder = nextOrder(),
		Visible = false,
		Parent = list,
	})

	local function sectionTitle(text: string)
		Components.label({
			Text = text,
			Size = UDim2.new(1, -12, 0, SECTION_TITLE_HEIGHT),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Palette.Accent,
			Stroke = 2,
			MaxTextSize = 24,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end

	-- Players -------------------------------------------------------------

	sectionTitle("Pick a player")
	local playerRow = Components.scroller({
		Size = UDim2.new(1, -12, 0, PLAYER_ROW_HEIGHT + 8),
		AutomaticCanvasSize = Enum.AutomaticSize.X,
		ScrollingDirection = Enum.ScrollingDirection.X,
		LayoutOrder = nextOrder(),
		Parent = list,
	})
	Components.listLayout({
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Left,
		Padding = UDim.new(0, 8),
	}).Parent =
		playerRow
	local nobody = Components.label({
		Text = "No one else is in this server yet.",
		Size = UDim2.new(1, 0, 0, PLAYER_ROW_HEIGHT),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 20,
		Parent = playerRow,
	})

	-- Commands --------------------------------------------------------------

	local isAdmin = false
	local selected: Player? = nil
	local playerButtons: { [Player]: Components.Button } = {}
	local targetedButtons: { Components.Button } = {}
	local ownButtons: { Components.Button } = {}

	local function grid(): Frame
		local frame: Frame = Components.new("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -12, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		Components.new("UIGridLayout", {
			CellSize = UDim2.new(1 / 3, -6, 0, CELL_HEIGHT),
			CellPadding = UDim2.fromOffset(8, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = frame,
		})
		return frame
	end

	local function commandCell(host: Frame, command: AdminCommands.Command, index: number): Components.Button
		local cell = Components.card({ LayoutOrder = index, Parent = host })
		Components.padding(6).Parent = cell
		local button = Components.button({
			Text = `{command.Icon} {command.Name}`,
			Size = UDim2.new(1, 0, 0, 48),
			BackgroundColor3 = if command.Target == "Player"
				then Palette.Primary
				elseif command.Target == "Self" then Palette.Positive
				else Palette.Secondary,
			MaxTextSize = 22,
			Parent = cell,
		}, function()
			local target = selected
			if command.Target == "Player" and not target then
				return
			end
			Sound.play(Theme.Sounds.Purchase)
			AdminController.run(command.Id, if command.Target == "Player" and target then target.UserId else nil)
		end)
		Components.label({
			Text = command.Description,
			Size = UDim2.new(1, 0, 1, -52),
			Position = UDim2.fromOffset(0, 52),
			TextColor3 = Palette.TextMuted,
			TextWrapped = true,
			MaxTextSize = 16,
			Parent = cell,
		})
		return button
	end

	local function addGroup(title: string, target: AdminCommands.Target, into: { Components.Button })
		sectionTitle(title)
		local host = grid()
		for index, command in AdminCommands.List do
			if command.Target == target then
				table.insert(into, commandCell(host, command, index))
			end
		end
	end

	addGroup("Troll them", "Player", targetedButtons)
	addGroup("Yourself", "Self", ownButtons)
	addGroup("Everyone", "Everyone", ownButtons)

	Components.label({
		Text = `Effects wear off by themselves. Anyone just hit is safe for {AdminCommands.Protection}s.`,
		Size = UDim2.new(1, -12, 0, 22),
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 16,
		LayoutOrder = nextOrder(),
		Parent = list,
	})

	-- State ---------------------------------------------------------------------

	local function render()
		locked.Visible = not isAdmin
		for player, button in playerButtons do
			button.setColor(if player == selected then Palette.Accent else Palette.Surface)
		end
		for _, button in targetedButtons do
			button.setEnabled(isAdmin and selected ~= nil)
		end
		for _, button in ownButtons do
			button.setEnabled(isAdmin)
		end
	end

	local function addPlayer(player: Player)
		if player == LocalPlayer or playerButtons[player] then
			return
		end
		nobody.Visible = false
		local button = Components.button({
			Text = player.DisplayName,
			Size = UDim2.fromOffset(PLAYER_BUTTON_WIDTH, PLAYER_ROW_HEIGHT),
			BackgroundColor3 = Palette.Surface,
			MaxTextSize = 22,
			Parent = playerRow,
		}, function()
			Sound.play(Theme.Sounds.Purchase)
			selected = if selected == player then nil else player
			render()
		end)
		playerButtons[player] = button
		render()
	end

	local function removePlayer(player: Player)
		local button = playerButtons[player]
		if not button then
			return
		end
		button.Instance:Destroy()
		playerButtons[player] = nil
		if selected == player then
			selected = nil
		end
		nobody.Visible = next(playerButtons) == nil
		render()
	end

	for _, player in Players:GetPlayers() do
		addPlayer(player)
	end
	Players.PlayerAdded:Connect(addPlayer)
	Players.PlayerRemoving:Connect(removePlayer)
	render()

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			isAdmin = snapshot.IsAdmin == true
			render()
		end,
	}
end

return Admin
