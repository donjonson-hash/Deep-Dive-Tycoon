--!strict
local TestKit = require("./TestKit")
local FishMotion = require("../src/shared/Logic/FishMotion")
local Config = require("../src/shared/Config")

local world = Config.World
local spawn = Config.FishSpawn

return function(t: TestKit.TestKit)
	t:test("lagoon band runs from the surface margin to just above the seabed", function()
		local lagoon = Config.Zones[1]
		local ring = lagoon.spawn :: Config.ZoneSpawn
		local minY, maxY = FishMotion.zoneBounds(
			lagoon,
			world,
			ring.floorMeters,
			spawn.surfaceMarginMeters,
			spawn.floorMarginMeters
		)
		t:eq(minY, -(50 - 2) * 3)
		t:eq(maxY, -3)
	end)

	t:test("a zone deeper than the seabed is clamped above the sand", function()
		local minY, maxY = FishMotion.zoneBounds({ minDepth = 20, maxDepth = 100 }, world, 50, 1, 2)
		t:eq(minY, -(50 - 2) * 3)
		t:eq(maxY, -60)
	end)

	t:test("a zone entirely below the seabed has no band", function()
		local minY, maxY = FishMotion.zoneBounds({ minDepth = 60, maxDepth = 100 }, world, 50, 1, 2)
		t:eq(minY, nil)
		t:eq(maxY, nil)
	end)

	t:test("zero rolls give the nearest, deepest point on the +X axis", function()
		local x, y, z = FishMotion.randomPoint(60, 220, -60, -3, 0, 0, 0)
		t:near(x, 60)
		t:eq(y, -60)
		t:near(z, 0)
	end)

	t:test("random points stay inside the ring and the band", function()
		for i = 0, 99 do
			local a = (i * 0.37) % 1
			local r = (i * 0.61) % 1
			local h = (i * 0.83) % 1
			local x, y, z = FishMotion.randomPoint(60, 220, -60, -3, a, r, h)
			local radius = math.sqrt(x * x + z * z)
			assert(radius >= 60 - 1e-6 and radius <= 220 + 1e-6, `radius {radius}`)
			assert(y >= -60 and y <= -3, `y {y}`)
		end
	end)

	t:test("bob and tail swing peak at a quarter period and return to zero", function()
		t:near(FishMotion.bob(0, 0.3, 2), 0)
		t:near(FishMotion.bob(0.125, 0.3, 2), 0.3)
		t:near(FishMotion.bob(0.25, 0.3, 2), 0, 1e-6)
		t:near(FishMotion.tailAngle(0.1, 0.5, 2.5), 0.5)
	end)
end
