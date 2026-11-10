--!strict
local TestKit = require("./TestKit")
local Movement = require("../src/shared/Logic/Movement")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	local base = Config.Movement.baseWalkSpeed
	local fins = Config.Gear.finsSwimMultiplier

	t:test("fins do nothing on land", function()
		t:eq(Movement.speed(base, 1, false, fins), base)
	end)

	t:test("fins speed up swimming", function()
		t:eq(Movement.speed(base, 1, true, fins), base * fins)
		assert(fins > 1, "fins must make the diver faster")
	end)

	t:test("fins and catch weight stack", function()
		t:near(Movement.speed(16, 0.5, true, 1.5), 12)
		t:near(Movement.speed(16, 0.5, false, 1.5), 8)
	end)
end
