--!strict
-- The egg popup: what this egg can turn up, what each of those pets does for you,
-- and the button that buys one.
--
-- Opened by the prompt on an egg pad, and only from there -- it is about one pad,
-- so there is no menu entry for it. The pad's own sign carries just the name and the
-- price, because the odds and a list of pets are a wall of text at sign size and
-- this is read standing still.
--
-- Showing what is in an egg before it is bought is deliberate. A gacha that hides
-- its odds is hiding them, and a pet's whole value is its perk -- so a player
-- choosing between a cheap egg and a dear one is really choosing between two lists
-- of perks, which they can only do if they can see both.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local ODDS_HEIGHT = 34
local ROW_HEIGHT = 54
local HATCH_HEIGHT = 66

local Egg = {}

type OddsRow = {
	Instance: Frame,
	Name: TextLabel,
	Chance: TextLabel,
}

type PetRow = {
	Instance: Frame,
	Swatch: Frame,
	Name: TextLabel,
	Detail: TextLabel,
}

-- The most rows either list can ever need, built once so opening the popup never
-- creates instances. Every egg draws from the same theme, so the pet list's ceiling
-- is simply how many pets the theme has.
local function oddsRow(order: number, parent: Instance): OddsRow
	local frame = Components.card({
		Size = UDim2.new(1, -12, 0, ODDS_HEIGHT),
		LayoutOrder = order,
		Visible = false,
		Parent = parent,
	})
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -110, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 19,
		Parent = frame,
	})
	local chance = Components.label({
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(90, ODDS_HEIGHT - 10),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 21,
		Parent = frame,
	})
	return { Instance = frame, Name = name, Chance = chance }
end

local function petRow(order: number, parent: Instance): PetRow
	local frame = Components.card({
		Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Pattern = true,
		Visible = false,
		Parent = parent,
	})
	local swatch: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(34, 34),
		Position = UDim2.fromOffset(12, 10),
		Parent = frame,
	})
	Components.corner(17).Parent = swatch
	local name = Components.label({
		Text = "",
		Size = UDim2.new(0.42, 0, 1, -10),
		Position = UDim2.fromOffset(56, 5),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 18,
		Parent = frame,
	})
	local detail = Components.label({
		Text = "",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.new(0.45, 0, 1, -10),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		MaxTextSize = 16,
		Parent = frame,
	})
	return { Instance = frame, Swatch = swatch, Name = name, Detail = detail }
end

function Egg.create(parent: Instance)
	local panel = Components.panel("Egg", UDim2.fromOffset(500, 560), parent)

	-- Which pad opened it. Set before the panel is shown, so `update` always has
	-- one to draw even on the snapshot that arrives first.
	local current: Types.PetEggDef? = nil

	local oddsTitle = Components.label({
		Text = "Chances",
		Position = UDim2.fromOffset(4, 0),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		Parent = panel.Content,
	})
	oddsTitle.Name = "OddsTitle"

	local oddsList: Frame = Components.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 0, #Economy.petRarities() * (ODDS_HEIGHT + 6)),
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = oddsList

	local oddsRows: { OddsRow } = {}
	for index = 1, #Economy.petRarities() do
		oddsRows[index] = oddsRow(index, oddsList)
	end

	local oddsBottom = 30 + #Economy.petRarities() * (ODDS_HEIGHT + 6)

	local poolTitle = Components.label({
		Text = "What's inside",
		Position = UDim2.fromOffset(4, oddsBottom + 6),
		Size = UDim2.new(1, -8, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		MaxTextSize = 22,
		Parent = panel.Content,
	})
	poolTitle.Name = "PoolTitle"

	local poolTop = oddsBottom + 36
	local pool = Components.scroller({
		Position = UDim2.fromOffset(0, poolTop),
		Size = UDim2.new(1, 0, 1, -(poolTop + HATCH_HEIGHT + 12)),
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, 6) }).Parent = pool

	local petRows: { PetRow } = {}
	for index = 1, math.max(#Config.Pets, 1) do
		petRows[index] = petRow(index, pool)
	end

	local hatch = Components.button({
		Text = "",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, HATCH_HEIGHT),
		BackgroundColor3 = Palette.Positive,
		Parent = panel.Content,
	}, function()
		local egg = current
		if not egg then
			return
		end
		Sound.play(Theme.Sounds.Purchase)
		-- The server re-checks the price, the room and that the player is actually
		-- stood at the pad. This only asks.
		Net.event("HatchEgg"):FireServer(egg.Id)
	end)

	local latest: { [string]: any }? = nil

	local function render()
		local snapshot = latest
		local egg = current
		if not (snapshot and egg) then
			return
		end
		local data: Types.PlayerData = snapshot.Data
		panel.setTitle(egg.Name)

		-- During a Hatch Luck event the odds shown are the event's, since those are
		-- the odds being rolled.
		local hatchLuck = 1
		for _, entry in snapshot.Events or {} do
			if entry.Id == "HatchLuck" and entry.EndsAt > Workspace:GetServerTimeNow() then
				hatchLuck = entry.Strength
			end
		end
		local chances = Economy.eggChances(egg, hatchLuck)
		for index, rarity in Economy.petRarities() do
			local row = oddsRows[index]
			local chance = chances[rarity.Id]
			row.Instance.Visible = chance ~= nil and chance > 0
			if chance and chance > 0 then
				local color = Economy.petRarityColor(rarity)
				row.Name.Text = rarity.Name
				row.Name.TextColor3 = color
				-- %.4g rather than a fixed number of places: a 0.4% Legendary and a
				-- 72% Common both have to read exactly, and rounding either to the
				-- other's precision loses it.
				row.Chance.Text = `{string.format("%.4g", chance * 100)}%`
				row.Chance.TextColor3 = color
			end
		end

		local pets = Economy.eggPool(egg)
		for index, row in petRows do
			local def = pets[index]
			row.Instance.Visible = def ~= nil
			if def then
				local rarity = Config.PetRarityById[def.Rarity]
				local perk = Economy.petPerkDef(def.Perk)
				row.Swatch.BackgroundColor3 = def.Color
				row.Name.Text = def.Name
				row.Name.TextColor3 = if rarity then Economy.petRarityColor(rarity) else Palette.Text
				-- What it does, not what it is worth: the perk is the reason to want
				-- a particular pet out of an egg.
				row.Detail.Text = if perk then perk.Description else def.Perk
			end
		end

		-- The button says why it can't be pressed, rather than going quiet.
		local cost = egg.Cost
		if Economy.petsFull(data) then
			hatch.setText(`Full — release a pet first`)
			hatch.setEnabled(false)
		elseif data.Cash < cost then
			hatch.setText(`Need {Format.number(cost - data.Cash)} more {Theme.Text.Currency}`)
			hatch.setEnabled(false)
		else
			hatch.setText(`Hatch — {Format.number(cost)} {Theme.Text.Currency}`)
			hatch.setEnabled(true)
		end
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			latest = snapshot
			if panel.isOpen() then
				render()
			end
		end,
		-- Called by the HUD when an egg pad's prompt fires, before the panel opens.
		setEgg = function(eggId: string)
			current = Economy.eggById(eggId)
			render()
		end,
	}
end

return Egg
