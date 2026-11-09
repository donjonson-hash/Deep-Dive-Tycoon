--!strict
-- Builds the greybox prototype map at server start: ocean, island, pools, the
-- market kiosk, pier and diving board. Everything is driven by Config, so the
-- layout lives in git instead of a binary place file.
--
-- Island layout (player spawns at the origin facing -Z):
--   pools in front (-Z), market kiosk to the right (-X), pier off to +X.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)

local MapBuilder = {}

local WOOD = Color3.fromRGB(150, 105, 60)
local DARK_WOOD = Color3.fromRGB(95, 65, 40)
local STONE = Color3.fromRGB(150, 150, 145)
local WHITE = Color3.fromRGB(245, 245, 245)
local AWNING_RED = Color3.fromRGB(215, 60, 50)

local PIER_LENGTH = 120
local PIER_WIDTH = 12
local TERRAIN_TILE = 200 -- fill the ocean in tiles to stay under terrain write limits

-- Pools: a row in front of the spawn.
local POOL_SIZE = 10 -- inner water square
local POOL_SPACING = 30 -- center to center
local POOL_ROW_Z = -36
-- Terrain is smoothed on a 4-stud grid, so anything flush with the grass sinks
-- into it. The basin floor sits POOL_LIFT above the nominal island top.
local POOL_LIFT = 3
local POOL_WALL_HEIGHT = 3
local POOL_WALL_THICKNESS = 1
local POOL_WATER_DEPTH = 2.4
local LADDER_WIDTH = 2

local TILE = Color3.fromRGB(30, 110, 150)
local TILE_FLOOR = Color3.fromRGB(150, 210, 240)
local POOL_WATER = Color3.fromRGB(40, 170, 255)
local POOL_SURFACE = Color3.fromRGB(130, 215, 255)
local DUCK = Color3.fromRGB(255, 220, 40)
local BEAK = Color3.fromRGB(255, 130, 40)
local CORALS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
}

-- Market kiosk: to the right of the spawn, facing it, on a stone plinth so it
-- clears the terrain like the pools do.
local MARKET_POSITION = Vector3.new(-40, 0, 0)
local MARKET_LIFT = 3

-- Palms: a ring near the shore with a gap toward the pier, plus four inland.
local PALM_RING_COUNT = 12
local PALM_RING_INSET = 14 -- studs in from the island edge
local PALM_INNER_RADIUS = 58
local PALM_PIER_GAP = math.rad(25) -- keep the +X approach to the pier clear
local PALM_SEED = 7 -- fixed so the island looks the same every server
local TRUNK = Color3.fromRGB(140, 100, 60)
local FROND = Color3.fromRGB(60, 150, 60)
local COCONUT = Color3.fromRGB(90, 60, 35)

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

-- Floating label above a part (name, hints). Fades out past MaxDistance.
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

-- A board with text painted on its front face (-Z of the given CFrame).
local function addSign(
	parent: Instance,
	cframe: CFrame,
	size: Vector3,
	text: string,
	boardColor: Color3,
	textColor: Color3
): BasePart
	local board = makePart(nil, {
		Name = "Sign",
		Size = size,
		CFrame = cframe,
		Color = boardColor,
		Material = Enum.Material.Wood,
	}, parent)

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 50

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(0.9, 0.8)
	label.Position = UDim2.fromScale(0.05, 0.1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui

	gui.Parent = board
	return board
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

	-- Island: a sand column from the seabed to above the surface. All sand, no
	-- grass: it is a beach, and the palms carry the green.
	local islandHeight = world.islandTopY - floorY
	terrain:FillCylinder(
		CFrame.new(0, floorY + islandHeight / 2, 0),
		islandHeight,
		world.islandRadius,
		Enum.Material.Sand
	)
end

---------------------------------------------------------------------------
-- Palms
---------------------------------------------------------------------------

-- A palm: a gently curving trunk of cylinder segments, a crown of drooping
-- fronds and a few coconuts. `lean` is the horizontal drift of the top.
local function buildPalm(parent: Instance, base: Vector3, height: number, lean: Vector3)
	local palm = Instance.new("Model")
	palm.Name = "Palm"

	local segments = 5
	local function pointAt(t: number): Vector3
		-- Quadratic curve: straight at the root, leaning more toward the top.
		return base + Vector3.new(0, height * t, 0) + lean * (t * t)
	end
	for i = 1, segments do
		local from = pointAt((i - 1) / segments)
		local to = pointAt(i / segments)
		local mid = (from + to) / 2
		local thickness = 1.6 - 0.6 * (i / segments)
		makePart(nil, {
			Name = "Trunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new((to - from).Magnitude + 0.2, thickness, thickness),
			-- Cylinders lie along X; aim X from `from` to `to`.
			CFrame = CFrame.lookAt(mid, to) * CFrame.Angles(0, math.pi / 2, 0),
			Color = TRUNK,
			Material = Enum.Material.Wood,
		}, palm)
	end

	local top = pointAt(1)
	local fronds = 7
	for i = 1, fronds do
		local yaw = (i / fronds) * 2 * math.pi
		makePart(nil, {
			Name = "Frond",
			Size = Vector3.new(1.8, 0.2, 7),
			CFrame = CFrame.new(top)
				* CFrame.Angles(0, yaw, 0)
				* CFrame.Angles(math.rad(-28), 0, 0)
				* CFrame.new(0, 0, -3.5),
			Color = FROND,
			Material = Enum.Material.Grass,
			CanCollide = false,
		}, palm)
	end
	for i = 1, 3 do
		local yaw = i * 2.1
		makePart(nil, {
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * 0.9,
			CFrame = CFrame.new(top + Vector3.new(math.cos(yaw) * 0.8, -0.6, math.sin(yaw) * 0.8)),
			Color = COCONUT,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		}, palm)
	end

	palm.Parent = parent
end

local function buildPalms(parent: Instance)
	local world = Config.World
	local rng = Random.new(PALM_SEED)
	local folder = Instance.new("Folder")
	folder.Name = "Palms"

	local function plant(angle: number, radius: number)
		local base =
			Vector3.new(math.cos(angle) * radius, world.islandTopY, math.sin(angle) * radius)
		local height = rng:NextNumber(14, 20)
		-- Lean outward a little, toward the sea, like real shore palms.
		local lean = Vector3.new(math.cos(angle), 0, math.sin(angle)) * rng:NextNumber(1.5, 3.5)
		buildPalm(folder, base, height, lean)
	end

	-- Shore ring, skipping the sector where the pier leaves the island (+X).
	local ringRadius = world.islandRadius - PALM_RING_INSET
	for i = 1, PALM_RING_COUNT do
		local angle = (i / PALM_RING_COUNT) * 2 * math.pi + rng:NextNumber(-0.12, 0.12)
		local fromPier = math.abs(math.atan2(math.sin(angle), math.cos(angle)))
		if fromPier < PALM_PIER_GAP then
			continue
		end
		plant(angle, ringRadius + rng:NextNumber(-4, 4))
	end

	-- Four inland palms on the diagonals, clear of spawn, pools, market and pier.
	for i = 0, 3 do
		plant(math.pi / 4 + i * math.pi / 2, PALM_INNER_RADIUS)
	end

	folder.Parent = parent
end

---------------------------------------------------------------------------
-- Pools
---------------------------------------------------------------------------

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
	Kiddie = function(model, x, floorTop, z)
		addDuck(model, x + 2, floorTop + POOL_WATER_DEPTH, z + 2)
	end,
	Coral = function(model, x, floorTop, z)
		addCoral(model, x, floorTop, z)
	end,
}

-- Climbable ladder (TrussPart) from bottomY to topY, centered at (x, z).
local function addLadder(parent: Instance, x: number, bottomY: number, topY: number, z: number)
	local height = topY - bottomY
	makePart("TrussPart", {
		Name = "Ladder",
		Size = Vector3.new(LADDER_WIDTH, height, LADDER_WIDTH),
		CFrame = CFrame.new(x, bottomY + height / 2, z),
		Color = STONE,
		Material = Enum.Material.Metal,
	}, parent)
end

-- Above-ground pool: tiled basin on a raised floor, bright water, a ladder on
-- the outside to climb in and one on the inside to climb out, a name sign.
local function buildPool(pool: Config.Pool, index: number, count: number, parent: Instance)
	local groundY = Config.World.islandTopY
	local x = (index - (count + 1) / 2) * POOL_SPACING
	local z = POOL_ROW_Z
	local floorTop = groundY + POOL_LIFT
	local wallTop = floorTop + POOL_WALL_HEIGHT
	local outer = POOL_SIZE + 2 * POOL_WALL_THICKNESS
	local frontZ = z + outer / 2 -- the side facing the spawn (+Z)

	local model = Instance.new("Model")
	model.Name = pool.id
	model:SetAttribute("PoolId", pool.id)

	-- Raised floor: light tiles, seen through the water.
	makePart(nil, {
		Name = "Floor",
		Size = Vector3.new(outer, POOL_LIFT, outer),
		CFrame = CFrame.new(x, groundY + POOL_LIFT / 2, z),
		Color = TILE_FLOOR,
		Material = Enum.Material.Marble,
	}, model)

	-- Dark tiled walls with a white coping.
	local wallY = floorTop + POOL_WALL_HEIGHT / 2
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
			Color = WHITE,
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

	-- Water: a tinted glass body plus a glowing surface so it reads from afar.
	local water = makePart(nil, {
		Name = "PoolWater",
		Size = Vector3.new(POOL_SIZE, POOL_WATER_DEPTH, POOL_SIZE),
		CFrame = CFrame.new(x, floorTop + POOL_WATER_DEPTH / 2, z),
		Color = POOL_WATER,
		Material = Enum.Material.Glass,
		Transparency = 0.3,
		CanCollide = false,
	}, model)
	water:SetAttribute("PoolId", pool.id)
	makePart(nil, {
		Name = "WaterSurface",
		Size = Vector3.new(POOL_SIZE, 0.2, POOL_SIZE),
		CFrame = CFrame.new(x, floorTop + POOL_WATER_DEPTH - 0.1, z),
		Color = POOL_SURFACE,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		CanCollide = false,
		CanQuery = false,
	}, model)

	-- Ladders on the spawn side: outside (grass → coping) and inside (floor → coping).
	local ladderX = x - POOL_SIZE / 2 + LADDER_WIDTH / 2 + 1
	addLadder(model, ladderX, groundY, wallTop + 0.3, frontZ + LADDER_WIDTH / 2)
	addLadder(
		model,
		ladderX,
		floorTop,
		wallTop + 0.3,
		frontZ - POOL_WALL_THICKNESS - LADDER_WIDTH / 2
	)

	-- Name sign on a post beside the ladder, facing the spawn.
	local signX = x + POOL_SIZE / 2 - 2
	makePart(nil, {
		Name = "SignPost",
		Size = Vector3.new(0.5, 7, 0.5),
		CFrame = CFrame.new(signX, groundY + 3.5, frontZ + 1.5),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	}, model)
	addSign(
		model,
		CFrame.new(signX, groundY + 7.5, frontZ + 1.5) * CFrame.Angles(0, math.pi, 0),
		Vector3.new(7, 1.8, 0.4),
		pool.name,
		DARK_WOOD,
		WHITE
	)

	local decorate = POOL_DECOR[pool.id]
	if decorate then
		decorate(model, x, floorTop, z)
	end

	local text = `+{pool.gainPerTick} O₂ / {Config.Oxygen.poolTickSeconds} с`
	if pool.unlockMaxO2 > 0 then
		text ..= `\nоткрывается с {pool.unlockMaxO2} O₂`
	end
	addLabel(water, text, 6)

	model.Parent = parent
end

---------------------------------------------------------------------------
-- Market kiosk
---------------------------------------------------------------------------

-- Built in kiosk space (front = -Z, ground y = 0) and placed with `root`.
local function buildMarket(parent: Instance)
	local groundY = Config.World.islandTopY
	-- Face the spawn: the kiosk's -Z must point to world +X. Kiosk y = 0 is the
	-- top of the plinth, MARKET_LIFT above the sand.
	local root = CFrame.new(MARKET_POSITION + Vector3.new(0, groundY + MARKET_LIFT, 0))
		* CFrame.Angles(0, -math.pi / 2, 0)

	local market = Instance.new("Model")
	market.Name = "Market"

	local function place(className: string?, props: { [string]: any }): BasePart
		props.CFrame = root * props.CFrame
		return makePart(className, props, market)
	end

	-- Stone plinth from the sand up to kiosk level, then the wooden hut: back
	-- wall, two side walls, roof.
	place(nil, {
		Name = "Base",
		Size = Vector3.new(22, MARKET_LIFT + 1, 14),
		CFrame = CFrame.new(0, (1 - MARKET_LIFT) / 2, 0),
		Color = STONE,
		Material = Enum.Material.Slate,
	})
	place(nil, {
		Name = "BackWall",
		Size = Vector3.new(22, 9, 1),
		CFrame = CFrame.new(0, 5.5, 6.5),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	for _, dx in { -10.5, 10.5 } do
		place(nil, {
			Name = "SideWall",
			Size = Vector3.new(1, 9, 13),
			CFrame = CFrame.new(dx, 5.5, 0),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
		})
	end
	place(nil, {
		Name = "Roof",
		Size = Vector3.new(24, 0.6, 15),
		CFrame = CFrame.new(0, 10.3, 0),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})

	-- Counter with a lighter top, scales and a couple of fish on display.
	place(nil, {
		Name = "Counter",
		Size = Vector3.new(18, 3.5, 3),
		CFrame = CFrame.new(0, 2.75, -4),
		Color = WOOD,
		Material = Enum.Material.WoodPlanks,
	})
	place(nil, {
		Name = "CounterTop",
		Size = Vector3.new(18.6, 0.3, 3.6),
		CFrame = CFrame.new(0, 4.65, -4),
		Color = WHITE,
		Material = Enum.Material.Marble,
	})
	place(nil, {
		Name = "ScaleBase",
		Size = Vector3.new(1.6, 0.3, 1.6),
		CFrame = CFrame.new(5, 4.95, -4),
		Color = DARK_WOOD,
		Material = Enum.Material.Metal,
	})
	place(nil, {
		Name = "ScalePan",
		Size = Vector3.new(2.2, 0.2, 2.2),
		CFrame = CFrame.new(5, 6.2, -4),
		Color = STONE,
		Material = Enum.Material.Metal,
	})
	place(nil, {
		Name = "ScalePole",
		Size = Vector3.new(0.3, 1.2, 0.3),
		CFrame = CFrame.new(5, 5.5, -4),
		Color = STONE,
		Material = Enum.Material.Metal,
	})
	for i, color in { Color3.fromRGB(150, 170, 190), Color3.fromRGB(255, 140, 50) } do
		place(nil, {
			Name = "DisplayFish",
			Size = Vector3.new(2.2, 0.6, 0.9),
			CFrame = CFrame.new(-5 + (i - 1) * 2.8, 5.1, -4) * CFrame.Angles(0, 0.3 * i, 0),
			Color = color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
	end

	-- Striped awning sloping down over the counter, held by two front poles.
	local stripes = 7
	local stripeWidth = 24 / stripes
	for i = 1, stripes do
		local sx = -12 + stripeWidth * (i - 0.5)
		place(nil, {
			Name = "Awning",
			Size = Vector3.new(stripeWidth, 0.25, 7),
			CFrame = CFrame.new(sx, 9.4, -10) * CFrame.Angles(math.rad(-18), 0, 0),
			Color = if i % 2 == 1 then AWNING_RED else WHITE,
			Material = Enum.Material.Fabric,
			CanCollide = false,
		})
	end
	for _, dx in { -11.5, 11.5 } do
		place(nil, {
			Name = "AwningPole",
			Size = Vector3.new(0.5, 8.5, 0.5),
			CFrame = CFrame.new(dx, 4.25, -13),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		})
	end

	-- Shelves with jars on the back wall.
	for shelf, y in { 4, 6.8 } do
		place(nil, {
			Name = "Shelf",
			Size = Vector3.new(16, 0.3, 2),
			CFrame = CFrame.new(0, y, 5),
			Color = DARK_WOOD,
			Material = Enum.Material.Wood,
		})
		for j = 1, 5 do
			place(nil, {
				Name = "Jar",
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(1.4, 1, 1),
				CFrame = CFrame.new(-6 + (j - 1) * 3 + shelf * 0.7, y + 0.85, 5)
					* CFrame.Angles(0, 0, math.pi / 2),
				Color = if (j + shelf) % 2 == 0 then POOL_WATER else AWNING_RED,
				Material = Enum.Material.Glass,
				Transparency = 0.3,
				CanCollide = false,
			})
		end
	end

	-- Crates and a barrel at the sides.
	for _, offset in
		{ Vector3.new(-8, 1.75, 1), Vector3.new(-8, 4.25, 1), Vector3.new(-5.2, 1.75, 2) }
	do
		place(nil, {
			Name = "Crate",
			Size = Vector3.one * 2.5,
			CFrame = CFrame.new(offset),
			Color = WOOD,
			Material = Enum.Material.WoodPlanks,
		})
	end
	place(nil, {
		Name = "Barrel",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(3.2, 2.6, 2.6),
		CFrame = CFrame.new(8, 2.1, 1.5) * CFrame.Angles(0, 0, math.pi / 2),
		Color = DARK_WOOD,
		Material = Enum.Material.Wood,
	})

	-- Hanging sign above the awning and a chalkboard by the counter.
	local sign = addSign(
		market,
		root * CFrame.new(0, 12.4, -6),
		Vector3.new(12, 2.4, 0.4),
		"РЫБНЫЙ РЫНОК",
		DARK_WOOD,
		WHITE
	)
	for _, dx in { -5, 5 } do
		place(nil, {
			Name = "SignChain",
			Size = Vector3.new(0.2, 1.4, 0.2),
			CFrame = CFrame.new(dx, 11.1, -6),
			Color = STONE,
			Material = Enum.Material.Metal,
			CanCollide = false,
		})
	end
	addLabel(sign, "Скупаем улов", 3)
	addSign(
		market,
		root * CFrame.new(-8.5, 3, -9) * CFrame.Angles(0, math.rad(20), 0),
		Vector3.new(4, 5, 0.3),
		"Цены\nна табло\nрядом",
		Color3.fromRGB(40, 60, 50),
		WHITE
	)

	-- Standing in SellZone opens the market UI; MarketService checks the same
	-- zone before paying out. About 10 studs of sand in front of the counter,
	-- reaching down to ground level below the plinth.
	local sellZone = place(nil, {
		Name = "SellZone",
		Size = Vector3.new(20, 10, 12),
		CFrame = CFrame.new(0, 2 - MARKET_LIFT, -11),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	sellZone:SetAttribute("Zone", "Market")

	market.Parent = parent
end

---------------------------------------------------------------------------
-- Pier
---------------------------------------------------------------------------

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
		Color = WHITE,
		Material = Enum.Material.SmoothPlastic,
	}, pier)
	addLabel(board, "Прыжок в океан ↓", 4)

	pier.Parent = parent
end

---------------------------------------------------------------------------
-- Island
---------------------------------------------------------------------------

local function buildIsland(parent: Instance)
	local topY = Config.World.islandTopY

	-- Spawn faces -Z, straight at the pool row.
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

	buildMarket(parent)
	buildPalms(parent)
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
