--!strict
-- Shared type definitions. Every theme in Shared/Themes must satisfy `Theme`;
-- saved player data follows `PlayerData`.

export type UnitDef = {
	Name: string,
	Color: Color3,
	-- Name of a Model under ReplicatedStorage.ThemeAssets.Units. When nil or not
	-- found, a procedural squishy blob in `Color` is built instead.
	Model: string?,
	Scale: number?,
	-- Namesake features built onto the procedural blob, from the vocabulary in
	-- UnitVisuals.Features: "CatEars", "Snout", "Tail" and so on. A unit with a
	-- supplied `Model` ignores them -- the model is already the artwork. An
	-- unknown name is warned about and skipped, so a typo costs one unit's ears
	-- rather than the game.
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
	-- Studs tall. Ignored by supplied models, which use `Scale` instead.
	Height: number?,
	Scale: number?,
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
		Border: Color3,
		-- The hub pad and the moving walkway ringing it.
		Hub: Color3,
		Path: Color3,
		PathMaterial: Enum.Material,
	},
	Sounds: {
		Merge: string?,
		Spawn: string?,
		Purchase: string?,
		Rebirth: string?,
		Error: string?,
		Music: string?,
	},
	-- Index = tier. Tier 1 spawns first; merging two tier N units makes tier N + 1.
	Units: { UnitDef },
	-- The crafting station's prizes, lowest band first. A theme with none still
	-- gets a working machine: it just trades units up a few tiers.
	Sparkles: { SparkleDef }?,
	-- How this skin dresses the variants in Balance.Variants, keyed by their
	-- Ids. Anything left out falls back to a default, so this table is optional
	-- in whole and in part.
	Variants: { [string]: VariantDef }?,
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

export type PlayerData = {
	Cash: number,
	-- Premium currency, spent only on the timed earning boost.
	Gems: number,
	-- os.time() the earning boost and the luck charm run out; 0 when they have
	-- never been bought. Real time, so neither pauses while the player is away.
	BoostEndsAt: number,
	LuckEndsAt: number,
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
	Daily: DailyState,
	-- Wheel spins bought with gems, and the day the last free spin was taken.
	Spins: number,
	LastFreeSpinDay: number,
	-- Recent developer product receipt IDs, so a retried receipt is never granted twice.
	PurchaseIds: { string },
	Craft: CraftState,
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
