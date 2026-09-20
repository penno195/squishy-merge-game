--!strict
-- Dresses the map with scenery. Where props stand is shared layout, in
-- Balance.PropZones; what stands there comes from the active theme's `Props`
-- table. Reskinning the world is therefore a data change in one theme file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local GardenService = require(script.Parent.GardenService)
local PropVisuals = require(ReplicatedStorage.Shared.PropVisuals)

local Balance = Config.Balance
local Theme = Config.Theme

local PropService = {}

function PropService.init()
	local world = GardenService.world()
	local props = Theme.Props
	if not world then
		warn("PropService.init ran before the world existed; skipping scenery")
		return
	end
	if not props then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = "Props"
	folder.Parent = world

	local plotRadius = GardenService.plotRadius()

	for _, zone in Balance.PropZones do
		local options = props[zone.Id]
		if not options or #options == 0 then
			continue
		end

		local zoneFolder = Instance.new("Folder")
		zoneFolder.Name = zone.Id
		zoneFolder.Parent = folder

		-- What stood in the slot before this one, and in the first slot, so a
		-- ring never puts two of the same thing side by side. Picking freely at
		-- random reads as clumps -- three buns in a row looks like a decision
		-- somebody made, and the ring stops looking like a mixture.
		local previous, first = 0, 0
		for slot = 1, zone.Count do
			local pick = math.random(#options)
			if #options > 1 then
				-- Re-rolling into the gap between the choices is cheaper than
				-- shuffling, and unlike a shuffle it still allows a repeat a
				-- few slots along, which is what a mixture actually looks like.
				local last = slot == zone.Count
				while pick == previous or (last and pick == first) do
					pick = math.random(#options)
				end
			end
			previous = pick
			if slot == 1 then
				first = pick
			end

			-- Jitter is radial only. Spreading them sideways as well would
			-- eventually drop one across a path out to a garden.
			local angle = (slot - 1 + zone.Offset) / zone.Count * math.pi * 2
			local radius = plotRadius * zone.Radius + (math.random() * 2 - 1) * zone.Jitter
			local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			-- Facing the middle of the map, so anything with a front (a
			-- lollipop's disc) is turned towards the players.
			local base = CFrame.lookAt(position, Vector3.new(0, 0, 0))
			PropVisuals.build(options[pick], base, zoneFolder)
		end
	end
end

return PropService
