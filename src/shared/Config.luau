--!strict
-- All game balance lives here. Numbers are starting values from docs/PROJECT.md
-- and are expected to change after playtests.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type Zone = {
	id: string,
	name: string,
	minDepth: number, -- meters, inclusive
	maxDepth: number, -- meters, exclusive (math.huge for the last zone)
	drainPerSecond: number, -- passive O2 drain while in this zone
	recommendedMaxO2: number, -- hint for players, not enforced
}

export type Fish = {
	id: string,
	name: string,
	zoneId: string,
	rarity: Rarity,
	basePrice: number, -- coins
	minWeight: number, -- kg
	maxWeight: number, -- kg
	catchCost: number, -- CurrentO2 required to take the fish (not spent)
}

export type Pool = {
	id: string,
	name: string,
	unlockMaxO2: number, -- pool opens once MaxO2 reaches this value
	gainPerTick: number, -- MaxO2 gained every Oxygen.poolTickSeconds
}

local Config = {}

Config.World = {
	surfaceY = 0, -- water surface height in studs
	studsPerMeter = 3, -- game depth scale: 1 meter = 3 studs
	oceanFloorMeters = 66, -- prototype ocean only covers Lagoon + Coral Reef
	oceanSize = 800, -- studs, square
	islandRadius = 90, -- studs; big enough for spawn, pools and the market
	islandTopY = 6, -- studs
	surfaceToleranceMeters = 1, -- bobbing this close to the surface counts as "on the surface"
}

Config.Oxygen = {
	startingMaxO2 = 30,
	tickSeconds = 0.25, -- server depth/oxygen check interval (docs/PROJECT.md)
	surfaceRefillPerSecond = 10, -- assumption: a starting tank refills in 3 s at the surface
	poolTickSeconds = 1, -- assumption: pools pay out once per second
	warningFraction = 0.25, -- O2 bar turns red
	criticalFraction = 0.10, -- heartbeat sound
}

Config.Economy = {
	startingCoins = 0,
}

-- Live fish swimming in the ocean. They are the targets for catching, so counts
-- and speed are balance, not decoration.
Config.FishSpawn = {
	perSpecies = 4, -- fish of each species alive at once
	respawnSeconds = 20, -- a caught fish is replaced after this long (GDD: 20–60 s)
	swimSpeed = 6, -- studs per second
	minRadius = 100, -- studs from the island center; keeps fish out of the island
	maxRadius = 260,
	surfaceMarginMeters = 1, -- fish never break the surface
	floorMarginMeters = 2, -- or swim into the sand
}

Config.Inventory = {
	netCapacity = 3,
}

Config.Catching = {
	holdSeconds = 1.5, -- hold the prompt this long next to a fish
	reachStuds = 10, -- prompt activation distance; the server trusts the prompt's own check
}

Config.Movement = {
	baseWalkSpeed = 16, -- Roblox default; swimming speed derives from it
}

Config.Weight = {
	speedPenaltyPerKg = 0.02, -- each kg carried slows swimming by 2 %
	minSpeedMultiplier = 0.4, -- never slower than 40 % of base speed
}

-- Prototype market: fixed prices (basePrice), the live exchange comes with the MVP.
Config.Market = {
	sellCooldownSeconds = 1, -- rate limit on the sell request
}

-- Chance of each rarity among the fish of a zone. Rarities missing in a zone
-- are skipped and the remaining chances are renormalized.
Config.RarityWeights = {
	Common = 60,
	Uncommon = 25,
	Rare = 10,
	Epic = 4,
	Legendary = 1,
} :: { [Rarity]: number }

Config.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary" } :: { Rarity }

Config.Zones = {
	{
		id = "Lagoon",
		name = "Лагуна",
		minDepth = 0,
		maxDepth = 20,
		drainPerSecond = 1,
		recommendedMaxO2 = 50,
	},
	{
		id = "CoralReef",
		name = "Коралловый риф",
		minDepth = 20,
		maxDepth = 60,
		drainPerSecond = 2,
		recommendedMaxO2 = 300,
	},
	{
		id = "OpenOcean",
		name = "Открытый океан",
		minDepth = 60,
		maxDepth = 150,
		drainPerSecond = 3,
		recommendedMaxO2 = 2000,
	},
	{
		id = "Twilight",
		name = "Сумеречная зона",
		minDepth = 150,
		maxDepth = 400,
		drainPerSecond = 5,
		recommendedMaxO2 = 12000,
	},
	{
		id = "Abyss",
		name = "Бездна",
		minDepth = 400,
		maxDepth = 1000,
		drainPerSecond = 8,
		recommendedMaxO2 = 80000,
	},
	{
		id = "Trench",
		name = "Марианская впадина",
		minDepth = 1000,
		maxDepth = math.huge,
		drainPerSecond = 12,
		recommendedMaxO2 = 500000,
	},
} :: { Zone }

-- Prototype fish: three species per zone for the first two zones.
Config.Fish = {
	{
		id = "Sardine",
		name = "Сардина",
		zoneId = "Lagoon",
		rarity = "Common",
		basePrice = 5,
		minWeight = 0.1,
		maxWeight = 0.3,
		catchCost = 3,
	},
	{
		id = "Seahorse",
		name = "Морской конёк",
		zoneId = "Lagoon",
		rarity = "Uncommon",
		basePrice = 12,
		minWeight = 0.05,
		maxWeight = 0.2,
		catchCost = 5,
	},
	{
		id = "Clownfish",
		name = "Рыба-клоун",
		zoneId = "Lagoon",
		rarity = "Rare",
		basePrice = 20,
		minWeight = 0.2,
		maxWeight = 0.5,
		catchCost = 8,
	},
	{
		id = "Parrotfish",
		name = "Рыба-попугай",
		zoneId = "CoralReef",
		rarity = "Common",
		basePrice = 40,
		minWeight = 1,
		maxWeight = 3,
		catchCost = 10,
	},
	{
		id = "Surgeonfish",
		name = "Рыба-хирург",
		zoneId = "CoralReef",
		rarity = "Uncommon",
		basePrice = 80,
		minWeight = 0.8,
		maxWeight = 2,
		catchCost = 15,
	},
	{
		id = "Angelfish",
		name = "Рыба-ангел",
		zoneId = "CoralReef",
		rarity = "Rare",
		basePrice = 150,
		minWeight = 0.5,
		maxWeight = 1.5,
		catchCost = 25,
	},
} :: { Fish }

Config.Pools = {
	{
		id = "Kiddie",
		name = "Лягушатник",
		unlockMaxO2 = 0,
		gainPerTick = 1,
	},
	{
		id = "Coral",
		name = "Коралловый",
		unlockMaxO2 = 100, -- assumption, tune after playtests
		gainPerTick = 3,
	},
} :: { Pool }

return Config
