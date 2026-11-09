--!strict
-- Client entry point: UI controllers and local-only visuals. Game state is
-- owned by the server.

local DepthHud = require(script.Hud.DepthHud)
local StatsHud = require(script.Hud.StatsHud)
local MarketUi = require(script.Market.MarketUi)
local KelpSway = require(script.World.KelpSway)
local UnderwaterFx = require(script.World.UnderwaterFx)

DepthHud.start()
StatsHud.start()
UnderwaterFx.start()
KelpSway.start()
MarketUi.start() -- last: it waits for the map and the remotes
