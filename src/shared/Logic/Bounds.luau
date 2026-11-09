--!strict
-- Pure box test for "is the player inside this area". Callers convert the world
-- position into the part's object space first (CFrame:PointToObjectSpace).

local Bounds = {}

-- True when (x, y, z) lies inside a box of half-extents (halfX, halfY, halfZ)
-- centered at the origin, stretched upward by extraUp. The stretch exists
-- because a character's root part floats about 3 studs above its feet.
function Bounds.contains(
	x: number,
	y: number,
	z: number,
	halfX: number,
	halfY: number,
	halfZ: number,
	extraUp: number
): boolean
	return math.abs(x) <= halfX and math.abs(z) <= halfZ and y >= -halfY and y <= halfY + extraUp
end

return Bounds
