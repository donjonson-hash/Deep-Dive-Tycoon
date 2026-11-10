--!strict
-- Decides whether a player may take a fish. Distance is already enforced by the
-- ProximityPrompt (MaxActivationDistance is checked on the server); this module
-- checks the rest: alive, net space, enough oxygen. Oxygen is a requirement,
-- not a price: nothing is spent on a catch.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Fishing = require(ReplicatedStorage.Shared.Logic.Fishing)
local Net = require(ReplicatedStorage.Shared.Logic.Net)
local PlayerState = require(script.Parent.Parent.Player.PlayerState)

local CatchService = {}

local rng = Random.new()

-- Returns true when the fish was taken (and should leave the water).
function CatchService.tryCatch(player: Player, species: Config.Fish): boolean
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid or humanoid.Health <= 0 then
		return false
	end

	if Net.isFull(#PlayerState.getNet(player), Config.Inventory.netCapacity) then
		return false
	end

	if not Fishing.canAfford(PlayerState.getCurrentO2(player), species.catchCost) then
		return false
	end

	PlayerState.addToNet(player, {
		id = species.id,
		weight = Fishing.rollWeight(species, rng:NextNumber()),
	})
	return true
end

return CatchService
