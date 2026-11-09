--!strict
local TestKit = require("./TestKit")
local Fishing = require("../src/shared/Logic/Fishing")
local Config = require("../src/shared/Config")

local function roll(zoneId: string, r: number): string?
	local fish = Fishing.rollFish(Config.Fish, zoneId, Config.RarityWeights, Config.RarityOrder, r)
	return if fish then fish.id else nil
end

return function(t: TestKit.TestKit)
	-- Lagoon has Common/Uncommon/Rare: weights 60/25/10 out of 95.
	t:test("low rolls give common fish", function()
		t:eq(roll("Lagoon", 0), "Sardine")
		t:eq(roll("Lagoon", 0.63), "Sardine")
	end)

	t:test("middle rolls give uncommon fish", function()
		t:eq(roll("Lagoon", 0.64), "Seahorse")
		t:eq(roll("Lagoon", 0.89), "Seahorse")
	end)

	t:test("top rolls give rare fish", function()
		t:eq(roll("Lagoon", 0.9), "Clownfish")
		t:eq(roll("Lagoon", 0.999999), "Clownfish")
		t:eq(roll("Lagoon", 1), "Clownfish")
	end)

	t:test("rarity frequencies match weights", function()
		local counts: { [string]: number } = {}
		local samples = 9500
		for i = 0, samples - 1 do
			local id = roll("CoralReef", i / samples) :: string
			counts[id] = (counts[id] or 0) + 1
		end
		t:eq(counts.Parrotfish, 6000)
		t:eq(counts.Surgeonfish, 2500)
		t:eq(counts.Angelfish, 1000)
	end)

	t:test("a disabled rarity never drops, even on roll = 1", function()
		local weights = table.clone(Config.RarityWeights)
		weights.Rare = 0
		local fish = Fishing.rollFish(Config.Fish, "Lagoon", weights, Config.RarityOrder, 1)
		t:eq(if fish then fish.id else nil, "Seahorse")
	end)

	t:test("zone without fish returns nil", function()
		t:eq(roll("Trench", 0.5), nil)
	end)

	t:test("fish needs at least its catch cost in oxygen, exactly enough is fine", function()
		t:eq(Fishing.canAfford(10, 10), true)
		t:eq(Fishing.canAfford(99, 100), false)
		t:eq(Fishing.canAfford(0, 0), true)
	end)

	t:test("weight stays within the species range", function()
		local sardine = Config.Fish[1]
		t:eq(Fishing.rollWeight(sardine, 0), sardine.minWeight)
		t:eq(Fishing.rollWeight(sardine, 1), sardine.maxWeight)
		t:near(Fishing.rollWeight(sardine, 0.5), 0.2)
	end)

	t:test("heavier catch swims slower, down to the floor", function()
		t:eq(Fishing.speedMultiplier(0, 0.02, 0.4), 1)
		t:near(Fishing.speedMultiplier(10, 0.02, 0.4), 0.8)
		t:eq(Fishing.speedMultiplier(1000, 0.02, 0.4), 0.4)
	end)
end
