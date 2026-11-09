--!strict
-- Oxygen training: a player standing in an unlocked pool gains MaxO2 every
-- Config.Oxygen.poolTickSeconds. Presence is checked from the character's root
-- position on the server against the pool water parts MapBuilder created.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Pools = require(ReplicatedStorage.Shared.Logic.Pools)
local PlayerState = require(script.Parent.PlayerState)

local PoolService = {}

-- The root part sits about 3 studs above the feet, so the hit box is stretched
-- upward past the water part; horizontally it stays inside the pool.
local VERTICAL_MARGIN = 4 -- studs

type PoolArea = {
	pool: Config.Pool,
	water: BasePart,
}

local areas: { PoolArea } = {}

local function poolById(id: string): Config.Pool?
	for _, pool in Config.Pools do
		if pool.id == id then
			return pool
		end
	end
	return nil
end

local function collectAreas(): { PoolArea }
	local found: { PoolArea } = {}
	local map = Workspace:FindFirstChild("Map")
	local pools = if map then map:FindFirstChild("Pools", true) else nil
	if not pools then
		warn("[PoolService] No Map.Pier.Pools folder; pools will not train oxygen")
		return found
	end
	for _, water in pools:GetDescendants() do
		if water.Name == "PoolWater" and water:IsA("BasePart") then
			local id = water:GetAttribute("PoolId")
			local pool = if type(id) == "string" then poolById(id) else nil
			if pool then
				table.insert(found, { pool = pool, water = water })
			else
				warn(`[PoolService] PoolWater without a known PoolId: {water:GetFullName()}`)
			end
		end
	end
	return found
end

local function contains(water: BasePart, position: Vector3): boolean
	local local_ = water.CFrame:PointToObjectSpace(position)
	local half = water.Size / 2
	return math.abs(local_.X) <= half.X
		and math.abs(local_.Z) <= half.Z
		and local_.Y >= -half.Y
		and local_.Y <= half.Y + VERTICAL_MARGIN
end

local function poolAt(position: Vector3): Config.Pool?
	for _, area in areas do
		if contains(area.water, position) then
			return area.pool
		end
	end
	return nil
end

local function tick(player: Player)
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end

	local pool = poolAt(root.Position)
	if not pool then
		return
	end

	local maxO2 = PlayerState.getMaxO2(player)
	local gain = Pools.gainFor(pool, maxO2)
	if gain > 0 then
		PlayerState.setMaxO2(player, maxO2 + gain)
	end
end

function PoolService.start()
	areas = collectAreas()
	task.spawn(function()
		while true do
			task.wait(Config.Oxygen.poolTickSeconds)
			for _, player in Players:GetPlayers() do
				tick(player)
			end
		end
	end)
end

return PoolService
