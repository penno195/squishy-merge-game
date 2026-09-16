--!strict
-- What every player sees of staff events: a chip for each event running, down the
-- top right with its clock, and a banner across the middle of the screen when
-- staff send a message to the whole game.

local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Components)
local Format = require(ReplicatedStorage.Shared.Format)
local LiveEvents = require(ReplicatedStorage.Shared.LiveEvents)

local Palette = Components.Palette

local CHIP_WIDTH = 250
local CHIP_HEIGHT = 44
-- Long enough to read a full-length message twice.
local BANNER_SECONDS = 9

local EventStrip = {}

export type Strip = {
	update: ({ [string]: any }) -> (),
	announce: (text: string, from: string) -> (),
}

function EventStrip.create(screen: Instance): Strip
	local topInset = GuiService:GetGuiInset().Y

	local column: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 16 + topInset),
		Size = UDim2.fromOffset(CHIP_WIDTH, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = Components.Layer.Hud,
		Parent = screen,
	})
	Components.listLayout({ Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Right }).Parent =
		column

	local chips: { [string]: TextLabel } = {}
	local running: { { [string]: any } } = {}

	local function chipFor(id: string): TextLabel
		local existing = chips[id]
		if existing then
			return existing
		end
		local card = Components.card({
			Size = UDim2.fromOffset(CHIP_WIDTH, CHIP_HEIGHT),
			BackgroundColor3 = Palette.Primary,
			Parent = column,
		})
		local label = Components.label({
			Text = "",
			Position = UDim2.fromOffset(10, 6),
			Size = UDim2.new(1, -20, 1, -12),
			MaxTextSize = 20,
			Stroke = 2,
			Parent = card,
		})
		chips[id] = label
		return label
	end

	local function render()
		local now = Workspace:GetServerTimeNow()
		local seen: { [string]: boolean } = {}
		for _, entry in running do
			local def = LiveEvents.ById[entry.Id]
			local left = entry.EndsAt - now
			if def and left > 0 then
				seen[entry.Id] = true
				chipFor(entry.Id).Text = `{def.Icon} {def.Name} x{entry.Strength}  {Format.time(math.ceil(left))}`
			end
		end
		for id, label in chips do
			if not seen[id] then
				(label.Parent :: Instance):Destroy()
				chips[id] = nil
			end
		end
	end

	local elapsed = 0
	RunService.Heartbeat:Connect(function(delta)
		elapsed += delta
		if elapsed >= 1 then
			elapsed = 0
			render()
		end
	end)

	-- Announcements ---------------------------------------------------------------

	local banner = Components.card({
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.2),
		Size = UDim2.fromOffset(640, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Palette.Background,
		Visible = false,
		ZIndex = Components.Layer.Toast,
		Parent = screen,
	})
	Components.padding(16).Parent = banner
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = banner
	local fromLabel = Components.label({
		Text = "",
		Size = UDim2.new(1, 0, 0, 26),
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		Stroke = 2,
		LayoutOrder = 1,
		Parent = banner,
	})
	-- Not scaled: a long message wraps onto more lines at a readable size rather
	-- than shrinking to fit one.
	local textLabel = Components.label({
		Text = "",
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextScaled = false,
		TextSize = 28,
		TextWrapped = true,
		Stroke = 2,
		LayoutOrder = 2,
		Parent = banner,
	})

	-- One at a time, in the order they came, so two sent close together are both read.
	local queue: { { Text: string, From: string } } = {}
	local showing = false

	local function showNext()
		local nextMessage = table.remove(queue, 1)
		if not nextMessage then
			showing = false
			banner.Visible = false
			return
		end
		showing = true
		fromLabel.Text = `📢 {nextMessage.From}`
		textLabel.Text = nextMessage.Text
		banner.Visible = true
		task.delay(BANNER_SECONDS, showNext)
	end

	return {
		update = function(snapshot: { [string]: any })
			running = snapshot.Events or {}
			render()
		end,
		announce = function(text: string, from: string)
			table.insert(queue, { Text = text, From = from })
			if not showing then
				showNext()
			end
		end,
	}
end

return EventStrip
