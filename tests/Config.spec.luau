--!strict
-- Sanity checks on balance data, so a typo in Config fails fast.
local TestKit = require("./TestKit")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	t:test("zones are contiguous and ordered", function()
		for i = 2, #Config.Zones do
			t:eq(Config.Zones[i].minDepth, Config.Zones[i - 1].maxDepth)
		end
		t:eq(Config.Zones[1].minDepth, 0)
		t:eq(Config.Zones[#Config.Zones].maxDepth, math.huge)
	end)

	t:test("deeper zones drain more oxygen", function()
		for i = 2, #Config.Zones do
			assert(
				Config.Zones[i].drainPerSecond > Config.Zones[i - 1].drainPerSecond,
				Config.Zones[i].id
			)
		end
	end)

	t:test("every fish has a known zone, rarity and valid weight", function()
		local zoneIds = {}
		for _, zone in Config.Zones do
			zoneIds[zone.id] = true
		end
		local ids = {}
		for _, fish in Config.Fish do
			assert(zoneIds[fish.zoneId], `{fish.id}: unknown zone {fish.zoneId}`)
			assert(Config.RarityWeights[fish.rarity], `{fish.id}: unknown rarity`)
			assert(fish.minWeight > 0 and fish.minWeight <= fish.maxWeight, `{fish.id}: bad weight`)
			assert(not ids[fish.id], `duplicate fish id {fish.id}`)
			ids[fish.id] = true
		end
	end)

	t:test("pools: first is free, gains grow with the threshold", function()
		t:eq(Config.Pools[1].unlockMaxO2, 0)
		for i = 2, #Config.Pools do
			assert(
				Config.Pools[i].unlockMaxO2 > Config.Pools[i - 1].unlockMaxO2,
				`{Config.Pools[i].id}: threshold`
			)
			assert(
				Config.Pools[i].gainPerTick > Config.Pools[i - 1].gainPerTick,
				`{Config.Pools[i].id}: gain`
			)
		end
	end)

	t:test("prototype ocean floor is below the deepest fish zone", function()
		local deepest = 0
		for _, fish in Config.Fish do
			for _, zone in Config.Zones do
				if zone.id == fish.zoneId then
					deepest = math.max(deepest, zone.maxDepth)
				end
			end
		end
		assert(Config.World.oceanFloorMeters > deepest, `ocean floor must be below {deepest} m`)
	end)

	t:test("every zone with fish has a spawn ring that fits the ocean", function()
		local half = Config.World.oceanSize / 2
		for _, fish in Config.Fish do
			for _, zone in Config.Zones do
				if zone.id == fish.zoneId then
					local spawn = zone.spawn
					assert(spawn, `{zone.id}: fish but no spawn ring`)
					assert(
						spawn.minRadius > Config.World.islandRadius,
						`{zone.id}: ring inside island`
					)
					assert(spawn.maxRadius <= half, `{zone.id}: ring outside the ocean`)
					assert(spawn.floorMeters > zone.minDepth, `{zone.id}: seabed above the zone`)
				end
			end
		end
	end)

	t:test("egg odds add up to 100 and name real fish", function()
		local fishIds = {}
		for _, fish in Config.Fish do
			fishIds[fish.id] = true
		end
		for _, egg in Config.Eggs do
			local total = 0
			for _, entry in egg.hatch do
				assert(fishIds[entry.fishId], `{egg.id}: unknown fish {entry.fishId}`)
				total += entry.chance
			end
			t:eq(total, 100)
			assert(egg.price > 0 and egg.nestCount > 0, `{egg.id}: price/nests`)
		end
	end)
end
