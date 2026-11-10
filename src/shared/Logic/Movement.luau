--!strict
-- Pure movement speed. Roblox swims at Humanoid.WalkSpeed, so one number
-- covers walking and swimming; the fins only count in the water.

local Movement = {}

-- Speed in studs/s for a diver whose catch already slows them by
-- `weightMultiplier` (see Fishing.speedMultiplier).
function Movement.speed(
	base: number,
	weightMultiplier: number,
	inWater: boolean,
	finsMultiplier: number
): number
	return base * weightMultiplier * (if inWater then finsMultiplier else 1)
end

return Movement
