--!strict
-- Number and time formatting for UI.

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc" }

local Format = {}

function Format.number(value: number): string
	if value ~= value then
		return "0"
	end
	if math.abs(value) < 1000 then
		return tostring(math.floor(value))
	end

	local group = math.min(math.floor(math.log10(math.abs(value)) / 3), #SUFFIXES - 1)
	local scaled = value / 10 ^ (group * 3)
	local text
	if math.abs(scaled) >= 100 then
		text = tostring(math.floor(scaled))
	elseif math.abs(scaled) >= 10 then
		text = string.format("%.1f", math.floor(scaled * 10) / 10)
	else
		text = string.format("%.2f", math.floor(scaled * 100) / 100)
	end
	if string.find(text, ".", 1, true) then
		text = string.gsub(string.gsub(text, "0+$", ""), "%.$", "")
	end
	return text .. SUFFIXES[group + 1]
end

function Format.time(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local hours = seconds // 3600
	local minutes = (seconds % 3600) // 60
	if hours > 0 then
		return `{hours}h {minutes}m`
	elseif minutes > 0 then
		return `{minutes}m {seconds % 60}s`
	end
	return `{seconds}s`
end

return Format
