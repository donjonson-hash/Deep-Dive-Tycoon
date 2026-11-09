--!strict
-- A sunken brig on the lagoon seabed, built to real proportions so it towers
-- over a diver: 30 m hull, 8 m beam, 5 m from keel to deck, 22 m main mast.
-- Human-scale details (rail at 1.1 m, a 2 m cabin door, 0.9 m barrels) make
-- the size readable. All sizes are meters converted with
-- Config.World.studsPerMeter (a Roblox character is ~5 studs ≈ 1.7 m).
--
-- The ship is built in ship space (bow toward +X, deck up, y = 0 at the keel)
-- and placed with a root CFrame that heels it over and buries the keel. Debris
-- on the sand uses an un-heeled ground CFrame so it rests on the seabed.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local WreckBuilder = {}

local SPM = Config.World.studsPerMeter
local function mv(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z) * SPM
end
local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x * SPM, y * SPM, z * SPM)
end

-- Where it lies: an angle around the island and a fraction of the way across
-- the Lagoon's spawn ring (0 = inner edge, 1 = outer edge).
local ANGLE = math.rad(215)
local RING_FRACTION = 0.5
local YAW = math.rad(35)
local HEEL = math.rad(18) -- the +Z (starboard) side dips into the sand
local SINK = 1.2 -- meters of keel in the sand

-- Brig proportions, meters.
local L = 30 -- hull length
local B = 8 -- beam
local H = 5 -- keel to deck
local DECK = H + 0.2 -- top of the deck planks

local HULL = Color3.fromRGB(80, 55, 35)
local PLANK = Color3.fromRGB(120, 90, 55)
local TRIM = Color3.fromRGB(150, 130, 70)
local MAST = Color3.fromRGB(95, 70, 45)
local SAIL = Color3.fromRGB(150, 145, 130)
local IRON = Color3.fromRGB(60, 60, 65)
local DARK = Color3.fromRGB(10, 10, 12)
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
	local ground = CFrame.new(math.cos(ANGLE) * radius, floorY, math.sin(ANGLE) * radius)
		* CFrame.Angles(0, YAW, 0)
	local root = ground * at(0, -SINK, 0) * CFrame.Angles(HEEL, 0, 0)

	local wreck = Instance.new("Model")
	wreck.Name = "Shipwreck"

	-- Places a part at base * props.CFrame (props sizes already in studs).
	local function place(base: CFrame, className: string, props: { [string]: any }): BasePart
		local part = Instance.new(className :: any) :: BasePart
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.Material = Enum.Material.WoodPlanks
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		props.CFrame = base * props.CFrame
		for key, value in props do
			(part :: any)[key] = value
		end
		part.Parent = wreck
		return part
	end
	local function cylinder(
		base: CFrame,
		name: string,
		length: number,
		diameter: number,
		cframe: CFrame,
		color: Color3
	)
		place(base, "Part", {
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = mv(length, diameter, diameter),
			CFrame = cframe,
			Color = color,
			Material = Enum.Material.Wood,
		})
	end
	local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y

	-------------------------------------------------------------------------
	-- Hull, bow, deck (solid: divers can land on them)
	-------------------------------------------------------------------------
	place(root, "Part", {
		Name = "Hull",
		Size = mv(L, H, B),
		CFrame = at(0, H / 2, 0),
		Color = HULL,
		CanCollide = true,
	})
	-- Pointed bow: a square turned 45°, half of it sticking out of the hull.
	place(root, "Part", {
		Name = "Bow",
		Size = mv(B / math.sqrt(2), H, B / math.sqrt(2)),
		CFrame = at(L / 2, H / 2, 0) * CFrame.Angles(0, math.pi / 4, 0),
		Color = HULL,
		CanCollide = true,
	})
	cylinder(
		root,
		"Bowsprit",
		7,
		0.3,
		at(L / 2 + B / 2 + 2.5, H + 1.2, 0) * CFrame.Angles(0, 0, math.rad(20)),
		MAST
	)
	place(root, "Part", {
		Name = "Deck",
		Size = mv(L - 0.4, 0.2, B - 0.4),
		CFrame = at(0, H + 0.1, 0),
		Color = PLANK,
		CanCollide = true,
	})

	-- Rows of portholes along both sides.
	for _, side in { -1, 1 } do
		for x = -L / 2 + 3, L / 2 - 3, 4 do
			place(root, "Part", {
				Name = "Porthole",
				Size = mv(0.6, 0.6, 0.05),
				CFrame = at(x, H - 1.3, side * (B / 2 + 0.03)),
				Color = DARK,
				Material = Enum.Material.SmoothPlastic,
			})
		end
	end

	-------------------------------------------------------------------------
	-- Gunwale and railing (rail at 1.1 m: waist height for the player)
	-------------------------------------------------------------------------
	for _, side in { -1, 1 } do
		local z = side * (B / 2 - 0.15)
		place(root, "Part", {
			Name = "Gunwale",
			Size = mv(L, 0.4, 0.3),
			CFrame = at(0, DECK + 0.2, z),
			Color = TRIM,
		})
		for x = -L / 2 + 1, L / 2 - 1, 2 do
			place(root, "Part", {
				Name = "RailPost",
				Size = mv(0.12, 1.1, 0.12),
				CFrame = at(x, DECK + 0.55, z),
				Color = TRIM,
				Material = Enum.Material.Wood,
			})
		end
		place(root, "Part", {
			Name = "Rail",
			Size = mv(L - 1, 0.1, 0.12),
			CFrame = at(0, DECK + 1.1, z),
			Color = TRIM,
			Material = Enum.Material.Wood,
		})
	end

	-------------------------------------------------------------------------
	-- Stern cabin: 2.3 m headroom, a door and two windows facing the bow
	-------------------------------------------------------------------------
	local cabinX = -L / 2 + 4
	local cabinFront = cabinX + 3.5
	place(root, "Part", {
		Name = "Cabin",
		Size = mv(7, 2.3, B - 1.5),
		CFrame = at(cabinX, DECK + 1.15, 0),
		Color = HULL,
		CanCollide = true,
	})
	place(root, "Part", {
		Name = "CabinRoof",
		Size = mv(7.6, 0.2, B - 1),
		CFrame = at(cabinX, DECK + 2.4, 0),
		Color = PLANK,
		CanCollide = true,
	})
	place(root, "Part", {
		Name = "Door",
		Size = mv(0.06, 2.0, 0.9),
		CFrame = at(cabinFront + 0.03, DECK + 1.0, 0),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	for _, dz in { -2.2, 2.2 } do
		place(root, "Part", {
			Name = "Window",
			Size = mv(0.06, 0.6, 0.8),
			CFrame = at(cabinFront + 0.03, DECK + 1.5, dz),
			Color = DARK,
			Material = Enum.Material.Glass,
		})
	end

	-------------------------------------------------------------------------
	-- Masts: a 22 m main mast with yard, crow's nest and torn sail; the
	-- foremast snapped 2.5 m above the deck and lies across the rail.
	-------------------------------------------------------------------------
	local mastX = -1
	cylinder(root, "MainMast", 22, 0.5, at(mastX, DECK + 11, 0) * UPRIGHT, MAST)
	cylinder(
		root,
		"Yard",
		14,
		0.3,
		at(mastX + 0.4, DECK + 16, 0) * CFrame.Angles(0, math.pi / 2, 0),
		MAST
	)
	cylinder(root, "CrowsNest", 0.4, 2.2, at(mastX, DECK + 18.5, 0) * UPRIGHT, PLANK)
	place(root, "Part", {
		Name = "Sail",
		Size = mv(0.05, 7, 11),
		CFrame = at(mastX + 0.6, DECK + 12.3, 0.6) * CFrame.Angles(0.15, 0, 0.1),
		Color = SAIL,
		Material = Enum.Material.Fabric,
		Transparency = 0.15,
	})
	cylinder(root, "ForemastStump", 2.5, 0.45, at(8, DECK + 1.25, 0) * UPRIGHT, MAST)
	cylinder(
		root,
		"ForemastFallen",
		14,
		0.45,
		at(11, DECK + 1.5, -4.5) * CFrame.Angles(0, -0.6, 0.2),
		MAST
	)

	-------------------------------------------------------------------------
	-- Breach in the raised (port, -Z) side with splintered planks
	-------------------------------------------------------------------------
	place(root, "Part", {
		Name = "Breach",
		Size = mv(4, 2.5, 0.05),
		CFrame = at(4, 2.2, -(B / 2 + 0.03)),
		Color = DARK,
		Material = Enum.Material.SmoothPlastic,
	})
	for i = 1, 4 do
		place(root, "Part", {
			Name = "Plank",
			Size = mv(0.25, 2 + i * 0.3, 0.1),
			CFrame = at(2.5 + i * 0.9, 2.5 + i * 0.15, -(B / 2 + 0.6))
				* CFrame.Angles(-(0.4 + i * 0.15), 0, 0.2),
			Color = HULL,
		})
	end

	-------------------------------------------------------------------------
	-- Cargo on deck: barrels (0.9 m) and an open chest with gold
	-------------------------------------------------------------------------
	for _, spot in { Vector3.new(3, 0, -2.4), Vector3.new(3.8, 0, -3.1), Vector3.new(4.4, 0, -2.2) } do
		cylinder(root, "Barrel", 0.9, 0.6, at(spot.X, DECK + 0.45, spot.Z) * UPRIGHT, HULL)
	end
	place(root, "Part", {
		Name = "Chest",
		Size = mv(1, 0.6, 0.6),
		CFrame = at(-2.5, DECK + 0.3, 2),
		Color = HULL,
		Material = Enum.Material.Wood,
	})
	place(root, "Part", {
		Name = "Gold",
		Size = mv(0.9, 0.12, 0.5),
		CFrame = at(-2.5, DECK + 0.62, 2),
		Color = GOLD,
		Material = Enum.Material.Neon,
	})
	place(root, "Part", {
		Name = "ChestLid",
		Size = mv(1.05, 0.08, 0.62),
		CFrame = at(-2.5, DECK + 0.85, 1.65) * CFrame.Angles(-1.2, 0, 0),
		Color = HULL,
		Material = Enum.Material.Wood,
	})

	-------------------------------------------------------------------------
	-- Debris on the sand next to the hull (un-heeled, rests on the seabed)
	-------------------------------------------------------------------------
	cylinder(
		ground,
		"Barrel",
		0.9,
		0.6,
		at(-8, 0.25, -(B / 2 + 3)) * CFrame.Angles(0, 0.5, 0),
		HULL
	)
	cylinder(
		ground,
		"Barrel",
		0.9,
		0.6,
		at(-6.5, 0.25, -(B / 2 + 4.2)) * CFrame.Angles(0, 1.2, 0),
		HULL
	)
	place(ground, "Part", {
		Name = "Crate",
		Size = mv(0.8, 0.8, 0.8),
		CFrame = at(-9.5, 0.3, -(B / 2 + 1.8)) * CFrame.Angles(0.1, 0.4, 0.2),
		Color = PLANK,
	})
	-- Anchor (2.5 m shank and a stock) lying in the sand off the bow.
	local anchor = ground * at(L / 2 + 6, 0.2, -(B / 2 + 2)) * CFrame.Angles(0, 0.4, math.rad(80))
	place(anchor, "Part", {
		Name = "AnchorShank",
		Size = mv(0.25, 2.5, 0.25),
		CFrame = CFrame.new(),
		Color = IRON,
		Material = Enum.Material.Metal,
	})
	place(anchor, "Part", {
		Name = "AnchorArms",
		Size = mv(1.8, 0.25, 0.25),
		CFrame = at(0, -1.15, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	})
	place(anchor, "Part", {
		Name = "AnchorStock",
		Size = mv(0.2, 0.2, 1.6),
		CFrame = at(0, 1.1, 0),
		Color = IRON,
		Material = Enum.Material.Metal,
	})

	wreck.Parent = parent
	return wreck
end

return WreckBuilder
