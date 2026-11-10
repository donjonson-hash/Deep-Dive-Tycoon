--!strict
-- Drains oxygen by depth and refills it at the surface, on a fixed server tick.
-- Depth comes from the character's root part on the server, never from the client.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Depth = require(ReplicatedStorage.Shared.Logic.Depth)
local Oxygen = require(ReplicatedStorage.Shared.Logic.Oxygen)
local PlayerState = require(script.Parent.PlayerState)

local OxygenService = {}

local function tick(player: Player, dt: number)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local world = Config.World
	local depth = Depth.toMeters(root.Position.Y, world.surfaceY, world.studsPerMeter)
	PlayerState.setInWater(player, root.Position.Y < world.surfaceY) -- fins only work in the water
	local current = PlayerState.getCurrentO2(player)

	if depth < world.surfaceToleranceMeters then
		local max = PlayerState.getMaxO2(player)
		PlayerState.setCurrentO2(
			player,
			Oxygen.refill(current, max, Config.Oxygen.surfaceRefillPerSecond, dt)
		)
		return
	end

	local zone = Depth.zoneAt(Config.Zones, depth)
	-- Below the last zone is impossible by Config (it ends at math.huge), so the
	-- fallback only guards against a broken table.
	local drainPerSecond = if zone
		then zone.drainPerSecond
		else Config.Zones[#Config.Zones].drainPerSecond
	local nextValue, dead = Oxygen.drain(current, drainPerSecond, dt)
	PlayerState.setCurrentO2(player, nextValue)
	if dead then
		-- Catch loss arrives with the catching feature; for now death is the whole penalty.
		humanoid.Health = 0
	end
end

function OxygenService.start()
	task.spawn(function()
		while true do
			local dt = task.wait(Config.Oxygen.tickSeconds)
			for _, player in Players:GetPlayers() do
				tick(player, dt)
			end
		end
	end)
end

return OxygenService
