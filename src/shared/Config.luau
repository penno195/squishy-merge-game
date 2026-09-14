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
}
