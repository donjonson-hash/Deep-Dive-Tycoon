--!strict
local TestKit = require("./TestKit")
local Pools = require("../src/shared/Logic/Pools")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	t:test("first pool is open from the start", function()
		t:eq(Pools.isUnlocked(Config.Pools[1], 0), true)
	end)

	t:test("second pool opens at its threshold", function()
		local second = Config.Pools[2]
		t:eq(Pools.isUnlocked(second, second.unlockMaxO2 - 1), false)
		t:eq(Pools.isUnlocked(second, second.unlockMaxO2), true)
	end)

	t:test("best unlocked pool is the one with the highest gain", function()
		t:eq((Pools.bestUnlocked(Config.Pools, 0) :: any).id, "Kiddie")
		t:eq((Pools.bestUnlocked(Config.Pools, 10_000) :: any).id, "Coral")
	end)

	t:test("no pools means nothing unlocked", function()
		t:eq(Pools.bestUnlocked({}, 100), nil)
	end)
end
