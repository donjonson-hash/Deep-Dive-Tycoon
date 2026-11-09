--!strict
-- A sunken sailing ship on the lagoon seabed: hull with a wedge bow, deck,
-- stern cabin, two masts (one snapped), a torn sail, railings, a breach in
-- the hull, barrels and a chest. Built in ship space (bow toward +X, deck up)
-- and placed with a root CFrame that heels it over and buries the keel.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WreckBuilder = {}

-- Where it lies: an angle around the island and a fraction of the way across
-- the Lagoon's spawn ring (0 = inner edge, 1 = outer edge).
local ANGLE = math.rad(215)
local RING_FRACTION = 0.5
local YAW = math.rad(35)
local HEEL = math.rad(18) -- roll onto the port side
local SINK = 3 -- studs of keel in the sand

local HULL_LENGTH = 50
local HULL_WIDTH = 12
local HULL_HEIGHT = 10

local HULL = Color3.fromRGB(80, 55, 35)
local DECK = Color3.fromRGB(120, 90, 55)
local TRIM = Color3.fromRGB(150, 130, 70)
local MAST = Color3.fromRGB(95, 70, 45)
local SAIL = Color3.fromRGB(150, 145, 130)
local IRON = Color3.fromRGB(60, 60, 65)
local BREACH = Color3.fromRGB(10, 10, 12)
local GOLD = Color3.fromRGB(255, 200, 60)

local function lagoonRadius(): number
	for _, zone in Config.Zones do
		if zone.id == "Lagoon" and zone.spawn then
			local ring = zone.spawn
			return ring.minRadius + (ring.maxRadius - ring.minRadius) * RING_FRACTION
		end
	end
	return Config.World.islandRadius * 2
end

function WreckBuilder.build(parent: Instance, floorY: number): Model
	local radius = lagoonRadius()
	local root = CFrame.new(math.cos(ANGLE) * radius, floorY - SINK, math.sin(ANGLE) * radius)
		* CFrame.Angles(0, YAW, 0)
		* CFrame.Angles(HEEL, 0, 0)

	local wreck = Instance.new("Model")
	wreck.Name = "Shipwreck"

	local function place(className: string, props: { [string]: any }): BasePart
		local part = Instance.new(className :: any) :: BasePart
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Material = Enum.Material.WoodPlanks
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		props.CFrame = root * props.CFrame
		for key, value in props do
			(part :: any)[key] = value
		end
		part.Parent = wreck
		return part
	end

	-- Hull: a long box, solid so divers can land on the deck.
	place("Part", {
		Name = "Hull",
		Size = Vector3.new(HULL_LENGTH, HULL_HEIGHT, HULL_WIDTH),
		CFrame = CFrame.new(0, HULL_HEIGHT / 2, 0),
		Color = HULL,
		CanCollide = true,
	})
	-- Bow: a wedge with its thin edge forward (+X).
	place("WedgePart", {
		Name = "Bow",
		Size = Vector3.new(HULL_WIDTH, HULL_HEIGHT, 14),
		CFrame = CFrame.new(HULL_LENGTH / 2 + 7, HULL_HEIGHT / 2, 0)
			* CFrame.Angles(0, -math.pi / 2, 0),
		Color = HULL,
		CanCollide = true,
	})
	place("Part", {
		Name = "Deck",
		Size = Vector3.new(HULL_LENGTH - 2, 0.6, HULL_WIDTH - 1),
		CFrame = CFrame.new(0, HULL_HEIGHT + 0.3, 0),
		Color = DECK,
		CanCollide = true,
	})
	-- Gunwale trim along both sides.
	for _, side in { -1, 1 } do
		place("Part", {
			Name = "Gunwale",
			Size = Vector3.new(HULL_LENGTH, 1.2, 0.6),
			CFrame = CFrame.new(0, HULL_HEIGHT + 0.6, side * (HULL_WIDTH / 2 - 0.3)),
			Color = TRIM,
		})
		-- Railing posts and a rail.
		for x = -HULL_LENGTH / 2 + 4, HULL_LENGTH / 2 - 4, 6 do
			place("Part", {
				Name = "RailPost",
				Size = Vector3.new(0.4, 2.4, 0.4),
				CFrame = CFrame.new(x, HULL_HEIGHT + 2.2, side * (HULL_WIDTH / 2 - 0.5)),
				Color = TRIM,
				Material = Enum.Material.Wood,
			})
		end
		place("Part", {
			Name = "Rail",
			Size = Vector3.new(HULL_LENGTH - 8, 0.3, 0.3),
			CFrame = CFrame.new(0, HULL_HEIGHT + 3.3, side * (HULL_WIDTH / 2 - 0.5)),
			Color = TRIM,
			Material = Enum.Material.Wood,
		})
	end

	-- Stern cabin with a small roof.
	place("Part", {
		Name = "Cabin",
		Size = Vector3.new(10, 6, HULL_WIDTH - 2),
		CFrame = CFrame.new(-HULL_LENGTH / 2 + 7, HULL_HEIGHT + 3.6, 0),
		Color = HULL,
		CanCollide = true,
	})
	place("Part", {
		Name = "CabinRoof",
		Size = Vector3.new(11.5, 0.5, HULL_WIDTH - 0.5),
		CFrame = CFrame.new(-HULL_LENGTH / 2 + 7, HULL_HEIGHT + 6.85, 0),
		Color = DECK,
	})
	-- Dark windows on the cabin's front.
	for _, dz in { -2.5, 2.5 } do
		place("Part", {
			Name = "Window",
			Size = Vector3.new(0.2, 1.6, 1.6),
			CFrame = CFrame.new(-HULL_LENGTH / 2 + 12.1, HULL_HEIGHT + 3.8, dz),
			Color = BREACH,
			Material = Enum.Material.Glass,
		})
	end

	-- Main mast with a yard and a torn sail; foremast snapped and leaning.
	place("Part", {
		Name = "MainMast",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(30, 1.2, 1.2),
		CFrame = CFrame.new(-4, HULL_HEIGHT + 15, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = MAST,
		Material = Enum.Material.Wood,
	})
	place("Part", {
		Name = "Yard",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(16, 0.7, 0.7),
		CFrame = CFrame.new(-4, HULL_HEIGHT + 24, 0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = MAST,
		Material = Enum.Material.Wood,
	})
	place("Part", {
		Name = "Sail",
		Size = Vector3.new(0.2, 9, 13),
		CFrame = CFrame.new(-3.6, HULL_HEIGHT + 19, 1) * CFrame.Angles(0.15, 0, 0.1),
		Color = SAIL,
		Material = Enum.Material.Fabric,
		Transparency = 0.15,
	})
	place("Part", {
		Name = "ForemastStump",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(6, 1, 1),
		CFrame = CFrame.new(12, HULL_HEIGHT + 3, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color = MAST,
		Material = Enum.Material.Wood,
	})
	place("Part", {
		Name = "ForemastFallen",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(18, 1, 1),
		CFrame = CFrame.new(16, HULL_HEIGHT + 4, 7) * CFrame.Angles(0, 0.6, 0.35),
		Color = MAST,
		Material = Enum.Material.Wood,
	})

	-- Breach in the starboard hull with planks sticking out.
	place("Part", {
		Name = "Breach",
		Size = Vector3.new(9, 5, 0.3),
		CFrame = CFrame.new(6, 4, HULL_WIDTH / 2 + 0.05),
		Color = BREACH,
		Material = Enum.Material.SmoothPlastic,
	})
	for i = 1, 4 do
		place("Part", {
			Name = "Plank",
			Size = Vector3.new(0.6, 4 + i * 0.5, 0.4),
			CFrame = CFrame.new(2 + i * 2.2, 5 + i * 0.3, HULL_WIDTH / 2 + 1.5)
				* CFrame.Angles(0.4 + i * 0.15, 0, 0.2),
			Color = HULL,
		})
	end

	-- Cargo: barrels on deck and in the sand, a chest with a gold lid.
	for _, spot in
		{
			Vector3.new(2, HULL_HEIGHT + 1.8, -3),
			Vector3.new(5, HULL_HEIGHT + 1.8, -3.5),
			Vector3.new(-14, 1.2, -HULL_WIDTH / 2 - 4),
		}
	do
		place("Part", {
			Name = "Barrel",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(3, 2.4, 2.4),
			CFrame = CFrame.new(spot) * CFrame.Angles(0, 0, math.pi / 2),
			Color = HULL,
			Material = Enum.Material.Wood,
		})
	end
	place("Part", {
		Name = "Chest",
		Size = Vector3.new(3, 2, 2),
		CFrame = CFrame.new(-6, HULL_HEIGHT + 1.6, 3),
		Color = HULL,
		Material = Enum.Material.Wood,
	})
	place("Part", {
		Name = "ChestLid",
		Size = Vector3.new(3.1, 0.4, 2.1),
		CFrame = CFrame.new(-6, HULL_HEIGHT + 2.9, 2.3) * CFrame.Angles(-0.9, 0, 0),
		Color = GOLD,
		Material = Enum.Material.Neon,
	})
	place("Part", {
		Name = "Anchor",
		Size = Vector3.new(0.6, 5, 3),
		CFrame = CFrame.new(HULL_LENGTH / 2 + 10, 1.5, -HULL_WIDTH / 2 - 2)
			* CFrame.Angles(0, 0.4, 0.9),
		Color = IRON,
		Material = Enum.Material.Metal,
	})

	wreck.Parent = parent
	return wreck
end

return WreckBuilder
