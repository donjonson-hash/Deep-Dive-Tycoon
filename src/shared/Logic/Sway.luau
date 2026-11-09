--!strict
-- Pure math for swaying kelp. A stalk is a chain of segments; each joint bends
-- by an angle, and the angles add up along the chain. A wave runs from the
-- root to the tip (`lag` per joint) and joints higher up bend more, so the
-- base stays planted while the top drifts with the current.

local Sway = {}

-- Bend angle (radians) of each of `count` joints at `time` seconds.
-- `lean` is a constant bend per joint (the mean current), `amplitude` the
-- extra swing at the top joint, `frequency` in Hz.
function Sway.angles(
	time: number,
	phase: number,
	count: number,
	amplitude: number,
	frequency: number,
	lag: number,
	lean: number
): { number }
	local out = table.create(count)
	for i = 1, count do
		local weight = i / count
		out[i] = lean
			+ amplitude * weight * math.sin(2 * math.pi * frequency * time + phase - i * lag)
	end
	return out
end

return Sway
