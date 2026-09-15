--!strict
-- Single entry point for configuration: resolves the active theme from
-- Settings and merges its balance overrides over the defaults.

local Balance = require(script.Parent.Balance)
local Settings = require(script.Parent.Settings)
local Types = require(script.Parent.Types)

local function deepMerge(base: { [any]: any }, overrides: { [any]: any }): { [any]: any }
	local result = table.clone(base)
	for key, value in overrides do
		-- Arrays replace wholesale; dictionaries merge key by key.
		if type(value) == "table" and type(base[key]) == "table" and #value == 0 then
			result[key] = deepMerge(base[key], value)
		else
			result[key] = value
		end
	end
	return result
end

local themeModule = script.Parent.Themes:FindFirstChild(Settings.Theme)
assert(themeModule and themeModule:IsA("ModuleScript"), `Theme "{Settings.Theme}" not found in Shared/Themes`)

local theme: Types.Theme = (require :: any)(themeModule)
assert(#theme.Units >= 2, `Theme "{theme.Id}" needs at least 2 units`)
for tier, unit in theme.Units do
	assert(unit.Name and unit.Color, `Theme "{theme.Id}" unit {tier} needs a Name and Color`)
end

local balance: typeof(Balance) = if theme.Balance then deepMerge(Balance, theme.Balance) :: any else Balance

-- Sparkles are units too: they are carried, lie in the garden and earn, and the
-- only things they can't do are drop and merge. So they live on the end of one
-- unit list, at indices above the merge ladder, and everything that works on a
-- tier works on them without knowing they exist. `MaxTier` stays the top of the
-- ladder, which is what stops a sparkle ever being merged into one.
local maxTier = #theme.Units
local sparkles: { Types.SparkleDef } = theme.Sparkles or {}
-- Copied rather than referenced: Config stamps `Tier` onto each entry, and the
-- theme's own table shouldn't change under it.
local units: { Types.UnitDef } = {}
for tier, unit in theme.Units do
	local entry = table.clone(unit)
	entry.Tier = tier
	units[tier] = entry
end

for position, sparkle in sparkles do
	local bottom, top = sparkle.Band[1], sparkle.Band[2]
	assert(
		bottom and top and bottom >= 1 and top >= bottom and top <= maxTier,
		`Theme "{theme.Id}" sparkle "{sparkle.Id}" needs a Band inside 1..{maxTier}`
	)
	units[maxTier + position] = {
		Name = sparkle.Name,
		Color = sparkle.Color,
		Model = sparkle.Model,
		Scale = sparkle.Scale,
		Sparkle = true,
	}
end

-- Variants use the same trick again, one rung further out. Each one appends a
-- whole copy of the merge ladder past the sparkles, so a variant unit is just
-- another index: it drops, merges, earns, is carried and is sold through code
-- that has never heard of variants. Because a block is a copy of the ladder in
-- order, merging is still "the next index up", which keeps a merge inside the
-- variant it started in without anything having to check.
--
-- Blocks are laid out ordinary units, then sparkles, then one block per variant:
--   1 .. MaxTier                            the merge ladder
--   MaxTier + 1 .. VariantBase              the sparkles
--   VariantBase + (v - 1) * MaxTier + tier  variant v of that tier
local variantDefs = balance.Variants :: { Types.VariantRung }
local themeVariants = theme.Variants or {}
local variantBase = maxTier + #sparkles

-- A variant the theme hasn't styled is tinted toward white and named after its
-- Id, so it reads as "the shiny one" rather than as a missing asset.
local DEFAULT_TINT = 0.45
local DEFAULT_VARIANT_COLOR = Color3.new(1, 1, 1)

local variantChanceTotal = 0
for position, variant in variantDefs do
	variantChanceTotal += variant.Chance
	local styling: Types.VariantDef = themeVariants[variant.Id] or {}
	local prefix = styling.Prefix or variant.Id
	local color = styling.Color or DEFAULT_VARIANT_COLOR
	local tint = styling.Tint or DEFAULT_TINT
	local base = variantBase + (position - 1) * maxTier

	for tier = 1, maxTier do
		local unit = theme.Units[tier]
		units[base + tier] = {
			Name = `{prefix} {unit.Name}`,
			Color = unit.Color:Lerp(color, tint),
			Model = unit.Model,
			Scale = unit.Scale,
			Features = unit.Features,
			Tier = tier,
			Variant = position,
			Shine = styling.Shine,
		}
	end
end
assert(
	variantChanceTotal < 1,
	`Balance.Variants chances add up to {variantChanceTotal}; they have to leave room for an ordinary unit`
)

-- Pets need no index trickery -- they are not units and never lie in the garden --
-- so all this does is check the theme's list against the vocabulary in Balance and
-- build the lookups the egg roll wants. A pet naming a rarity or a perk that
-- doesn't exist is a hard error rather than a warning: unlike a unit's missing
-- ears, there is no sensible thing to fall back to, and a pet with no perk is a
-- pet with no reason to be owned.
local pets: { Types.PetDef } = theme.Pets or {}
local petRarities = balance.Pets.Rarities :: { Types.PetRarity }
local petPerks = balance.Pets.Perks :: { Types.PetPerkDef }

local petById: { [string]: Types.PetDef } = {}
local rarityById: { [string]: Types.PetRarity } = {}
local perkById: { [string]: Types.PetPerkDef } = {}
-- Pet Ids by rarity Id, which is what an egg draws from once it has rolled one.
local petsByRarity: { [string]: { string } } = {}

for _, rarity in petRarities do
	rarityById[rarity.Id] = rarity
	petsByRarity[rarity.Id] = {}
end
for _, perk in petPerks do
	perkById[perk.Id] = perk
end
for _, pet in pets do
	assert(pet.Id and pet.Name and pet.Color, `Theme "{theme.Id}" has a pet missing an Id, Name or Color`)
	assert(not petById[pet.Id], `Theme "{theme.Id}" has two pets with the Id "{pet.Id}"`)
	assert(
		rarityById[pet.Rarity],
		`Theme "{theme.Id}" pet "{pet.Id}" names rarity "{pet.Rarity}", which isn't in Balance`
	)
	assert(perkById[pet.Perk], `Theme "{theme.Id}" pet "{pet.Id}" names perk "{pet.Perk}", which isn't in Balance`)
	petById[pet.Id] = pet
	table.insert(petsByRarity[pet.Rarity], pet.Id)
end

-- An egg that can roll a rarity the theme has no pets for would take the player's
-- cash and hand back nothing, so say which egg and which rarity now rather than
-- at the pad.
for _, egg in balance.Pets.Eggs :: { Types.PetEggDef } do
	for rarityId in egg.Weights do
		assert(rarityById[rarityId], `Balance.Pets egg "{egg.Id}" weights rarity "{rarityId}", which isn't in Rarities`)
		if #pets > 0 then
			assert(
				#petsByRarity[rarityId] > 0,
				`Theme "{theme.Id}" has no {rarityId} pets, but egg "{egg.Id}" can roll one`
			)
		end
	end
end

return {
	Settings = Settings,
	Theme = theme,
	Balance = balance,
	-- The merge ladder, indexed by tier.
	MaxTier = maxTier,
	-- The ladder, with the sparkles and then the variant blocks appended.
	-- Index anything by unit here.
	Units = units,
	-- Sparkle at position n is unit index MaxTier + n.
	Sparkles = sparkles,
	-- The variant ladder from Balance, and where its blocks start. Economy does
	-- the arithmetic; nothing else should need to.
	Variants = variantDefs,
	VariantBase = variantBase,
	-- Pets, and the lookups Economy does the arithmetic with. Empty tables rather
	-- than nil for a theme with no pets, so callers never branch on it.
	Pets = pets,
	PetById = petById,
	PetRarityById = rarityById,
	PetPerkById = perkById,
	PetsByRarity = petsByRarity,
}
