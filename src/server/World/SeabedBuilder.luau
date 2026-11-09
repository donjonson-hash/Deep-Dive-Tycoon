--!strict
-- Dresses the lagoon seabed so the dive has something to look at: clusters of
-- rocks, corals of several shapes and tall seaweed, scattered over the
-- Lagoon's spawn ring. Seeded so every server matches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local SeabedBuilder = {}

local SEED = 11
local CLUSTERS = 90
local EDGE_MARGIN = 12 -- studs kept clear of the ring edges
local SINK = 0.6 -- bury bases a little so nothing floats over the sand
local CORAL_SCALE = 1.6 -- corals read better big at 50 m

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

-- Upright cylinder standing on `base` (cylinders lie along X by default).
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

---------------------------------------------------------------------------
-- Coral shapes
---------------------------------------------------------------------------

-- Several upright, slightly splayed branches.
local function branchCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(3, 6) do
		local height = rng:NextNumber(2.5, 5) * CORAL_SCALE
		local offset = Vector3.new(rng:NextNumber(-1.5, 1.5), 0, rng:NextNumber(-1.5, 1.5))
		pillar(
			height,
			0.35 * CORAL_SCALE,
			base + offset,
			rng:NextNumber(-0.35, 0.35),
			rng:NextNumber(0, 2 * math.pi),
			color,
			parent
		)
	end
end

-- A low dome.
local function brainCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local width = rng:NextNumber(2.5, 4.5) * CORAL_SCALE
	blob(
		Vector3.new(width, width * 0.6, width * rng:NextNumber(0.8, 1.1)),
		CFrame.new(base + Vector3.new(0, width * 0.3 - SINK, 0)),
		color,
		parent
	)
end

-- Thin upright plate.
local function fanCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local size = rng:NextNumber(2.5, 4) * CORAL_SCALE
	blob(
		Vector3.new(size, size * 1.1, 0.3),
		CFrame.new(base + Vector3.new(0, size * 0.55 - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
		color,
		parent
	)
end

-- Flat plate on a stalk.
local function tableCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local height = rng:NextNumber(2, 3.5) * CORAL_SCALE
	local width = rng:NextNumber(4, 6) * CORAL_SCALE
	pillar(height, 0.5 * CORAL_SCALE, base, 0, 0, color, parent)
	blob(
		Vector3.new(width, 0.6 * CORAL_SCALE, width * rng:NextNumber(0.7, 1)),
		CFrame.new(base + Vector3.new(0, height - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), rng:NextNumber(-0.1, 0.1)),
		color,
		parent
	)
end

-- Bundle of vertical tubes of different heights.
local function tubeCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(5, 8) do
		local height = rng:NextNumber(2, 5) * CORAL_SCALE
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		pillar(
			height,
			0.45 * CORAL_SCALE,
			base + offset,
			rng:NextNumber(-0.1, 0.1),
			0,
			color,
			parent
		)
	end
end

-- Stack of shrinking lumps.
local function towerCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local y = -SINK
	local width = rng:NextNumber(3, 4.5) * CORAL_SCALE
	for _ = 1, rng:NextInteger(3, 4) do
		local height = width * 0.6
		blob(
			Vector3.new(width, height, width * rng:NextNumber(0.85, 1.1)),
			CFrame.new(
				base
					+ Vector3.new(
						rng:NextNumber(-0.4, 0.4),
						y + height / 2,
						rng:NextNumber(-0.4, 0.4)
					)
			),
			color,
			parent
		)
		y += height * 0.75
		width *= 0.7
	end
end

-- A tuft of tall blades (four times the original height: they frame the dive).
local function seaweed(parent: Instance, base: Vector3, rng: Random)
	for i = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(16, 32)
		local offset = Vector3.new(rng:NextNumber(-4.8, 4.8), 0, rng:NextNumber(-4.8, 4.8))
		makePart({
			Name = "Seaweed",
			Size = Vector3.new(2, height, 0.8),
			CFrame = CFrame.new(base + offset + Vector3.new(0, height / 2 - SINK, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), 0),
			Color = if i % 2 == 0 then SEAWEED_DARK else SEAWEED,
			Material = Enum.Material.Grass,
		}, parent)
	end
end

local function rocks(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(1.5, 3.5)
		local offset = Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		blob(
			Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.3)),
			CFrame.new(base + offset + Vector3.new(0, size * 0.35 - SINK, 0)),
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
		-- Two to three corals of random shapes plus, often, a seaweed tuft.
		for _ = 1, rng:NextInteger(2, 3) do
			local color = CORAL_COLORS[rng:NextInteger(1, #CORAL_COLORS)]
			local spot = base + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
			CORAL_SHAPES[rng:NextInteger(1, #CORAL_SHAPES)](cluster, spot, rng, color)
		end
		if rng:NextNumber() < 0.6 then
			seaweed(
				cluster,
				base + Vector3.new(rng:NextNumber(-6, 6), 0, rng:NextNumber(-6, 6)),
				rng
			)
		end
		cluster.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return SeabedBuilder
