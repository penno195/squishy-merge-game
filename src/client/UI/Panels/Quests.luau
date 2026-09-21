--!strict
-- Daily and weekly quests, drawn on the shared claim list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ClaimList = require(script.Parent.Parent.ClaimList)
local Components = require(script.Parent.Parent.Components)
local Config = require(ReplicatedStorage.Shared.Config)
local Economy = require(ReplicatedStorage.Shared.Economy)
local Format = require(ReplicatedStorage.Shared.Format)
local Net = require(ReplicatedStorage.Shared.Net)
local Sound = require(script.Parent.Parent.Sound)
local Types = require(ReplicatedStorage.Shared.Types)

local Palette = Components.Palette
local Theme = Config.Theme

local Quests = {}

-- What a bundle pays, in the words the daily panel already uses. Income-scaled
-- rewards need the player's band to mean anything, so it's passed in.
local function describe(reward: Types.Reward, band: number): string
	local parts = {}
	if reward.Payout then
		local amount = Economy.rewardCash(band, reward.Payout)
		table.insert(parts, `{Format.number(amount)} {Theme.Text.Currency}`)
	end
	if reward.Gems then
		table.insert(parts, `{reward.Gems} Gems`)
	end
	return table.concat(parts, " + ")
end

function Quests.create(parent: Instance)
	local panel = Components.panel("Quests", UDim2.fromOffset(580, 440), parent)

	local summary = Components.label({
		Text = "",
		Size = UDim2.new(1, -24, 0, 28),
		Position = UDim2.fromOffset(12, 0),
		TextColor3 = Palette.Accent,
		Parent = panel.Content,
	})

	local list = ClaimList.create({
		Size = UDim2.new(1, 0, 1, -36),
		Position = UDim2.fromOffset(0, 36),
		Parent = panel.Content,
	}, function(index)
		Sound.play(Theme.Sounds.Purchase)
		Net.event("ClaimQuest"):FireServer(index)
	end)

	local function update(snapshot: { [string]: any })
		local data: Types.PlayerData = snapshot.Data
		local band = Economy.rewardBand(snapshot.Data)
		local rows: { ClaimList.Row } = {}
		local ready = 0

		for _, slot in data.Quests.Active do
			local quest = Economy.questById(slot.Id)
			if quest then
				local done, target = Economy.questProgress(data, slot)
				if Economy.questClaimable(data, slot) then
					ready += 1
				end
				table.insert(rows, {
					-- The weekly is worth calling out: it's the one that pays.
					Text = if slot.Weekly then `⭐ {quest.Text}` else quest.Text,
					Progress = done,
					Target = target,
					Reward = describe(quest.Reward, band),
					Claimed = slot.Claimed,
				})
			end
		end

		summary.Text = if ready > 0 then `{ready} ready to claim!` else "Three new quests every day, one every week."
		summary.TextColor3 = if ready > 0 then Palette.Positive else Palette.Accent
		list.render(rows)
	end

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = update,
	}
end

return Quests
