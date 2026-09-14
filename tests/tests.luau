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
		for slot = 1, Config.Balance.Craft.Slots do
			stacked[slot] = Economy.variantIndex(top, #variants)
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

print(`{checks - failures} / {checks} checks passed`)
if failures > 0 then
	error(`{failures} checks failed`)
end
