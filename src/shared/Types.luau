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
	},
	Icons: {
		Currency: string?,
	},
	Font: Font,
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
	-- Optional partial overrides of Shared/Balance, deep-merged over the defaults.
	Balance: { [string]: any }?,
}

export type DailyState = {
	Streak: number,
	LastClaimDay: number,
}

export type PlayerData = {
	Cash: number,
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
	-- Recent developer product receipt IDs, so a retried receipt is never granted twice.
	PurchaseIds: { string },
}

-- A bundle of rewards (daily rewards, dev products). Cash is "minutes of the
-- player's current income", floored at MinCash.
export type Reward = {
	IncomeMinutes: number?,
	MinCash: number?,
	UnitTierBonus: number?,
}

return nil
