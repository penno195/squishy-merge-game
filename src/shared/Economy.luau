--!strict
-- Pure economy formulas shared by server (authoritative) and client (display).

local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Balance = Config.Balance

local Economy = {}

local upgradeById = {}
for _, upgrade in Balance.Upgrades do
	upgradeById[upgrade.Id] = upgrade
end

-- Sparkles ---------------------------------------------------------------
-- A unit index above the merge ladder is one of the theme's sparkles. Keeping
-- the test in one place is what lets the rest of the game treat them as units.

function Economy.isSparkle(index: number): boolean
	return index > Config.MaxTier and index <= Config.VariantBase
end

function Economy.sparkleAt(index: number): Types.SparkleDef?
	if not Economy.isSparkle(index) then
		return nil
	end
	return Config.Sparkles[index - Config.MaxTier]
end

-- The unit index of the sparkle at position `position` in the theme's list.
function Economy.sparkleIndex(position: number): number
	return Config.MaxTier + position
end

-- Everything the player's sparkles add to their cash multiplier. Counted off
-- the collection record rather than what's lying in the garden, so each
-- distinct sparkle pays once however many of it have been made: the bonus
-- belongs to the trophy on the plinth, and a second copy is just another very
-- good unit. Once earned it's permanent, rebirths included.
function Economy.sparkleBonus(data: Types.PlayerData): number
	local bonus = 0
	for _, sparkle in Config.Sparkles do
		if (data.Sparkles[sparkle.Id] or 0) > 0 then
			bonus += sparkle.Bonus
		end
	end
	return bonus
end

function Economy.hasSparkle(data: Types.PlayerData, id: string): boolean
	return (data.Sparkles[id] or 0) > 0
end

-- Variants ---------------------------------------------------------------
-- A variant is the same unit worth more: the merge ladder repeated past the
-- sparkles, one block per variant. Config stamps `Tier` and `Variant` onto
-- every entry when it builds the list, so reading either back is a lookup
-- rather than arithmetic on the index -- and the arithmetic that is left, going
-- the other way, lives here and nowhere else.

-- Which variant an index is, or 0 for an ordinary unit or a sparkle.
function Economy.variantOf(index: number): number
	local unit = Config.Units[index]
	return if unit then unit.Variant or 0 else 0
end

function Economy.variantAt(index: number)
	return Config.Variants[Economy.variantOf(index)]
end

-- The rung on the merge ladder an index sits on, the same for a unit and every
-- variant of it. 0 for a sparkle, which sits off the end of the ladder.
function Economy.ladderTier(index: number): number
	local unit = Config.Units[index]
	return if unit then unit.Tier or 0 else 0
end

-- The other direction: the index of a tier in a given variant. Variant 0 is the
-- ordinary ladder, where the index and the tier are the same number.
function Economy.variantIndex(tier: number, variant: number): number
	-- A variant the current Balance doesn't have falls back to the ordinary
	-- unit, rather than pointing past the end of the list. That happens when a
	-- theme trims the variant ladder under a save that used it.
	if variant <= 0 or not Config.Variants[variant] then
		return tier
	end
	return Config.VariantBase + (variant - 1) * Config.MaxTier + tier
end

-- What a variant multiplies income and sale value by. 1 for ordinary units.
function Economy.variantIncome(index: number): number
	local variant = Economy.variantAt(index)
	return if variant then variant.Income else 1
end

-- Whether two of this index can still become something. False at the top of
-- the ladder and for sparkles, which is what stops either being merged away.
function Economy.canMerge(index: number): boolean
	local tier = Economy.ladderTier(index)
	return tier > 0 and tier < Config.MaxTier
end

-- What two of them make. Variant blocks are copies of the ladder in order, so
-- the next index up is the next tier in the same variant.
function Economy.mergeResult(index: number): number
	return index + 1
end

-- Upgrades ---------------------------------------------------------------

function Economy.getUpgrade(id: string)
	return upgradeById[id]
end

function Economy.upgradeLevel(data: Types.PlayerData, id: string): number
	return data.Upgrades[id] or 0
end

function Economy.upgradeCost(id: string, level: number): number
	local upgrade = upgradeById[id]
	return math.floor(upgrade.BaseCost * upgrade.Growth ^ level)
end

-- Some upgrades are capped by the theme/balance (a theme with few tiers can't
-- raise the drop tier as far).
function Economy.upgradeMaxLevel(id: string): number
	local upgrade = upgradeById[id]
	if id == "SpawnTier" then
		return math.min(upgrade.MaxLevel, Config.MaxTier - 2)
	elseif id == "GardenSpace" then
		return math.min(upgrade.MaxLevel, #Balance.GardenCapacities - 1)
	end
	return upgrade.MaxLevel
end

-- Garden -----------------------------------------------------------------

-- `extraSpaces` is what the Bigger Garden pass adds, passed in by whoever
-- verified it -- the server from PassService, the client from its snapshot --
-- the same way every other pass effect reaches this module.
function Economy.gardenCapacity(data: Types.PlayerData, extraSpaces: number?): number
	local level = math.clamp(Economy.upgradeLevel(data, "GardenSpace"), 0, #Balance.GardenCapacities - 1)
	return Balance.GardenCapacities[level + 1] + (extraSpaces or 0)
end

-- A carried item still takes up its space in the garden, so putting it back
-- down is always possible.
function Economy.usedSpace(data: Types.PlayerData): number
	return #data.Items + (if data.Carried > 0 then 1 else 0)
end

function Economy.hasRoom(data: Types.PlayerData, extraSpaces: number?): boolean
	return Economy.usedSpace(data) < Economy.gardenCapacity(data, extraSpaces)
end

-- What the Bigger Garden pass is worth, given whether it's owned. Here rather
-- than at each call site because the server asks this question once and the
-- client asks it in two places, and three copies of one `if` is how the three
-- come to disagree.
function Economy.gardenPassSpaces(owned: boolean?): number
	return if owned then Balance.Monetisation.BiggerGardenSpaces else 0
end

-- The permanent charm, in the form every luck-sensitive function here already
-- takes: a bias override, or nil for "whatever the player's own charm says".
function Economy.luckPassBias(owned: boolean?): number?
	return if owned then Balance.Luck.Bias else nil
end

-- New players (and rebirths) start with a mergeable pair on the ground.
function Economy.startingItems(): { number }
	return { 1, 1 }
end

-- What survives a rebirth: the sparkles, which are limited editions rather than
-- progress, plus the usual starting pair.
function Economy.itemsAfterRebirth(items: { number }): { number }
	local kept = Economy.startingItems()
	for _, index in items do
		if Economy.isSparkle(index) then
			table.insert(kept, index)
		end
	end
	return kept
end

-- Earning boost & gems ---------------------------------------------------

function Economy.boostCost(): number
	return Balance.Boost.GemCost
end

function Economy.boostSeconds(): number
	return Balance.Boost.Seconds
end

function Economy.boostRemaining(data: Types.PlayerData, now: number?): number
	return math.max(data.BoostEndsAt - (now or os.time()), 0)
end

function Economy.boostActive(data: Types.PlayerData, now: number?): boolean
	return Economy.boostRemaining(data, now) > 0
end

function Economy.boostMultiplier(data: Types.PlayerData, now: number?): number
	return if Economy.boostActive(data, now) then Balance.Boost.Multiplier else 1
end

-- Luck is the boost's twin: bought with gems, runs on a clock, and does
-- nothing once it lapses. What it buys is a tilt on the drop roll rather than
-- a cash multiplier, so it's spent in Economy.dropTierChances.

function Economy.luckCost(): number
	return Balance.Luck.GemCost
end

function Economy.luckSeconds(): number
	return Balance.Luck.Seconds
end

function Economy.luckRemaining(data: Types.PlayerData, now: number?): number
	return math.max(data.LuckEndsAt - (now or os.time()), 0)
end

function Economy.luckActive(data: Types.PlayerData, now: number?): boolean
	return Economy.luckRemaining(data, now) > 0
end

-- Auto merge on the same terms: gems, a clock, and extended rather than reset
-- when bought again. The pass owner's version is checked by whoever knows about
-- passes; this is only ever the timed one.

function Economy.autoMergeCost(): number
	return Balance.AutoMerge.GemCost
end

function Economy.autoMergeSeconds(): number
	return Balance.AutoMerge.Seconds
end

function Economy.autoMergeRemaining(data: Types.PlayerData, now: number?): number
	return math.max(data.AutoMergeEndsAt - (now or os.time()), 0)
end

-- Income -----------------------------------------------------------------

-- Takes any unit index. A sparkle earns like an ordinary unit a few tiers above
-- the top of its band, which puts it above anything else a craft can produce.
-- A variant earns its own multiple of the tier it copies, which is what makes
-- one worth keeping rather than merging away at the first opportunity.
function Economy.tierIncome(index: number): number
	local sparkle = Economy.sparkleAt(index)
	local tier = if sparkle then sparkle.Band[2] + Balance.Craft.SparkleIncomeTiers else Economy.ladderTier(index)
	return Balance.Income.Base * Balance.Income.TierGrowth ^ (tier - 1) * Economy.variantIncome(index)
end

function Economy.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * Balance.Rebirth.MultiplierPerRebirth
end

-- `passMultiplier` comes from gamepasses the server has verified. Pass
-- `boostMultiplier` to override the timed boost -- offline earnings pass 1, so
-- a boost bought before logging off can't multiply hours of away time.
function Economy.cashMultiplier(data: Types.PlayerData, passMultiplier: number, boostMultiplier: number?): number
	local upgrade = upgradeById.Income
	local upgradeBonus = 1 + Economy.upgradeLevel(data, "Income") * upgrade.PerLevel
	return upgradeBonus
		* (1 + Economy.sparkleBonus(data))
		* Economy.rebirthMultiplier(data.Rebirths)
		* passMultiplier
		* (boostMultiplier or Economy.boostMultiplier(data))
end

-- Only items lying in the garden earn; whatever the player is carrying doesn't.
function Economy.incomePerSecond(data: Types.PlayerData, passMultiplier: number, boostMultiplier: number?): number
	local base = 0
	for _, tier in data.Items do
		base += Economy.tierIncome(tier)
	end
	return base * Economy.cashMultiplier(data, passMultiplier, boostMultiplier)
end

-- Rewards ----------------------------------------------------------------

-- One full reward bundle at a band. Balance.Rewards carries the reasoning; the
-- short of it is that this climbs slower than income does, so a bundle is worth
-- steadily less of a garden as the garden grows.
function Economy.bandPayout(band: number): number
	local rewards = Balance.Rewards
	return math.floor(rewards.Base * rewards.Growth ^ (math.max(band, 1) - 1))
end

-- What a reward pays: its share of one bundle at that band.
function Economy.rewardCash(band: number, payout: number): number
	return math.floor(Economy.bandPayout(band) * payout)
end

-- The band a player's rewards are paid at. Read rather than computed, because
-- it is frozen between weekly rollovers -- a band that moved with the drop tier
-- the moment it changed would put the day's rewards up mid-claim.
function Economy.rewardBand(data: Types.PlayerData): number
	return math.max(data.Weekly.Band, 1)
end

-- Re-reads the band off the player's progress. Called when the week rolls over,
-- which is also the first thing that happens to a player who has never had one.
function Economy.refreshRewardBand(data: Types.PlayerData)
	data.Weekly.Band = Economy.dropTier(data)
end

-- `autoCollect` is the pass: it replaces both halves of the deal at once, the
-- fraction earned and how many hours are counted. Replacing rather than stacking
-- keeps the offer describable in one line -- "a full day, at full rate" -- and
-- means the two numbers can be tuned without their product surprising anyone.
--
-- MinSeconds is deliberately not waived. It exists so rejoining after a
-- disconnect doesn't pay out, which is as true for a pass owner as anyone.
function Economy.offlineEarnings(incomePerSecond: number, secondsAway: number, autoCollect: boolean?): number
	local offline = Balance.OfflineEarnings
	local auto = Balance.Monetisation.AutoCollect
	if secondsAway < offline.MinSeconds then
		return 0
	end
	local maxHours = if autoCollect then auto.MaxHours else offline.MaxHours
	local rate = if autoCollect then auto.Rate else offline.Rate
	local seconds = math.min(secondsAway, maxHours * 3600)
	return math.floor(incomePerSecond * seconds * rate)
end

-- What the Auto Collect pass is worth, for the shop line that sells it: hours
-- banked and the rate they bank at, against what the same time is worth without.
function Economy.offlineHours(autoCollect: boolean?): number
	return if autoCollect then Balance.Monetisation.AutoCollect.MaxHours else Balance.OfflineEarnings.MaxHours
end

function Economy.offlineRate(autoCollect: boolean?): number
	return if autoCollect then Balance.Monetisation.AutoCollect.Rate else Balance.OfflineEarnings.Rate
end

-- Pets --------------------------------------------------------------------
-- One pet is equipped at a time and the rest wait in the inventory, so a pet is
-- a tool chosen for what the player is about to do. Everything here is about the
-- equipped one: `petPerkValue` is the single question every consumer asks, and it
-- answers 0 for a player with no pet, the wrong pet, or no pets at all -- which
-- means none of them has to branch on whether pets exist in this theme.

local PetBalance = Balance.Pets

function Economy.petDef(id: string): Types.PetDef?
	return Config.PetById[id]
end

function Economy.petRarityOf(id: string): Types.PetRarity?
	local def = Config.PetById[id]
	return if def then Config.PetRarityById[def.Rarity] else nil
end

-- The pet at the player's heels, or nil. `EquippedPet` is an index into the
-- inventory, so releasing a pet can leave it pointing past the end -- this is
-- where that's caught rather than at every call site.
function Economy.equippedPet(data: Types.PlayerData): Types.PetRecord?
	local record = data.Pets[data.EquippedPet]
	return if record and Config.PetById[record.Id] then record else nil
end

-- How hard one pet's perk hits: the perk's own Amount, scaled by rarity and then
-- by the variant. Both scales are modest on purpose -- see Balance.Pets.
function Economy.petPerkStrength(record: Types.PetRecord): number
	local def = Config.PetById[record.Id]
	if not def then
		return 0
	end
	local perk = Config.PetPerkById[def.Perk]
	local rarity = Config.PetRarityById[def.Rarity]
	if not (perk and rarity) then
		return 0
	end
	local variant = Config.Variants[record.Variant]
	return perk.Amount * rarity.Perk * (if variant then variant.PetPerk else 1)
end

-- The strength of `perkId` from whatever is equipped, or 0. Every consumer of a
-- perk goes through this, so asking for a perk the equipped pet doesn't have is
-- the ordinary case rather than a special one.
function Economy.petPerkValue(data: Types.PlayerData, perkId: string): number
	local record = Economy.equippedPet(data)
	if not record then
		return 0
	end
	local def = Config.PetById[record.Id]
	if not def or def.Perk ~= perkId then
		return 0
	end
	return Economy.petPerkStrength(record)
end

-- What the equipped pet multiplies cash by. A narrow band by design, so this is
-- a nudge rather than a reason to keep the rarest pet on forever.
function Economy.petCashMultiplier(data: Types.PlayerData): number
	local record = Economy.equippedPet(data)
	if not record then
		return 1
	end
	local rarity = Economy.petRarityOf(record.Id)
	return if rarity then rarity.Multiplier else 1
end

-- Dressed the way a variant unit is, out of the theme's own Variants styling, so
-- a Golden pet needs nothing configured beyond what Golden units already have.
function Economy.petName(record: Types.PetRecord): string
	local def = Config.PetById[record.Id]
	if not def then
		return "Unknown"
	end
	local variant = Config.Variants[record.Variant]
	if not variant then
		return def.Name
	end
	local styling = (Config.Theme.Variants or {})[variant.Id]
	local prefix = if styling and styling.Prefix then styling.Prefix else variant.Id
	return `{prefix} {def.Name}`
end

function Economy.petColor(record: Types.PetRecord): Color3
	local def = Config.PetById[record.Id]
	if not def then
		return Color3.new(1, 1, 1)
	end
	local variant = Config.Variants[record.Variant]
	if not variant then
		return def.Color
	end
	local styling = (Config.Theme.Variants or {})[variant.Id]
	local color = if styling and styling.Color then styling.Color else Color3.new(1, 1, 1)
	local tint = if styling and styling.Tint then styling.Tint else 0.45
	return def.Color:Lerp(color, tint)
end

-- The colour a rarity reads as, out of the theme's palette. Here rather than in
-- either panel, because both of them ask and a rarity that looked like two
-- different things in two places would not be a rarity.
function Economy.petRarityColor(rarity: Types.PetRarity): Color3
	local palette = Config.Theme.Palette :: { [string]: Color3 }
	return palette[rarity.Tone] or palette.Text
end

-- The rarity ladder, weakest first -- the order anything listing rarities should
-- use, since Weights is a dictionary and has no order of its own.
function Economy.petRarities(): { Types.PetRarity }
	return PetBalance.Rarities :: { Types.PetRarity }
end

-- Every pet an egg could hand over, weakest rarity first. What the egg panel lists
-- so a player can see what they are paying for before they pay it.
function Economy.eggPool(egg: Types.PetEggDef): { Types.PetDef }
	local pool: { Types.PetDef } = {}
	for _, rarity in Economy.petRarities() do
		if egg.Weights[rarity.Id] then
			for _, id in Config.PetsByRarity[rarity.Id] do
				local def = Config.PetById[id]
				if def then
					table.insert(pool, def)
				end
			end
		end
	end
	return pool
end

function Economy.petPerkDef(id: string): Types.PetPerkDef?
	return Config.PetPerkById[id]
end

function Economy.eggById(id: string): Types.PetEggDef?
	for _, egg in PetBalance.Eggs :: { Types.PetEggDef } do
		if egg.Id == id then
			return egg
		end
	end
	return nil
end

function Economy.maxOwnedPets(): number
	return PetBalance.MaxOwned
end

function Economy.petsFull(data: Types.PlayerData): boolean
	return #data.Pets >= PetBalance.MaxOwned
end

-- An egg's weights with a Hatch Luck event applied: each rarer rarity multiplied
-- by `boost` once more than the one below it, the same shape Luck puts on the drop
-- pyramid. No boost, or a boost of 1, is the egg exactly as written.
local function eggWeights(egg: Types.PetEggDef, boost: number?): { [string]: number }
	local tilt = boost or 1
	if tilt == 1 then
		return egg.Weights
	end
	local weights: { [string]: number } = {}
	for rank, rarity in Economy.petRarities() do
		local weight = egg.Weights[rarity.Id]
		if weight then
			weights[rarity.Id] = weight * tilt ^ (rank - 1)
		end
	end
	return weights
end

-- What an egg can turn up, as a chance per rarity Id. The panel and the pad quote
-- this, and it is derived from the same weights the roll uses rather than written
-- out twice. `boost` is a running Hatch Luck event's strength, so the odds shown
-- during one are the odds being rolled.
function Economy.eggChances(egg: Types.PetEggDef, boost: number?): { [string]: number }
	local weights = eggWeights(egg, boost)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	local chances: { [string]: number } = {}
	if total <= 0 then
		return chances
	end
	for rarityId, weight in weights do
		chances[rarityId] = weight / total
	end
	return chances
end

-- One hatch: a rarity from the egg's weights, a pet of that rarity from the
-- theme, then a variant on top using the very same chances a drop rolls with --
-- so a Golden pet is exactly as rare as a Golden unit, and Luck tilts both.
--
-- nil when the theme has no pet for the rarity that came up, which Config has
-- already refused to let happen; the check stays because taking a player's cash
-- and returning nothing is the one outcome that must be impossible.
function Economy.rollEgg(
	egg: Types.PetEggDef,
	data: Types.PlayerData,
	bias: number?,
	rarityBoost: number?
): Types.PetRecord?
	local weights = eggWeights(egg, rarityBoost)
	local total = 0
	for _, weight in weights do
		total += weight
	end
	if total <= 0 then
		return nil
	end
	local roll = math.random() * total
	local chosen: string? = nil
	for rarityId, weight in weights do
		roll -= weight
		if roll <= 0 then
			chosen = rarityId
			break
		end
	end
	-- Floating-point drift on the last rarity.
	if not chosen then
		for rarityId in weights do
			chosen = rarityId
		end
	end
	local candidates = if chosen then Config.PetsByRarity[chosen] else nil
	if not candidates or #candidates == 0 then
		return nil
	end
	return {
		Id = candidates[math.random(#candidates)],
		Variant = Economy.randomVariant(data, bias),
	}
end

-- The starter pack --------------------------------------------------------
-- On offer for a fixed window from a player's first join, and only until they
-- have had it. Both halves are decided here, so the shop and the server reach
-- the same verdict about whether it is on sale without either asking the other.

function Economy.starterWindow(): number
	return Balance.Monetisation.StarterPack.Hours * 3600
end

-- Seconds left on the offer, or 0 if it has expired, been taken, or the player's
-- first join was never recorded.
function Economy.starterRemaining(data: Types.PlayerData, now: number?): number
	if data.StarterClaimed or data.FirstJoin <= 0 then
		return 0
	end
	return math.max(data.FirstJoin + Economy.starterWindow() - (now or os.time()), 0)
end

function Economy.starterOffered(data: Types.PlayerData, now: number?): boolean
	return Economy.starterRemaining(data, now) > 0
end

-- Drops & buying ---------------------------------------------------------

-- Capped below the top tier so a dropped item can always still merge.
function Economy.dropTier(data: Types.PlayerData): number
	return math.min(1 + Economy.upgradeLevel(data, "SpawnTier"), Config.MaxTier - 1)
end

-- The average wait between drops.
function Economy.dropInterval(data: Types.PlayerData, passMultiplier: number): number
	local drop = Balance.Drop
	local interval = drop.BaseInterval * drop.Factor ^ Economy.upgradeLevel(data, "SpawnSpeed")
	return math.max(interval * passMultiplier, drop.MinInterval)
end

-- One actual wait, scattered around the average.
function Economy.randomDropInterval(data: Types.PlayerData, passMultiplier: number): number
	local jitter = Balance.Drop.Jitter
	local spread = 1 + (math.random() * 2 - 1) * jitter
	return math.max(Economy.dropInterval(data, passMultiplier) * spread, Balance.Drop.MinInterval / 2)
end

-- How hard Luck tilts the pyramid toward its top. 0 -- the base weights -- for
-- as long as no charm is running.
function Economy.luckBias(data: Types.PlayerData, now: number?): number
	return if Economy.luckActive(data, now) then Balance.Luck.Bias else 0
end

-- Every source of luck at once: the timed charm, the permanent pass, and the
-- equipped pet's Charmed perk. Returned as the same `bias` override every
-- luck-sensitive function here already takes, so adding a third source threaded
-- nothing new through anything.
--
-- The charm and the pass are the same tilt and so are taken as the greater of the
-- two rather than summed -- a pass owner who buys a charm has wasted their gems,
-- which is why the shop refuses the sale. The pet is a separate, smaller thing
-- and adds on top.
function Economy.totalLuckBias(data: Types.PlayerData, now: number?, passOwned: boolean?): number
	local timed = Economy.luckBias(data, now)
	local pass = Economy.luckPassBias(passOwned) or 0
	return math.max(timed, pass) + Economy.petPerkValue(data, "DropLuck")
end

-- What a Drop Luck event adds to that. x2 is worth one Lucky Charm to everyone,
-- x3 two of them, and so on; 1, which is no event, adds nothing.
function Economy.eventLuckBias(strength: number): number
	return Balance.Luck.Bias * math.max(strength - 1, 0)
end

-- The tiers a drop can roll: the drop tier and the rungs below it, so an
-- upgraded garden still receives the lower tiers it needs to merge with. A
-- short window (early on, near tier 1) uses the bottom of the weight list.
function Economy.dropTierRange(data: Types.PlayerData): (number, number)
	local top = Economy.dropTier(data)
	return math.max(1, top - (#Balance.Drop.TierWeights - 1)), top
end

-- The chance of each tier in that window, lowest first. Luck multiplies every
-- rung up the pyramid by (1 + bias), so it lifts the rare top tiers steeply
-- without ever making any tier impossible to roll.
--
-- `bias` overrides the player's own: the board passes the charm's bias in to
-- quote what buying one would do, rather than what is happening now.
function Economy.dropTierChances(data: Types.PlayerData, bias: number?): { number }
	local bottom, top = Economy.dropTierRange(data)
	local weights = Balance.Drop.TierWeights
	local tilt = bias or Economy.luckBias(data)
	local chances = {}
	local total = 0
	for rung = 1, top - bottom + 1 do
		local weight = (weights[rung] or weights[#weights]) * (1 + tilt) ^ (rung - 1)
		chances[rung] = weight
		total += weight
	end
	for rung, weight in chances do
		chances[rung] = weight / total
	end
	return chances
end

-- How likely a drop is to come up as variant `position`, before anything else
-- has been rolled. Luck lifts every variant by the same (1 + bias) it puts on
-- the tier pyramid, so a charm buys better drops twice over.
--
-- `bias` overrides the player's own, so the garden board can quote what buying
-- a charm would do rather than what is happening now. `boost` multiplies it on top,
-- which is what a Variant Luck event is.
function Economy.variantChance(position: number, data: Types.PlayerData, bias: number?, boost: number?): number
	local variant = Config.Variants[position]
	if not variant then
		return 0
	end
	return math.min(variant.Chance * (1 + (bias or Economy.luckBias(data))) * (boost or 1), 1)
end

-- The chance a drop is a variant of any kind. What the board quotes, and what
-- Luck's second half is really buying.
function Economy.variantDropChance(data: Types.PlayerData, bias: number?): number
	local total = 0
	for position in Config.Variants do
		total += Economy.variantChance(position, data, bias)
	end
	return math.min(total, 1)
end

-- Rolled independently of the tier, so a variant is as likely on a low rung as
-- a high one: the prize is the variant, not the pairing. 0 is an ordinary unit,
-- which is what most drops are.
function Economy.randomVariant(data: Types.PlayerData, bias: number?, boost: number?): number
	local roll = math.random()
	local cumulative = 0
	for position in Config.Variants do
		cumulative += Economy.variantChance(position, data, bias, boost)
		if roll < cumulative then
			return position
		end
	end
	return 0
end

-- `bias` overrides the player's own, which is how the permanent charm reaches
-- the roll: the pass is worth exactly a charm that never runs out, so the server
-- passes Luck.Bias in rather than this module learning about gamepasses.
function Economy.randomDropTier(data: Types.PlayerData, bias: number?): number
	local bottom, top = Economy.dropTierRange(data)
	local roll = math.random()
	for rung, chance in Economy.dropTierChances(data, bias) do
		roll -= chance
		if roll <= 0 then
			return bottom + rung - 1
		end
	end
	-- Only reachable through floating-point drift on the last rung.
	return top
end

-- A whole drop: a tier from the pyramid, then a variant over the top of it.
-- `variantBoost` is a Variant Luck event's strength.
function Economy.randomDropIndex(data: Types.PlayerData, bias: number?, variantBoost: number?): number
	return Economy.variantIndex(Economy.randomDropTier(data, bias), Economy.randomVariant(data, bias, variantBoost))
end

-- The chance a drop rolls the very top tier, which is what Luck is really
-- buying, and what the garden board quotes.
function Economy.topTierChance(data: Types.PlayerData, bias: number?): number
	local chances = Economy.dropTierChances(data, bias)
	return chances[#chances]
end

-- Buying and binning -----------------------------------------------------

-- The base price of a tier, before the inflation from units already bought.
-- Both the buy button and the bin are priced off this, so the two can't drift
-- into a loop where binning a bought unit turns a profit.
function Economy.unitValue(index: number): number
	local tier = Economy.ladderTier(index)
	return Balance.BuyUnit.BaseCost * Balance.Income.TierGrowth ^ (tier - 1) * Economy.variantIncome(index)
end

-- `sellBonus` is added to the refund fraction, which is where a Haggler pet lands.
-- Capped below 1 whatever it adds up to: a bin that paid the full price would make
-- buying and binning a free loop, which is the thing Bin.Refund exists to prevent.
function Economy.binValue(tier: number, sellBonus: number?): number
	local refund = math.min(Balance.Bin.Refund + (sellBonus or 0), 0.95)
	return math.floor(Economy.unitValue(tier) * refund)
end

-- What a merge hands over, for a pet with the Merge Payout perk: a share of what
-- the unit that came out is worth. Measured off the result rather than the inputs
-- so it grows with the ladder the same way everything else does.
function Economy.mergePayout(index: number, strength: number): number
	if strength <= 0 then
		return 0
	end
	return math.floor(Economy.unitValue(index) * strength)
end

-- True when the carried unit can never be merged again: nothing on the ground
-- matches it, and drops have moved past its tier so no partner is coming. This
-- is the case the bin exists for.
function Economy.carriedIsStranded(data: Types.PlayerData): boolean
	if data.Carried == 0 then
		return false
	end
	-- A sparkle is never stranded: it can't be merged in the first place, and
	-- the bin won't take it either.
	local tier = Economy.ladderTier(data.Carried)
	local bottom = Economy.dropTierRange(data)
	if tier == 0 or tier >= bottom then
		return false
	end
	-- Matched on the whole index, not the rung: an ordinary tier 3 is no use to
	-- a golden one, and drops can still bring another of either.
	for _, index in data.Items do
		if index == data.Carried then
			return false
		end
	end
	return true
end

function Economy.buyUnitCost(data: Types.PlayerData): number
	local value = Economy.unitValue(Economy.dropTier(data))
	return math.floor(value * Balance.BuyUnit.Growth ^ data.UnitsBought)
end

-- Rebirth ----------------------------------------------------------------

function Economy.rebirthCost(rebirths: number): number
	return math.floor(Balance.Rebirth.BaseCost * Balance.Rebirth.Growth ^ rebirths)
end

-- The rung the garden has to reach before the next rebirth is allowed. Capped
-- below the top of the ladder, so however many rebirths deep a player gets,
-- the requirement stays something a garden can actually hold.
function Economy.rebirthTier(rebirths: number): number
	local rebirth = Balance.Rebirth
	return math.min(rebirth.BaseTier + rebirths * rebirth.TierPerRebirth, Config.MaxTier - 2)
end

-- The best rung the player has to hand: what's lying in the garden and what
-- they're carrying. A variant counts as the rung it copies, and a sparkle as
-- nothing, since it was never merged for.
function Economy.bestOwnedTier(data: Types.PlayerData): number
	local best = Economy.ladderTier(data.Carried)
	for _, index in data.Items do
		best = math.max(best, Economy.ladderTier(index))
	end
	return best
end

function Economy.rebirthTierMet(data: Types.PlayerData): boolean
	return Economy.bestOwnedTier(data) >= Economy.rebirthTier(data.Rebirths)
end

function Economy.canRebirth(data: Types.PlayerData): boolean
	return data.Cash >= Economy.rebirthCost(data.Rebirths) and Economy.rebirthTierMet(data)
end

-- Daily rewards ----------------------------------------------------------

function Economy.currentDay(now: number): number
	return now // 86400
end

-- Returns whether a claim is available and which streak day (1-based) it would be.
-- (see below for the wheel, which shares this module's day boundary)
function Economy.dailyStatus(data: Types.PlayerData, now: number): (boolean, number)
	local today = Economy.currentDay(now)
	local daily = data.Daily
	if daily.LastClaimDay == today then
		return false, daily.Streak
	end
	local continues = daily.LastClaimDay == today - 1
	local streak = if continues then daily.Streak % #Balance.DailyRewards + 1 else 1
	return true, streak
end

-- Quests -----------------------------------------------------------------
-- Three a day and one a week, each a tally of a verb the game already counts.
-- Everything here is pure: which quests a player gets is a function of their
-- id and the day, so the same three come back on a rejoin without the set
-- being stored anywhere, and the server and the panel agree without talking.

export type QuestDef = {
	Id: string,
	Text: string,
	Stat: string,
	Target: number,
	Reward: Types.Reward,
}

-- Balance is a plain table, so its quest entries infer a shape narrower than
-- QuestDef (a reward without Gems isn't the same inferred type as one with).
-- Pinned here once rather than cast at every use.
local DAILY_POOL: { QuestDef } = Balance.Quests.Daily :: any
local WEEKLY_POOL: { QuestDef } = Balance.Quests.Weekly :: any

local questById: { [string]: QuestDef } = {}
for _, quest in DAILY_POOL do
	questById[quest.Id] = quest
end
for _, quest in WEEKLY_POOL do
	questById[quest.Id] = quest
end

function Economy.currentWeek(now: number): number
	return Economy.currentDay(now) // 7
end

function Economy.questById(id: string): QuestDef?
	return questById[id]
end

-- A small deterministic generator, seeded per player per day. Roblox's Random
-- would do, but this is pure Luau arithmetic, which means the quest roll can be
-- tested outside Studio like everything else in this file.
local function nextSeed(seed: number): number
	return (seed * 1103515245 + 12345) % 2147483648
end

-- Picks `count` distinct quests out of a pool, by shuffling it. Seeded, so it
-- returns the same set every time it's asked for the same seed -- which is what
-- stops the day's quests reshuffling every time a player rejoins.
function Economy.pickQuests(seed: number, count: number, weekly: boolean): { QuestDef }
	local pool: { QuestDef } = if weekly then WEEKLY_POOL else DAILY_POOL
	local order = table.clone(pool)
	local state = nextSeed(math.abs(math.floor(seed)) % 2147483648)
	-- Fisher-Yates from the back, so every arrangement is equally likely.
	for index = #order, 2, -1 do
		state = nextSeed(state)
		local swap = state % index + 1
		order[index], order[swap] = order[swap], order[index]
	end

	local picked = {}
	for index = 1, math.min(count, #order) do
		picked[index] = order[index]
	end
	return picked
end

-- How far along a quest is, and what it needs. Progress is measured from the
-- counter's value when the quest was handed out, and clamped, so a tally that
-- was already high doesn't hand over a finished quest.
function Economy.questProgress(data: Types.PlayerData, slot: Types.QuestSlot): (number, number)
	local quest = questById[slot.Id]
	if not quest then
		return 0, 1
	end
	local done = (data.Stats[quest.Stat] or 0) - slot.Base
	return math.clamp(done, 0, quest.Target), quest.Target
end

function Economy.questComplete(data: Types.PlayerData, slot: Types.QuestSlot): boolean
	local done, target = Economy.questProgress(data, slot)
	return done >= target
end

function Economy.questClaimable(data: Types.PlayerData, slot: Types.QuestSlot): boolean
	return not slot.Claimed and Economy.questComplete(data, slot)
end

-- The weekly leaderboard race --------------------------------------------
-- The global boards rank lifetime totals, which is right for a hall of fame and
-- wrong for a prize: whoever has played longest sits at the top of them forever,
-- so paying out on one would reward seniority rather than the week. The weekly
-- board ranks what a player earned since their week turned over instead, which
-- everyone starts level on every Monday.

-- What this player has earned this week. A `Base` captured for another week is
-- stale, and reads as nothing earned yet rather than as a windfall -- rolling
-- it over is the server's job, and this has to be right before it happens.
function Economy.weeklyEarned(data: Types.PlayerData, now: number): number
	local weekly = data.Weekly
	if weekly.Week ~= Economy.currentWeek(now) then
		return 0
	end
	-- TotalEarned only ever climbs (a rebirth doesn't reset it), so the
	-- difference can't go negative unless a save has been edited underneath us.
	return math.max(data.TotalEarned - weekly.Base, 0)
end

local PRIZES: { number } = Balance.Leaderboard.Prizes

-- How many places pay. Below this the board is still worth being on; it just
-- doesn't hand over gems.
function Economy.prizePlaces(): number
	return #PRIZES
end

-- Gems for finishing in that place, or 0 for a place that doesn't pay -- which
-- includes rank 0, the "didn't place at all" a lookup returns.
function Economy.leaderboardPrize(rank: number): number
	return PRIZES[rank] or 0
end

-- Whether last week's prize is still owed. A prize is claimed during the week
-- after the one it was won in, so the week being claimed for is always behind
-- the current one.
function Economy.prizeUnclaimed(data: Types.PlayerData, week: number): boolean
	return week >= 0 and data.Weekly.PaidWeek < week
end

-- Playtime rewards --------------------------------------------------------
-- A ladder of claims through one session. Unlike quests, nothing here is
-- measured off the save: the ladder is how long the player has been in *this*
-- session, and what they have already taken from it resets when they leave.
-- So these take the elapsed seconds and the claimed flags as arguments rather
-- than PlayerData, which also means the panel and the server agree on whether
-- a rung is ready without either one asking the other.

export type PlaytimeRung = {
	Minutes: number,
	Reward: Types.Reward,
}

-- Cast for the same reason the quest pools are: Balance is a plain table, and
-- a rung whose reward has no Gems infers a narrower shape than one that does.
local PLAYTIME_RUNGS: { PlaytimeRung } = Balance.Playtime.Rungs :: any

for index = 2, #PLAYTIME_RUNGS do
	assert(
		PLAYTIME_RUNGS[index].Minutes > PLAYTIME_RUNGS[index - 1].Minutes,
		`Balance.Playtime.Rungs must climb; rung {index} is not above the one before it`
	)
end

function Economy.playtimeRungs(): { PlaytimeRung }
	return PLAYTIME_RUNGS
end

-- How long into the session this rung unlocks, in seconds.
function Economy.playtimeTarget(index: number): number
	local rung = PLAYTIME_RUNGS[index]
	return if rung then rung.Minutes * 60 else 0
end

-- Seconds waited towards this rung and what it needs, clamped so a finished row
-- reads as finished rather than as overshot.
function Economy.playtimeProgress(elapsed: number, index: number): (number, number)
	local target = Economy.playtimeTarget(index)
	if target <= 0 then
		return 0, 0
	end
	return math.clamp(math.floor(elapsed), 0, target), target
end

function Economy.playtimeReached(elapsed: number, index: number): boolean
	local target = Economy.playtimeTarget(index)
	return target > 0 and elapsed >= target
end

-- `claimed` is keyed by rung index. A rung that isn't there yet counts as
-- unclaimed, which is what makes an empty table the state of a fresh session.
function Economy.playtimeClaimable(elapsed: number, claimed: { [number]: boolean }, index: number): boolean
	return Economy.playtimeReached(elapsed, index) and not claimed[index]
end

-- How many rungs are sitting there waiting to be taken. The panel leads with it
-- and the server uses it to decide whether a session is worth interrupting.
function Economy.playtimeReadyCount(elapsed: number, claimed: { [number]: boolean }): number
	local ready = 0
	for index = 1, #PLAYTIME_RUNGS do
		if Economy.playtimeClaimable(elapsed, claimed, index) then
			ready += 1
		end
	end
	return ready
end

-- Prize wheel -------------------------------------------------------------
-- Placed after the daily section because it reuses `currentDay`, so a free
-- spin and a daily reward roll over at the same moment.

function Economy.spinCost(): number
	return Balance.Wheel.GemCost
end

function Economy.freeSpinAvailable(data: Types.PlayerData, now: number): boolean
	return data.LastFreeSpinDay ~= Economy.currentDay(now)
end

-- Free spin included, so the UI can show one number.
function Economy.spinsAvailable(data: Types.PlayerData, now: number): number
	return data.Spins + (if Economy.freeSpinAvailable(data, now) then Balance.Wheel.FreeSpinsPerDay else 0)
end

function Economy.prizeChance(index: number): number
	local total = 0
	for _, prize in Balance.Wheel.Prizes do
		total += prize.Weight
	end
	return Balance.Wheel.Prizes[index].Weight / total
end

-- Picks a prize by weight and returns its index into Balance.Wheel.Prizes.
function Economy.rollPrize(): number
	local prizes = Balance.Wheel.Prizes
	local total = 0
	for _, prize in prizes do
		total += prize.Weight
	end
	local roll = math.random() * total
	for index, prize in prizes do
		roll -= prize.Weight
		if roll <= 0 then
			return index
		end
	end
	-- Only reachable through floating-point drift on the last prize.
	return #prizes
end

-- Crafting station --------------------------------------------------------
-- Pure odds, so the panel can show the player exactly what the server will
-- roll. Every outcome is a unit index, and the chances always add up to 1.

export type CraftOutcome = {
	Index: number,
	Chance: number,
	Sparkle: boolean,
}

-- Units one craft takes. Unchanged by anything a player can buy: the pass sells
-- a second craft, not a bigger one, so the odds a load reaches are the same for
-- everyone and nothing about the sparkle ceiling has to be re-balanced.
function Economy.craftInputs(): number
	return Balance.Craft.Inputs
end

-- Crafts a player can have running at once. `extra` is the Second Slot pass.
function Economy.craftSlots(extra: number?): number
	return Balance.Craft.Slots + (extra or 0)
end

-- The most any player could have, which is how long the saved list is kept. Held
-- at full length rather than grown on demand so nothing has to create a slot
-- mid-purchase, and so a slot loaded while the pass was owned is still there --
-- untouched, not emptied -- if the pass ever goes away.
function Economy.maxCraftSlots(): number
	return Balance.Craft.Slots + Balance.Monetisation.ExtraCraftSlots
end

-- The craft in a slot, or nil for a slot index that doesn't exist. Callers take
-- the nil rather than being handed an empty craft, because "no such slot" and
-- "an empty slot" have to produce different answers on the wire: one is a player
-- without the pass, the other is a player with it who hasn't loaded it yet.
function Economy.craftAt(data: Types.PlayerData, slot: number): Types.CraftState?
	return data.Craft[slot]
end

function Economy.craftSeconds(): number
	return Balance.Craft.Seconds
end

-- The highest ordinary tier in the machine. Everything about a craft is
-- measured from this: which sparkle is in play, and what comes out instead.
local function highestInput(inputs: { number }): number
	local highest = 0
	for _, index in inputs do
		highest = math.max(highest, Economy.ladderTier(index))
	end
	return highest
end

-- What the variants in a load are worth to it. Every variant input multiplies
-- the ceiling on the sparkle chance, so feeding a rare one in is worth
-- something even to a machine already filled with the band's top tier -- which
-- is the whole point of letting variants in here.
-- `petBoost` is added on top of whatever the variants in the load are worth, which
-- is what a Lucky Crafter pet contributes. Added rather than multiplied because it
-- has to be worth something to an ordinary load -- a multiplier on a boost of 1 is
-- a boost of 1.
function Economy.craftBoost(inputs: { number }, petBoost: number?): number
	local boost = 1 + (petBoost or 0)
	for _, index in inputs do
		local variant = Economy.variantAt(index)
		if variant then
			boost *= variant.CraftBoost
		end
	end
	return boost
end

-- Which sparkle a load is playing for: the one whose band holds the best unit
-- in the machine. Padding a high band with low-tier fodder still plays for the
-- high sparkle, and the odds below take care of how badly.
function Economy.craftSparkleIndex(inputs: { number }): number?
	local highest = highestInput(inputs)
	if highest == 0 then
		return nil
	end
	for position, sparkle in Config.Sparkles do
		if highest >= sparkle.Band[1] and highest <= sparkle.Band[2] then
			return Economy.sparkleIndex(position)
		end
	end
	return nil
end

-- How close a load is to the best one that band can be given: every slot
-- filled with the band's top tier. A unit below the band still counts, just
-- fractionally, which is what makes topping up with fodder barely move it.
function Economy.craftProgress(inputs: { number }, sparkle: Types.SparkleDef): number
	local craft = Balance.Craft
	local bottom, top = sparkle.Band[1], sparkle.Band[2]
	local best = craft.Inputs * craft.TierWeight ^ (top - bottom)
	local total = 0
	for _, index in inputs do
		total += craft.TierWeight ^ (Economy.ladderTier(index) - bottom)
	end
	return math.clamp(total / best, 0, 1)
end

-- The best odds this load could reach, variants included. Raising the ceiling
-- rather than the chance is what makes a variant worth feeding to a machine
-- that's already full of the band's top tier.
--
-- The boost closes a share of the gap between this sparkle's own ceiling and
-- the hard cap, rather than multiplying the ceiling outright. Multiplying looks
-- simpler and behaves badly: the bottom band's ceiling is already 0.5, so a
-- single Golden would hit the cap on its own, and after that a Rainbow and a
-- full machine of Rainbows would all be worth exactly the same. Closing the gap
-- keeps every rung of the variant ladder distinguishable, keeps stacking worth
-- something, and approaches the cap without ever reaching it -- because a
-- sparkle you're guaranteed isn't a sparkle.
function Economy.craftCeiling(inputs: { number }, sparkle: Types.SparkleDef, petBoost: number?): number
	local craft = Balance.Craft
	local base = sparkle.MaxChance or craft.MaxChance
	local boost = Economy.craftBoost(inputs, petBoost)
	if boost <= 1 or base >= craft.HardCap then
		return base
	end
	return base + (craft.HardCap - base) * (1 - 1 / boost)
end

function Economy.craftSparkleChance(inputs: { number }, sparkle: Types.SparkleDef, petBoost: number?): number
	local craft = Balance.Craft
	local ceiling = Economy.craftCeiling(inputs, sparkle, petBoost)
	local progress = Economy.craftProgress(inputs, sparkle)
	return math.min(craft.MinChance + (ceiling - craft.MinChance) * progress ^ craft.Curve, ceiling)
end

-- The sparkle first, then the ordinary units that share out the rest. An empty
-- machine has no outcomes at all.
function Economy.craftOutcomes(inputs: { number }, petBoost: number?): { CraftOutcome }
	local outcomes: { CraftOutcome } = {}
	local highest = highestInput(inputs)
	if highest == 0 then
		return outcomes
	end

	local sparkleChance = 0
	local sparkleIndex = Economy.craftSparkleIndex(inputs)
	if sparkleIndex then
		local sparkle = Economy.sparkleAt(sparkleIndex) :: Types.SparkleDef
		sparkleChance = Economy.craftSparkleChance(inputs, sparkle, petBoost)
		table.insert(outcomes, { Index = sparkleIndex, Chance = sparkleChance, Sparkle = true })
	end

	-- Near the top of the ladder both consolations clamp to the same tier, so
	-- they're accumulated by index rather than listed twice.
	local remaining = 1 - sparkleChance
	local shareTotal = 0
	for _, entry in Balance.Craft.Consolation do
		shareTotal += entry.Share
	end
	local chanceByIndex: { [number]: number } = {}
	local order: { number } = {}
	for _, entry in Balance.Craft.Consolation do
		local index = math.min(highest + entry.Tiers, Config.MaxTier)
		if not chanceByIndex[index] then
			chanceByIndex[index] = 0
			table.insert(order, index)
		end
		chanceByIndex[index] += remaining * entry.Share / shareTotal
	end
	for _, index in order do
		table.insert(outcomes, { Index = index, Chance = chanceByIndex[index], Sparkle = false })
	end
	return outcomes
end

-- Picks one outcome by its chance and returns the unit index, or 0 for a load
-- with nothing in it.
function Economy.rollCraft(inputs: { number }, petBoost: number?): number
	local outcomes = Economy.craftOutcomes(inputs, petBoost)
	if #outcomes == 0 then
		return 0
	end
	local roll = math.random()
	for _, outcome in outcomes do
		roll -= outcome.Chance
		if roll <= 0 then
			return outcome.Index
		end
	end
	-- Only reachable through floating-point drift on the last outcome.
	return outcomes[#outcomes].Index
end

-- These take one craft rather than the player, because with two slots there is
-- no longer a single answer to "is the machine running". Whoever asks has to say
-- which one they mean -- and the two loops that care about either of them use
-- the slot-finding helpers below.
function Economy.craftRunning(craft: Types.CraftState): boolean
	return craft.EndsAt > 0
end

function Economy.craftRemaining(craft: Types.CraftState, now: number?): number
	if not Economy.craftRunning(craft) then
		return 0
	end
	return math.max(craft.EndsAt - (now or os.time()), 0)
end

function Economy.craftReady(craft: Types.CraftState, now: number?): boolean
	return Economy.craftRunning(craft) and Economy.craftRemaining(craft, now) <= 0
end

-- Gems to finish a craft now, by the hours still to wait. Always at least one,
-- so the button never reads as free.
function Economy.craftSkipCost(craft: Types.CraftState, now: number?): number
	local hours = math.ceil(Economy.craftRemaining(craft, now) / 3600)
	return math.max(hours * Balance.Craft.SkipGemsPerHour, 1)
end

-- The first slot with something waiting in it, within the `slots` the player
-- actually has. `slots` is passed rather than assumed so a craft parked in a
-- second slot the player no longer has access to is never announced as ready --
-- it would be a toast about a button they cannot press.
function Economy.readyCraftSlot(data: Types.PlayerData, now: number?, slots: number): number?
	for slot = 1, math.min(slots, #data.Craft) do
		if Economy.craftReady(data.Craft[slot], now) then
			return slot
		end
	end
	return nil
end

-- The first slot that could take a unit right now: empty, or part-loaded and not
-- yet started. What the panel opens on, and what the machine's prompt loads.
function Economy.openCraftSlot(data: Types.PlayerData, slots: number): number?
	for slot = 1, math.min(slots, #data.Craft) do
		local craft = data.Craft[slot]
		if not Economy.craftRunning(craft) and #craft.Inputs < Economy.craftInputs() then
			return slot
		end
	end
	return nil
end

return Economy
