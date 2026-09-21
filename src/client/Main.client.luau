--!strict
-- Client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminController = require(script.Parent.Controllers.AdminController)
local Board = require(script.Parent.UI.Board)
local CarryController = require(script.Parent.Controllers.CarryController)
local Config = require(ReplicatedStorage.Shared.Config)
local CraftController = require(script.Parent.Controllers.CraftController)
local EffectsController = require(script.Parent.Controllers.EffectsController)
local Hud = require(script.Parent.UI.Hud)
local Net = require(ReplicatedStorage.Shared.Net)
local PetController = require(script.Parent.Controllers.PetController)
local Sound = require(script.Parent.UI.Sound)
local State = require(script.Parent.State)
local TacoController = require(script.Parent.Controllers.TacoController)
local WalkwayController = require(script.Parent.Controllers.WalkwayController)
local WheelController = require(script.Parent.Controllers.WheelController)

Hud.start()
Board.start()
EffectsController.start()
CarryController.start()
PetController.start()
AdminController.start()
WheelController.start()
CraftController.start()
TacoController.start()
WalkwayController.start()
State.start()

-- The background track, for as long as the session lasts. Under the UI and the
-- world, so it sits below both.
Sound.loop(Config.Theme.Sounds.Music, 0.25)

-- Tell the server the UI is listening; it replies with state, any queued
-- messages (offline earnings) and the leaderboards.
Net.event("Ready"):FireServer()
