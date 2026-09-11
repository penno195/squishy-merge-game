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

return {
	Settings = Settings,
	Theme = theme,
	Balance = balance,
	MaxTier = #theme.Units,
}
