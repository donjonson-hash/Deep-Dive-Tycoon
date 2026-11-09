--!strict
local TestKit = require("./TestKit")
local Sway = require("../src/shared/Logic/Sway")

return function(t: TestKit.TestKit)
	t:test("one angle per joint", function()
		t:eq(#Sway.angles(0, 0, 5, 0.1, 0.2, 0.7, 0.02), 5)
	end)

	t:test("no swing leaves only the lean", function()
		for _, angle in Sway.angles(3.7, 1.2, 4, 0, 0.2, 0.7, 0.02) do
			t:near(angle, 0.02)
		end
	end)

	t:test("joints higher up swing more, the root barely moves", function()
		local amplitude, count = 0.1, 5
		for step = 0, 40 do
			local angles = Sway.angles(step * 0.37, 0.4, count, amplitude, 0.2, 0.7, 0)
			for i, angle in angles do
				assert(math.abs(angle) <= amplitude * i / count + 1e-9, `joint {i} over its limit`)
			end
		end
	end)

	t:test("the wave reaches the tip later than the root", function()
		-- With zero phase and time, joint i sits at sin(-i * lag): each joint is
		-- further behind in the cycle, so the angles differ along the chain.
		local angles = Sway.angles(0, 0, 3, 0.3, 0.2, 0.5, 0)
		t:near(angles[1], 0.3 * (1 / 3) * math.sin(-0.5))
		t:near(angles[3], 0.3 * math.sin(-1.5))
	end)
end
