--!strict
-- Dresses the reef shelf so the Coral Reef zone reads as a biome: clusters of
-- branching, brain and fan corals plus seaweed, scattered over the terrace
-- between the island and the shelf edge. Seeded so every server matches.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ReefBuilder = {}

local SEED = 11
local CLUSTERS = 44
local EDGE_MARGIN = 12 -- studs kept clear of the island foot and the shelf edge
local SINK = 0.6 -- bury bases a little so nothing floats over the sand

local CORAL_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(80, 200, 190),
}
local SEAWEED = Color3.fromRGB(50, 140, 70)
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

-- Several upright, slightly splayed cylinders.
local function branchCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(2.5, 5)
		local tilt = rng:NextNumber(-0.35, 0.35)
		local yaw = rng:NextNumber(0, 2 * math.pi)
		local offset = Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1))
		makePart({
			Name = "Coral",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 0.7, 0.7),
			CFrame = CFrame.new(base + offset + Vector3.new(0, height / 2 - SINK, 0))
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(tilt, 0, math.pi / 2),
			Color = color,
		}, parent)
	end
end

-- A low dome.
local function brainCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local width = rng:NextNumber(2.5, 4.5)
	blob(
		Vector3.new(width, width * 0.6, width * rng:NextNumber(0.8, 1.1)),
		CFrame.new(base + Vector3.new(0, width * 0.3 - SINK, 0)),
		color,
		parent
	)
end

-- Thin upright plate.
local function fanCoral(parent: Instance, base: Vector3, rng: Random, color: Color3)
	local size = rng:NextNumber(2.5, 4)
	blob(
		Vector3.new(size, size * 1.1, 0.3),
		CFrame.new(base + Vector3.new(0, size * 0.55 - SINK, 0))
			* CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0),
		color,
		parent
	)
end

-- A tuft of tall thin blades.
local function seaweed(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(4, 8)
		local offset = Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
		makePart({
			Name = "Seaweed",
			Size = Vector3.new(0.5, height, 0.2),
			CFrame = CFrame.new(base + offset + Vector3.new(0, height / 2 - SINK, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, math.pi), 0),
			Color = SEAWEED,
			Material = Enum.Material.Grass,
		}, parent)
	end
end

local function rocks(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(1, 2.5)
		local offset = Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))
		blob(
			Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.3)),
			CFrame.new(base + offset + Vector3.new(0, size * 0.35 - SINK, 0)),
			ROCK,
			parent
		)
	end
end

local function reefRing(): Config.ZoneSpawn?
	for _, zone in Config.Zones do
		if zone.id == "CoralReef" then
			return zone.spawn
		end
	end
	return nil
end

function ReefBuilder.build(parent: Instance, shelfY: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = "Reef"

	local ring = reefRing()
	local minRadius = (if ring then ring.minRadius else Config.World.islandRadius) + EDGE_MARGIN
	local maxRadius = Config.World.shelfRadius - EDGE_MARGIN
	local rng = Random.new(SEED)

	for _ = 1, CLUSTERS do
		local angle = rng:NextNumber(0, 2 * math.pi)
		local radius = rng:NextNumber(minRadius, maxRadius)
		local base = Vector3.new(math.cos(angle) * radius, shelfY, math.sin(angle) * radius)

		local cluster = Instance.new("Model")
		cluster.Name = "Cluster"
		rocks(cluster, base, rng)
		for _ = 1, rng:NextInteger(2, 3) do
			local color = CORAL_COLORS[rng:NextInteger(1, #CORAL_COLORS)]
			local spot = base + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
			local kind = rng:NextInteger(1, 4)
			if kind == 1 then
				branchCoral(cluster, spot, rng, color)
			elseif kind == 2 then
				brainCoral(cluster, spot, rng, color)
			elseif kind == 3 then
				fanCoral(cluster, spot, rng, color)
			else
				seaweed(cluster, spot, rng)
			end
		end
		cluster.Parent = folder
	end

	folder.Parent = parent
	return folder
end

return ReefBuilder
