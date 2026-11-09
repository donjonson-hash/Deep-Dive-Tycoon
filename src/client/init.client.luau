--!strict
-- Client entry point: UI controllers only. Game state is owned by the server.

local DepthHud = require(script.Hud.DepthHud)
local StatsHud = require(script.Hud.StatsHud)
local MarketUi = require(script.Market.MarketUi)

DepthHud.start()
StatsHud.start()
MarketUi.start()
