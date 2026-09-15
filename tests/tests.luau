local failures = 0
local checks = 0
local function check(name, ok, detail)
	checks += 1
	if not ok then
		failures += 1
		print(`FAIL  {name}` .. (if detail then `  ({detail})` else ""))
	end
end

local MaxTier = Config.MaxTier
local variants = Config.Variants
local sparkles = Config.Sparkles

print(`theme={Config.Theme.Id} ladder={MaxTier} sparkles={#sparkles} variants={#variants} units={#Config.Units}`)

-- Layout: every index in the list is exactly one of ordinary, sparkle, variant.
for index = 1, #Config.Units do
	local isSparkle = Economy.isSparkle(index)
	local variant = Economy.variantOf(index)
	local tier = Economy.ladderTier(index)
	check("index has a name", Config.Units[index] ~= nil, `index {index}`)
	if isSparkle then
		check("sparkle has no variant", variant == 0, `index {index}`)
		check("sparkle is off the ladder", tier == 0, `index {index}`)
	else
		check("non-sparkle is on the ladder", tier >= 1 and tier <= MaxTier, `index {index} tier {tier}`)
	end
end

-- The sparkle block is exactly where it used to be, and nothing else is in it.
for index = 1, #Config.Units do
	local expected = index > MaxTier and index <= MaxTier + #sparkles
	check("isSparkle is bounded", Economy.isSparkle(index) == expected, `index {index}`)
end

-- Round trip: tier and variant -> index -> tier and variant.
for position = 0, #variants do
	for tier = 1, MaxTier do
		local index = Economy.variantIndex(tier, position)
		check("round trip tier", Economy.ladderTier(index) == tier, `v{position} t{tier} -> {index}`)
		check("round trip variant", Economy.variantOf(index) == position, `v{position} t{tier} -> {index}`)
		check("round trip in range", index >= 1 and index <= #Config.Units, `v{position} t{tier} -> {index}`)
	end
end

-- A variant is a copy of its rung, so it has to wear the same face. A Golden
-- Pup with no ears would read as a different animal to the Pup it came from.
for position = 1, #variants do
	for tier = 1, MaxTier do
		local base = Config.Units[tier].Features
		local copy = Config.Units[Economy.variantIndex(tier, position)].Features
		if base == nil then
			check("a plain rung stays plain in every variant", copy == nil, `v{position} t{tier}`)
		else
			check("a variant keeps its rung's features", copy ~= nil and #copy == #base, `v{position} t{tier}`)
			for slot, name in base do
				check("a variant keeps them in order", copy and copy[slot] == name, `v{position} t{tier} {name}`)
			end
		end
	end
end

-- Merging stays inside its own variant block, and stops at the top of it.
for position = 0, #variants do
	for tier = 1, MaxTier do
		local index = Economy.variantIndex(tier, position)
		if tier < MaxTier then
			check("can merge below the top", Economy.canMerge(index), `v{position} t{tier}`)
			check(
				"merge keeps its variant",
				Economy.mergeResult(index) == Economy.variantIndex(tier + 1, position),
				`v{position} t{tier}`
			)
		else
			check("top of the ladder cannot merge", not Economy.canMerge(index), `v{position} t{tier}`)
		end
	end
end
for position = 1, #sparkles do
	check("sparkles cannot merge", not Economy.canMerge(Economy.sparkleIndex(position)), `sparkle {position}`)
end

-- Income: a variant is its multiplier times the rung it copies, and ordinary
-- units earn exactly what they earned before variants existed.
local function ordinaryIncome(tier)
	return Config.Balance.Income.Base * Config.Balance.Income.TierGrowth ^ (tier - 1)
end
for tier = 1, MaxTier do
	check("ordinary income unchanged", math.abs(Economy.tierIncome(tier) - ordinaryIncome(tier)) < 1e-6, `t{tier}`)
	for position, variant in variants do
		local index = Economy.variantIndex(tier, position)
		local expected = ordinaryIncome(tier) * variant.Income
		check("variant income scales", math.abs(Economy.tierIncome(index) - expected) < 1e-6, `v{position} t{tier}`)
		check("variant is worth more", Economy.unitValue(index) > Economy.unitValue(tier), `v{position} t{tier}`)
	end
end

-- Sparkle income still measured off the top of its band, untouched by variants.
for position, sparkle in sparkles do
	local expected = ordinaryIncome(sparkle.Band[2] + Config.Balance.Craft.SparkleIncomeTiers)
	local actual = Economy.tierIncome(Economy.sparkleIndex(position))
	check("sparkle income unchanged", math.abs(actual - expected) < 1e-6, sparkle.Id)
end

-- The drop roll: always a real index, always inside the player's tier window,
-- and variants turn up at roughly the rate Balance asks for.
local data = {
	Upgrades = { SpawnTier = 6 },
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Sparkles = {},
	Discovered = {},
}
local bottom, top = Economy.dropTierRange(data)
local counts = {}
local ROLLS = 200000
for _ = 1, ROLLS do
	local index = Economy.randomDropIndex(data)
	local tier = Economy.ladderTier(index)
	if tier < bottom or tier > top then
		check("drop lands in the window", false, `index {index} tier {tier}`)
	end
	local position = Economy.variantOf(index)
	counts[position] = (counts[position] or 0) + 1
end
check("drop window held", true)
for position, variant in variants do
	local seen = (counts[position] or 0) / ROLLS
	local drift = math.abs(seen - variant.Chance)
	check(
		`{variant.Id} rolls at about its chance`,
		drift < variant.Chance * 0.25 + 0.002,
		`wanted {variant.Chance}, saw {string.format("%.4f", seen)}`
	)
end
local ordinaryShare = (counts[0] or 0) / ROLLS
check("most drops are ordinary", ordinaryShare > 0.9, `saw {string.format("%.3f", ordinaryShare)}`)

-- Luck lifts the variant chance as well as the tier pyramid.
if #variants > 0 then
	local lucky = Economy.variantDropChance(data, Config.Balance.Luck.Bias)
	local plain = Economy.variantDropChance(data, 0)
	check("luck lifts variants", lucky > plain * 2, `{plain} -> {lucky}`)
end

-- Stranding: a variant is only stranded when nothing matches it exactly.
if #variants > 0 then
	local strandedData = {
		Upgrades = { SpawnTier = 6 },
		Items = { Economy.variantIndex(2, 1) },
		Carried = Economy.variantIndex(2, 1),
		LuckEndsAt = 0,
		Rebirths = 0,
		Sparkles = {},
		Discovered = {},
	}
	check("a matching variant is not stranded", not Economy.carriedIsStranded(strandedData))
	strandedData.Items = { 2 }
	check("an ordinary unit will not do", Economy.carriedIsStranded(strandedData))
	if #sparkles > 0 then
		strandedData.Carried = Economy.sparkleIndex(1)
		check("a sparkle is never stranded", not Economy.carriedIsStranded(strandedData))
	end
end

-- Rebirth now needs a rung as well as a price.
local rebirthData = {
	Upgrades = {},
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Cash = 0,
	Sparkles = {},
	Discovered = {},
}
local capped = false
for rebirths = 0, 40 do
	local required = Economy.rebirthTier(rebirths)
	check("rebirth rung stays on the ladder", required >= 1 and required <= MaxTier - 2, `r{rebirths} -> {required}`)
	if rebirths > 0 then
		local previous = Economy.rebirthTier(rebirths - 1)
		check("rebirth rung never falls", required >= previous, `r{rebirths}`)
	end
	if required == MaxTier - 2 then
		capped = true
	end
end
check("rebirth rung reaches its cap", capped)

local required = Economy.rebirthTier(0)
rebirthData.Cash = Economy.rebirthCost(0)
check("cash alone is not enough", not Economy.canRebirth(rebirthData))
rebirthData.Items = { required - 1 }
check("one rung short is not enough", not Economy.canRebirth(rebirthData))
rebirthData.Items = { required }
check("the rung plus the cash is enough", Economy.canRebirth(rebirthData))
rebirthData.Cash = Economy.rebirthCost(0) - 1
check("the rung alone is not enough", not Economy.canRebirth(rebirthData))

-- A variant counts as the rung it copies; a sparkle counts as nothing.
rebirthData.Cash = Economy.rebirthCost(0)
if #variants > 0 then
	rebirthData.Items = { Economy.variantIndex(required, 1) }
	check("a variant counts as its rung", Economy.canRebirth(rebirthData))
end
if #sparkles > 0 then
	rebirthData.Items = { Economy.sparkleIndex(#sparkles) }
	check("a sparkle is not a rung", not Economy.canRebirth(rebirthData))
end
rebirthData.Items = {}
rebirthData.Carried = required
check("what you are carrying counts", Economy.canRebirth(rebirthData))

-- The crafting machine now takes variants, which must read as their rung.
local HardCap = Config.Balance.Craft.HardCap
if #sparkles > 0 then
	local sparkle = sparkles[1]
	local bottom, top = sparkle.Band[1], sparkle.Band[2]
	local plain = { top, top, top, top }

	-- A load's outcomes always add up, variants or not.
	local function totals(inputs)
		local sum = 0
		for _, outcome in Economy.craftOutcomes(inputs) do
			sum += outcome.Chance
			check("no outcome is negative", outcome.Chance >= 0)
			check("every outcome is a real unit", Config.Units[outcome.Index] ~= nil, `index {outcome.Index}`)
		end
		return sum
	end
	check("plain odds add up", math.abs(totals(plain) - 1) < 1e-9)

	if #variants > 0 then
		-- A variant is read as the rung it copies, so it plays for the same
		-- sparkle an ordinary unit of that rung would.
		local variantTop = Economy.variantIndex(top, 1)
		check(
			"a variant plays for its rung's sparkle",
			Economy.craftSparkleIndex({ variantTop }) == Economy.craftSparkleIndex({ top }),
			`{Economy.craftSparkleIndex({ variantTop })}`
		)
		check(
			"a variant counts as its rung for progress",
			math.abs(Economy.craftProgress({ variantTop }, sparkle) - Economy.craftProgress({ top }, sparkle)) < 1e-9
		)

		-- The boost multiplies, raises the ceiling, and never reaches certainty.
		check("no variants means no boost", math.abs(Economy.craftBoost(plain) - 1) < 1e-9)
		for position, variant in variants do
			local one = { Economy.variantIndex(top, position), top, top, top }
			check(
				`{variant.Id} boosts by its own factor`,
				math.abs(Economy.craftBoost(one) - variant.CraftBoost) < 1e-9
			)
			check(
				`{variant.Id} raises the ceiling`,
				Economy.craftCeiling(one, sparkle) > Economy.craftCeiling(plain, sparkle)
			)
			check(
				`{variant.Id} improves the odds`,
				Economy.craftSparkleChance(one, sparkle) > Economy.craftSparkleChance(plain, sparkle)
			)
		end

		local stacked = {}
		for input = 1, Economy.craftInputs() do
			stacked[input] = Economy.variantIndex(top, #variants)
		end
		check("boosts multiply", Economy.craftBoost(stacked) > Economy.craftBoost({ stacked[1] }))
		check("the ceiling stops short of certainty", Economy.craftCeiling(stacked, sparkle) <= HardCap)
		check("even a full load of the best variant is not certain", Economy.craftSparkleChance(stacked, sparkle) < 1)
		check("a boosted load still adds up", math.abs(totals(stacked) - 1) < 1e-9)

		-- A variant from a lower band still plays for the band its rung is in.
		local lowVariant = Economy.variantIndex(bottom, #variants)
		local playedFor = Economy.craftSparkleIndex({ lowVariant })
		check("a low variant plays for a low band", playedFor == Economy.craftSparkleIndex({ bottom }))

		-- Rolling a boosted load never produces a sparkle out of nowhere.
		for _ = 1, 2000 do
			local rolled = Economy.rollCraft(stacked)
			check("a craft always rolls a real unit", Config.Units[rolled] ~= nil, `rolled {rolled}`)
		end
	end
end

-- Quests.
local questData = {
	Upgrades = {},
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Sparkles = {},
	Discovered = {},
	Stats = {},
}
local dailyCount = Config.Balance.Quests.DailyCount

-- The same seed always returns the same set, and it is always distinct.
for seed = 1, 200 do
	local picked = Economy.pickQuests(seed, dailyCount, false)
	check("picks the asked-for count", #picked == dailyCount, `seed {seed} gave {#picked}`)
	local seen = {}
	for _, quest in picked do
		check("no quest is picked twice", not seen[quest.Id], `seed {seed} repeated {quest.Id}`)
		seen[quest.Id] = true
		check("every pick is a real quest", Economy.questById(quest.Id) ~= nil, quest.Id)
	end
	local again = Economy.pickQuests(seed, dailyCount, false)
	for index, quest in picked do
		check("the same seed gives the same set", again[index].Id == quest.Id, `seed {seed}`)
	end
end

-- Different days give different sets, at least most of the time.
local differing = 0
for seed = 1, 100 do
	local a, b = Economy.pickQuests(seed, dailyCount, false), Economy.pickQuests(seed + 1, dailyCount, false)
	if a[1].Id ~= b[1].Id then
		differing += 1
	end
end
check("consecutive days usually differ", differing > 50, `{differing} of 100`)

-- Weeklies come from their own pool.
for seed = 1, 50 do
	local weekly = Economy.pickQuests(seed, 1, true)
	check("a weekly is picked", #weekly == 1)
	local fromWeeklyPool = false
	for _, quest in Config.Balance.Quests.Weekly do
		if quest.Id == weekly[1].Id then
			fromWeeklyPool = true
		end
	end
	check("the weekly comes from the weekly pool", fromWeeklyPool, weekly[1].Id)
end

-- Progress is measured from the baseline, never from zero.
local quest = Config.Balance.Quests.Daily[1]
questData.Stats[quest.Stat] = 1000
local slot = { Id = quest.Id, Base = 1000, Claimed = false, Weekly = false }
local done, target = Economy.questProgress(questData, slot)
check("a running tally starts the quest at zero", done == 0, `saw {done}`)
check("the target is the quest's own", target == quest.Target)
check("nothing is claimable at zero", not Economy.questClaimable(questData, slot))

questData.Stats[quest.Stat] = 1000 + quest.Target - 1
check("one short is not complete", not Economy.questComplete(questData, slot))
questData.Stats[quest.Stat] = 1000 + quest.Target
check("the target completes it", Economy.questComplete(questData, slot))
check("a complete quest is claimable", Economy.questClaimable(questData, slot))
slot.Claimed = true
check("a claimed quest is not claimable again", not Economy.questClaimable(questData, slot))

questData.Stats[quest.Stat] = 1000 + quest.Target * 10
local over = Economy.questProgress(questData, slot)
check("progress is clamped to the target", over == quest.Target, `saw {over}`)

-- An unknown quest id degrades rather than throwing.
local ghost = { Id = "NotAQuest", Base = 0, Claimed = false, Weekly = false }
check("an unknown quest is never complete", not Economy.questComplete(questData, ghost))

-- Weeks advance with days.
check("a week is seven days", Economy.currentWeek(0) == 0 and Economy.currentWeek(86400 * 7) == 1)

-- Playtime rewards. The ladder is session seconds rather than anything in the
-- save, so these are the arithmetic: a rung is ready at its own minute and not
-- a second before, and claiming one never affects another.
local rungs = Economy.playtimeRungs()
check("the ladder has rungs", #rungs > 0)

local claimedNone: { [number]: boolean } = {}
for index, rung in rungs do
	local target = Economy.playtimeTarget(index)
	check("a rung's target is its minutes", target == rung.Minutes * 60, `rung {index}`)
	check("a rung is not ready a second early", not Economy.playtimeReached(target - 1, index), `rung {index}`)
	check("a rung is ready on the second", Economy.playtimeReached(target, index), `rung {index}`)

	local done, shown = Economy.playtimeProgress(target - 30, index)
	check("progress counts the seconds waited", done == target - 30, `rung {index}`)
	check("progress is out of the target", shown == target, `rung {index}`)
	local over = Economy.playtimeProgress(target * 10, index)
	check("progress is clamped to the target", over == target, `rung {index}`)

	check("an unclaimed reached rung is claimable", Economy.playtimeClaimable(target, claimedNone, index))
	check(
		"an unreached rung is not claimable",
		not Economy.playtimeClaimable(target - 1, claimedNone, index),
		`rung {index}`
	)
end

-- A rung off the end of the ladder degrades rather than throwing, the way an
-- unknown quest id does: the index comes off a remote.
check("a rung past the end has no target", Economy.playtimeTarget(#rungs + 1) == 0)
check("a rung past the end is never ready", not Economy.playtimeReached(math.huge, #rungs + 1))
local ghostDone, ghostTarget = Economy.playtimeProgress(500, 0)
check("a rung before the start has no progress", ghostDone == 0 and ghostTarget == 0)

-- Sitting past the top of the ladder has every rung waiting, and claiming one
-- takes exactly one off the count.
local forever = Economy.playtimeTarget(#rungs)
check("every rung comes up eventually", Economy.playtimeReadyCount(forever, claimedNone) == #rungs)
check("a fresh session has none ready", Economy.playtimeReadyCount(0, claimedNone) == 0)

local claimedOne: { [number]: boolean } = { [1] = true }
check("claiming one takes one off the count", Economy.playtimeReadyCount(forever, claimedOne) == #rungs - 1)
check("a claimed rung is not claimable again", not Economy.playtimeClaimable(forever, claimedOne, 1))
check("claiming one leaves the others alone", Economy.playtimeClaimable(forever, claimedOne, 2))

-- The rungs climb, which is what lets the panel list them in order and what
-- makes "the next one up" mean anything.
for index = 2, #rungs do
	check("the ladder climbs", rungs[index].Minutes > rungs[index - 1].Minutes, `rung {index}`)
end

-- The weekly leaderboard race. The board resets by being keyed on the week, so
-- what's tested here is the arithmetic that decides what a player has earned
-- since theirs turned over, and who is owed what for the week before.
local WEEK = 86400 * 7
local raceData = {
	Upgrades = {},
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Sparkles = {},
	Discovered = {},
	Stats = {},
	TotalEarned = 5000,
	Weekly = { Week = Economy.currentWeek(WEEK * 3), Base = 1000, PaidWeek = -1 },
}

check("earnings are counted from the base", Economy.weeklyEarned(raceData, WEEK * 3) == 4000)

-- A base captured for another week is stale. Reading it as earnings would put
-- the whole of last week on top of this week's board.
check("a stale base earns nothing yet", Economy.weeklyEarned(raceData, WEEK * 4) == 0)
check("a base from the future earns nothing yet", Economy.weeklyEarned(raceData, WEEK * 2) == 0)

raceData.Weekly.Base = 9000
check("earnings never go negative", Economy.weeklyEarned(raceData, WEEK * 3) == 0)
raceData.Weekly.Base = 5000
check("having earned nothing is zero, not nil", Economy.weeklyEarned(raceData, WEEK * 3) == 0)

-- Prizes pay down the places and stop.
local places = Economy.prizePlaces()
check("some places pay", places > 0)
for rank = 1, places do
	check("a paying place pays", Economy.leaderboardPrize(rank) > 0, `rank {rank}`)
end
for rank = 2, places do
	check(
		"a lower place never pays more",
		Economy.leaderboardPrize(rank) <= Economy.leaderboardPrize(rank - 1),
		`rank {rank}`
	)
end
check("first place pays the most", Economy.leaderboardPrize(1) > Economy.leaderboardPrize(places))
check("a place off the end pays nothing", Economy.leaderboardPrize(places + 1) == 0)
-- Rank 0 is what a lookup returns for a player who wasn't on the board at all,
-- so it has to be safe rather than an error.
check("not placing pays nothing", Economy.leaderboardPrize(0) == 0)

-- A prize is claimed during the week after the one it was won in, so the week
-- being claimed for is always behind the current one.
raceData.Weekly.PaidWeek = -1
check("an uncollected prize is owed", Economy.prizeUnclaimed(raceData, 5))
raceData.Weekly.PaidWeek = 5
check("a collected prize is not owed again", not Economy.prizeUnclaimed(raceData, 5))
check("the next week's prize is owed", Economy.prizeUnclaimed(raceData, 6))
check("an older week is not owed", not Economy.prizeUnclaimed(raceData, 4))
-- Before any standings have been read the week is -1, which is nobody's week.
check("no standings means nothing owed", not Economy.prizeUnclaimed(raceData, -1))

-- Monetisation: what each pass is worth, checked against what the same player is
-- worth without it. Every one of these is a number the shop quotes and the server
-- acts on, so the two agreeing is the whole point.

local passData = {
	-- Drop tier upgraded on purpose: at level 0 the drop window is a single rung,
	-- where the top tier is 100% of drops and no amount of luck can improve on it.
	-- A pass that looks worthless is usually a fixture that gave it nothing to do.
	Upgrades = { SpawnTier = 6 },
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Sparkles = {},
	Discovered = {},
	FirstJoin = 0,
	StarterClaimed = false,
	Craft = { { Inputs = {}, EndsAt = 0 }, { Inputs = {}, EndsAt = 0 } },
}

-- Bigger Garden: spaces on top of the upgrade, at every level of it.
local baseCapacity = Economy.gardenCapacity(passData)
local passSpaces = Economy.gardenPassSpaces(true)
check("the garden pass is worth something", passSpaces > 0)
check("no pass adds nothing", Economy.gardenPassSpaces(false) == 0)
check("no pass adds nothing when unknown", Economy.gardenPassSpaces(nil) == 0)
check("the pass adds its spaces", Economy.gardenCapacity(passData, passSpaces) == baseCapacity + passSpaces)
passData.Upgrades.GardenSpace = Economy.upgradeMaxLevel("GardenSpace")
check(
	"the pass is worth the same at the top of the upgrade",
	Economy.gardenCapacity(passData, passSpaces) - Economy.gardenCapacity(passData) == passSpaces
)
-- Room is measured against the raised capacity, or the pass buys nothing.
for _ = 1, Economy.gardenCapacity(passData) do
	table.insert(passData.Items, 1)
end
check("a full garden is full", not Economy.hasRoom(passData))
check("the pass makes room in a full garden", Economy.hasRoom(passData, passSpaces))
passData.Items = {}
passData.Upgrades.GardenSpace = nil

-- Luck: the pass is a charm that never runs out, so it has to be worth exactly
-- one -- no more, and no less.
local charmBias = Config.Balance.Luck.Bias
check("the pass is worth a charm", Economy.luckPassBias(true) == charmBias)
check("no pass overrides nothing", Economy.luckPassBias(false) == nil)
local plainOdds = Economy.topTierChance(passData)
local passOdds = Economy.topTierChance(passData, Economy.luckPassBias(true))
check("the pass improves the top-tier odds", passOdds > plainOdds)
passData.LuckEndsAt = os.time() + 600
check(
	"a charm on top of the pass is worth nothing more",
	math.abs(Economy.topTierChance(passData, Economy.luckPassBias(true)) - Economy.topTierChance(passData)) < 1e-9
)
passData.LuckEndsAt = 0
-- The roll takes the same override the quote does, or the shop would be lying.
for _ = 1, 2000 do
	local index = Economy.randomDropIndex(passData, charmBias)
	check("a lucky drop is still a real unit", Config.Units[index] ~= nil, `index {index}`)
end

-- Auto Collect: a better rate over more hours. Checked at a time away inside
-- both caps and at one past them, since the cap is half the offer.
local perSecond = 10
local oneHour = 3600
check(
	"the pass pays more for the same hour",
	Economy.offlineEarnings(perSecond, oneHour, true) > Economy.offlineEarnings(perSecond, oneHour, false)
)
local longAway = Economy.offlineHours(true) * oneHour * 2
check(
	"the pass banks more of a long absence",
	Economy.offlineEarnings(perSecond, longAway, true) > Economy.offlineEarnings(perSecond, longAway, false)
)
check(
	"the cap still bites with the pass",
	Economy.offlineEarnings(perSecond, longAway, true)
		== Economy.offlineEarnings(perSecond, Economy.offlineHours(true) * oneHour, true)
)
check("the pass's cap is the longer one", Economy.offlineHours(true) > Economy.offlineHours(false))
check("the pass's rate is the better one", Economy.offlineRate(true) > Economy.offlineRate(false))
-- The minimum stands for everyone: rejoining after a disconnect pays nobody.
local brief = Config.Balance.OfflineEarnings.MinSeconds - 1
check("a moment away pays nothing", Economy.offlineEarnings(perSecond, brief, false) == 0)
check("a moment away pays nothing with the pass either", Economy.offlineEarnings(perSecond, brief, true) == 0)

-- Craft slots: the pass sells a second craft, not a bigger one.
check("one slot by default", Economy.craftSlots() == Config.Balance.Craft.Slots)
check("the pass adds a slot", Economy.craftSlots(1) == Economy.craftSlots() + 1)
check("the save holds every slot anyone can have", Economy.maxCraftSlots() >= Economy.craftSlots(1))
check("the inputs are unchanged by the pass", Economy.craftInputs() == Config.Balance.Craft.Inputs)
check("slot 1 exists", Economy.craftAt(passData, 1) ~= nil)
check("a slot past the save is nothing", Economy.craftAt(passData, #passData.Craft + 1) == nil)

-- The two slot-finders are what every loop over crafts uses, and both have to
-- respect how many slots the player actually has.
local slotOne = passData.Craft[1]
local slotTwo = passData.Craft[2]
check("an empty machine is open at slot 1", Economy.openCraftSlot(passData, 1) == 1)
check("nothing is ready in an empty machine", Economy.readyCraftSlot(passData, os.time(), 2) == nil)
slotOne.Inputs = { 1, 1, 1, 1 }
slotOne.EndsAt = os.time() + Economy.craftSeconds()
check("a running slot is not open", Economy.openCraftSlot(passData, 1) == nil)
check("the second slot is open to a pass owner", Economy.openCraftSlot(passData, 2) == 2)
check("running is not ready", Economy.readyCraftSlot(passData, os.time(), 2) == nil)
slotOne.EndsAt = os.time() - 1
check("a finished slot is ready", Economy.readyCraftSlot(passData, os.time(), 2) == 1)
-- A craft parked in a slot the player no longer has access to is invisible to
-- both, rather than being announced as a thing they can collect.
slotTwo.Inputs = { 1 }
slotTwo.EndsAt = os.time() - 1
check("only the first slot is ready without the pass", Economy.readyCraftSlot(passData, os.time(), 1) == 1)
slotOne.EndsAt = os.time() + Economy.craftSeconds()
check("a parked second slot is never ready without the pass", Economy.readyCraftSlot(passData, os.time(), 1) == nil)
check("a parked second slot is never open without the pass", Economy.openCraftSlot(passData, 1) == nil)
check("but it is with the pass", Economy.readyCraftSlot(passData, os.time(), 2) == 2)
-- The clocks are per craft now, so one slot's state must say nothing about the
-- other's.
check("the running slot is running", Economy.craftRunning(slotOne))
check("the running slot is not ready", not Economy.craftReady(slotOne, os.time()))
check("the finished slot is ready", Economy.craftReady(slotTwo, os.time()))
check("a skip is never free", Economy.craftSkipCost(slotOne, os.time()) >= 1)
check("a finished craft costs the minimum to skip", Economy.craftSkipCost(slotTwo, os.time()) == 1)
check(
	"a longer wait costs more to skip",
	Economy.craftSkipCost(slotOne, os.time()) > Economy.craftSkipCost(slotOne, os.time() + Economy.craftSeconds() // 2)
)

-- The starter pack: one window, from first join, once.
local starterData = {
	FirstJoin = 0,
	StarterClaimed = false,
}
local window = Economy.starterWindow()
check("the window is a real length of time", window > 0)
-- A save with no first join recorded is not a new player, and gets no offer.
check("no first join means no offer", not Economy.starterOffered(starterData, os.time()))
local joined = os.time()
starterData.FirstJoin = joined
check("a new player is offered it", Economy.starterOffered(starterData, joined))
check("the whole window is left at the start", Economy.starterRemaining(starterData, joined) == window)
check("it is still offered just before the end", Economy.starterOffered(starterData, joined + window - 1))
check("it expires exactly at the end", not Economy.starterOffered(starterData, joined + window))
check("an expired offer has nothing left", Economy.starterRemaining(starterData, joined + window + 1) == 0)
-- Taking it withdraws it, whatever the clock says.
starterData.StarterClaimed = true
check("a claimed pack is not offered again", not Economy.starterOffered(starterData, joined))
check("a claimed pack has no time left", Economy.starterRemaining(starterData, joined) == 0)

-- Pets. One is equipped at a time and the perk is the reason to own it, so what
-- these hold is: the perk reaching the right consumer, rarity and variant scaling
-- it the amounts Balance says, the cash multiplier staying in its narrow band, and
-- an egg always handing back something real for the cash it takes.

local petData = {
	Upgrades = { SpawnTier = 6 },
	Items = {},
	Carried = 0,
	LuckEndsAt = 0,
	Rebirths = 0,
	Sparkles = {},
	Discovered = {},
	Pets = {},
	EquippedPet = 0,
}

local petList = Config.Pets
check("the theme ships pets", #petList > 0)

-- Every pet names a rarity and a perk that exist. Config asserts this at load, so
-- reaching here at all is most of the check; this says which one if it ever fails.
for _, pet in petList do
	check(`{pet.Id} has a real rarity`, Config.PetRarityById[pet.Rarity] ~= nil, pet.Rarity)
	check(`{pet.Id} has a real perk`, Config.PetPerkById[pet.Perk] ~= nil, pet.Perk)
end

-- Every perk in the vocabulary is carried by at least one pet, or it is a perk no
-- player can ever have -- which is a typo, not a design.
for _, perk in Config.Balance.Pets.Perks do
	local carried = false
	for _, pet in petList do
		carried = carried or pet.Perk == perk.Id
	end
	check(`some pet carries {perk.Id}`, carried)
end

-- Nothing equipped answers nothing, for every perk. Every consumer relies on this
-- rather than checking whether the player has a pet.
check("no pet means no multiplier", Economy.petCashMultiplier(petData) == 1)
for _, perk in Config.Balance.Pets.Perks do
	check(`no pet means no {perk.Id}`, Economy.petPerkValue(petData, perk.Id) == 0)
end
check("no pet is no pet", Economy.equippedPet(petData) == nil)

-- Equip one, and only its own perk answers.
local sample = petList[1]
petData.Pets = { { Id = sample.Id, Variant = 0 } }
petData.EquippedPet = 1
check("the equipped pet is found", Economy.equippedPet(petData) ~= nil)
check("its own perk answers", Economy.petPerkValue(petData, sample.Perk) > 0)
for _, perk in Config.Balance.Pets.Perks do
	if perk.Id ~= sample.Perk then
		check(`a pet does not carry {perk.Id} as well`, Economy.petPerkValue(petData, perk.Id) == 0)
	end
end

-- An index pointing past the end is what releasing a pet can leave behind, and it
-- has to read as "nothing equipped" rather than throwing.
petData.EquippedPet = 5
check("an index past the end is nothing", Economy.equippedPet(petData) == nil)
check("and pays nothing", Economy.petCashMultiplier(petData) == 1)
petData.EquippedPet = 1

-- Rarity and variant both scale the perk, and the multiplier stays in its band.
local rarities = Config.Balance.Pets.Rarities
local lowest, highest = rarities[1], rarities[#rarities]
check("the rarity ladder climbs", highest.Perk > lowest.Perk)
check("so does what it pays", highest.Multiplier > lowest.Multiplier)
check(
	"but the multiplier stays a nudge",
	highest.Multiplier / lowest.Multiplier < 1.5,
	`{highest.Multiplier} vs {lowest.Multiplier}`
)
for _, rarity in rarities do
	check(`{rarity.Id} pays more than nothing`, rarity.Multiplier >= 1)
	check(`{rarity.Id} is not a doubling`, rarity.Multiplier <= 1.5, `{rarity.Multiplier}`)
end

local plain = { Id = sample.Id, Variant = 0 }
local plainStrength = Economy.petPerkStrength(plain)
check("a pet's perk is worth something", plainStrength > 0)
for position, variant in Config.Variants do
	local dressed = { Id = sample.Id, Variant = position }
	check(`a {variant.Id} pet has a stronger perk`, Economy.petPerkStrength(dressed) > plainStrength, variant.Id)
	check(
		`{variant.Id} scales the perk by PetPerk`,
		math.abs(Economy.petPerkStrength(dressed) - plainStrength * variant.PetPerk) < 1e-9
	)
	-- A variant changes the perk and nothing else: the cash multiplier is the
	-- rarity's, so a Rainbow common still pays what a common pays.
	petData.Pets = { dressed }
	local dressedMultiplier = Economy.petCashMultiplier(petData)
	petData.Pets = { plain }
	check(`a {variant.Id} pet pays the same`, Economy.petCashMultiplier(petData) == dressedMultiplier)
end
-- The variant ladder has to climb for pets as well, or the rarest dressing is not
-- the best one.
for position = 2, #Config.Variants do
	check(
		`variant {position} beats {position - 1} on perks`,
		Config.Variants[position].PetPerk > Config.Variants[position - 1].PetPerk
	)
end

-- Eggs: the odds add up, they only name rarities the theme can fill, and a roll
-- always produces a pet that exists. The last one matters most -- an egg takes
-- cash, so a roll that returns nothing is a robbery.
for _, egg in Config.Balance.Pets.Eggs do
	local chances = Economy.eggChances(egg)
	local total = 0
	for rarityId, chance in chances do
		total += chance
		check(`{egg.Id} weights a real rarity`, Config.PetRarityById[rarityId] ~= nil, rarityId)
		check(`{egg.Id} has pets for {rarityId}`, #Config.PetsByRarity[rarityId] > 0)
	end
	check(`{egg.Id}'s odds add up`, math.abs(total - 1) < 1e-9, `{total}`)
	check(`{egg.Id} costs something`, egg.Cost > 0)
	check(`{egg.Id} is found by Id`, Economy.eggById(egg.Id) ~= nil)

	for _ = 1, 500 do
		local rolled = Economy.rollEgg(egg, petData)
		check(`{egg.Id} always rolls a real pet`, rolled ~= nil and Economy.petDef(rolled.Id) ~= nil)
		if rolled then
			local def = Economy.petDef(rolled.Id)
			check(`{egg.Id} only rolls rarities it weights`, egg.Weights[(def :: any).Rarity] ~= nil)
			check(`{egg.Id} rolls a real variant`, rolled.Variant == 0 or Config.Variants[rolled.Variant] ~= nil)
			check(`{egg.Id} names what it rolled`, Economy.petName(rolled) ~= "Unknown")
		end
	end
end
check("an egg that doesn't exist isn't found", Economy.eggById("NoSuchEgg") == nil)

-- Dearer eggs have to be better, or there is no reason to walk to one. Measured on
-- the chance of the best rarity the ladder has.
local best = rarities[#rarities].Id
local eggs = Config.Balance.Pets.Eggs
for index = 2, #eggs do
	local dearer, cheaper = eggs[index], eggs[index - 1]
	check(`{dearer.Id} costs more than {cheaper.Id}`, dearer.Cost > cheaper.Cost)
	check(
		`{dearer.Id} has better odds at a {best}`,
		(Economy.eggChances(dearer)[best] or 0) >= (Economy.eggChances(cheaper)[best] or 0)
	)
end

-- The perks that ride on seams other things already used: each has to make a
-- difference in the direction it claims.
local sellStrength = 0.2
check("a Haggler makes the bin pay more", Economy.binValue(5, sellStrength) > Economy.binValue(5))
check(
	"but never the full price, however strong",
	Economy.binValue(5, 99) < Economy.unitValue(5),
	`{Economy.binValue(5, 99)} vs {Economy.unitValue(5)}`
)
check("a merge pays nothing without the perk", Economy.mergePayout(5, 0) == 0)
check("and something with it", Economy.mergePayout(5, 0.5) > 0)
local sparkleForCraft = sparkles[1]
if sparkleForCraft then
	local load = { sparkleForCraft.Band[1] }
	check(
		"a Lucky Crafter raises the ceiling",
		Economy.craftCeiling(load, sparkleForCraft, 0.5) > Economy.craftCeiling(load, sparkleForCraft)
	)
	check(
		"and the odds with it",
		Economy.craftSparkleChance(load, sparkleForCraft, 0.5) > Economy.craftSparkleChance(load, sparkleForCraft)
	)
	-- The outcome chances still add to 1 with a pet in the mix, which is the one
	-- thing raising a ceiling could quietly break.
	local total = 0
	for _, outcome in Economy.craftOutcomes(load, 0.5) do
		total += outcome.Chance
	end
	check("a craft with a pet still adds up", math.abs(total - 1) < 1e-9, `{total}`)
end

-- Luck has three sources now and they must not stack into something silly: the
-- charm and the permanent pass are the same tilt, so the greater of the two.
petData.Pets = { plain }
petData.EquippedPet = 1
local charmBiasForPets = Config.Balance.Luck.Bias
petData.LuckEndsAt = 0
local noLuck = Economy.totalLuckBias(petData, os.time(), false)
local passLuck = Economy.totalLuckBias(petData, os.time(), true)
check("the pass is worth its bias", math.abs(passLuck - noLuck - charmBiasForPets) < 1e-9)
petData.LuckEndsAt = os.time() + 600
check(
	"a charm on top of the pass adds nothing",
	math.abs(Economy.totalLuckBias(petData, os.time(), true) - passLuck) < 1e-9
)
check(
	"a charm alone is worth the same as the pass alone",
	math.abs(Economy.totalLuckBias(petData, os.time(), false) - passLuck) < 1e-9
)
petData.LuckEndsAt = 0

-- The Charmed pet adds on top of both, and only when it's the equipped one.
local charmedId = nil
for _, pet in petList do
	if pet.Perk == "DropLuck" then
		charmedId = pet.Id
	end
end
if charmedId then
	petData.Pets = { { Id = charmedId, Variant = 0 } }
	local withPet = Economy.totalLuckBias(petData, os.time(), false)
	check("a Charmed pet adds luck", withPet > noLuck)
	check(
		"and adds on top of the pass rather than replacing it",
		Economy.totalLuckBias(petData, os.time(), true) > passLuck
	)
	petData.EquippedPet = 0
	check(
		"a Charmed pet in the bag adds nothing",
		math.abs(Economy.totalLuckBias(petData, os.time(), false) - noLuck) < 1e-9
	)
end

-- Rarity colours and the egg's pool: both are read by the two panels, and both
-- have to answer for every rarity a theme could ship.
for _, rarity in Economy.petRarities() do
	check(`{rarity.Id} has a real palette tone`, (Config.Theme.Palette :: any)[rarity.Tone] ~= nil, rarity.Tone)
	check(`{rarity.Id} resolves to a colour`, Economy.petRarityColor(rarity) ~= nil)
end
check(
	"the rarity ladder is ordered weakest first",
	Economy.petRarities()[1].Perk < Economy.petRarities()[#Economy.petRarities()].Perk
)

-- The egg panel lists what an egg can hand over, so the pool has to match the
-- weights exactly: nothing the egg can't roll, and nothing it can roll left out.
for _, egg in Config.Balance.Pets.Eggs do
	local pool = Economy.eggPool(egg)
	check(`{egg.Id}'s pool isn't empty`, #pool > 0)
	local seen: { [string]: boolean } = {}
	for _, def in pool do
		check(`{egg.Id}'s pool only holds rarities it weights`, egg.Weights[def.Rarity] ~= nil, def.Rarity)
		check(`{egg.Id}'s pool has no duplicates`, not seen[def.Id], def.Id)
		seen[def.Id] = true
	end
	for rarityId in egg.Weights do
		local found = false
		for _, def in pool do
			found = found or def.Rarity == rarityId
		end
		check(`{egg.Id}'s pool covers {rarityId}`, found)
	end
	-- Weakest first, so the panel reads in the same order as the odds above it.
	local lastRank = 0
	local rank: { [string]: number } = {}
	for position, rarity in Economy.petRarities() do
		rank[rarity.Id] = position
	end
	local ordered = true
	for _, def in pool do
		ordered = ordered and rank[def.Rarity] >= lastRank
		lastRank = rank[def.Rarity]
	end
	check(`{egg.Id}'s pool is ordered by rarity`, ordered)
end

check("the inventory has a ceiling", Economy.maxOwnedPets() > 0)
petData.Pets = {}
check("an empty inventory is not full", not Economy.petsFull(petData))
for index = 1, Economy.maxOwnedPets() do
	petData.Pets[index] = { Id = sample.Id, Variant = 0 }
end
check("a full inventory is full", Economy.petsFull(petData))

print(`{checks - failures} / {checks} checks passed`)
if failures > 0 then
	error(`{failures} checks failed`)
end
