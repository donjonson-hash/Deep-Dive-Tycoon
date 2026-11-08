--!strict
-- Server entry point. Services are added here as prototype features land.

local MapBuilder = require(script.World.MapBuilder)

MapBuilder.build()
print("[DeepDive] Server started, map built")
