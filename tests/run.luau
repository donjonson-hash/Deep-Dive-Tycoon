--!strict
-- Runs all specs: `lune run tests/run`
local process = require("@lune/process")
local TestKit = require("./TestKit")

local specs: { [string]: (TestKit.TestKit) -> () } = {
	Config = require("./Config.spec"),
	Depth = require("./Depth.spec"),
	Oxygen = require("./Oxygen.spec"),
	Pools = require("./Pools.spec"),
	Fishing = require("./Fishing.spec"),
}

local kit = TestKit.new()
for name, spec in specs do
	kit.prefix = `{name} > `
	spec(kit)
end

for _, failure in kit.failures do
	print(`FAIL {failure}`)
end
print(`{kit.passed} passed, {#kit.failures} failed`)
process.exit(if #kit.failures == 0 then 0 else 1)
