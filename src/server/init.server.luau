--!strict
-- Server entry point. Services are added here as prototype features land.

local MapBuilder = require(script.World.MapBuilder)
local PlayerState = require(script.Player.PlayerState)
local OxygenService = require(script.Player.OxygenService)
local FishService = require(script.Fish.FishService)

MapBuilder.build()
PlayerState.start()
OxygenService.start()
local fishFolder = FishService.start()
print(`[DeepDive] Server started, map built, {#fishFolder:GetChildren()} fish spawned`)
