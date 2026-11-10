--!strict
local TestKit = require("./TestKit")
local Bounds = require("../src/shared/Logic/Bounds")

return function(t: TestKit.TestKit)
	-- A 10 x 2.5 x 10 pool: half extents 5, 1.25, 5, stretched 4 studs upward.
	t:test("center and edges are inside", function()
		t:eq(Bounds.contains(0, 0, 0, 5, 1.25, 5, 4), true)
		t:eq(Bounds.contains(5, 1.25, -5, 5, 1.25, 5, 4), true)
	end)

	t:test("root part standing above the water still counts", function()
		t:eq(Bounds.contains(0, 4, 0, 5, 1.25, 5, 4), true)
		t:eq(Bounds.contains(0, 5.25, 0, 5, 1.25, 5, 4), true)
		t:eq(Bounds.contains(0, 5.3, 0, 5, 1.25, 5, 4), false)
	end)

	t:test("outside horizontally or below is outside", function()
		t:eq(Bounds.contains(5.1, 0, 0, 5, 1.25, 5, 4), false)
		t:eq(Bounds.contains(0, 0, -5.1, 5, 1.25, 5, 4), false)
		t:eq(Bounds.contains(0, -1.3, 0, 5, 1.25, 5, 4), false)
	end)
end
