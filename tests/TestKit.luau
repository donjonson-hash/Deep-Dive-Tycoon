--!strict
-- Minimal test helpers for Lune. Specs return function(t: TestKit) ... end.

local TestKit = {}
TestKit.__index = TestKit

export type TestKit = typeof(setmetatable(
	{} :: { passed: number, failures: { string }, prefix: string },
	TestKit
))

function TestKit.new(): TestKit
	return setmetatable({ passed = 0, failures = {}, prefix = "" }, TestKit)
end

function TestKit.test(self: TestKit, name: string, fn: () -> ())
	local ok, err = pcall(fn)
	if ok then
		self.passed += 1
	else
		table.insert(self.failures, `{self.prefix}{name}: {err}`)
	end
end

local function show(value: any): string
	if type(value) == "string" then
		return `"{value}"`
	end
	return tostring(value)
end

function TestKit.eq(_self: TestKit, actual: any, expected: any)
	if actual ~= expected then
		error(`expected {show(expected)}, got {show(actual)}`, 2)
	end
end

function TestKit.near(_self: TestKit, actual: number, expected: number, epsilon: number?)
	if math.abs(actual - expected) > (epsilon or 1e-9) then
		error(`expected ~{expected}, got {actual}`, 2)
	end
end

return TestKit
