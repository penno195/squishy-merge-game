--!strict
-- The pets panel: what's on your shoulder, and everything else you've hatched.
--
-- One pet is equipped at a time, so this panel's whole job is the swap. That makes
-- the perk the thing each row has to say loudest -- the cash multiplier is a nudge
-- by design, and if the rows led with it the player would sort by it and never
-- switch, which is the one outcome the design is trying to avoid.
--
-- Hatching isn't here. It happens at the egg pads behind the crafting station,
-- where the prompt does it in one press; a panel would only add a step.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local ROW_HEIGHT = 74
local SUMMARY_HEIGHT = 96

local Pets = {}

type Row = {
	Card: Frame,
	Swatch: Frame,
	Name: TextLabel,
	Detail: TextLabel,
	Equip: Components.Button,
	Release: Components.Button,
}

-- What a pet does, in one line: its perk, then what it pays. The perk first
-- because that's what the player is choosing between.
local function describe(record: Types.PetRecord): string
	local def = Economy.petDef(record.Id)
	if not def then
		return ""
	end
	local perk = Economy.petPerkDef(def.Perk)
	local rarity = Economy.petRarityOf(record.Id)
	local strength = Economy.petPerkStrength(record)
	local multiplier = if rarity then rarity.Multiplier else 1
	local perkName = if perk then perk.Name else def.Perk
	-- The strength is quoted as a multiple of one unit of the perk rather than in
	-- the perk's own units, which differ per perk -- a fraction of a sale, a chance
	-- of a gem, a number of spaces. "x2.4 Haggler" compares across all of them.
	local unit = if perk then perk.Amount else 1
	local scale = if unit > 0 then strength / unit else 1
	return `{perkName} x{string.format("%.1f", scale)}  ·  {string.format("%.0f", (multiplier - 1) * 100)}% {Theme.Text.Currency}`
end

local function row(order: number, parent: Instance, onEquip: () -> (), onRelease: () -> ()): Row
	local card = Components.card({
		Size = UDim2.new(1, -12, 0, ROW_HEIGHT),
		LayoutOrder = order,
		Pattern = true,
		Visible = false,
		Parent = parent,
	})
	local swatch: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(12, 15),
		Parent = card,
	})
	Components.corner(22).Parent = swatch
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -250, 0, 26),
		Position = UDim2.fromOffset(66, 10),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = card,
	})
	local detail = Components.label({
		Text = "",
		Size = UDim2.new(1, -250, 0, 26),
		Position = UDim2.fromOffset(66, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 17,
		Parent = card,
	})
	local equip = Components.button({
		Text = "Equip",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -96, 0.5, 0),
		Size = UDim2.fromOffset(104, 50),
		BackgroundColor3 = Palette.Positive,
		Parent = card,
	}, onEquip)
	local release = Components.button({
		Text = "Release",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(78, 50),
		BackgroundColor3 = Palette.Negative,
		Parent = card,
	}, onRelease)
	return { Card = card, Swatch = swatch, Name = name, Detail = detail, Equip = equip, Release = release }
end

function Pets.create(parent: Instance)
	local panel = Components.panel("Pets", UDim2.fromOffset(500, 540), parent)

	-- What's equipped, spelled out above the list, because it's the one thing the
	-- rest of the game is actually reading.
	local summary = Components.card({
		Size = UDim2.new(1, -12, 0, SUMMARY_HEIGHT),
		BackgroundColor3 = Palette.Secondary,
		Parent = panel.Content,
	})
	local summarySwatch: Frame = Components.new("Frame", {
		BackgroundColor3 = Palette.Background,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(60, 60),
		Position = UDim2.fromOffset(14, 18),
		Parent = summary,
	})
	Components.corner(30).Parent = summarySwatch
	local summaryName = Components.label({
		Text = "",
		Size = UDim2.new(1, -100, 0, 32),
		Position = UDim2.fromOffset(86, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 26,
		Parent = summary,
	})
	local summaryDetail = Components.label({
		Text = "",
		Size = UDim2.new(1, -100, 0, 44),
		Position = UDim2.fromOffset(86, 46),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Text,
		TextWrapped = true,
		MaxTextSize = 18,
		Parent = summary,
	})

	local countLabel = Components.label({
		Text = "",
		Position = UDim2.fromOffset(4, SUMMARY_HEIGHT + 12),
		Size = UDim2.new(1, -8, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.Accent,
		MaxTextSize = 19,
		Parent = panel.Content,
	})

	local list = Components.scroller({
		Position = UDim2.fromOffset(0, SUMMARY_HEIGHT + 40),
		Size = UDim2.new(1, 0, 1, -(SUMMARY_HEIGHT + 40)),
		Parent = panel.Content,
	})
	Components.listLayout({ Padding = UDim.new(0, 8) }).Parent = list

	-- Built for the most a player can ever hold and shown down to what they have,
	-- so opening the panel never creates instances and a hatch never makes it
	-- stutter.
	-- Which row is equipped, kept here because the handlers are built once and the
	-- Equip button on the equipped row has to send 0 instead of its own index. The
	-- server re-checks either way; this only decides what to ask for.
	local equippedIndex = 0

	local rows: { Row } = {}
	for index = 1, Economy.maxOwnedPets() do
		rows[index] = row(index, list, function()
			Sound.play(Theme.Sounds.Purchase)
			Net.event("EquipPet"):FireServer(if equippedIndex == index then 0 else index)
		end, function()
			Sound.play(Theme.Sounds.Purchase)
			Net.event("ReleasePet"):FireServer(index)
		end)
	end

	local emptyLabel = Components.label({
		Text = `No pets yet — hatch one at the egg pads behind the {Theme.Text.Machine}.`,
		Size = UDim2.new(1, -24, 0, 70),
		TextColor3 = Palette.TextMuted,
		TextWrapped = true,
		MaxTextSize = 19,
		Visible = false,
		Parent = list,
	})
	emptyLabel.LayoutOrder = Economy.maxOwnedPets() + 1

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local owned = data.Pets
		equippedIndex = data.EquippedPet

		local equipped = Economy.equippedPet(data)
		if equipped then
			summarySwatch.BackgroundColor3 = Economy.petColor(equipped)
			summaryName.Text = Economy.petName(equipped)
			local def = Economy.petDef(equipped.Id)
			local perk = if def then Economy.petPerkDef(def.Perk) else nil
			summaryDetail.Text = if perk then perk.Description else ""
		else
			summarySwatch.BackgroundColor3 = Palette.Background
			summaryName.Text = "Nothing equipped"
			summaryDetail.Text = if #owned > 0
				then "Pick one below — you can swap whenever you like."
				else `Hatch one at the egg pads behind the {Theme.Text.Machine}.`
		end

		countLabel.Text = `Your pets — {#owned} / {Economy.maxOwnedPets()}`
		emptyLabel.Visible = #owned == 0

		for index, entry in rows do
			local record = owned[index]
			entry.Card.Visible = record ~= nil
			if record then
				local isEquipped = index == data.EquippedPet
				entry.Swatch.BackgroundColor3 = Economy.petColor(record)
				entry.Name.Text = Economy.petName(record)
				entry.Detail.Text = describe(record)
				-- The equipped row's button takes the pet off rather than going
				-- dead, because no pet is a choice a player might want -- it's the
				-- only way to see what the garden earns on its own.
				entry.Equip.setText(if isEquipped then "Take off" else "Equip")
				entry.Equip.setColor(if isEquipped then Palette.Secondary else Palette.Positive)
				-- Releasing what you are wearing is allowed; it just takes it off
				-- first, which the server does. Nothing to stop here.
				entry.Card.BackgroundColor3 = if isEquipped then Palette.Secondary else Palette.Surface
			end
		end
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Pets
