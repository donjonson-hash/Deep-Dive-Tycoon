--!strict
-- Pure depth helpers. No Roblox APIs, so they run both in-game and in Lune tests.

export type ZoneLike = {
	id: string,
	minDepth: number,
	maxDepth: number,
}

local Depth = {}

-- Depth in meters below the water surface; 0 when at or above the surface.
function Depth.toMeters(y: number, surfaceY: number, studsPerMeter: number): number
	if y >= surfaceY then
		return 0
	end
	return (surfaceY - y) / studsPerMeter
end

-- Zone that contains the given depth, or nil when no zone covers it.
function Depth.zoneAt<Z>(zones: { Z & ZoneLike }, depth: number): (Z & ZoneLike)?
	for _, zone in zones do
		if depth >= zone.minDepth and depth < zone.maxDepth then
			return zone
		end
	end
	return nil
end

return Depth
