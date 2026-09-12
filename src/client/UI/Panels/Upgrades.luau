--!strict
-- Upgrade shop in a pop-up panel. The garden board shows the same entries as
-- tiles; this lists every one of them, including any the board leaves out.

local Components = require(script.Parent.Parent.Components)
local UpgradeList = require(script.Parent.Parent.UpgradeList)

local Upgrades = {}

function Upgrades.create(parent: Instance)
	local panel = Components.panel("Upgrades", UDim2.fromOffset(520, 460), parent)
	local list = UpgradeList.rows(panel.Content, UpgradeList.allIds())

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = list.update,
	}
end

return Upgrades
