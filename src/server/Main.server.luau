--!strict
-- Server entry point: starts the services and wires the player lifecycle.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local Services = script.Parent.Services

local AnalyticsService = require(Services.AnalyticsService)
local CraftService = require(Services.CraftService)
local DailyService = require(Services.DailyService)
local DataService = require(Services.DataService)
local GameplayService = require(Services.GameplayService)
local GardenService = require(Services.GardenService)
local HubService = require(Services.HubService)
local ItemService = require(Services.ItemService)
local LeaderboardService = require(Services.LeaderboardService)
local PassService = require(Services.PassService)
local PlaytimeService = require(Services.PlaytimeService)
local PlinthService = require(Services.PlinthService)
local ProductService = require(Services.ProductService)
local QuestService = require(Services.QuestService)
local PropService = require(Services.PropService)
local ShopService = require(Services.ShopService)
local StarterService = require(Services.StarterService)
local StatsService = require(Services.StatsService)
local StateService = require(Services.StateService)
local WheelService = require(Services.WheelService)

StateService.init()
-- Before anything that fires an action, so nothing early is missed.
AnalyticsService.init()
StatsService.init()
GardenService.init()
-- After GardenService: these hang off the world it builds.
HubService.init()
PropService.init()
PlinthService.init()
PassService.init()
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

DataService.onLoaded(function(player, data)
	PassService.load(player)
	-- The ownership check yields; the player may have left in the meantime.
	if not DataService.get(player) then
		return
	end

	if not GardenService.assign(player) then
		player:Kick("This server is full. Please try another!")
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
	LeaderboardService.removePlayer(player)
	PlaytimeService.removePlayer(player)
	ItemService.clear(player)
	-- Before the garden is released, while its owner is still known.
	PlinthService.clear(player)
	GardenService.release(player)
	PassService.unload(player)
end)

DataService.start()
