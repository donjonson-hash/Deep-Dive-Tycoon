--!strict
-- Builds fish models from parts, one recipe per species, so a sardine and a
-- tuna look like what their names say. Bodies are Parts with a Sphere
-- SpecialMesh (an ellipsoid the size of the part), fins are wedges or
-- flattened ellipsoids.
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

-- Recipes are written at "natural" size; every part, hinge and tag offset is
-- multiplied by this on the way out (owner asked for fish twice as big).
local SCALE = 2

---------------------------------------------------------------------------
-- Part helpers. Everything is built around the origin facing -Z, in recipe
-- units; makePart applies SCALE to sizes and positions (rotation untouched).
---------------------------------------------------------------------------

local function scaled(cframe: CFrame): CFrame
	return CFrame.new(cframe.Position * SCALE) * cframe.Rotation
end

local function makePart(className: string, props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new(className :: any) :: BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Size then
		props.Size = props.Size * SCALE
	end
	if props.CFrame then
		props.CFrame = scaled(props.CFrame)
	end
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
	local hinge = scaled(CFrame.new(0, 0, hingeZ))
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

local function tuna(model: Model): (BasePart, Model, CFrame, number)
	local steel = Color3.fromRGB(40, 60, 110)
	local silver = Color3.fromRGB(200, 210, 220)
	local yellow = Color3.fromRGB(255, 210, 60)
	local length = 7.5
	-- Torpedo body: dark back, silver belly, pointed nose.
	local body = blob("Body", Vector3.new(1.6, 2.2, length), CFrame.new(), steel, model)
	blob("Belly", Vector3.new(1.55, 1.5, length * 0.9), CFrame.new(0, -0.5, 0.1), silver, model)
	blob("Nose", Vector3.new(0.9, 1.1, 1.6), CFrame.new(0, -0.1, -length / 2 + 0.3), steel, model)
	dorsalFin(model, 1.6, 1.3, 1.05, -1.0, steel)
	dorsalFin(model, 1.2, 0.8, 1.0, 1.2, yellow)
	analFin(model, 1.2, 0.7, -1.05, 1.3, yellow)
	-- Finlets along the tail stock, the tuna's signature.
	for i = 1, 3 do
		local z = 2.2 + i * 0.4
		wedge(
			"Finlet",
			Vector3.new(0.1, 0.35, 0.3),
			CFrame.new(0, 0.75, z) * CFrame.Angles(math.pi / 2, 0, 0),
			yellow,
			model
		)
		wedge(
			"Finlet",
			Vector3.new(0.1, 0.35, 0.3),
			CFrame.new(0, -0.75, z) * CFrame.Angles(-math.pi / 2, 0, 0),
			yellow,
			model
		)
	end
	-- Long sickle pectoral fins.
	pectoralFins(model, 0.8, -0.2, -1.4, 2.4, steel)
	eyes(model, 0.78, 0.35, -length / 2 + 1.1, 0.45)
	local tail, hinge = forkedTail(model, length / 2 - 0.4, 1.6, 1.7, steel)
	return body, tail, hinge, 1.9
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
	Tuna = tuna,
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
	local body, tail, tailHinge, recipeHeight = recipe(model)
	local height = recipeHeight * SCALE
	model.PrimaryPart = body
	addPriceTag(body, species, height)

	return { model = model, body = body, tail = tail, tailHinge = tailHinge, height = height }
end

return FishBuilder
