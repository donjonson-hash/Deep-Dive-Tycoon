--!strict
local TestKit = require("./TestKit")
local Eggs = require("../src/shared/Logic/Eggs")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	local reefEgg = Config.Eggs[1]

	t:test("egg needs at least its price in coins", function()
		t:eq(Eggs.canBuy(50, 50), true)
		t:eq(Eggs.canBuy(49, 50), false)
	end)

	t:test("hatch follows the published odds", function()
		t:eq(Eggs.hatch(reefEgg.hatch, 0), "Sardine")
		t:eq(Eggs.hatch(reefEgg.hatch, 0.69), "Sardine")
		t:eq(Eggs.hatch(reefEgg.hatch, 0.7), "Tuna")
		t:eq(Eggs.hatch(reefEgg.hatch, 1), "Tuna")
	end)

	t:test("hatch frequencies match the table", function()
		local counts: { [string]: number } = {}
		for i = 0, 999 do
			local id = Eggs.hatch(reefEgg.hatch, i / 1000) :: string
			counts[id] = (counts[id] or 0) + 1
		end
		t:eq(counts.Sardine, 700)
		t:eq(counts.Tuna, 300)
	end)

	t:test("empty or zero tables hatch nothing", function()
		t:eq(Eggs.hatch({}, 0.5), nil)
		t:eq(Eggs.hatch({ { fishId = "X", chance = 0 } }, 0.5), nil)
	end)

	t:test("chances describe themselves for the label", function()
		local text = Eggs.describeChances(reefEgg.hatch, function(id)
			return string.lower(id)
		end)
		t:eq(text, "sardine 70% · tuna 30%")
	end)
end
