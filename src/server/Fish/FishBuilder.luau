--!strict
-- Builds a greybox fish model out of parts. The body points down -Z so
-- CFrame.lookAt() aims the fish at where it swims. Size grows with the species'
-- max weight and color follows rarity, so a sardine and a parrotfish read
-- differently from a distance without any art.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local FishBuilder = {}

local RARITY_COLORS: { [string]: Color3 } = {
	Common = Color3.fromRGB(150, 170, 190),
	Uncommon = Color3.fromRGB(90, 190, 110),
	Rare = Color3.fromRGB(255, 140, 50),
	Epic = Color3.fromRGB(170, 90, 230),
	Legendary = Color3.fromRGB(255, 210, 60),
}
local EYE = Color3.fromRGB(20, 20, 20)

local MIN_LENGTH = 1.5 -- studs
local MAX_LENGTH = 5

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

export type FishParts = {
	model: Model,
	body: BasePart,
	tail: BasePart,
}

function FishBuilder.build(species: Config.Fish): FishParts
	local length = math.clamp(MIN_LENGTH + species.maxWeight, MIN_LENGTH, MAX_LENGTH)
	local height = length * 0.45
	local width = length * 0.25
	local color = RARITY_COLORS[species.rarity] or RARITY_COLORS.Common

	local model = Instance.new("Model")
	model.Name = species.id
	model:SetAttribute("SpeciesId", species.id)
	model:SetAttribute("ZoneId", species.zoneId)
	model:SetAttribute("Rarity", species.rarity)

	local body = makePart("Part", {
		Name = "Body",
		Size = Vector3.new(width, height, length),
		Color = color,
	}, model)
	model.PrimaryPart = body

	-- Tail: a wedge behind the body, thin edge toward the body. FishService swings it.
	local tail = makePart("WedgePart", {
		Name = "Tail",
		Size = Vector3.new(width * 0.5, height * 0.9, length * 0.45),
		Color = color,
		CFrame = body.CFrame * CFrame.new(0, 0, length / 2 + length * 0.225),
	}, model)

	-- Dorsal fin on top.
	makePart("WedgePart", {
		Name = "Fin",
		Size = Vector3.new(width * 0.3, height * 0.5, length * 0.4),
		Color = color,
		CFrame = body.CFrame * CFrame.new(0, height / 2 + height * 0.25, 0),
	}, model)

	-- Eyes near the nose, one per side.
	for _, side in { -1, 1 } do
		makePart("Part", {
			Name = "Eye",
			Shape = Enum.PartType.Ball,
			Size = Vector3.one * (height * 0.25),
			Color = EYE,
			CFrame = body.CFrame * CFrame.new(side * width / 2, height * 0.15, -length * 0.35),
		}, model)
	end

	return { model = model, body = body, tail = tail }
end

return FishBuilder
