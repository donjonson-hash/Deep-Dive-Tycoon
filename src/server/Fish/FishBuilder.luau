--!strict
-- Builds fish models from parts, one recipe per species, so a sardine, a
-- seahorse and a parrotfish look like what their names say. Bodies are Parts
-- with a Sphere SpecialMesh (an ellipsoid the size of the part), fins are
-- wedges or flattened ellipsoids.
--
-- Contract with FishService: every fish faces -Z, PrimaryPart is "Body", and
-- the tail is a Model whose pivot sits on its hinge; FishService swings it with
-- PivotTo(body * tailHinge * yaw).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local RarityColors = require(ReplicatedStorage.Shared.RarityColors)

local FishBuilder = {}

export type FishParts = {
	model: Model,
	body: BasePart,
	tail: Model,
	tailHinge: CFrame, -- relative to the body
	height: number, -- studs above the body center where the price tag goes
}

local EYE = Color3.fromRGB(15, 15, 15)
local EYE_WHITE = Color3.fromRGB(240, 240, 240)
local LABEL_DISTANCE = 80 -- studs; the price tag fades beyond this

---------------------------------------------------------------------------
-- Part helpers. Everything is built around the origin facing -Z.
---------------------------------------------------------------------------

local function makePart(className: string, props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(className :: any) :: BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
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
	local part =
		makePart("Part", { Name = name, Size = size, CFrame = cframe, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function box(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): BasePart
	return makePart("Part", { Name = name, Size = size, CFrame = cframe, Color = color }, parent)
end

-- Swept triangular fin. A WedgePart is thin at -Z and full height at +Z, so by
-- default it is a tail lobe (thin edge at the body, flaring backward).
local function wedge(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): BasePart
	return makePart(
		"WedgePart",
		{ Name = name, Size = size, CFrame = cframe, Color = color },
		parent
	)
end

-- Dorsal fin standing on the back: base `length` along the body, `height` up.
local function dorsalFin(
	parent: Instance,
	length: number,
	height: number,
	y: number,
	z: number,
	color: Color3
)
	wedge(
		"DorsalFin",
		Vector3.new(0.12, length, height),
		CFrame.new(0, y + height / 2, z) * CFrame.Angles(math.pi / 2, 0, 0),
		color,
		parent
	)
end

-- Anal fin hanging under the belly, mirror of the dorsal fin.
local function analFin(
	parent: Instance,
	length: number,
	height: number,
	y: number,
	z: number,
	color: Color3
)
	wedge(
		"AnalFin",
		Vector3.new(0.12, length, height),
		CFrame.new(0, y - height / 2, z) * CFrame.Angles(-math.pi / 2, 0, 0),
		color,
		parent
	)
end

-- Pair of rounded pectoral fins, angled back along the flanks.
local function pectoralFins(
	parent: Instance,
	halfWidth: number,
	y: number,
	z: number,
	length: number,
	color: Color3
)
	for _, side in { -1, 1 } do
		blob(
			"PectoralFin",
			Vector3.new(0.1, length * 0.5, length),
			CFrame.new(side * halfWidth, y, z)
				* CFrame.Angles(0, side * 0.5, side * -0.3)
				* CFrame.new(0, 0, length * 0.4),
			color,
			parent
		)
	end
end

local function eyes(parent: Instance, halfWidth: number, y: number, z: number, size: number)
	for _, side in { -1, 1 } do
		blob("EyeWhite", Vector3.one * size, CFrame.new(side * halfWidth, y, z), EYE_WHITE, parent)
		blob(
			"Eye",
			Vector3.one * size * 0.55,
			CFrame.new(side * (halfWidth + size * 0.2), y, z - size * 0.1),
			EYE,
			parent
		)
	end
end

-- Forked tail: two wedge lobes, one flaring up and one flaring down, in a Model
-- pivoted at the hinge so FishService can swing it.
local function forkedTail(
	parent: Instance,
	hingeZ: number,
	lobeHeight: number,
	lobeLength: number,
	color: Color3
): (Model, CFrame)
	local tail = Instance.new("Model")
	tail.Name = "Tail"
	local size = Vector3.new(0.12, lobeHeight, lobeLength)
	wedge("TailUpper", size, CFrame.new(0, lobeHeight / 2, hingeZ + lobeLength / 2), color, tail)
	wedge(
		"TailLower",
		size,
		CFrame.new(0, -lobeHeight / 2, hingeZ + lobeLength / 2) * CFrame.Angles(0, 0, math.pi),
		color,
		tail
	)
	local hinge = CFrame.new(0, 0, hingeZ)
	tail.WorldPivot = hinge
	tail.Parent = parent
	return tail, hinge
end

-- Rounded fan tail (clownfish-style) as a flattened ellipsoid.
local function roundTail(
	parent: Instance,
	hingeZ: number,
	height: number,
	length: number,
	color: Color3
): (Model, CFrame)
	local tail = Instance.new("Model")
	tail.Name = "Tail"
	blob(
		"TailFin",
		Vector3.new(0.14, height, length),
		CFrame.new(0, 0, hingeZ + length / 2),
		color,
		tail
	)
	local hinge = CFrame.new(0, 0, hingeZ)
	tail.WorldPivot = hinge
	tail.Parent = parent
	return tail, hinge
end

---------------------------------------------------------------------------
-- Species recipes. Each returns body, tail, tail hinge and the height of the
-- top of the fish above its center.
---------------------------------------------------------------------------

type Recipe = (model: Model) -> (BasePart, Model, CFrame, number)

local function sardine(model: Model): (BasePart, Model, CFrame, number)
	local silver = Color3.fromRGB(205, 215, 225)
	local back = Color3.fromRGB(55, 90, 150)
	local length = 3.2
	local body = blob("Body", Vector3.new(0.55, 0.85, length), CFrame.new(), silver, model)
	blob("Back", Vector3.new(0.5, 0.5, length * 0.9), CFrame.new(0, 0.25, 0), back, model)
	dorsalFin(model, 0.7, 0.45, 0.4, 0.2, back)
	pectoralFins(model, 0.27, -0.1, -0.7, 0.6, silver)
	eyes(model, 0.22, 0.12, -length / 2 + 0.45, 0.22)
	local tail, hinge = forkedTail(model, length / 2 - 0.1, 0.5, 0.8, back)
	return body, tail, hinge, 0.9
end

local function seahorse(model: Model): (BasePart, Model, CFrame, number)
	local gold = Color3.fromRGB(240, 180, 60)
	local dark = Color3.fromRGB(200, 130, 40)
	-- Upright body, head bent forward at the top, snout pointing -Z.
	local body = blob("Body", Vector3.new(0.7, 2.0, 1.0), CFrame.new(), gold, model)
	blob("Belly", Vector3.new(0.75, 1.3, 1.1), CFrame.new(0, -0.25, -0.05), gold, model)
	blob("Head", Vector3.new(0.6, 0.8, 0.9), CFrame.new(0, 1.25, -0.3), gold, model)
	makePart("Part", {
		Name = "Snout",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.9, 0.3, 0.3),
		CFrame = CFrame.new(0, 1.2, -1.0) * CFrame.Angles(0, math.pi / 2, 0),
		Color = dark,
	}, model)
	blob("Crown", Vector3.new(0.35, 0.4, 0.35), CFrame.new(0, 1.75, -0.2), dark, model)
	-- Small back fin pointing away from the chest.
	wedge("DorsalFin", Vector3.new(0.1, 0.9, 0.5), CFrame.new(0, 0.2, 0.7), dark, model)
	eyes(model, 0.25, 1.35, -0.55, 0.2)
	-- Curled prehensile tail hanging from the belly.
	local tail = Instance.new("Model")
	tail.Name = "Tail"
	local segments = {
		{ CFrame.new(0, -1.35, 0.05) * CFrame.Angles(0, 0, math.pi / 2), 0.8 },
		{
			CFrame.new(0, -1.9, -0.2)
				* CFrame.Angles(0, 0, math.pi / 2)
				* CFrame.Angles(0, 0, math.rad(45)),
			0.7,
		},
		{ CFrame.new(0, -2.1, -0.7) * CFrame.Angles(0, math.pi / 2, 0), 0.6 },
		{
			CFrame.new(0, -1.9, -1.05)
				* CFrame.Angles(0, 0, math.pi / 2)
				* CFrame.Angles(0, 0, math.rad(-45)),
			0.5,
		},
	}
	for i, segment in segments do
		local thickness = 0.3 - i * 0.04
		makePart("Part", {
			Name = "TailSegment",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segment[2], thickness, thickness),
			CFrame = segment[1],
			Color = if i % 2 == 0 then dark else gold,
		}, tail)
	end
	local hinge = CFrame.new(0, -1.0, 0)
	tail.WorldPivot = hinge
	tail.Parent = model
	return body, tail, hinge, 2.0
end

local function clownfish(model: Model): (BasePart, Model, CFrame, number)
	local orange = Color3.fromRGB(255, 120, 20)
	local white = Color3.fromRGB(250, 250, 250)
	local length = 3.4
	local body = blob("Body", Vector3.new(0.9, 1.5, length), CFrame.new(), orange, model)
	-- Three white bands: head, a wide middle one, and the tail root.
	for _, band in { { -0.95, 0.35, 1.0 }, { 0.15, 0.5, 1.08 }, { 1.2, 0.3, 0.9 } } do
		blob(
			"Band",
			Vector3.new(0.95 * band[3], 1.55 * band[3], band[2]),
			CFrame.new(0, 0, band[1]),
			white,
			model
		)
	end
	blob("DorsalFin", Vector3.new(0.12, 0.8, 1.5), CFrame.new(0, 0.95, 0.1), orange, model)
	blob("AnalFin", Vector3.new(0.12, 0.6, 1.0), CFrame.new(0, -0.9, 0.5), orange, model)
	pectoralFins(model, 0.45, -0.15, -0.6, 0.8, orange)
	eyes(model, 0.38, 0.25, -length / 2 + 0.5, 0.3)
	local tail, hinge = roundTail(model, length / 2 - 0.15, 1.3, 1.1, orange)
	return body, tail, hinge, 1.4
end

local function parrotfish(model: Model): (BasePart, Model, CFrame, number)
	local teal = Color3.fromRGB(40, 170, 150)
	local pink = Color3.fromRGB(230, 120, 170)
	local blue = Color3.fromRGB(60, 120, 220)
	local beak = Color3.fromRGB(250, 235, 235)
	local length = 6.5
	local body = blob("Body", Vector3.new(1.5, 2.6, length), CFrame.new(), teal, model)
	blob("Belly", Vector3.new(1.45, 1.5, length * 0.85), CFrame.new(0, -0.65, 0.1), pink, model)
	blob("Cheek", Vector3.new(1.55, 1.2, 1.6), CFrame.new(0, -0.1, -2.0), blue, model)
	blob("Beak", Vector3.new(0.9, 0.7, 0.7), CFrame.new(0, -0.3, -length / 2 + 0.05), beak, model)
	dorsalFin(model, 4.2, 0.9, 1.25, 0.4, pink)
	analFin(model, 2.6, 0.7, -1.25, 1.0, pink)
	pectoralFins(model, 0.75, -0.2, -1.4, 1.6, Color3.fromRGB(255, 200, 80))
	eyes(model, 0.72, 0.55, -2.4, 0.4)
	local tail, hinge = forkedTail(model, length / 2 - 0.3, 1.2, 1.5, blue)
	return body, tail, hinge, 2.2
end

local function surgeonfish(model: Model): (BasePart, Model, CFrame, number)
	local blue = Color3.fromRGB(30, 70, 220)
	local ink = Color3.fromRGB(15, 15, 40)
	local yellow = Color3.fromRGB(255, 220, 0)
	local length = 4.6
	-- Flat oval body with the blue tang's black "palette" on the upper flank.
	local body = blob("Body", Vector3.new(0.6, 2.6, length), CFrame.new(), blue, model)
	blob("Palette", Vector3.new(0.62, 1.7, length * 0.7), CFrame.new(0, 0.35, 0.3), ink, model)
	blob("PaletteGap", Vector3.new(0.64, 0.6, length * 0.4), CFrame.new(0, 0.45, 0.2), blue, model)
	dorsalFin(model, 3.2, 0.6, 1.25, 0.2, ink)
	analFin(model, 2.4, 0.5, -1.25, 0.6, ink)
	pectoralFins(model, 0.3, 0.1, -0.9, 1.1, yellow)
	blob("Scalpel", Vector3.new(0.66, 0.25, 0.7), CFrame.new(0, -0.1, 1.9), yellow, model)
	eyes(model, 0.3, 0.6, -length / 2 + 0.6, 0.32)
	local tail, hinge = forkedTail(model, length / 2 - 0.2, 1.0, 1.2, yellow)
	return body, tail, hinge, 1.9
end

local function angelfish(model: Model): (BasePart, Model, CFrame, number)
	local silver = Color3.fromRGB(215, 215, 225)
	local stripe = Color3.fromRGB(25, 25, 35)
	local finColor = Color3.fromRGB(190, 190, 205)
	local length = 3.4
	-- Tall, thin disc of a body with vertical stripes and trailing fins.
	local body = blob("Body", Vector3.new(0.5, 3.6, length), CFrame.new(), silver, model)
	for _, z in { -0.9, 0.2, 1.2 } do
		blob("Stripe", Vector3.new(0.54, 3.65, 0.35), CFrame.new(0, 0, z), stripe, model)
	end
	dorsalFin(model, 2.4, 3.0, 1.75, 0.3, finColor)
	analFin(model, 2.4, 3.0, -1.75, 0.3, finColor)
	-- Long ventral "feelers" trailing below the chest.
	for _, side in { -1, 1 } do
		box(
			"VentralFin",
			Vector3.new(0.1, 2.6, 0.12),
			CFrame.new(side * 0.15, -1.5, -0.6)
				* CFrame.Angles(math.rad(-25), 0, 0)
				* CFrame.new(0, -1.2, 0),
			finColor,
			model
		)
	end
	pectoralFins(model, 0.25, 0.1, -0.7, 0.8, finColor)
	eyes(model, 0.26, 0.5, -length / 2 + 0.5, 0.3)
	local tail, hinge = forkedTail(model, length / 2 - 0.15, 1.1, 1.3, finColor)
	return body, tail, hinge, 4.8
end

-- Fallback for a species without a recipe: a plain fish colored by rarity.
local function generic(species: Config.Fish): Recipe
	return function(model: Model)
		local color = RarityColors[species.rarity] or RarityColors.Common
		local length = math.clamp(3 + species.maxWeight * 1.5, 3, 8)
		local body = blob(
			"Body",
			Vector3.new(length * 0.25, length * 0.45, length),
			CFrame.new(),
			color,
			model
		)
		dorsalFin(model, length * 0.4, length * 0.2, length * 0.225, 0, color)
		eyes(model, length * 0.12, length * 0.07, -length * 0.35, length * 0.1)
		local tail, hinge = forkedTail(model, length / 2 - 0.1, length * 0.2, length * 0.3, color)
		return body, tail, hinge, length * 0.45
	end
end

local RECIPES: { [string]: Recipe } = {
	Sardine = sardine,
	Seahorse = seahorse,
	Clownfish = clownfish,
	Parrotfish = parrotfish,
	Surgeonfish = surgeonfish,
	Angelfish = angelfish,
}

---------------------------------------------------------------------------

-- Name and O2 requirement above the fish, name colored by rarity.
local function addPriceTag(body: BasePart, species: Config.Fish, height: number)
	local gui = Instance.new("BillboardGui")
	gui.Name = "PriceTag"
	gui.Size = UDim2.fromOffset(170, 48)
	gui.StudsOffset = Vector3.new(0, height + 1, 0)
	gui.MaxDistance = LABEL_DISTANCE
	gui.LightInfluence = 0

	local name = Instance.new("TextLabel")
	name.Size = UDim2.fromScale(1, 0.55)
	name.BackgroundTransparency = 1
	name.TextScaled = true
	name.Font = Enum.Font.GothamBold
	name.TextColor3 = RarityColors[species.rarity] or Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.3
	name.Text = species.name
	name.Parent = gui

	local cost = Instance.new("TextLabel")
	cost.Position = UDim2.fromScale(0, 0.55)
	cost.Size = UDim2.fromScale(1, 0.45)
	cost.BackgroundTransparency = 1
	cost.TextScaled = true
	cost.Font = Enum.Font.GothamBold
	cost.TextColor3 = Color3.new(1, 1, 1)
	cost.TextStrokeTransparency = 0.3
	cost.Text = `нужно {species.catchCost} O₂`
	cost.Parent = gui

	gui.Parent = body
end

function FishBuilder.build(species: Config.Fish): FishParts
	local model = Instance.new("Model")
	model.Name = species.id
	model:SetAttribute("SpeciesId", species.id)
	model:SetAttribute("ZoneId", species.zoneId)
	model:SetAttribute("Rarity", species.rarity)

	local recipe = RECIPES[species.id] or generic(species)
	local body, tail, tailHinge, height = recipe(model)
	model.PrimaryPart = body
	addPriceTag(body, species, height)

	return { model = model, body = body, tail = tail, tailHinge = tailHinge, height = height }
end

return FishBuilder
