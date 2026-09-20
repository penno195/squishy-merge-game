--!strict
-- Server entry point: starts the services and wires the player lifecycle.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)

local Services = script.Parent.Services

local AdminService = require(Services.AdminService)
local AnalyticsService = require(Services.AnalyticsService)
local CanopyService = require(Services.CanopyService)
local CraftService = require(Services.CraftService)
local DailyService = require(Services.DailyService)
local DataService = require(Services.DataService)
local EventService = require(Services.EventService)
local GameplayService = require(Services.GameplayService)
local GardenService = require(Services.GardenService)
local HubService = require(Services.HubService)
local ItemService = require(Services.ItemService)
local LeaderboardService = require(Services.LeaderboardService)
local PassService = require(Services.PassService)
local PetService = require(Services.PetService)
local PlaytimeService = require(Services.PlaytimeService)
local PlinthService = require(Services.PlinthService)
local ProductService = require(Services.ProductService)
local QuestService = require(Services.QuestService)
local PropService = require(Services.PropService)
local ShopService = require(Services.ShopService)
local StaffService = require(Services.StaffService)
local StarterService = require(Services.StarterService)
local StatsService = require(Services.StatsService)
local TacoService = require(Services.TacoService)
local StateService = require(Services.StateService)
local WheelService = require(Services.WheelService)

StateService.init()
-- Early, so an event already running elsewhere is in place before the first drop.
EventService.init()
-- Before anything that fires an action, so nothing early is missed.
AnalyticsService.init()
StatsService.init()
GardenService.init()
-- After GardenService: these hang off the world it builds.
HubService.init()
-- After HubService: its poles stand in the same gaps between the paths.
CanopyService.init()
PropService.init()
TacoService.init()
PlinthService.init()
PassService.init()
-- After PassService: the Admin pass is one of its passes.
AdminService.init()
GameplayService.init()
ShopService.init()
DailyService.init()
ProductService.init()
-- After PassService: it hangs off the pass it is sold as.
StarterService.init()
LeaderboardService.init()
WheelService.init()
QuestService.init()
PlaytimeService.init()
-- After HubService: it needs to know where the machine was built.
CraftService.init()
-- After HubService too: it connects to the prompts on the egg pads.
PetService.init()
StaffService.init()

-- What a player is told when every garden is taken. It says what to do about it,
-- because "server full" on its own reads as "the game is broken".
local FULL_MESSAGE = "Every garden in this server is taken. Rejoin and you'll land in one with room!"
-- How long a player gets to be moved before they're sent away instead. A teleport
-- that is never going to land leaves them stood in a world with no garden, unable
-- to play and with nothing saying why.
local FULL_TELEPORT_GRACE = 12
-- Marks a player who has already been moved once for this. Roblox picks the server
-- they land in, and it can pick another full one, so the second try says so rather
-- than bouncing them round the game forever.
local RETRY_KEY = "FullServerRetry"

-- The place's max players is meant to match Balance.PlotCount. It's set on the
-- Creator Hub rather than in here, so it can drift -- and Roblox can fill a server
-- past its own limit while players are being sorted. Either way somebody arrives
-- with nowhere to play, so they're moved to another server rather than left
-- standing in the hub or dropped without a word.
local function serverFull(player: Player)
	local joinData = player:GetJoinData()
	local teleportData = joinData and joinData.TeleportData
	local alreadyMoved = typeof(teleportData) == "table" and (teleportData :: any)[RETRY_KEY] == true

	-- Teleports don't work in Studio at all, and a second full server is a sign
	-- the whole game is busy rather than this one server being unlucky.
	if alreadyMoved or RunService:IsStudio() then
		player:Kick(FULL_MESSAGE)
		return
	end

	local options = Instance.new("TeleportOptions")
	options:SetTeleportData({ [RETRY_KEY] = true })
	local sent = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
	if not sent then
		player:Kick(FULL_MESSAGE)
		return
	end
	-- TeleportAsync returning doesn't mean the player went anywhere: it can still
	-- fail on the way, and TeleportInitFailed only fires for some of those.
	task.delay(FULL_TELEPORT_GRACE, function()
		if player.Parent and not GardenService.getPlot(player) then
			player:Kick(FULL_MESSAGE)
		end
	end)
end

TeleportService.TeleportInitFailed:Connect(function(player, _result, _message)
	if player.Parent and not GardenService.getPlot(player) then
		player:Kick(FULL_MESSAGE)
	end
end)

-- Said once at startup, because the mismatch is invisible until the extra player
-- joins -- and on a quiet new game that can be weeks after the setting was wrong.
if not RunService:IsStudio() and Players.MaxPlayers > Config.Balance.PlotCount then
	warn(
		`This place allows {Players.MaxPlayers} players but the world has {Config.Balance.PlotCount} gardens.`
			.. ` Set Max Players to {Config.Balance.PlotCount} on the Creator Hub, under Configure > Places.`
	)
end

DataService.onLoaded(function(player, data)
	PassService.load(player)
	-- The ownership check yields; the player may have left in the meantime.
	if not DataService.get(player) then
		return
	end

	if not GardenService.assign(player) then
		serverFull(player)
		return
	end
	-- Playtesting money. Never runs on a real server.
	if RunService:IsStudio() then
		data.Gems = math.max(data.Gems, Config.Settings.StudioGems)
	end

	ItemService.renderFromData(player, data)
	PlinthService.refresh(player)
	DailyService.applyOffline(player, data)
	-- After ownership is loaded, and before the HUD is told anything: a player
	-- who bought the pack on a server that died still gets it on this join.
	StarterService.addPlayer(player)
	GameplayService.addPlayer(player)
	PetService.addPlayer(player)
	LeaderboardService.addPlayer(player)
	CraftService.addPlayer(player)
	QuestService.refresh(player)
	PlaytimeService.addPlayer(player)
	AnalyticsService.addPlayer(player)
	StateService.markDirty(player)
end)

DataService.onReleasing(function(player, data)
	data.LastOnline = os.time()
	-- First, while the profile is still readable: it reports the session totals.
	AnalyticsService.removePlayer(player)
	GameplayService.removePlayer(player)
	PetService.removePlayer(player)
	LeaderboardService.removePlayer(player)
	PlaytimeService.removePlayer(player)
	ItemService.clear(player)
	-- Before the garden is released, while its owner is still known.
	PlinthService.clear(player)
	GardenService.release(player)
	PassService.unload(player)
end)

DataService.start()
