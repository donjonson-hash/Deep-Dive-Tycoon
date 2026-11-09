--!strict
-- Pure helpers for fish wandering around the island. Positions are plain numbers
-- (studs) so the math runs in Lune; the server turns them into Vector3s.

export type ZoneLike = {
	minDepth: number, -- meters
	maxDepth: number, -- meters
}

export type WorldLike = {
	surfaceY: number,
	studsPerMeter: number,
	oceanFloorMeters: number,
}

local FishMotion = {}

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

-- Vertical band (in studs) where fish of a zone may swim: minY is the deepest
-- point, maxY the shallowest. Nil when the zone lies entirely below the ocean floor.
function FishMotion.zoneBounds(
	zone: ZoneLike,
	world: WorldLike,
	surfaceMarginMeters: number,
	floorMarginMeters: number
): (number?, number?)
	local top = math.max(zone.minDepth, surfaceMarginMeters)
	local bottom = math.min(zone.maxDepth, world.oceanFloorMeters - floorMarginMeters)
	if bottom <= top then
		return nil, nil
	end
	return world.surfaceY - bottom * world.studsPerMeter, world.surfaceY - top * world.studsPerMeter
end

-- Random point in a ring around the origin between minRadius and maxRadius, at a
-- height between minY and maxY. Rolls are in [0, 1); the radius is area-weighted
-- so fish do not bunch up near the island.
function FishMotion.randomPoint(
	minRadius: number,
	maxRadius: number,
	minY: number,
	maxY: number,
	angleRoll: number,
	radiusRoll: number,
	heightRoll: number
): (number, number, number)
	local angle = angleRoll * 2 * math.pi
	local radius = math.sqrt(lerp(minRadius * minRadius, maxRadius * maxRadius, radiusRoll))
	return math.cos(angle) * radius, lerp(minY, maxY, heightRoll), math.sin(angle) * radius
end

-- Gentle up/down drift so a straight swim does not look like a conveyor belt.
function FishMotion.bob(time: number, amplitude: number, frequency: number): number
	return math.sin(time * frequency * 2 * math.pi) * amplitude
end

-- Tail swing angle in radians at a given time.
function FishMotion.tailAngle(time: number, maxRadians: number, frequency: number): number
	return math.sin(time * frequency * 2 * math.pi) * maxRadians
end

return FishMotion
