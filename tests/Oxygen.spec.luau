--!strict
local TestKit = require("./TestKit")
local Oxygen = require("../src/shared/Logic/Oxygen")

return function(t: TestKit.TestKit)
	t:test("drain reduces oxygen over time", function()
		local value, dead = Oxygen.drain(30, 2, 0.5)
		t:eq(value, 29)
		t:eq(dead, false)
	end)

	t:test("drain to zero kills and never goes negative", function()
		local value, dead = Oxygen.drain(1, 4, 1)
		t:eq(value, 0)
		t:eq(dead, true)
	end)

	t:test("spending more than you have kills", function()
		local value, dead = Oxygen.spend(5, 8)
		t:eq(value, 0)
		t:eq(dead, true)
	end)

	t:test("spending less keeps you alive", function()
		local value, dead = Oxygen.spend(10, 3)
		t:eq(value, 7)
		t:eq(dead, false)
	end)

	t:test("refill at the surface stops at max", function()
		t:eq(Oxygen.refill(20, 30, 10, 0.5), 25)
		t:eq(Oxygen.refill(28, 30, 10, 0.5), 30)
		t:eq(Oxygen.refill(30, 30, 10, 1), 30)
	end)

	t:test("warning levels at 25 % and 10 %", function()
		t:eq(Oxygen.warningLevel(100, 100, 0.25, 0.1), "Ok")
		t:eq(Oxygen.warningLevel(26, 100, 0.25, 0.1), "Ok")
		t:eq(Oxygen.warningLevel(25, 100, 0.25, 0.1), "Low")
		t:eq(Oxygen.warningLevel(10, 100, 0.25, 0.1), "Critical")
		t:eq(Oxygen.warningLevel(0, 0, 0.25, 0.1), "Critical")
	end)
end
