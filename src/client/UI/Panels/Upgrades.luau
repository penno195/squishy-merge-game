--!strict
-- Upgrade shop in a pop-up panel. The same rows also appear on the board at
-- the back of the garden.

local Components = require(script.Parent.Parent.Components)
local UpgradeList = require(script.Parent.Parent.UpgradeList)

local Upgrades = {}

function Upgrades.create(parent: Instance)
	local panel = Components.panel("Upgrades", UDim2.fromOffset(480, 420), parent)
	local list = UpgradeList.create(panel.Content)

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = list.update,
	}
end

return Upgrades
