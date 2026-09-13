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
local units: { Types.UnitDef } = table.clone(theme.Units)

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

return {
	Settings = Settings,
	Theme = theme,
	Balance = balance,
	-- The merge ladder, indexed by tier.
	MaxTier = maxTier,
	-- The ladder with the sparkles appended. Index anything by unit here.
	Units = units,
	-- Sparkle at position n is unit index MaxTier + n.
	Sparkles = sparkles,
}
