--!strict
-- Dresses the lagoon seabed: patches of rocks and corals in thirteen shapes,
-- forests of giant kelp that the client sways, and vents leaking bubbles.
-- Seeded so every server matches.
--
-- Sizes are real-world meters converted with Config.World.studsPerMeter (a
-- Roblox character is ~5 studs ≈ 1.7 m). Corals use the upper end of what
-- real colonies reach (2–4 m), so the reef reads as old and lush.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local KelpRig = require(ReplicatedStorage.Shared.KelpRig)
local Sway = require(ReplicatedStorage.Shared.Logic.Sway)

local SeabedBuilder = {}

local SPM = Config.World.studsPerMeter
local function m(meters: number): number
	return meters * SPM
end

local SEED = 11
local CLUSTERS = 80
local KELP_CHANCE = 0.5 -- share of patches with a kelp tuft
local VENTS = 12
local EDGE_MARGIN = 14 -- studs kept clear of the ring edges
local SINK = m(0.15) -- bury bases a little so nothing floats over the sand
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y
local TAU = 2 * math.pi

local CORAL_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(80, 200, 190),
	Color3.fromRGB(240, 90, 90),
	Color3.fromRGB(120, 200, 110),
}
local SPONGE_COLORS = {
	Color3.fromRGB(190, 95, 60),
	Color3.fromRGB(220, 150, 60),
	Color3.fromRGB(150, 80, 140),
}
local STONE_CORAL = Color3.fromRGB(205, 180, 135)
local TUBE_MOUTH = Color3.fromRGB(40, 25, 30)
local CLAM_SHELL = Color3.fromRGB(210, 205, 185)
local CLAM_MANTLE =
	{ Color3.fromRGB(40, 110, 220), Color3.fromRGB(130, 60, 200), Color3.fromRGB(30, 170, 140) }
local KELP_STIPE = Color3.fromRGB(110, 95, 40)
local KELP_LEAVES = {
	Color3.fromRGB(140, 120, 45),
	Color3.fromRGB(105, 115, 40),
	Color3.fromRGB(85, 120, 55),
}
local ROCK = Color3.fromRGB(110, 110, 105)
local BUBBLE = Color3.fromRGB(220, 240, 255)

---------------------------------------------------------------------------
-- Part helpers
---------------------------------------------------------------------------

local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.Pebble
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

-- Ellipsoid the size of `size`.
local function blob(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): BasePart
	local part = makePart({ Name = name, Size = size, CFrame = cframe, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Cylinder of `length` and `radius` growing from `from` along from.UpVector.
local function rod(
	name: string,
	from: CFrame,
	length: number,
	radius: number,
	color: Color3,
	parent: Instance
)
	makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(length, radius * 2, radius * 2),
		CFrame = from * CFrame.new(0, length / 2, 0) * UPRIGHT,
		Color = color,
	}, parent)
end

-- Flat disc (a very short upright cylinder) centered on `at`.
local function disc(
	name: string,
	at: CFrame,
	diameter: number,
	thickness: number,
	color: Color3,
	parent: Instance
)
	makePart({
		Name = name,
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(thickness, diameter, diameter),
		CFrame = at * UPRIGHT,
		Color = color,
	}, parent)
end

local function jitter(rng: Random, meters: number): Vector3
	return Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * m(meters)
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- A frame on the sand at `base`, turned to a random yaw.
local function ground(base: Vector3, rng: Random): CFrame
	return CFrame.new(base - Vector3.new(0, SINK, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
end

---------------------------------------------------------------------------
-- Coral shapes
---------------------------------------------------------------------------

type Shape = (parent: Instance, base: Vector3, rng: Random) -> ()

-- Staghorn: branches 1–2 m long, each forking once or twice.
local function staghorn(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, CORAL_COLORS)
	for _ = 1, rng:NextInteger(5, 8) do
		local length = m(rng:NextNumber(1, 2))
		local radius = m(0.1)
		local stem = ground(base + jitter(rng, 0.6), rng)
			* CFrame.Angles(rng:NextNumber(-0.6, 0.6), 0, 0)
		rod("Staghorn", stem, length, radius, color, parent)
		local fork = stem * CFrame.new(0, length * 0.55, 0)
		for _ = 1, rng:NextInteger(1, 2) do
			local branch = fork
				* CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
				* CFrame.Angles(rng:NextNumber(0.4, 0.8), 0, 0)
			rod("Staghorn", branch, length * 0.5, radius * 0.8, color, parent)
		end
	end
end

-- Elkhorn: broad flat antlers fanning out and up, 1.2–2.2 m.
local function elkhorn(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, { STONE_CORAL, Color3.fromRGB(220, 160, 90) })
	local root = ground(base, rng)
	for i = 1, rng:NextInteger(4, 6) do
		local length = m(rng:NextNumber(1.2, 2.2))
		local antler = root
			* CFrame.Angles(0, i * 1.2 + rng:NextNumber(-0.3, 0.3), 0)
			* CFrame.Angles(rng:NextNumber(0.5, 0.95), 0, 0)
		blob(
			"Elkhorn",
			Vector3.new(m(0.6), length, m(0.12)),
			antler * CFrame.new(0, length / 2, 0),
			color,
			parent
		)
		-- Split tip.
		for _, side in { -1, 1 } do
			blob(
				"Elkhorn",
				Vector3.new(m(0.3), length * 0.4, m(0.1)),
				antler
					* CFrame.new(0, length * 0.95, 0)
					* CFrame.Angles(0, 0, side * 0.5)
					* CFrame.new(0, length * 0.18, 0),
				color,
				parent
			)
		end
	end
end

-- Brain coral: a dome 1.5–3.5 m across, sometimes with a smaller twin.
local function brainCoral(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, CORAL_COLORS)
	local width = m(rng:NextNumber(1.5, 3.5))
	blob(
		"BrainCoral",
		Vector3.new(width, width * 0.55, width * rng:NextNumber(0.8, 1.1)),
		CFrame.new(base + Vector3.new(0, width * 0.27 - SINK, 0)),
		color,
		parent
	)
	if rng:NextNumber() < 0.5 then
		local small = width * 0.5
		blob(
			"BrainCoral",
			Vector3.new(small, small * 0.55, small),
			CFrame.new(base + Vector3.new(width * 0.55, small * 0.27 - SINK, width * 0.2)),
			color,
			parent
		)
	end
end

-- Sea fan: a lacy plate 1.5–3 m wide on a short stalk.
local function seaFan(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, CORAL_COLORS)
	local size = m(rng:NextNumber(1.5, 3))
	local root = ground(base, rng)
	rod("FanStalk", root, m(0.3), m(0.06), color, parent)
	local plate = blob(
		"SeaFan",
		Vector3.new(size, size * 1.1, m(0.04)),
		root * CFrame.new(0, m(0.25) + size * 0.55, 0),
		color,
		parent
	)
	plate.Transparency = 0.15
end

-- Table coral: a plate 2.5–4 m across on a stalk, sometimes two tiers.
local function tableCoral(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, CORAL_COLORS)
	local root = ground(base, rng)
	local height = m(rng:NextNumber(0.6, 1.2))
	local width = m(rng:NextNumber(2.5, 4))
	rod("TableStalk", root, height, m(0.25), color, parent)
	blob(
		"TableCoral",
		Vector3.new(width, m(0.18), width * rng:NextNumber(0.7, 1)),
		root * CFrame.new(0, height, 0),
		color,
		parent
	)
	if rng:NextNumber() < 0.4 then
		local upper = width * 0.55
		rod("TableStalk", root * CFrame.new(0, height, 0), height * 0.6, m(0.15), color, parent)
		blob(
			"TableCoral",
			Vector3.new(upper, m(0.15), upper),
			root * CFrame.new(0, height * 1.6, 0),
			color,
			parent
		)
	end
end

-- Tube sponges: 4–7 tubes 1–2.5 m tall with dark open mouths.
local function tubeSponge(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, SPONGE_COLORS)
	for _ = 1, rng:NextInteger(4, 7) do
		local height = m(rng:NextNumber(1, 2.5))
		local radius = m(rng:NextNumber(0.15, 0.25))
		local root = ground(base + jitter(rng, 0.5), rng)
			* CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, 0)
		rod("TubeSponge", root, height, radius, color, parent)
		disc(
			"TubeMouth",
			root * CFrame.new(0, height + 0.01, 0),
			radius * 1.6,
			m(0.03),
			TUBE_MOUTH,
			parent
		)
	end
end

-- Barrel sponge: a fat cylinder 1.2–2 m tall with a flared rim.
local function barrelSponge(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, SPONGE_COLORS)
	local root = ground(base, rng)
	local height = m(rng:NextNumber(1.2, 2))
	local radius = m(rng:NextNumber(0.5, 0.8))
	rod("BarrelSponge", root, height, radius, color, parent)
	disc("BarrelRim", root * CFrame.new(0, height, 0), radius * 2.3, m(0.2), color, parent)
	disc(
		"BarrelMouth",
		root * CFrame.new(0, height + m(0.11), 0),
		radius * 1.7,
		m(0.02),
		TUBE_MOUTH,
		parent
	)
end

-- Pillar coral: 4–8 upright fingers 1.5–3 m tall with rounded tops.
local function pillarCoral(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, { STONE_CORAL, Color3.fromRGB(190, 170, 120) })
	for _ = 1, rng:NextInteger(4, 8) do
		local height = m(rng:NextNumber(1.5, 3))
		local radius = m(rng:NextNumber(0.2, 0.3))
		local root = ground(base + jitter(rng, 0.7), rng)
		rod("PillarCoral", root, height, radius, color, parent)
		blob("PillarTop", Vector3.one * radius * 2, root * CFrame.new(0, height, 0), color, parent)
	end
end

-- Mushroom corals: free-living discs 0.6–1.2 m lying on the sand.
local function mushroomCoral(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = m(rng:NextNumber(0.6, 1.2))
		blob(
			"MushroomCoral",
			Vector3.new(size, size * 0.25, size * rng:NextNumber(0.75, 1)),
			ground(base + jitter(rng, 1.2), rng) * CFrame.new(0, size * 0.1, 0),
			pick(rng, CORAL_COLORS),
			parent
		)
	end
end

-- Soft coral: a bushy tree of puffs 1–2 m tall.
local function softCoral(parent: Instance, base: Vector3, rng: Random)
	local color = pick(rng, CORAL_COLORS)
	local root = ground(base, rng)
	local height = m(rng:NextNumber(0.6, 1.2))
	rod("SoftStalk", root, height, m(0.15), color, parent)
	local crown = root * CFrame.new(0, height, 0)
	for _ = 1, rng:NextInteger(8, 14) do
		local size = m(rng:NextNumber(0.25, 0.5))
		local offset = Vector3.new(
			rng:NextNumber(-0.8, 0.8),
			rng:NextNumber(0, 0.8),
			rng:NextNumber(-0.8, 0.8)
		)
		blob("SoftCoral", Vector3.one * size, crown * CFrame.new(offset * SPM), color, parent)
	end
end

-- Sea anemone: a squat column ringed with tentacles reaching up and out.
local function anemone(parent: Instance, base: Vector3, rng: Random)
	local color = pick(
		rng,
		{ Color3.fromRGB(230, 80, 150), Color3.fromRGB(120, 210, 120), Color3.fromRGB(240, 150, 80) }
	)
	local root = ground(base, rng)
	local width = m(rng:NextNumber(0.6, 0.9))
	blob(
		"AnemoneBody",
		Vector3.new(width, width * 0.7, width),
		root * CFrame.new(0, width * 0.3, 0),
		color,
		parent
	)
	local count = 14
	for i = 1, count do
		local length = m(rng:NextNumber(0.4, 0.7))
		local tentacle = root
			* CFrame.new(0, width * 0.6, 0)
			* CFrame.Angles(0, i / count * TAU, 0)
			* CFrame.new(0, 0, width * 0.3)
			* CFrame.Angles(rng:NextNumber(0.3, 0.8), 0, 0)
		rod("Tentacle", tentacle, length, m(0.04), color:Lerp(Color3.new(1, 1, 1), 0.35), parent)
	end
end

-- Sea whips: 6–10 thin rods 2–4 m tall swaying off vertical.
local function seaWhip(parent: Instance, base: Vector3, rng: Random)
	local color = pick(
		rng,
		{ Color3.fromRGB(230, 70, 60), Color3.fromRGB(250, 200, 60), Color3.fromRGB(240, 120, 40) }
	)
	for _ = 1, rng:NextInteger(6, 10) do
		local root = ground(base + jitter(rng, 0.5), rng)
			* CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, 0)
		rod("SeaWhip", root, m(rng:NextNumber(2, 4)), m(0.04), color, parent)
	end
end

-- Giant clam: two ridged shells gaping open around a vivid mantle.
local function giantClam(parent: Instance, base: Vector3, rng: Random)
	local root = ground(base, rng)
	local length = m(rng:NextNumber(1, 1.3))
	for _, side in { -1, 1 } do
		blob(
			"ClamShell",
			Vector3.new(length, length * 0.35, length * 0.45),
			root
				* CFrame.new(0, length * 0.15, side * length * 0.12)
				* CFrame.Angles(side * 0.45, 0, 0),
			CLAM_SHELL,
			parent
		)
	end
	local mantle = blob(
		"ClamMantle",
		Vector3.new(length * 0.9, length * 0.12, length * 0.3),
		root * CFrame.new(0, length * 0.28, 0),
		pick(rng, CLAM_MANTLE),
		parent
	)
	mantle.Material = Enum.Material.Neon
end

local SHAPES: { Shape } = {
	staghorn,
	elkhorn,
	brainCoral,
	seaFan,
	tableCoral,
	tubeSponge,
	barrelSponge,
	pillarCoral,
	mushroomCoral,
	softCoral,
	anemone,
	seaWhip,
	giantClam,
}

-- Boulders 0.6–2.2 m.
local function rocks(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = m(rng:NextNumber(0.6, 2.2))
		local rock = blob(
			"Rock",
			Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.3)),
			CFrame.new(base + jitter(rng, 1.5) + Vector3.new(0, size * 0.3 - SINK, 0)),
			ROCK,
			parent
		)
		rock.Material = Enum.Material.Slate
	end
end

---------------------------------------------------------------------------
-- Giant kelp: segmented stalks the client sways (see KelpRig, KelpSway)
---------------------------------------------------------------------------

local function kelp(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local height = m(rng:NextNumber(12, 22))
		local spec: KelpRig.Spec = {
			segments = 5,
			segLength = height / 5,
			leafLength = m(rng:NextNumber(1.2, 2)),
		}
		local baseCFrame = CFrame.new(base + jitter(rng, 1.8) - Vector3.new(0, SINK, 0))
			* CFrame.Angles(0, KelpRig.CURRENT_YAW + rng:NextNumber(-0.3, 0.3), 0)
		local phase = rng:NextNumber(0, TAU)
		local sway = KelpRig.SWAY
		local angles = Sway.angles(
			0,
			phase,
			spec.segments,
			sway.amplitude,
			sway.frequency,
			sway.lag,
			sway.lean
		)
		local segments, leaves = KelpRig.pose(baseCFrame, spec, angles)

		local model = Instance.new("Model")
		model.Name = "Kelp"
		-- Stream the whole stalk at once so the client never sees half of it.
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("BaseCFrame", baseCFrame)
		model:SetAttribute("Segments", spec.segments)
		model:SetAttribute("SegLength", spec.segLength)
		model:SetAttribute("LeafLength", spec.leafLength)
		model:SetAttribute("Phase", phase)

		local leafColor = pick(rng, KELP_LEAVES)
		for i, cframe in segments do
			makePart({
				Name = `S{i}`,
				Size = Vector3.new(m(0.12), spec.segLength * 1.03, m(0.12)),
				CFrame = cframe,
				Color = KELP_STIPE,
				Material = Enum.Material.SmoothPlastic,
			}, model)
		end
		for i, cframe in leaves do
			blob(`L{i}`, Vector3.new(spec.leafLength, m(0.03), m(0.45)), cframe, leafColor, model)
		end

		CollectionService:AddTag(model, KelpRig.TAG)
		model.Parent = parent
	end
end

---------------------------------------------------------------------------
-- Bubble vents
---------------------------------------------------------------------------

local function vent(parent: Instance, base: Vector3, rng: Random)
	local rock = blob(
		"VentRock",
		Vector3.new(m(1.2), m(0.6), m(1)),
		CFrame.new(base + Vector3.new(0, m(0.2) - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, TAU), 0),
		ROCK,
		parent
	)
	rock.Material = Enum.Material.Slate

	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, m(0.3), 0)
	attachment.Parent = rock

	local bubbles = Instance.new("ParticleEmitter")
	bubbles.Name = "Bubbles"
	bubbles.Rate = 3
	bubbles.Lifetime = NumberRange.new(10, 14)
	bubbles.Speed = NumberRange.new(4, 6)
	bubbles.SpreadAngle = Vector2.new(8, 8)
	bubbles.EmissionDirection = Enum.NormalId.Top
	bubbles.Acceleration = Vector3.new(0, 1, 0)
	bubbles.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	bubbles.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	bubbles.Color = ColorSequence.new(BUBBLE)
	bubbles.LightEmission = 0.3
	bubbles.Parent = attachment
end

---------------------------------------------------------------------------

local function lagoonRing(): Config.ZoneSpawn?
	for _, zone in Config.Zones do
		if zone.id == "Lagoon" then
			return zone.spawn
		end
	end
	return nil
end

function SeabedBuilder.build(parent: Instance, floorY: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Seabed"

	local ring = lagoonRing()
	local minRadius = (if ring then ring.minRadius else Config.World.islandRadius) + EDGE_MARGIN
	local maxRadius = (if ring then ring.maxRadius else Config.World.oceanSize / 2) - EDGE_MARGIN
	local rng = Random.new(SEED)

	local function randomSpot(): Vector3
		local angle = rng:NextNumber(0, TAU)
		local radius = rng:NextNumber(minRadius, maxRadius)
		return Vector3.new(math.cos(angle) * radius, floorY, math.sin(angle) * radius)
	end

	for _ = 1, CLUSTERS do
		local base = randomSpot()
		local cluster = Instance.new("Model")
		cluster.Name = "Reef"
		rocks(cluster, base, rng)
		for _ = 1, rng:NextInteger(3, 4) do
			pick(rng, SHAPES)(cluster, base + jitter(rng, 2.5), rng)
		end
		cluster.Parent = folder

		if rng:NextNumber() < KELP_CHANCE then
			kelp(folder, base + jitter(rng, 3), rng)
		end
	end

	for _ = 1, VENTS do
		vent(folder, randomSpot(), rng)
	end

	folder.Parent = parent
	return folder
end

return SeabedBuilder
