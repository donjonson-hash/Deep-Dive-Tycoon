--!strict
-- One color per rarity, shared by the fish models and the market price list so
-- a player learns the code once.

local RarityColors: { [string]: Color3 } = {
	Common = Color3.fromRGB(150, 170, 190),
	Uncommon = Color3.fromRGB(90, 190, 110),
	Rare = Color3.fromRGB(255, 140, 50),
	Epic = Color3.fromRGB(170, 90, 230),
	Legendary = Color3.fromRGB(255, 210, 60),
}

return RarityColors
