--!strict
-- Builds the greybox prototype map at server start: ocean, island, pier with
-- training pools, diving board and market stall. Everything is driven by Config,
-- so the layout lives in git instead of a binary place file.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local WOOD = Color3.fromRGB(150, 105, 60)
local POOL_WATER = Color3.fromRGB(80, 190, 255)
local STALL = Color3.fromRGB(220, 90, 60)

local PIER_LENGTH = 120
local PIER_WIDTH = 12
local POOL_SIZE = 10
local POOL_SPACING = 30
local TERRAIN_TILE = 200 -- fill the ocean in tiles to stay under terrain write limits

local function makePart(className: string?, props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new((className or "Part") :: any) :: BasePart
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function addLabel(adornee: BasePart, text: string, offsetY: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 60)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = 150

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui

	gui.Parent = adornee
end

-- The default Studio "Baseplate" template ships a baseplate and spawn that would cut
-- through the ocean. Remove them for the session and say so in the output.
local function removeTemplateLeftovers()
	for _, name in { "Baseplate", "SpawnLocation" } do
		local leftover = Workspace:FindFirstChild(name)
		if leftover then
			warn(
				`[MapBuilder] Removing template {name} for this session; delete it in Studio to silence this.`
			)
			leftover:Destroy()
		end
	end
end

local function buildTerrain()
	local world = Config.World
	local terrain = Workspace.Terrain
	local floorY = world.surfaceY - world.oceanFloorMeters * world.studsPerMeter
	local waterHeight = world.surfaceY - floorY
	local half = world.oceanSize / 2

	for x = -half, half - TERRAIN_TILE, TERRAIN_TILE do
		for z = -half, half - TERRAIN_TILE, TERRAIN_TILE do
			local centerX = x + TERRAIN_TILE / 2
			local centerZ = z + TERRAIN_TILE / 2
			terrain:FillBlock(
				CFrame.new(centerX, floorY + waterHeight / 2, centerZ),
				Vector3.new(TERRAIN_TILE, waterHeight, TERRAIN_TILE),
				Enum.Material.Water
			)
			terrain:FillBlock(
				CFrame.new(centerX, floorY - 8, centerZ),
				Vector3.new(TERRAIN_TILE, 16, TERRAIN_TILE),
				Enum.Material.Sand
			)
		end
	end

	-- Island: a sand column from the seabed to above the surface, grass on top.
	local islandHeight = world.islandTopY - floorY
	terrain:FillCylinder(
		CFrame.new(0, floorY + islandHeight / 2, 0),
		islandHeight,
		world.islandRadius,
		Enum.Material.Sand
	)
	terrain:FillCylinder(
		CFrame.new(0, world.islandTopY - 1, 0),
		2,
		world.islandRadius - 6,
		Enum.Material.Grass
	)
end

local function buildPool(
	pool: Config.Pool,
	index: number,
	pierStartX: number,
	deckY: number,
	parent: Instance
)
	-- Pools sit on platforms beside the pier, alternating sides, so the walkway stays clear.
	local side = if index % 2 == 1 then 1 else -1
	local x = pierStartX + 25 + (index - 1) * POOL_SPACING
	local z = side * (PIER_WIDTH / 2 + POOL_SIZE / 2 + 1)

	local model = Instance.new("Model")
	model.Name = pool.id
	model:SetAttribute("PoolId", pool.id)

	makePart(nil, {
		Name = "Platform",
		Size = Vector3.new(POOL_SIZE + 2, 1, POOL_SIZE + 2),
		CFrame = CFrame.new(x, deckY - 0.5, z),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, model)

	local water = makePart(nil, {
		Name = "PoolWater",
		Size = Vector3.new(POOL_SIZE, 2.5, POOL_SIZE),
		CFrame = CFrame.new(x, deckY + 1.25, z),
		Color = POOL_WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.5,
		CanCollide = false,
	}, model)
	water:SetAttribute("PoolId", pool.id)

	-- Low rim on the three outer sides; the side facing the pier stays open.
	local rimHeight = 1
	local rimY = deckY + rimHeight / 2
	local outerZ = z + side * (POOL_SIZE / 2 + 0.5)
	makePart(nil, {
		Name = "RimOuter",
		Size = Vector3.new(POOL_SIZE + 2, rimHeight, 1),
		CFrame = CFrame.new(x, rimY, outerZ),
		Color = WOOD,
		Material = Enum.Material.Wood,
	}, model)
	for _, dx in { -1, 1 } do
		makePart(nil, {
			Name = "RimSide",
			Size = Vector3.new(1, rimHeight, POOL_SIZE + 1),
			CFrame = CFrame.new(x + dx * (POOL_SIZE / 2 + 0.5), rimY, z + side * 0.5),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, model)
	end

	local text = `{pool.name}\n+{pool.gainPerTick} O₂ / {Config.Oxygen.poolTickSeconds} с`
	if pool.unlockMaxO2 > 0 then
		text ..= `\nоткрывается с {pool.unlockMaxO2} O₂`
	end
	addLabel(water, text, 5)

	model.Parent = parent
end

local function buildPier(parent: Instance)
	local world = Config.World
	local deckY = world.islandTopY
	local pierStartX = world.islandRadius - 8

	local pier = Instance.new("Folder")
	pier.Name = "Pier"

	makePart(nil, {
		Name = "Deck",
		Size = Vector3.new(PIER_LENGTH, 1, PIER_WIDTH),
		CFrame = CFrame.new(pierStartX + PIER_LENGTH / 2, deckY - 0.5, 0),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, pier)

	-- Posts from the deck down below the surface, both sides, every 12 studs.
	local postBottom = world.surfaceY - 12
	local postHeight = deckY - postBottom
	for x = pierStartX + 12, pierStartX + PIER_LENGTH, 12 do
		for _, side in { -1, 1 } do
			makePart(nil, {
				Name = "Post",
				Size = Vector3.new(1.5, postHeight, 1.5),
				CFrame = CFrame.new(x, postBottom + postHeight / 2, side * (PIER_WIDTH / 2 - 0.75)),
				Color = WOOD,
				Material = Enum.Material.Wood,
			}, pier)
		end
	end

	local pools = Instance.new("Folder")
	pools.Name = "Pools"
	for index, pool in Config.Pools do
		buildPool(pool, index, pierStartX, deckY, pools)
	end
	pools.Parent = pier

	-- Diving board at the far end: the way into the ocean.
	local board = makePart(nil, {
		Name = "DivingBoard",
		Size = Vector3.new(8, 0.6, 4),
		CFrame = CFrame.new(pierStartX + PIER_LENGTH + 4, deckY - 0.3, 0),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.SmoothPlastic,
	}, pier)
	addLabel(board, "Прыжок в океан ↓", 4)

	pier.Parent = parent
end

local function buildIsland(parent: Instance)
	local world = Config.World
	local topY = world.islandTopY

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "IslandSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.CFrame = CFrame.new(0, topY + 0.5, 0)
	spawn.Neutral = true
	spawn.Duration = 0 -- no spawn force field
	spawn.Parent = parent

	-- Market stall: visual only for now; selling arrives with the market feature.
	local market = Instance.new("Model")
	market.Name = "Market"
	local stallZ = -25
	makePart(nil, {
		Name = "Counter",
		Size = Vector3.new(14, 3, 4),
		CFrame = CFrame.new(0, topY + 1.5, stallZ),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	}, market)
	local roof = makePart(nil, {
		Name = "Roof",
		Size = Vector3.new(16, 0.6, 8),
		CFrame = CFrame.new(0, topY + 8, stallZ - 1),
		Color = STALL,
		Material = Enum.Material.Fabric,
	}, market)
	for _, dx in { -7, 7 } do
		makePart(nil, {
			Name = "Pole",
			Size = Vector3.new(0.6, 8, 0.6),
			CFrame = CFrame.new(dx, topY + 4, stallZ - 2),
			Color = WOOD,
			Material = Enum.Material.Wood,
		}, market)
	end
	addLabel(roof, "Рынок", 3)
	local sellZone = makePart(nil, {
		Name = "SellZone",
		Size = Vector3.new(16, 6, 10),
		CFrame = CFrame.new(0, topY + 3, stallZ + 5),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	}, market)
	sellZone:SetAttribute("Zone", "Market")
	market.Parent = parent
end

function MapBuilder.build(): Folder
	removeTemplateLeftovers()

	local existing = Workspace:FindFirstChild("Map")
	if existing then
		existing:Destroy()
	end

	local map = Instance.new("Folder")
	map.Name = "Map"

	buildTerrain()
	buildIsland(map)
	buildPier(map)

	map.Parent = Workspace
	return map
end

return MapBuilder
