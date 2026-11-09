--!strict
local TestKit = require("./TestKit")
local Net = require("../src/shared/Logic/Net")

return function(t: TestKit.TestKit)
	t:test("net is full at capacity, not before", function()
		t:eq(Net.isFull(2, 3), false)
		t:eq(Net.isFull(3, 3), true)
		t:eq(Net.isFull(0, 0), true)
	end)

	t:test("total weight sums the catch", function()
		t:eq(Net.totalWeight({}), 0)
		t:near(Net.totalWeight({ { weight = 0.2 }, { weight = 1.5 }, { weight = 3 } }), 4.7)
	end)
end
