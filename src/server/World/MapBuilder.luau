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
local POOL_SPACING = 30 -- center to center, pools in a row on the island
local POOL_ROW_Z = 32 -- the pool row sits behind the spawn, the market in front
local MARKET_Z = -30
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

-- Above-ground pools. Terrain is smoothed on a 4-stud grid, so anything flush
-- with the grass sinks into it; the basin floor sits POOL_DECK_LIFT above the
-- nominal island top and the walls rise from there. Stairs on the spawn side
-- lead onto the wall top; getting out is a jump over the wall.
local POOL_DECK_LIFT = 1.5
local POOL_WALL_HEIGHT = 2.5
local POOL_WALL_THICKNESS = 1
local POOL_WATER_DEPTH = 2
local POOL_STEP_DEPTH = 2
local POOL_STEP_WIDTH = 6

local TILE = Color3.fromRGB(190, 225, 240)
local TILE_DARK = Color3.fromRGB(120, 170, 200)
local COPING = Color3.fromRGB(245, 245, 245)
local STEP = Color3.fromRGB(205, 205, 200)
local DUCK = Color3.fromRGB(255, 220, 40)
local BEAK = Color3.fromRGB(255, 130, 40)
local CORALS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
}

local function addDuck(model: Model, x: number, waterTop: number, z: number)
	local body = makePart(nil, {
		Name = "DuckBody",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 2.4,
		CFrame = CFrame.new(x, waterTop + 0.6, z),
		Color = DUCK,
		CanCollide = false,
	}, model)
	makePart(nil, {
		Name = "DuckHead",
		Shape = Enum.PartType.Ball,
		Size = Vector3.one * 1.4,
		CFrame = body.CFrame * CFrame.new(0.9, 1.2, 0),
		Color = DUCK,
		CanCollide = false,
	}, model)
	makePart(nil, {
		Name = "DuckBeak",
		Size = Vector3.new(0.9, 0.35, 0.6),
		CFrame = body.CFrame * CFrame.new(1.9, 1.1, 0),
		Color = BEAK,
		CanCollide = false,
	}, model)
end

local function addCoral(model: Model, x: number, floorTop: number, z: number)
	local spots = { Vector3.new(-3, 0, -3), Vector3.new(3.5, 0, -2), Vector3.new(-2, 0, 3.5) }
	for i, offset in spots do
		local height = 1.2 + i * 0.5
		makePart(nil, {
			Name = "Coral",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 1.2, 1.2),
			-- Cylinders lie along X; stand this one up.
			CFrame = CFrame.new(x + offset.X, floorTop + height / 2, z + offset.Z)
				* CFrame.Angles(0, 0, math.pi / 2),
			Color = CORALS[(i - 1) % #CORALS + 1],
			Material = Enum.Material.Pebble,
			CanCollide = false,
		}, model)
	end
end

local POOL_DECOR: { [string]: (Model, number, number, number) -> () } = {
	Kiddie = function(model, x, deckTop, z)
		addDuck(model, x + 2, deckTop + POOL_WATER_DEPTH, z + 2)
	end,
	Coral = function(model, x, deckTop, z)
		addCoral(model, x, deckTop, z)
	end,
}

local function buildPool(pool: Config.Pool, index: number, count: number, parent: Instance)
	-- Pools stand in a row on the island grass, centered on the spawn's X.
	local topY = Config.World.islandTopY
	local x = (index - (count + 1) / 2) * POOL_SPACING
	local z = POOL_ROW_Z
	local deckTop = topY + POOL_DECK_LIFT
	local wallTop = deckTop + POOL_WALL_HEIGHT
	local outer = POOL_SIZE + 2 * POOL_WALL_THICKNESS

	local model = Instance.new("Model")
	model.Name = pool.id
	model:SetAttribute("PoolId", pool.id)

	-- Basin floor, visibly above the grass.
	makePart(nil, {
		Name = "Floor",
		Size = Vector3.new(outer, POOL_DECK_LIFT, outer),
		CFrame = CFrame.new(x, topY + POOL_DECK_LIFT / 2, z),
		Color = TILE_DARK,
		Material = Enum.Material.Marble,
	}, model)

	-- Tiled walls with a white coping on top.
	local wallY = deckTop + POOL_WALL_HEIGHT / 2
	local wallOffset = POOL_SIZE / 2 + POOL_WALL_THICKNESS / 2
	local function wall(size: Vector3, offset: Vector3)
		makePart(nil, {
			Name = "Wall",
			Size = size,
			CFrame = CFrame.new(x + offset.X, wallY, z + offset.Z),
			Color = TILE,
			Material = Enum.Material.Marble,
		}, model)
		makePart(nil, {
			Name = "Coping",
			Size = Vector3.new(size.X + 0.4, 0.3, size.Z + 0.4),
			CFrame = CFrame.new(x + offset.X, wallTop + 0.15, z + offset.Z),
			Color = COPING,
			Material = Enum.Material.SmoothPlastic,
		}, model)
	end
	for _, dz in { -1, 1 } do
		wall(
			Vector3.new(outer, POOL_WALL_HEIGHT, POOL_WALL_THICKNESS),
			Vector3.new(0, 0, dz * wallOffset)
		)
	end
	for _, dx in { -1, 1 } do
		wall(
			Vector3.new(POOL_WALL_THICKNESS, POOL_WALL_HEIGHT, POOL_SIZE),
			Vector3.new(dx * wallOffset, 0, 0)
		)
	end

	local water = makePart(nil, {
		Name = "PoolWater",
		Size = Vector3.new(POOL_SIZE, POOL_WATER_DEPTH, POOL_SIZE),
		CFrame = CFrame.new(x, deckTop + POOL_WATER_DEPTH / 2, z),
		Color = POOL_WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.45,
		CanCollide = false,
	}, model)
	water:SetAttribute("PoolId", pool.id)

	-- Stairs from the grass up to the wall top, on the side facing the spawn.
	local rise = wallTop + 0.3 - topY
	local stepCount = math.ceil(rise)
	local stepRise = rise / stepCount
	local frontZ = z - outer / 2 - 0.2
	for i = 1, stepCount do
		local height = i * stepRise
		makePart(nil, {
			Name = "Step",
			Size = Vector3.new(POOL_STEP_WIDTH, height, POOL_STEP_DEPTH),
			CFrame = CFrame.new(
				x,
				topY + height / 2,
				frontZ - (stepCount - i) * POOL_STEP_DEPTH - POOL_STEP_DEPTH / 2
			),
			Color = STEP,
			Material = Enum.Material.Concrete,
		}, model)
	end

	local decorate = POOL_DECOR[pool.id]
	if decorate then
		decorate(model, x, deckTop, z)
	end

	local text = `{pool.name}\n+{pool.gainPerTick} O₂ / {Config.Oxygen.poolTickSeconds} с`
	if pool.unlockMaxO2 > 0 then
		text ..= `\nоткрывается с {pool.unlockMaxO2} O₂`
	end
	addLabel(water, text, 6)

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

	local pools = Instance.new("Folder")
	pools.Name = "Pools"
	for index, pool in Config.Pools do
		buildPool(pool, index, #Config.Pools, pools)
	end
	pools.Parent = parent

	-- Market stall. Standing in SellZone opens the market UI; MarketService
	-- checks the same zone before paying out.
	local market = Instance.new("Model")
	market.Name = "Market"
	local stallZ = MARKET_Z
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
	-- Walking up to the stall opens the market: the zone starts ~20 studs out.
	local sellZone = makePart(nil, {
		Name = "SellZone",
		Size = Vector3.new(30, 8, 26),
		CFrame = CFrame.new(0, topY + 4, stallZ + 9),
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
