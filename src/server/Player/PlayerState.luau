--!strict
-- Owns per-player state (MaxO2, CurrentO2, Coins, the net) and publishes it as
-- Player attributes so clients can draw it. Only this server code writes them.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Attributes = require(ReplicatedStorage.Shared.Attributes)
local Fishing = require(ReplicatedStorage.Shared.Logic.Fishing)
local Net = require(ReplicatedStorage.Shared.Logic.Net)

local PlayerState = {}

export type NetItem = {
	id: string, -- Config.Fish id
	weight: number, -- kg
}

-- The net lives in server memory; the attribute is a JSON copy for the client.
local nets: { [Player]: { NetItem } } = {}

local function getNumber(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function PlayerState.getMaxO2(player: Player): number
	return getNumber(player, Attributes.MaxO2)
end

function PlayerState.getCurrentO2(player: Player): number
	return getNumber(player, Attributes.CurrentO2)
end

function PlayerState.getCoins(player: Player): number
	return getNumber(player, Attributes.Coins)
end

function PlayerState.setCurrentO2(player: Player, value: number)
	if PlayerState.getCurrentO2(player) ~= value then
		player:SetAttribute(Attributes.CurrentO2, value)
	end
end

function PlayerState.setMaxO2(player: Player, value: number)
	player:SetAttribute(Attributes.MaxO2, value)
end

function PlayerState.addCoins(player: Player, amount: number)
	player:SetAttribute(Attributes.Coins, PlayerState.getCoins(player) + amount)
end

function PlayerState.getNet(player: Player): { NetItem }
	return nets[player] or {}
end

-- Heavier catch, slower diver (Config.Weight). Applied to the live Humanoid.
local function applyWeightPenalty(player: Player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if not humanoid then
		return
	end
	local multiplier = Fishing.speedMultiplier(
		Net.totalWeight(PlayerState.getNet(player)),
		Config.Weight.speedPenaltyPerKg,
		Config.Weight.minSpeedMultiplier
	)
	humanoid.WalkSpeed = Config.Movement.baseWalkSpeed * multiplier
end

local function publishNet(player: Player)
	player:SetAttribute(Attributes.Net, HttpService:JSONEncode(PlayerState.getNet(player)))
	applyWeightPenalty(player)
end

function PlayerState.addToNet(player: Player, item: NetItem)
	local net = nets[player]
	if not net then
		net = {}
		nets[player] = net
	end
	table.insert(net, item)
	publishNet(player)
end

function PlayerState.clearNet(player: Player)
	nets[player] = {}
	publishNet(player)
end

local function onCharacterAdded(player: Player, character: Model)
	-- Every new character starts with a full tank and an empty net.
	PlayerState.setCurrentO2(player, PlayerState.getMaxO2(player))
	PlayerState.clearNet(player)

	local humanoid = character:WaitForChild("Humanoid", 5)
	if humanoid and humanoid:IsA("Humanoid") then
		applyWeightPenalty(player)
		-- Dying underwater (or anywhere) loses the catch: the GDD's price of running out.
		humanoid.Died:Connect(function()
			PlayerState.clearNet(player)
		end)
	end
end

local function onPlayerAdded(player: Player)
	-- Fresh profile until saving lands; a save system will load these instead.
	PlayerState.setMaxO2(player, Config.Oxygen.startingMaxO2)
	PlayerState.setCurrentO2(player, Config.Oxygen.startingMaxO2)
	player:SetAttribute(Attributes.Coins, Config.Economy.startingCoins)
	PlayerState.clearNet(player)

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end

function PlayerState.start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(function(player)
		nets[player] = nil
	end)
end

return PlayerState
