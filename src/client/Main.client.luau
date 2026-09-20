--!strict
-- Client entry point.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminController = require(script.Parent.Controllers.AdminController)
local Board = require(script.Parent.UI.Board)
local CarryController = require(script.Parent.Controllers.CarryController)
local CraftController = require(script.Parent.Controllers.CraftController)
local EffectsController = require(script.Parent.Controllers.EffectsController)
local Hud = require(script.Parent.UI.Hud)
local Net = require(ReplicatedStorage.Shared.Net)
local PetController = require(script.Parent.Controllers.PetController)
local State = require(script.Parent.State)
local TacoController = require(script.Parent.Controllers.TacoController)
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
State.start()

-- Tell the server the UI is listening; it replies with state, any queued
-- messages (offline earnings) and the leaderboards.
Net.event("Ready"):FireServer()
