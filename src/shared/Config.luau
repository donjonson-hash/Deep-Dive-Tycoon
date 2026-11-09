--!strict
-- All game balance lives here. Numbers are starting values from docs/PROJECT.md
-- and are expected to change after playtests.

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

-- Where a zone's fish live: a ring around the island (studs from the center)
-- above a given seabed. Zones without it spawn no fish.
export type ZoneSpawn = {
	minRadius: number,
	maxRadius: number,
	floorMeters: number, -- seabed depth under this ring
}

export type Zone = {
	id: string,
	name: string,
	minDepth: number, -- meters, inclusive
	maxDepth: number, -- meters, exclusive (math.huge for the last zone)
	drainPerSecond: number, -- passive O2 drain while in this zone
	recommendedMaxO2: number, -- hint for players, not enforced
	spawn: ZoneSpawn?,
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

export type HatchChance = {
	fishId: string,
	chance: number, -- percent; chances of one egg add up to 100
}

export type Egg = {
	id: string,
	name: string,
	price: number, -- coins
	zoneId: string, -- nests sit on this zone's seabed
	nestCount: number,
	restockSeconds: number, -- a bought egg reappears after this long
	hatch: { HatchChance }, -- shown to the player before buying (platform rule)
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
	oceanFloorMeters = 50, -- the lagoon is 50 m deep (owner decision 2026-11-09)
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
	perSpecies = 6, -- fish of each species alive at once
	respawnSeconds = 20, -- a caught fish is replaced after this long (GDD: 20–60 s)
	swimSpeed = 6, -- studs per second
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

-- One biome in the prototype (owner decision 2026-11-09): the Lagoon, 50 m
-- deep. The six-zone ladder from the GDD returns when the prototype proves out.
local LAGOON_RING = { minRadius = 100, maxRadius = 300, floorMeters = 50 } :: ZoneSpawn

Config.Zones = {
	{
		id = "Lagoon",
		name = "Лагуна",
		minDepth = 0,
		maxDepth = math.huge,
		drainPerSecond = 1,
		recommendedMaxO2 = 50,
		spawn = LAGOON_RING,
	},
} :: { Zone }

-- Prototype fish: two species, both in the Lagoon (owner decision 2026-11-09).
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
		id = "Tuna",
		name = "Тунец",
		zoneId = "Lagoon",
		rarity = "Uncommon",
		basePrice = 60,
		minWeight = 8,
		maxWeight = 30,
		catchCost = 15,
	},
} :: { Fish }

-- Eggs sold from nests on the seabed. Hatching and the aquarium come next;
-- for now a bought egg sits in the player's inventory.
Config.Eggs = {
	{
		id = "LagoonEgg",
		name = "Икра лагуны",
		price = 50, -- assumption: about ten sardines or one tuna
		zoneId = "Lagoon",
		nestCount = 4,
		restockSeconds = 60,
		hatch = {
			{ fishId = "Sardine", chance = 70 },
			{ fishId = "Tuna", chance = 30 },
		},
	},
} :: { Egg }

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
