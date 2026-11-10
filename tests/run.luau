--!strict
-- Runs all specs: `lune run tests/run`
local process = require("@lune/process")
local TestKit = require("./TestKit")

-- Ordered list so runs and failure output are deterministic.
local specs: { { name: string, run: (TestKit.TestKit) -> () } } = {
	{ name = "Config", run = require("./Config.spec") },
	{ name = "Depth", run = require("./Depth.spec") },
	{ name = "Oxygen", run = require("./Oxygen.spec") },
	{ name = "Pools", run = require("./Pools.spec") },
	{ name = "Fishing", run = require("./Fishing.spec") },
	{ name = "FishMotion", run = require("./FishMotion.spec") },
	{ name = "Net", run = require("./Net.spec") },
	{ name = "Market", run = require("./Market.spec") },
	{ name = "Bounds", run = require("./Bounds.spec") },
	{ name = "Eggs", run = require("./Eggs.spec") },
	{ name = "Sway", run = require("./Sway.spec") },
	{ name = "Movement", run = require("./Movement.spec") },
}

local kit = TestKit.new()
for _, spec in specs do
	kit.prefix = `{spec.name} > `
	spec.run(kit)
end

for _, failure in kit.failures do
	print(`FAIL {failure}`)
end
print(`{kit.passed} passed, {#kit.failures} failed`)
process.exit(if #kit.failures == 0 then 0 else 1)
