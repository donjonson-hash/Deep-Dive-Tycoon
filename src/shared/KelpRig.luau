--!strict
-- Geometry of a kelp stalk, shared by the server (initial pose) and the client
-- (animated pose), so both agree on where every part goes.
--
-- A stalk model (tagged KelpRig.TAG) holds parts "S1".."Sn" (stipe segments,
-- long axis Y) and "L1".."Ln" (one leaf per segment, long axis X) and these
-- attributes: BaseCFrame (CFrame on the sand, X = current direction),
-- Segments, SegLength, LeafLength (studs) and Phase (radians).

local KelpRig = {}

KelpRig.TAG = "Kelp"

-- Gentle surge: about 17° of extra bend at the tip, one cycle every ~5.5 s.
KelpRig.SWAY = {
	amplitude = 0.1, -- radians at the top joint
	frequency = 0.18, -- Hz
	lag = 0.7, -- radians of wave delay per joint
	lean = 0.02, -- radians per joint toward the current
}

-- Direction the current pushes the kelp (yaw of BaseCFrame's X axis).
KelpRig.CURRENT_YAW = math.rad(30)

local LEAF_TILT = math.rad(55) -- leaves angle up along the stipe
local LEAF_SPIRAL = 2.4 -- radians between successive leaves around the stipe

export type Spec = {
	segments: number,
	segLength: number, -- studs
	leafLength: number, -- studs
}

-- Segment centers and leaf CFrames for the given joint bend angles. Joints
-- bend about the base's Z axis, i.e. toward the base's X (the current).
function KelpRig.pose(base: CFrame, spec: Spec, angles: { number }): ({ CFrame }, { CFrame })
	local segments = table.create(spec.segments)
	local leaves = table.create(spec.segments)
	local joint = base
	for i = 1, spec.segments do
		joint = joint * CFrame.Angles(0, 0, -(angles[i] or 0))
		table.insert(segments, joint * CFrame.new(0, spec.segLength / 2, 0))
		joint = joint * CFrame.new(0, spec.segLength, 0)
		table.insert(
			leaves,
			joint
				* CFrame.Angles(0, i * LEAF_SPIRAL, 0)
				* CFrame.Angles(0, 0, LEAF_TILT)
				* CFrame.new(spec.leafLength / 2, 0, 0)
		)
	end
	return segments, leaves
end

return KelpRig
