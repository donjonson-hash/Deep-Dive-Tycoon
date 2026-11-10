--!strict
-- Dresses the lagoon seabed: reef patches composed like the owner's
-- watercolor references (a tall "hero" coral, a middle layer around it,
-- cushions and leafy weed at the base), forests of giant kelp that the
-- client sways, and vents leaking bubbles. Seeded so every server matches.
--
-- Reference shapes: a pink-to-coral branching tree that splits down to fine
-- twigs, a sea fan with a maroon skeleton and a pink lacy membrane, clusters
-- of yellow-orange trumpet cups with pink rims, mint feathery bushes, olive
-- moss and dark-blue sponge cushions, a striped yellow/orange brain coral
-- and wavy orange weed.
--
-- Sizes are real-world meters converted with Config.World.studsPerMeter (a
-- Roblox character is ~5 studs ≈ 1.7 m); heroes reach 3–4 m like old reef
-- colonies.

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
local PATCHES = 50
-- Giant kelp. Real stalks grow up to the surface; ours stop SURFACE_GAP
-- short of it so nothing pokes out of the water.
local KELP_CHANCE = 0.85 -- share of reef patches with a kelp tuft
local KELP_TUFT = { min = 4, max = 7, spread = 2.5 } -- stalks, meters
local KELP_FORESTS = 8 -- dense groves on open sand
local KELP_FOREST = { min = 12, max = 20, spread = 7 }
local KELP_HEIGHT = { min = 22, max = 42 } -- meters
local KELP_SURFACE_GAP = 2 -- meters kept between the tallest tip and the surface
local KELP_SEGMENTS = 6
local VENTS = 12
local EDGE_MARGIN = 14 -- studs kept clear of the ring edges
local SINK = m(0.15) -- bury bases a little so nothing floats over the sand
local UPRIGHT = CFrame.Angles(0, 0, math.pi / 2) -- cylinder axis X -> Y
local TAU = 2 * math.pi

---------------------------------------------------------------------------
-- Palettes, sampled from the references
---------------------------------------------------------------------------

type Gradient = { base: Color3, tip: Color3 }

local TREE_GRADIENTS: { Gradient } = {
	{ base = Color3.fromRGB(215, 70, 115), tip = Color3.fromRGB(250, 150, 165) }, -- pink
	{ base = Color3.fromRGB(230, 80, 70), tip = Color3.fromRGB(255, 160, 120) }, -- coral red
	{ base = Color3.fromRGB(240, 110, 90), tip = Color3.fromRGB(255, 190, 150) }, -- salmon
}
local FAN_SKELETON = Color3.fromRGB(140, 40, 60)
local FAN_MEMBRANES =
	{ Color3.fromRGB(240, 140, 160), Color3.fromRGB(245, 120, 140), Color3.fromRGB(250, 165, 175) }
local CUP_BODY =
	{ Color3.fromRGB(255, 205, 70), Color3.fromRGB(250, 165, 60), Color3.fromRGB(255, 185, 90) }
local CUP_RIM = Color3.fromRGB(245, 135, 115)
local CUP_MOUTH = Color3.fromRGB(190, 105, 50)
local FEATHER: { Gradient } = {
	{ base = Color3.fromRGB(110, 180, 175), tip = Color3.fromRGB(190, 230, 220) },
	{ base = Color3.fromRGB(130, 195, 185), tip = Color3.fromRGB(205, 235, 225) },
}
local MOSS =
	{ Color3.fromRGB(120, 150, 80), Color3.fromRGB(150, 170, 90), Color3.fromRGB(95, 130, 80) }
local DARK_SPONGE =
	{ Color3.fromRGB(40, 80, 100), Color3.fromRGB(55, 100, 110), Color3.fromRGB(35, 65, 90) }
local BRAIN_STRIPES = { Color3.fromRGB(250, 210, 120), Color3.fromRGB(235, 150, 50) }
local WEED =
	{ Color3.fromRGB(230, 140, 50), Color3.fromRGB(245, 165, 70), Color3.fromRGB(225, 120, 45) }

local CORAL_COLORS = {
	Color3.fromRGB(255, 120, 160),
	Color3.fromRGB(255, 150, 80),
	Color3.fromRGB(190, 110, 230),
	Color3.fromRGB(255, 210, 70),
	Color3.fromRGB(80, 200, 190),
	Color3.fromRGB(240, 90, 90),
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
	part.CanTouch = false
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

-- A point in a ring of minM..maxM meters around `base`.
local function around(rng: Random, base: Vector3, minM: number, maxM: number): Vector3
	local angle = rng:NextNumber(0, TAU)
	local radius = m(rng:NextNumber(minM, maxM))
	return base + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
end

local function pick<T>(rng: Random, list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

-- A frame on the sand at `base`, turned to a random yaw.
local function ground(base: Vector3, rng: Random): CFrame
	return CFrame.new(base - Vector3.new(0, SINK, 0)) * CFrame.Angles(0, rng:NextNumber(0, TAU), 0)
end

type Shape = (parent: Instance, base: Vector3, rng: Random) -> ()

---------------------------------------------------------------------------
-- Reference shapes
---------------------------------------------------------------------------

-- Branching tree coral (reference 1, center): a thick trunk that splits two
-- or three ways per level, mostly in one plane, thinning and paling toward
-- the twigs. 3–4 m tall.
local function treeCoral(parent: Instance, base: Vector3, rng: Random)
	local gradient = pick(rng, TREE_GRADIENTS)
	local maxDepth = 3

	local function branch(from: CFrame, length: number, radius: number, depth: number)
		local color = gradient.base:Lerp(gradient.tip, depth / maxDepth)
		rod("TreeCoral", from, length + radius, radius, color, parent)
		if depth >= maxDepth then
			blob(
				"TreeTip",
				Vector3.one * radius * 2.4,
				from * CFrame.new(0, length + radius, 0),
				color,
				parent
			)
			return
		end
		local top = from * CFrame.new(0, length, 0)
		if depth < 2 then
			-- Knuckle hides the seam where thick limbs meet.
			blob("TreeJoint", Vector3.one * radius * 2.2, top, color, parent)
		end
		local children = rng:NextInteger(2, 3)
		for c = 1, children do
			local spread = ((c - (children + 1) / 2) / children) * 1.5 + rng:NextNumber(-0.2, 0.2)
			local child = top * CFrame.Angles(rng:NextNumber(-0.35, 0.35), 0, spread)
			branch(child, length * rng:NextNumber(0.62, 0.78), radius * 0.62, depth + 1)
		end
	end

	branch(ground(base, rng), m(rng:NextNumber(1.2, 1.8)), m(0.22), 0)
end

-- Lacy sea fan (reference 2): a flat maroon skeleton forking in its own
-- plane, behind it a membrane of packed pink cells whose gaps read as holes.
local function lacyFan(parent: Instance, base: Vector3, rng: Random)
	local root = ground(base, rng)
	local width = m(rng:NextNumber(1.8, 2.8))
	local height = width * 0.85
	local membrane = pick(rng, FAN_MEMBRANES)

	local function bone(from: CFrame, length: number, radius: number, depth: number)
		rod("FanBone", from, length + radius, radius, FAN_SKELETON, parent)
		if depth >= 3 then
			return
		end
		local top = from * CFrame.new(0, length, 0)
		for _, side in { -1, 1 } do
			bone(
				top * CFrame.Angles(0, 0, side * rng:NextNumber(0.3, 0.6)),
				length * 0.7,
				radius * 0.7,
				depth + 1
			)
		end
	end
	bone(root, height * 0.35, m(0.07), 0)

	-- Hex-packed cells inside an ellipse; each is 90 % of the spacing so the
	-- triangular gaps between them show through like the lace's holes.
	local cell = m(0.42)
	local centerY = height * 0.55
	local halfW, halfH = width / 2, height / 2
	local rows = math.floor(height / (cell * 0.87))
	local cols = math.floor(width / cell)
	for row = 0, rows do
		local y = m(0.3) + row * cell * 0.87
		for col = -cols, cols do
			local x = col * cell + (row % 2) * cell / 2
			local dx, dy = x / halfW, (y - centerY) / halfH
			if dx * dx + dy * dy <= 1 then
				local piece = blob(
					"FanLace",
					Vector3.new(cell * 0.9, cell * 0.9, m(0.03)),
					root * CFrame.new(x, y, 0),
					membrane,
					parent
				)
				piece.Transparency = 0.2
			end
		end
	end
end

-- Trumpet cups (reference 1, left): 4–7 flared yellow-orange cups fanning
-- out from one foot, each with a pink rim and a darker mouth.
local function trumpetCups(parent: Instance, base: Vector3, rng: Random)
	local root = ground(base, rng)
	local count = rng:NextInteger(4, 7)
	for i = 1, count do
		local cup = root
			* CFrame.new(jitter(rng, 0.15))
			* CFrame.Angles(0, i / count * TAU + rng:NextNumber(-0.3, 0.3), 0)
			* CFrame.Angles(rng:NextNumber(0.15, 0.8), 0, 0)
		local length = m(rng:NextNumber(0.5, 1))
		local radius = m(rng:NextNumber(0.18, 0.3))
		local body = pick(rng, CUP_BODY)
		-- Stepped flare: stem, then two wider rings.
		rod("CupStem", cup, length * 0.45, radius * 0.45, body, parent)
		rod(
			"CupFlare",
			cup * CFrame.new(0, length * 0.4, 0),
			length * 0.35,
			radius * 0.75,
			body,
			parent
		)
		rod("CupFlare", cup * CFrame.new(0, length * 0.7, 0), length * 0.3, radius, body, parent)
		disc(
			"CupRim",
			cup * CFrame.new(0, length + m(0.01), 0),
			radius * 2.25,
			m(0.05),
			CUP_RIM,
			parent
		)
		disc(
			"CupMouth",
			cup * CFrame.new(0, length + m(0.04), 0),
			radius * 1.6,
			m(0.02),
			CUP_MOUTH,
			parent
		)
	end
end

-- Feathery bush (reference 1, behind): 3–5 fronds with paired leaflets,
-- mint at the base and paler at the tips. About 1–1.5 m.
local function featherBush(parent: Instance, base: Vector3, rng: Random)
	local gradient = pick(rng, FEATHER)
	local root = ground(base, rng)
	local count = rng:NextInteger(3, 5)
	for i = 1, count do
		local frond = root
			* CFrame.Angles(0, i / count * TAU + rng:NextNumber(-0.4, 0.4), 0)
			* CFrame.Angles(rng:NextNumber(0.2, 0.7), 0, 0)
		local length = m(rng:NextNumber(0.9, 1.6))
		rod("FeatherStem", frond, length, m(0.05), gradient.base, parent)
		for j = 1, 3 do
			local t = j / 3
			local leaf = m(0.5) * (1.15 - t * 0.45)
			local at = frond * CFrame.new(0, length * (0.2 + t * 0.6), 0)
			local color = gradient.base:Lerp(gradient.tip, t)
			for _, side in { -1, 1 } do
				blob(
					"Feather",
					Vector3.new(leaf, m(0.08), m(0.16)),
					at * CFrame.Angles(0, 0, side * 0.5) * CFrame.new(side * leaf / 2, 0, 0),
					color,
					parent
				)
			end
		end
		blob(
			"FeatherTip",
			Vector3.new(m(0.14), m(0.3), m(0.14)),
			frond * CFrame.new(0, length, 0),
			gradient.tip,
			parent
		)
	end
end

-- Lumpy cushion of overlapping balls (reference 1, base): moss or sponge.
local function cushion(
	parent: Instance,
	base: Vector3,
	rng: Random,
	palette: { Color3 },
	name: string
)
	local root = ground(base, rng)
	local width = m(rng:NextNumber(0.9, 1.8))
	for _ = 1, rng:NextInteger(5, 8) do
		local size = width * rng:NextNumber(0.35, 0.6)
		local offset = Vector3.new(
			rng:NextNumber(-0.5, 0.5) * width,
			size * 0.25,
			rng:NextNumber(-0.35, 0.35) * width
		)
		blob(
			name,
			Vector3.new(size, size * 0.7, size),
			root * CFrame.new(offset),
			pick(rng, palette),
			parent
		)
	end
end

local function mossMound(parent: Instance, base: Vector3, rng: Random)
	cushion(parent, base, rng, MOSS, "Moss")
end

local function spongeMound(parent: Instance, base: Vector3, rng: Random)
	cushion(parent, base, rng, DARK_SPONGE, "DarkSponge")
end

-- Striped brain coral (reference 2, base): stacked, shrinking domes in
-- alternating yellow and orange; each cap pokes out of the one below,
-- leaving a ring of the other color.
local function stripedBrain(parent: Instance, base: Vector3, rng: Random)
	local root = ground(base, rng)
	local width = m(rng:NextNumber(1.4, 2.6))
	local height = width * 0.5
	local top = height * 0.2 -- the first dome is half buried
	for i = 0, 4 do
		local k = 1 - i * 0.17
		local w, h = width * k, height * k
		local y = top + m(0.05) - h / 2
		blob(
			"BrainCoral",
			Vector3.new(w, h, w * 0.85),
			root
				* CFrame.new(
					rng:NextNumber(-0.04, 0.04) * width,
					y,
					rng:NextNumber(-0.04, 0.04) * width
				)
				* CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
			BRAIN_STRIPES[i % 2 + 1],
			parent
		)
		top = y + h / 2
	end
end

-- Wavy orange weed (reference 2, base): 5–8 blades, each bending halfway up.
local function leafyWeed(parent: Instance, base: Vector3, rng: Random)
	local root = ground(base, rng)
	local count = rng:NextInteger(5, 8)
	for i = 1, count do
		local blade = root
			* CFrame.Angles(0, i / count * TAU + rng:NextNumber(-0.3, 0.3), 0)
			* CFrame.Angles(rng:NextNumber(0.1, 0.5), 0, 0)
		local length = m(rng:NextNumber(0.6, 1.2))
		blob(
			"WeedBlade",
			Vector3.new(m(0.22), length * 0.6, m(0.03)),
			blade * CFrame.new(0, length * 0.3, 0),
			pick(rng, WEED),
			parent
		)
		blob(
			"WeedBlade",
			Vector3.new(m(0.18), length * 0.5, m(0.03)),
			blade
				* CFrame.new(0, length * 0.55, 0)
				* CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, 0)
				* CFrame.new(0, length * 0.25, 0),
			pick(rng, WEED),
			parent
		)
	end
end

---------------------------------------------------------------------------
-- Supporting shapes kept from before
---------------------------------------------------------------------------

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
	end
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

-- Sea anemone: a squat column ringed with tentacles reaching up and out.
local function anemone(parent: Instance, base: Vector3, rng: Random)
	local color = pick(
		rng,
		{
			Color3.fromRGB(230, 80, 150),
			Color3.fromRGB(120, 210, 120),
			Color3.fromRGB(240, 150, 80),
		}
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
		local tentacle = root
			* CFrame.new(0, width * 0.6, 0)
			* CFrame.Angles(0, i / count * TAU, 0)
			* CFrame.new(0, 0, width * 0.3)
			* CFrame.Angles(rng:NextNumber(0.3, 0.8), 0, 0)
		rod(
			"Tentacle",
			tentacle,
			m(rng:NextNumber(0.4, 0.7)),
			m(0.04),
			color:Lerp(Color3.new(1, 1, 1), 0.35),
			parent
		)
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

-- Giant clam: two shells gaping open around a vivid mantle.
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

---------------------------------------------------------------------------
-- Patch composition: hero in the middle, middle layer around, base in front
---------------------------------------------------------------------------

type Weighted = { shape: Shape, weight: number }

local HEROES: { Weighted } = {
	{ shape = treeCoral, weight = 4 },
	{ shape = lacyFan, weight = 3 },
	{ shape = tableCoral, weight = 1 },
	{ shape = pillarCoral, weight = 1 },
}
local MIDDLE: { Weighted } = {
	{ shape = trumpetCups, weight = 3 },
	{ shape = featherBush, weight = 3 },
	{ shape = stripedBrain, weight = 2 },
	{ shape = tubeSponge, weight = 1 },
	{ shape = barrelSponge, weight = 1 },
	{ shape = elkhorn, weight = 1 },
	{ shape = anemone, weight = 1 },
	{ shape = seaWhip, weight = 1 },
}
local BASE: { Weighted } = {
	{ shape = mossMound, weight = 3 },
	{ shape = spongeMound, weight = 2 },
	{ shape = leafyWeed, weight = 3 },
	{ shape = mushroomCoral, weight = 1 },
	{ shape = giantClam, weight = 1 },
}

local function weighted(rng: Random, list: { Weighted }): Shape
	local total = 0
	for _, entry in list do
		total += entry.weight
	end
	local roll = rng:NextNumber(0, total)
	for _, entry in list do
		roll -= entry.weight
		if roll <= 0 then
			return entry.shape
		end
	end
	return list[#list].shape
end

-- Boulders 0.6–2.2 m.
local function rocks(parent: Instance, base: Vector3, rng: Random)
	for _ = 1, rng:NextInteger(2, 3) do
		local size = m(rng:NextNumber(0.6, 2.2))
		local rock = blob(
			"Rock",
			Vector3.new(size, size * 0.7, size * rng:NextNumber(0.8, 1.3)),
			CFrame.new(around(rng, base, 1.5, 3.5) + Vector3.new(0, size * 0.3 - SINK, 0)),
			ROCK,
			parent
		)
		rock.Material = Enum.Material.Slate
	end
end

local function reefPatch(parent: Instance, base: Vector3, rng: Random)
	local patch = Instance.new("Model")
	patch.Name = "Reef"
	weighted(rng, HEROES)(patch, base, rng)
	for _ = 1, rng:NextInteger(2, 3) do
		weighted(rng, MIDDLE)(patch, around(rng, base, 1.6, 2.8), rng)
	end
	for _ = 1, rng:NextInteger(2, 4) do
		weighted(rng, BASE)(patch, around(rng, base, 0.9, 3.2), rng)
	end
	rocks(patch, base, rng)
	patch.Parent = parent
end

---------------------------------------------------------------------------
-- Giant kelp: segmented stalks the client sways (see KelpRig, KelpSway)
---------------------------------------------------------------------------

type KelpGroup = { min: number, max: number, spread: number }

local function kelp(parent: Instance, base: Vector3, rng: Random, group: KelpGroup)
	local tallest = math.min(KELP_HEIGHT.max, Config.World.oceanFloorMeters - KELP_SURFACE_GAP)
	for _ = 1, rng:NextInteger(group.min, group.max) do
		local height = m(rng:NextNumber(math.min(KELP_HEIGHT.min, tallest), tallest))
		local spec: KelpRig.Spec = {
			segments = KELP_SEGMENTS,
			segLength = height / KELP_SEGMENTS,
			leafLength = m(rng:NextNumber(1.5, 2.5)),
		}
		local baseCFrame = CFrame.new(base + jitter(rng, group.spread) - Vector3.new(0, SINK, 0))
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
				Size = Vector3.new(m(0.15), spec.segLength * 1.03, m(0.15)),
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

	for _ = 1, PATCHES do
		local base = randomSpot()
		reefPatch(folder, base, rng)
		if rng:NextNumber() < KELP_CHANCE then
			kelp(folder, around(rng, base, 4, 7), rng, KELP_TUFT)
		end
	end

	for _ = 1, KELP_FORESTS do
		kelp(folder, randomSpot(), rng, KELP_FOREST)
	end

	for _ = 1, VENTS do
		vent(folder, randomSpot(), rng)
	end

	folder.Parent = parent
	return folder
end

return SeabedBuilder
