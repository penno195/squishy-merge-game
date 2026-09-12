--!strict
-- Server entry point: starts the services and wires the player lifecycle.

local Services = script.Parent.Services

local DailyService = require(Services.DailyService)
local DataService = require(Services.DataService)
local GameplayService = require(Services.GameplayService)
local GardenService = require(Services.GardenService)
local HubService = require(Services.HubService)
local ItemService = require(Services.ItemService)
local LeaderboardService = require(Services.LeaderboardService)
local PassService = require(Services.PassService)
local ProductService = require(Services.ProductService)
local PropService = require(Services.PropService)
local ShopService = require(Services.ShopService)
local StateService = require(Services.StateService)
local WheelService = require(Services.WheelService)

StateService.init()
GardenService.init()
-- After GardenService: both hang off the world it builds.
HubService.init()
PropService.init()
PassService.init()
GameplayService.init()
ShopService.init()
DailyService.init()
ProductService.init()
LeaderboardService.init()
WheelService.init()

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
	ItemService.renderFromData(player, data)
	DailyService.applyOffline(player, data)
	GameplayService.addPlayer(player)
	LeaderboardService.addPlayer(player)
	StateService.markDirty(player)
end)

DataService.onReleasing(function(player, data)
	data.LastOnline = os.time()
	GameplayService.removePlayer(player)
	LeaderboardService.removePlayer(player)
	ItemService.clear(player)
	GardenService.release(player)
	PassService.unload(player)
end)

DataService.start()
