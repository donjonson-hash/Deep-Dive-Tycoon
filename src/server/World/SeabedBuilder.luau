--!strict
-- Dresses the lagoon seabed so the dive has something to look at: clusters of
-- rocks, corals of several shapes and tall seaweed, scattered over the
-- Lagoon's spawn ring. Seeded so every server matches.
--
-- Sizes are real-world meters converted with Config.World.studsPerMeter, so
-- they sit right next to the player (a Roblox character is ~5 studs ≈ 1.7 m).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SeabedBuilder = {}

local SPM = Config.World.studsPerMeter
local function m(meters: number): number
	return meters * SPM
end

local SEED = 11
local CLUSTERS = 90
local EDGE_MARGIN = 12 -- studs kept clear of the ring edges
local SINK = m(0.1) -- bury bases a little so nothing floats over the sand

local CORAL_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(80, 200, 190),
	Color3.fromRGB(240, 90, 90),
}
local SEAWEED = Color3.fromRGB(50, 140, 70)
local SEAWEED_DARK = Color3.fromRGB(35, 105, 55)
local ROCK = Color3.fromRGB(110, 110, 105)

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

local function blob(size: Vector3, cframe: CFrame, color: Color3, parent: Instance): BasePart
	local part = makePart({ Name = "Coral", Size = size, CFrame = cframe, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

-- Upright cylinder standing on `base`, sizes in studs (cylinders lie along X).
local function pillar(
	height: number,
	radius: number,
	base: Vector3,
	tilt: number,
	yaw: number,
	color: Color3,
	parent: Instance
)
	makePart({
		Name = "Coral",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, radius * 2, radius * 2),
		CFrame = CFrame.new(base + Vector3.new(0, height / 2 - SINK, 0))
			* CFrame.Angles(0, yaw, 0)
			* CFrame.Angles(tilt, 0, math.pi / 2),
		Color = color,
	}, parent)
end

local function jitter(rng: Random, meters: number): Vector3
	return Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * m(meters)
end

---------------------------------------------------------------------------
-- Coral shapes, sized like their real counterparts
---------------------------------------------------------------------------

-- Staghorn-style colony: thin branches 0.5–1.4 m tall, splayed.
local function branchCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(4, 8) do
		pillar(
			m(rng:NextNumber(0.5, 1.4)),
			m(0.08),
			base + jitter(rng, 0.4),
			rng:NextNumber(-0.45, 0.45),
			rng:NextNumber(0, 2 * math.pi),
			color,
			parent
		)
	end
end

-- Brain coral: a dome 0.6–1.8 m across.
local function brainCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local width = m(rng:NextNumber(0.6, 1.8))
	blob(
		Vector3.new(width, width * 0.55, width * rng:NextNumber(0.8, 1.1)),
		CFrame.new(base + Vector3.new(0, width * 0.27 - SINK, 0)),
		color,
		parent
	)
end

-- Sea fan: a thin upright plate 0.6–1.4 m wide.
local function fanCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local size = m(rng:NextNumber(0.6, 1.4))
	blob(
		Vector3.new(size, size * 1.1, m(0.04)),
		CFrame.new(base + Vector3.new(0, size * 0.55 - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
		color,
		parent
	)
end

-- Table coral: a plate 1–2.2 m across on a short stalk.
local function tableCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local height = m(rng:NextNumber(0.3, 0.6))
	local width = m(rng:NextNumber(1, 2.2))
	pillar(height, m(0.12), base, 0, 0, color, parent)
	blob(
		Vector3.new(width, m(0.12), width * rng:NextNumber(0.7, 1)),
		CFrame.new(base + Vector3.new(0, height - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.1, 0.1)),
		color,
		parent
	)
end

-- Tube sponge bundle: 5–9 tubes 0.3–1 m tall.
local function tubeCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(5, 9) do
		pillar(
			m(rng:NextNumber(0.3, 1.0)),
			m(rng:NextNumber(0.07, 0.11)),
			base + jitter(rng, 0.3),
			rng:NextNumber(-0.1, 0.1),
			0,
			color,
			parent
		)
	end
end

-- Pillar coral: a stack of shrinking lumps, up to ~1.5 m tall.
local function towerCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local y = -SINK
	local width = m(rng:NextNumber(0.7, 1.1))
	for _ = 1, rng:NextInteger(3, 4) do
		local height = width * 0.6
		blob(
			Vector3.new(width, height, width * rng:NextNumber(0.85, 1.1)),
			CFrame.new(base + jitter(rng, 0.08) + Vector3.new(0, y + height / 2, 0)),
			color,
			parent
		)
		y += height * 0.75
		width *= 0.7
	end
end

-- Kelp-like tuft: blades 5.5–10.5 m tall frame the dive.
local function seaweed(parent: Instance, base: Vector3, rng: Random)
	for i = 1, rng:NextInteger(3, 5) do
		local height = m(rng:NextNumber(5.5, 10.5))
		makePart({
			Name = "Seaweed",
			Size = Vector3.new(m(0.65), height, m(0.25)),
			CFrame = CFrame.new(base + jitter(rng, 1.6) + Vector3.new(0, height / 2 - SINK, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), 0),
			Color = if i % 2 == 0 then SEAWEED_DARK else SEAWEED,
			Material = Enum.Material.Grass,
		}, parent)
	end
end

-- Boulders 0.4–1.4 m.
local function rocks(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = m(rng:NextNumber(0.4, 1.4))
		blob(
			Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.3)),
			CFrame.new(base + jitter(rng, 1) + Vector3.new(0, size * 0.35 - SINK, 0)),
			ROCK,
			parent
		)
	end
end

local CORAL_SHAPES = { branchCoral, brainCoral, fanCoral, tableCoral, tubeCoral, towerCoral }

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

	for _ = 1, CLUSTERS do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local base = Vector3.new(math.cos(angle) * radius, floorY, math.sin(angle) * radius)

		local cluster = Instance.new("Model")
		cluster.Name = "Cluster"
		rocks(cluster, base, rng)
		-- Real reefs are dense: three to five corals per patch, often kelp.
		for _ = 1, rng:NextInteger(3, 5) do
			local color = CORAL_COLORS[rng:NextInteger(1, #CORAL_COLORS)]
			CORAL_SHAPES[rng:NextInteger(1, #CORAL_SHAPES)](
				cluster,
				base + jitter(rng, 1.5),
				rng,
				color
			)
		end
		if rng:NextNumber() < 0.6 then
			seaweed(cluster, base + jitter(rng, 2), rng)
		end
		cluster.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return SeabedBuilder
