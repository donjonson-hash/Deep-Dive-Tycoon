--!strict
-- Pure oxygen math. The server owns the actual values; this module only computes them.

export type WarningLevel = "Ok" | "Low" | "Critical"

local Oxygen = {}

-- Applies passive drain over dt seconds. Returns the new value and whether the diver died.
function Oxygen.drain(current: number, drainPerSecond: number, dt: number): (number, boolean)
	local nextValue = math.max(0, current - drainPerSecond * dt)
	return nextValue, nextValue <= 0
end

-- Spends a fixed amount (e.g. catching a fish). Running out while spending is fatal.
function Oxygen.spend(current: number, cost: number): (number, boolean)
	local nextValue = math.max(0, current - cost)
	return nextValue, nextValue <= 0
end

function Oxygen.warningLevel(
	current: number,
	max: number,
	warningFraction: number,
	criticalFraction: number
): WarningLevel
	if max <= 0 then
		return "Critical"
	end
	local fraction = current / max
	if fraction <= criticalFraction then
		return "Critical"
	elseif fraction <= warningFraction then
		return "Low"
	end
	return "Ok"
end

return Oxygen
