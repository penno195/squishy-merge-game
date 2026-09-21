--!strict
-- Playtime rewards for the current session, drawn on the shared claim list.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

local Playtime = {}

-- What a bundle pays, in the same words the quest and daily panels use. A
-- payout is a share of the band's bundle, so the band is passed in -- the
-- reward table on its own says nothing a player can read.
local function describe(reward: Types.Reward, band: number): string
	local parts = {}
	if reward.Payout then
		local amount = Economy.rewardCash(band, reward.Payout)
		table.insert(parts, `{Format.number(amount)} {Theme.Text.Currency}`)
	end
	if reward.Gems then
		table.insert(parts, `{reward.Gems} Gems`)
	end
	if reward.UnitTierBonus then
		table.insert(parts, `a bonus {Theme.Text.Unit}`)
	end
	return table.concat(parts, " + ")
end

function Playtime.create(parent: Instance)
	local panel = Components.panel("Playtime", UDim2.fromOffset(580, 440), parent)

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
		Net.event("ClaimPlaytime"):FireServer(index)
	end)

	local latest: { [string]: any }? = nil

	local function render()
		local snapshot = latest
		if not snapshot then
			return
		end
		local band = Economy.rewardBand(snapshot.Data)
		-- The session clock runs on the server; the panel counts against it
		-- rather than being told the time, so the rows tick between snapshots.
		local startedAt = snapshot.SessionStartedAt
		local speed = snapshot.PlaytimeSpeed or 1
		local elapsed = if startedAt then math.max(Workspace:GetServerTimeNow() - startedAt, 0) * speed else 0
		local claimed: { [number]: boolean } = snapshot.PlaytimeClaimed or {}

		local rows: { ClaimList.Row } = {}
		for index, rung in Economy.playtimeRungs() do
			local done, target = Economy.playtimeProgress(elapsed, index)
			table.insert(rows, {
				Text = `Play for {Format.time(rung.Minutes * 60)}`,
				Progress = done,
				Target = target,
				ProgressText = `{Format.time(done)} / {Format.time(target)}`,
				Reward = describe(rung.Reward, band),
				Claimed = claimed[index] == true,
			})
		end
		list.render(rows)

		local ready = Economy.playtimeReadyCount(elapsed, claimed)
		summary.Text = if ready > 0
			then `{ready} ready to claim!`
			else `Played {Format.time(elapsed)} this session — rewards reset when you leave.`
		summary.TextColor3 = if ready > 0 then Palette.Positive else Palette.Accent
	end

	-- The clock moves between snapshots, so the rows are redrawn while the
	-- panel is open rather than only when the server has something to say.
	RunService.RenderStepped:Connect(function()
		if panel.isOpen() then
			render()
		end
	end)

	return {
		setOpen = panel.setOpen,
		isOpen = panel.isOpen,
		update = function(snapshot: { [string]: any })
			latest = snapshot
			if panel.isOpen() then
				render()
			end
		end,
	}
end

return Playtime
