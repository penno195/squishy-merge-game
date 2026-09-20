--!strict
-- Turns the ring of sweets laid over the moving walkway, at the speed the
-- walkway carries you.
--
-- The walkway is a conveyor: anchored parts with a surface velocity, which move
-- what stands on them without moving themselves. That is the right way to build
-- one and the wrong way for it to look, because nothing on screen moves -- a
-- player glides along a floor that is plainly standing still, which reads as a
-- bug rather than as a travelator.
--
-- So the tiles turn. It is done here rather than on the server because it is
-- only a picture: no collisions hang off it, nobody stands on the tiles, and
-- turning them here costs the network nothing. The server sends the one number
-- the client can't work out on its own -- how fast, in radians -- as an
-- attribute on the model.
--
-- One call a frame, not six hundred: the tiles are one Model pivoted on the
-- middle of the map, so rotating it rotates every tile at once.

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local WalkwayController = {}

local TURN = math.pi * 2

function WalkwayController.start()
	task.spawn(function()
		local world = Workspace:WaitForChild("World", 30)
		local hub = world and world:WaitForChild("Hub", 30)
		local walkway = hub and hub:WaitForChild("Walkway", 30)
		local tiles = walkway and walkway:WaitForChild("Tiles", 30)
		if not tiles or not tiles:IsA("Model") then
			return
		end

		local speed = tiles:GetAttribute("RadiansPerSecond")
		if typeof(speed) ~= "number" or speed == 0 then
			return
		end

		local angle = 0
		RunService.RenderStepped:Connect(function(delta)
			-- Wrapped every turn: a number that only ever grows loses its
			-- precision by the end of a long session, and the ring would start
			-- to judder.
			angle = (angle + speed * delta) % TURN
			-- Negative, because a positive turn about Y walks the ring backwards
			-- against the direction the walkway carries people.
			tiles:PivotTo(CFrame.Angles(0, -angle, 0))
		end)
	end)
end

return WalkwayController
