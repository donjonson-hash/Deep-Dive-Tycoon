--!strict
local TestKit = require("./TestKit")
local Depth = require("../src/shared/Logic/Depth")
local Config = require("../src/shared/Config")

return function(t: TestKit.TestKit)
	t:test("above surface is depth 0", function()
		t:eq(Depth.toMeters(5, 0, 3), 0)
		t:eq(Depth.toMeters(0, 0, 3), 0)
	end)

	t:test("converts studs below surface to meters", function()
		t:eq(Depth.toMeters(-30, 0, 3), 10)
		t:eq(Depth.toMeters(-60, 0, 3), 20)
	end)

	t:test("zone boundaries: min inclusive, max exclusive", function()
		local zones = {
			{ id = "A", minDepth = 0, maxDepth = 20 },
			{ id = "B", minDepth = 20, maxDepth = math.huge },
		}
		t:eq((Depth.zoneAt(zones, 0) :: any).id, "A")
		t:eq((Depth.zoneAt(zones, 19.99) :: any).id, "A")
		t:eq((Depth.zoneAt(zones, 20) :: any).id, "B")
		t:eq((Depth.zoneAt(zones, 5000) :: any).id, "B")
	end)

	t:test("the prototype lagoon covers every depth", function()
		t:eq((Depth.zoneAt(Config.Zones, 0) :: any).id, "Lagoon")
		t:eq((Depth.zoneAt(Config.Zones, 49) :: any).id, "Lagoon")
	end)

	t:test("negative depth has no zone", function()
		t:eq(Depth.zoneAt(Config.Zones, -1), nil)
	end)
end
