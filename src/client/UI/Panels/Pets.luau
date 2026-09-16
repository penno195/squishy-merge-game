--!strict
-- The pets panel: what's at your heels, and everything else you've hatched.
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
	Ring: UIStroke,
	Name: TextLabel,
	Rarity: TextLabel,
	Detail: TextLabel,
	Equip: Components.Button,
	Release: Components.Button,
}

-- What a pet does, in one line: what its perk is for, then how strong it is, then
-- what it pays. In that order because that is the order the player cares about --
-- they are choosing a job, then a quality, and the cash is a tiebreak.
--
-- Strength is quoted as a multiple of one unit of the perk rather than in the
-- perk's own units, which differ per perk: a fraction of a sale, a chance of a gem,
-- a number of spaces. "x2.4" compares across all six of them, and the description
-- says what is being multiplied.
local function describe(record: Types.PetRecord): string
	local def = Economy.petDef(record.Id)
	if not def then
		return ""
	end
	local perk = Economy.petPerkDef(def.Perk)
	local rarity = Economy.petRarityOf(record.Id)
	local strength = Economy.petPerkStrength(record)
	local multiplier = if rarity then rarity.Multiplier else 1
	local unit = if perk then perk.Amount else 1
	local scale = if unit > 0 then strength / unit else 1
	local what = if perk then perk.Description else def.Perk
	return `{what}  ·  x{string.format("%.1f", scale)}  ·  +{string.format("%.0f", (multiplier - 1) * 100)}% {Theme.Text.Currency}`
end

-- Strongest first, and whatever is equipped above everything. A list in the order
-- things hatched buries the pet you want under twenty commons, and the panel exists
-- to make the swap quick.
local function sortedOrder(data: Types.PlayerData): { number }
	local order: { number } = {}
	for index in data.Pets do
		table.insert(order, index)
	end
	-- Rank by the rarity's own place on the ladder rather than by its multiplier,
	-- which is a narrow band and would sort almost flat.
	local rank: { [string]: number } = {}
	for position, rarity in Economy.petRarities() do
		rank[rarity.Id] = position
	end
	local function key(index: number): (number, number, number, string)
		local record = data.Pets[index]
		local def = Economy.petDef(record.Id)
		return if index == data.EquippedPet then 1 else 0,
			if def then rank[def.Rarity] or 0 else 0,
			record.Variant,
			if def then def.Name else ""
	end
	table.sort(order, function(a, b)
		local equippedA, rarityA, variantA, nameA = key(a)
		local equippedB, rarityB, variantB, nameB = key(b)
		if equippedA ~= equippedB then
			return equippedA > equippedB
		end
		if rarityA ~= rarityB then
			return rarityA > rarityB
		end
		if variantA ~= variantB then
			return variantA > variantB
		end
		if nameA ~= nameB then
			return nameA < nameB
		end
		-- Two of the same pet: keep the older one first, so the list doesn't
		-- reshuffle itself between snapshots.
		return a < b
	end)
	return order
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
	-- The rarity as a ring round the pet's own colour, so rarity is legible without
	-- spending a row on it and without fighting the pet's colour for the swatch.
	local ring = Components.stroke(Palette.TextMuted, 3)
	ring.Parent = swatch
	local name = Components.label({
		Text = "",
		Size = UDim2.new(1, -330, 0, 26),
		Position = UDim2.fromOffset(66, 9),
		TextXAlignment = Enum.TextXAlignment.Left,
		MaxTextSize = 22,
		Parent = card,
	})
	local rarityLabel = Components.label({
		Text = "",
		Size = UDim2.fromOffset(96, 22),
		Position = UDim2.new(1, -290, 0, 11),
		TextXAlignment = Enum.TextXAlignment.Right,
		MaxTextSize = 17,
		Parent = card,
	})
	local detail = Components.label({
		Text = "",
		Size = UDim2.new(1, -212, 0, 26),
		Position = UDim2.fromOffset(66, 38),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = Palette.TextMuted,
		MaxTextSize = 16,
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
	return {
		Card = card,
		Swatch = swatch,
		Ring = ring,
		Name = name,
		Rarity = rarityLabel,
		Detail = detail,
		Equip = equip,
		Release = release,
	}
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
	-- Which inventory slot each row is showing. The list is sorted, so a row's
	-- position is not the slot it stands for, and every message has to name the slot
	-- -- a row acting on its own position would equip whatever had sorted into it.
	local rowSlot: { number } = {}

	local rows: { Row } = {}
	for index = 1, Economy.maxOwnedPets() do
		rows[index] = row(index, list, function()
			local slot = rowSlot[index]
			if not slot then
				return
			end
			Sound.play(Theme.Sounds.Purchase)
			Net.event("EquipPet"):FireServer(if equippedIndex == slot then 0 else slot)
		end, function()
			local slot = rowSlot[index]
			if not slot then
				return
			end
			Sound.play(Theme.Sounds.Purchase)
			Net.event("ReleasePet"):FireServer(slot)
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
			local rarity = Economy.petRarityOf(equipped.Id)
			summarySwatch.BackgroundColor3 = Economy.petColor(equipped)
			summaryName.Text = Economy.petName(equipped)
			summaryName.TextColor3 = if rarity then Economy.petRarityColor(rarity) else Palette.Text
			summaryDetail.Text = describe(equipped)
		else
			summarySwatch.BackgroundColor3 = Palette.Background
			summaryName.Text = "Nothing equipped"
			summaryName.TextColor3 = Palette.Text
			summaryDetail.Text = if #owned > 0
				then "Pick one below — you can swap whenever you like."
				else `Hatch one at the egg pads behind the {Theme.Text.Machine}.`
		end

		countLabel.Text = `Your pets — {#owned} / {Economy.maxOwnedPets()}`
		emptyLabel.Visible = #owned == 0

		local order = sortedOrder(data)
		table.clear(rowSlot)
		for index, entry in rows do
			local slot = order[index]
			local record = if slot then owned[slot] else nil
			entry.Card.Visible = record ~= nil
			if record and slot then
				rowSlot[index] = slot
				local isEquipped = slot == data.EquippedPet
				local rarity = Economy.petRarityOf(record.Id)
				local tone = if rarity then Economy.petRarityColor(rarity) else Palette.TextMuted
				entry.Swatch.BackgroundColor3 = Economy.petColor(record)
				entry.Ring.Color = tone
				entry.Name.Text = Economy.petName(record)
				entry.Rarity.Text = if rarity then rarity.Name else ""
				entry.Rarity.TextColor3 = tone
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
