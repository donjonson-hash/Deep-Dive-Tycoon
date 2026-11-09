--!strict
-- Owns per-player state (MaxO2, CurrentO2, Coins) and publishes it as Player
-- attributes so clients can draw it. Only this server code writes the values.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Attributes = require(ReplicatedStorage.Shared.Attributes)

local PlayerState = {}

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

local function onPlayerAdded(player: Player)
	-- Fresh profile until saving lands; a save system will load these instead.
	PlayerState.setMaxO2(player, Config.Oxygen.startingMaxO2)
	PlayerState.setCurrentO2(player, Config.Oxygen.startingMaxO2)
	player:SetAttribute(Attributes.Coins, Config.Economy.startingCoins)

	-- Every new character starts with a full tank.
	player.CharacterAdded:Connect(function()
		PlayerState.setCurrentO2(player, PlayerState.getMaxO2(player))
	end)
end

function PlayerState.start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return PlayerState
