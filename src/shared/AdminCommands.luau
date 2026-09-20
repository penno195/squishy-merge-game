--!strict
-- What the admin panel can do. Shared, so the panel draws exactly the commands
-- the server will accept and the server checks against the same numbers the
-- panel shows.
--
-- The set is the one troll-admin passes in other games have settled on -- fling,
-- freeze, jail, rocket, resize, ragdoll -- plus a couple that only make sense
-- here: being flattened by a giant squishy, and a rain of them. Two things the
-- genre usually sells are left out on purpose:
--
--   * Anything that touches progress. No stealing cash, deleting units, taking a
--     garden or kicking. Every effect wears off by itself in seconds, and nothing
--     here can reach a player's saved data. Being trolled is part of the fun of a
--     server with an admin in it; losing an hour of merging to someone who paid
--     for the privilege is a reason to leave the game and report it.
--   * Flashbangs and screen-flash jumpscares. Rapid flashing is a photosensitivity
--     hazard, and nothing here is worth that.
--
-- Two rules keep one admin from ruining a server: a cooldown between an admin's
-- own commands, and a spell of protection for anyone just hit, so the same player
-- can't be chain-frozen for a whole session.

export type Target = "Player" | "Self" | "Everyone"

export type Command = {
	Id: string,
	Name: string,
	Icon: string,
	-- One short line, shown under the button.
	Description: string,
	Target: Target,
	-- How long it lasts. Zero for a single shove that wears off on its own.
	Seconds: number,
}

local AdminCommands = {}

-- Between any two commands from the same admin. Staff are exempt -- the checks
-- in AdminService that hold an admin back are there to stop a paying player
-- pinning someone down, which is not what a staff member running an event is
-- doing.
AdminCommands.Cooldown = 6
-- How long a player is left alone after a command lands on them, counted from the
-- moment it lands. Longer than every effect, so there is always a gap between one
-- wearing off and the next.
AdminCommands.Protection = 15
-- Between everyone-commands, per server rather than per admin, so two admins in
-- one server can't keep it raining between them.
AdminCommands.EveryoneCooldown = 60

AdminCommands.List = {
	-- On another player.
	{
		Id = "Squish",
		Name = "Squish",
		Icon = "🥞",
		Description = "A giant squishy lands on them",
		Target = "Player",
		Seconds = 6,
	},
	{
		Id = "Freeze",
		Name = "Freeze",
		Icon = "🧊",
		Description = "Frozen solid in a block of ice",
		Target = "Player",
		Seconds = 6,
	},
	{
		Id = "Jail",
		Name = "Jail",
		Icon = "⛓️",
		Description = "Locked in a glass cage",
		Target = "Player",
		Seconds = 8,
	},
	{
		Id = "Fling",
		Name = "Fling",
		Icon = "🌀",
		Description = "Sent spinning across the map",
		Target = "Player",
		Seconds = 0,
	},
	{
		Id = "Rocket",
		Name = "Rocket",
		Icon = "🚀",
		Description = "Blasted into the sky",
		Target = "Player",
		Seconds = 3,
	},
	{
		Id = "Trip",
		Name = "Trip",
		Icon = "🍌",
		Description = "Falls flat on their face",
		Target = "Player",
		Seconds = 3,
	},
	{
		Id = "Tiny",
		Name = "Tiny",
		Icon = "🐜",
		Description = "Shrunk to a fraction of their size",
		Target = "Player",
		Seconds = 10,
	},
	{
		Id = "Sticky",
		Name = "Sticky",
		Icon = "🍯",
		Description = "Stuck in goo, barely able to walk",
		Target = "Player",
		Seconds = 8,
	},
	-- On yourself.
	{ Id = "Speed", Name = "Speed", Icon = "👟", Description = "Run much faster", Target = "Self", Seconds = 30 },
	{
		Id = "SuperJump",
		Name = "Super Jump",
		Icon = "🦘",
		Description = "Jump over anything",
		Target = "Self",
		Seconds = 30,
	},
	{ Id = "Giant", Name = "Giant", Icon = "🦖", Description = "Grow huge", Target = "Self", Seconds = 30 },
	-- On the whole server.
	{
		Id = "Rain",
		Name = "Squishy Rain",
		Icon = "🌧️",
		Description = "It rains squishies on everyone",
		Target = "Everyone",
		Seconds = 10,
	},
} :: { Command }

-- How strong each effect is, beside the list rather than in it so the list stays
-- readable as a menu.
AdminCommands.TinyScale = 0.35
AdminCommands.GiantScale = 2.5
-- Squish flattens: tall scale down, the other two up, like a squishy pressed flat.
AdminCommands.SquishHeight = 0.25
AdminCommands.SquishSpread = 1.4
AdminCommands.StickySpeed = 4
AdminCommands.SpeedMultiplier = 2.5
AdminCommands.JumpMultiplier = 3

AdminCommands.ById = {} :: { [string]: Command }
for _, command in AdminCommands.List do
	AdminCommands.ById[command.Id] = command
end

return AdminCommands
