-- Enough of Roblox for the pure shared modules to load.
local function makeColor(r, g, b)
	local c = { R = r, G = g, B = b }
	function c:Lerp(other, t)
		return makeColor(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
	end
	return c
end
Color3 = {
	fromRGB = function(r, g, b) return makeColor(r / 255, g / 255, b / 255) end,
	new = function(r, g, b) return makeColor(r, g, b) end,
}
Enum = setmetatable({}, {
	__index = function(t, kind)
		local group = setmetatable({}, { __index = function(_, name) return { Name = name, EnumType = kind } end })
		rawset(t, kind, group)
		return group
	end,
})
Font = { fromEnum = function(e) return { Family = e } end }
Vector3 = { new = function(x, y, z) return { X = x, Y = y, Z = z } end }
