--!strict
-- Shared type definitions. Every theme in Shared/Themes must satisfy `Theme`;
-- saved player data follows `PlayerData`.

export type UnitDef = {
	Name: string,
	Color: Color3,
	-- Name of a Model under ReplicatedStorage.ThemeAssets.Units. When nil or not
	-- found, a procedural squishy blob in `Color` is built instead.
	Model: string?,
	-- Size of a supplied `Model`, off whatever it was modelled at. Left unset,
	-- a model with a "Body" part is sized as wide as the blob it replaces.
	Scale: number?,
	-- Namesake features built onto the procedural blob, from the vocabulary in
	-- UnitVisuals.Features: "CatEars", "Snout", "Tail" and so on. A supplied
	-- `Model` wears them only if it publishes its outline (see UnitVisuals);
	-- otherwise it goes without. An unknown name is warned about and skipped,
	-- so a typo costs one unit's ears rather than the game.
	Features: { string }?,
	-- Set by Config on the units it appends for the theme's sparkles, so the
	-- visuals know to build a glowing one. Themes don't set this.
	Sparkle: boolean?,
	-- Also set by Config, not by themes. `Tier` is the rung on the merge ladder
	-- this entry sits on -- the same for a unit and every variant of it, and
	-- absent on a sparkle, which sits off the end of the ladder. `Variant` is
	-- the position in Balance.Variants, absent on an ordinary unit. Between
	-- them, anything holding a unit index knows what it's looking at without
	-- doing arithmetic on the index.
	Tier: number?,
	Variant: number?,
	Shine: boolean?,
}

-- One rung of the variant ladder in Balance.Variants: the mechanics half,
-- shared by every theme. The look of it is VariantDef below, which a theme
-- supplies and which is keyed by this Id.
export type VariantRung = {
	Id: string,
	-- Chance a drop rolls this variant, before Luck tilts it.
	Chance: number,
	-- What it multiplies income and sale value by.
	Income: number,
	-- What it multiplies the ceiling on a craft's sparkle chance by, when one
	-- is fed into the machine.
	CraftBoost: number,
	-- What it multiplies a pet's perk by. Far smaller than `Income`, and on
	-- purpose: a variant unit earning sixty times as much is a jackpot, where a
	-- variant pet is the same pet doing its one job better. A Rainbow pet that
	-- were sixty times as good would end the switching the whole system is for.
	PetPerk: number,
}

-- How a theme dresses one of the variants in Balance.Variants. Every field is
-- optional: a variant the theme says nothing about still drops, named after its
-- Id and tinted toward white, so variants work in a skin nobody has styled yet.
export type VariantDef = {
	-- Goes in front of the unit's own name: "Golden Gummy Bear".
	Prefix: string?,
	-- Blended over the unit's own colour, so a variant reads as the same unit
	-- rather than a different one. `Tint` is how much of it to mix in.
	Color: Color3?,
	Tint: number?,
	-- Lit from inside with a drift of glitter, the way sparkles are. Worth
	-- saving for the rarest one or two: on everything it stops meaning much.
	Shine: boolean?,
}

-- A limited-edition unit, made at the crafting station and never dropped or
-- merged. `Band` is the range of ordinary tiers that can be fed in to play for
-- it: feeding the top of that band, and filling every slot, is what takes the
-- odds up to `MaxChance`.
export type SparkleDef = {
	Id: string,
	Name: string,
	Color: Color3,
	Model: string?,
	Scale: number?,
	Band: { number },
	-- Permanent share added to the player's cash multiplier while this one is
	-- lying in their garden. 0.1 is "+10% of everything, forever".
	Bonus: number,
	-- Best odds this one can ever be crafted at. Later bands set this lower, so
	-- the deeper sparkles stay rarer. Defaults to Balance.Craft.MaxChance.
	MaxChance: number?,
}

-- One pet a theme offers. Everything mechanical about it is a name pointing into
-- Balance.Pets -- which rarity band it sits in, and which perk it carries -- so a
-- reskin names and dresses pets without balancing any of them. Same fallback deal
-- as UnitDef: with no `Model` it's built as a procedural blob in `Color`, wearing
-- whatever `Features` it names from the UnitVisuals vocabulary.
export type PetDef = {
	Id: string,
	Name: string,
	Color: Color3,
	Model: string?,
	Scale: number?,
	Features: { string }?,
	-- Ids from Balance.Pets.Rarities and Balance.Pets.Perks.
	Rarity: string,
	Perk: string,
}

-- One rung of the rarity ladder in Balance.Pets.Rarities: how often an egg turns
-- one up, what it multiplies cash by, and how hard its perk hits.
export type PetRarity = {
	Id: string,
	Name: string,
	-- No weight of its own: how often a rarity turns up is the egg's business, so
	-- that number lives in PetEggDef.Weights and only there. A ladder that also
	-- carried a weight would be two answers to one question.
	-- Deliberately a narrow band across the whole ladder. Pets are a help, not
	-- the way the game is progressed, and a rare pet that paid ten times as much
	-- would be equipped forever whatever its perk said.
	Multiplier: number,
	-- Scales the perk's own Amount. This is where rarity is allowed to matter.
	Perk: number,
	-- Names a Palette entry, so a rarity reads as a colour everywhere it appears --
	-- the chip on an inventory row, the odds in the egg panel. The theme's palette
	-- rather than fixed colours, so a skin's rarest pet is its own accent.
	Tone: string,
}

-- What a perk does, and how much of it one unit of strength is worth. The Id is
-- read by the code that applies it, so adding a perk means adding a case there --
-- a theme can only choose among the ones that exist.
export type PetPerkDef = {
	Id: string,
	Name: string,
	-- Filled into `Name` and the panel's description. One line, present tense.
	Description: string,
	-- Meaning depends on the Id, and is documented per perk in Balance.Pets.
	Amount: number,
}

-- An egg on a pad in the hub: what it costs and which rarities it can turn up.
-- `Weights` overrides the rarity ladder's own weights by Id; anything it leaves
-- out cannot come out of that egg at all, which is what makes a dearer egg worth
-- standing at.
export type PetEggDef = {
	Id: string,
	Name: string,
	Cost: number,
	Weights: { [string]: number },
	-- Names a Palette entry, so the pad in the hub is coloured by the theme --
	-- the same trick the wheel's prizes use.
	Tone: string,
}

-- A pet the player owns. `Variant` is a position in Balance.Variants, or 0 for an
-- ordinary one -- the same numbering units use, so a Golden pet is dressed by the
-- theme's existing Variants styling with nothing new to configure.
export type PetRecord = {
	Id: string,
	Variant: number,
}

-- A piece of scenery. Same deal as UnitDef: a theme can point at a real model,
-- and anything it doesn't supply is built from parts in the theme's colours, so
-- a new skin looks right before any asset exists for it.
export type PropDef = {
	-- Name of a Model under ReplicatedStorage.ThemeAssets.Props. When nil or not
	-- found, `Shape` is built instead.
	Model: string?,
	-- One of the shapes PropVisuals knows: Cane, Lollipop, Cone, Stack, Sphere.
	Shape: string?,
	Color: Color3,
	-- Second colour, for stripes and trim. Defaults to white.
	Accent: Color3?,
	-- Studs tall. A supplied model is sized to it too, unless it sets `Scale`,
	-- which wins.
	Height: number?,
	Scale: number?,
	-- Squashes on the spot like a unit in the garden. Supplied models only: a
	-- built shape is made of balls and cylinders, which can't be stretched
	-- unevenly.
	Squish: boolean?,
}

-- The big top over the hub, if the theme wants one. Where it stands and how big
-- it is is Balance.Canopy's business; this is only what it is made of. A theme
-- that leaves this out gets a hub open to the sky, and nothing else changes.
export type CanopyDef = {
	-- The two colours the roof's gores alternate between.
	Stripe: Color3,
	StripeAlt: Color3,
	-- The poles, banded in these two the way a stick of rock is.
	Pole: Color3,
	PoleBand: Color3,
	-- The hem under the eaves, the crown the panels meet at, the spire, and the
	-- cord the bulbs hang from.
	Trim: Color3,
	-- Bulbs on the strings between the poles, taken in turn. An empty list
	-- leaves the poles unstrung.
	Bulbs: { Color3 },
	-- The pennants on the poles and the spire. Unset uses Trim.
	Flag: Color3?,
}

export type Palette = {
	Primary: Color3,
	Secondary: Color3,
	Accent: Color3,
	Background: Color3,
	Surface: Color3,
	Text: Color3,
	TextMuted: Color3,
	Positive: Color3,
	Negative: Color3,
}

export type Theme = {
	Id: string,
	DisplayName: string,
	-- Words the UI uses, so a reskin can call cash "Goo" or rebirths "Evolve".
	Text: {
		Currency: string,
		Unit: string,
		UnitPlural: string,
		Rebirth: string,
		Bin: string,
		-- The crafting station in the hub, and what it makes.
		Machine: string,
		Sparkle: string,
		SparklePlural: string,
	},
	-- Short glyphs (emoji work) shown beside stats and on upgrade tiles.
	Icons: {
		Currency: string?,
		Gems: string?,
		Boost: string?,
		SpawnTier: string?,
		SpawnSpeed: string?,
		GardenSpace: string?,
		Luck: string?,
		AutoMerge: string?,
		Income: string?,
		Craft: string?,
	},
	Font: Font,
	-- Optional artwork. Anything left unset is drawn from the palette instead,
	-- so a theme works with no uploaded assets at all.
	Images: {
		-- Face of the prize wheel. Must be a circle divided into as many equal
		-- segments as Balance.Wheel.Prizes, with segment 1 centred at the top.
		Wheel: string?,
		-- Tiled behind the contents of a patterned card. Must be a square that
		-- tiles seamlessly -- a two-tone checker is the usual one. Left unset,
		-- the checker is built from parts of the card's own colour instead, so
		-- a theme gets the pattern with no uploaded asset at all.
		CardPattern: string?,
	}?,
	Palette: Palette,
	World: {
		-- Ground outside the gardens; PlotBase is the garden floor itself.
		Ground: Color3,
		GroundMaterial: Enum.Material,
		PlotBase: Color3,
		PlotMaterial: Enum.Material,
		Fence: Color3,
		FenceMaterial: Enum.Material,
		-- The second colour of a candy-cane fence: rails are banded between this
		-- and `Fence`, and the posts alternate between them. Unset leaves the
		-- fence one colour and one part per rail.
		FenceStripe: Color3?,
		Border: Color3,
		-- The hub pad and the moving walkway ringing it.
		Hub: Color3,
		Path: Color3,
		PathMaterial: Enum.Material,
		-- Cobbles strewn over the paths, taken at random. `Path` stays as the
		-- slab under them, so it reads as the mortar between. Unset or empty
		-- leaves the paths plain.
		PathStones: { Color3 }?,
	},
	Sounds: {
		Merge: string?,
		Spawn: string?,
		Purchase: string?,
		Rebirth: string?,
		Error: string?,
		Music: string?,
		-- Looped for as long as the Taco Rain event runs. Unset, it rains in silence.
		TacoRain: string?,
	},
	-- A catalogue Model the Taco Rain event drops instead of the taco built out of
	-- parts in code. Unset or 0 uses the built one. Fetched once per server, and
	-- stripped of everything that isn't geometry first (TacoService).
	TacoRainModel: number?,
	-- Index = tier. Tier 1 spawns first; merging two tier N units makes tier N + 1.
	Units: { UnitDef },
	-- A Model under ReplicatedStorage.ThemeAssets.Units that every unit, sparkle
	-- and pet is built from unless it names a `Model` of its own -- for a skin
	-- whose whole cast is one body in different colours. Each is tinted to its
	-- own `Color`, and wears its `Features` if the model publishes an outline
	-- (see UnitVisuals). Left unset, anything without a Model is a blob.
	CreatureModel: string?,
	-- The crafting station's prizes, lowest band first. A theme with none still
	-- gets a working machine: it just trades units up a few tiers.
	Sparkles: { SparkleDef }?,
	-- How this skin dresses the variants in Balance.Variants, keyed by their
	-- Ids. Anything left out falls back to a default, so this table is optional
	-- in whole and in part.
	Variants: { [string]: VariantDef }?,
	-- The pets this skin offers, in no particular order -- which egg can turn one
	-- up is decided by its Rarity, not by its place here. A theme with no Pets
	-- still works: the egg pads simply aren't built.
	Pets: { PetDef }?,
	-- The big top over the hub. Nil leaves the hub open to the sky.
	Canopy: CanopyDef?,
	-- Scenery, keyed by the zone Ids in Balance.PropZones. Each slot in a zone
	-- picks one of that zone's entries at random. A zone the theme says nothing
	-- about is left bare, and a theme with no Props at all dresses no scenery.
	Props: { [string]: { PropDef } }?,
	-- Optional partial overrides of Shared/Balance, deep-merged over the defaults.
	Balance: { [string]: any }?,
}

export type DailyState = {
	Streak: number,
	LastClaimDay: number,
}

-- What's loaded into the crafting station. Inputs sit there until the craft is
-- started, and are locked in once it is. EndsAt is os.time(), not game time, so
-- a craft runs down while the player is away -- which is the whole point of it.
-- One craft. A player has `Economy.craftSlots` of these -- one by default, and
-- a second with the pass -- each with its own load and its own clock, so two can
-- run side by side without either waiting for the other.
export type CraftState = {
	Inputs: { number },
	EndsAt: number,
}

-- One quest as it was handed out. `Base` is where its counter stood at the
-- time, so progress is the counter now minus that -- which means a quest can
-- be measured off a tally that was already running without ever crediting the
-- player for work they did before it was set.
export type QuestSlot = {
	Id: string,
	Base: number,
	Claimed: boolean,
	Weekly: boolean,
}

export type QuestState = {
	-- The day the dailies were handed out, and the week the weekly was. Both
	-- are the boundaries Economy.currentDay/currentWeek return.
	Day: number,
	Week: number,
	-- Dailies and the weekly in one list, so the panel renders one thing.
	Active: { QuestSlot },
}

-- The weekly leaderboard race. The board ranks what a player earned *this*
-- week, which is TotalEarned now minus where it stood when their week turned
-- over -- so the race resets without anything being wiped.
export type WeeklyState = {
	-- The week `Base` was captured for, as Economy.currentWeek returns it. A
	-- week other than the current one means `Base` is stale and earnings this
	-- week are nothing yet.
	Week: number,
	Base: number,
	-- The last week whose prize was collected. Kept so a prize is paid once,
	-- and kept separately from `Week` because a prize is claimed during the
	-- week *after* the one it was won in.
	PaidWeek: number,
}

export type PlayerData = {
	Cash: number,
	-- Premium currency, spent only on the timed earning boost.
	Gems: number,
	-- os.time() the earning boost and the luck charm run out; 0 when they have
	-- never been bought. Real time, so neither pauses while the player is away.
	BoostEndsAt: number,
	LuckEndsAt: number,
	-- When the gem-bought auto merge stops. The pass doesn't use this: it never does.
	AutoMergeEndsAt: number,
	-- Tiers of the items lying in the garden. These earn income; order is not meaningful.
	Items: { number },
	-- Tier the player is carrying, or 0 for empty-handed. Carried items don't earn.
	Carried: number,
	Upgrades: { [string]: number },
	UnitsBought: number,
	Rebirths: number,
	TotalEarned: number,
	HighestTier: number,
	LastOnline: number,
	-- os.time() this player first loaded, which is what the starter pack's offer
	-- window counts from. 0 for a save written before the field existed; set on
	-- the first load that finds it 0.
	FirstJoin: number,
	-- Whether the starter pack has been handed over. The pass is what is bought,
	-- and this is what stops it being granted again on every join.
	StarterClaimed: boolean,
	-- Pets owned, in the order they hatched, and which one is at the player's
	-- heels as an index into it. 0 is none equipped, which is also what a
	-- player who releases the pet they had ends up with.
	Pets: { PetRecord },
	EquippedPet: number,
	Daily: DailyState,
	-- Wheel spins bought with gems, and the day the last free spin was taken.
	Spins: number,
	LastFreeSpinDay: number,
	-- Recent developer product receipt IDs, so a retried receipt is never granted twice.
	PurchaseIds: { string },
	-- Indexed by craft slot. Slots past what the player has access to are never
	-- written to, so losing the pass leaves a loaded second slot parked rather
	-- than destroying what is in it.
	Craft: { CraftState },
	-- How many of each sparkle the player has ever made, keyed by SparkleDef.Id.
	-- The collection record: what's in the garden can change, this can't.
	Sparkles: { [string]: number },
	-- Every unit index the player has ever held, keyed by tostring(index).
	-- `HighestTier` is the merge ladder alone; this covers what sits off it,
	-- which is what the index needs now that variants exist. Keys are strings
	-- because a map with number keys does not survive a round trip through a
	-- DataStore -- it comes back keyed by strings whatever it went in as.
	Discovered: { [string]: boolean },
	-- Lifetime tallies of the verbs, keyed by the ActionService action that
	-- counts toward them. Written by StatsService and read by anything that
	-- asks "how many times has this player ever...".
	Stats: { [string]: number },
	-- Seconds played across every session.
	Playtime: number,
	-- Redeemable codes already used, keyed by the code in upper case.
	Codes: { [string]: boolean },
	-- How far through the tutorial the player got. 0 is "hasn't started".
	Tutorial: number,
	Quests: QuestState,
	Weekly: WeeklyState,
}

-- A bundle of rewards (daily rewards, dev products). Cash is "minutes of the
-- player's current income", floored at MinCash.
export type Reward = {
	IncomeMinutes: number?,
	MinCash: number?,
	UnitTierBonus: number?,
	Gems: number?,
}

export type WheelPrize = {
	Label: string,
	Weight: number,
	-- Names a Palette entry, so the theme colours the wheel.
	Tone: string,
	Reward: Reward,
}

return nil
