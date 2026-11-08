--!strict
-- Pure fishing rolls. Callers pass random numbers in [0, 1) so results are testable.

export type FishLike = {
	id: string,
	zoneId: string,
	rarity: string,
	minWeight: number,
	maxWeight: number,
}

local Fishing = {}

-- Picks a fish species for a zone. The rarity is chosen by rarityWeights (only rarities
-- present in the zone count), then a species within that rarity by the rest of the roll.
function Fishing.rollFish<F>(
	fishList: { F & FishLike },
	zoneId: string,
	rarityWeights: { [string]: number },
	rarityOrder: { string },
	roll: number
): (F & FishLike)?
	local byRarity: { [string]: { F & FishLike } } = {}
	for _, fish in fishList do
		if fish.zoneId == zoneId then
			local bucket = byRarity[fish.rarity]
			if bucket == nil then
				bucket = {}
				byRarity[fish.rarity] = bucket
			end
			table.insert(bucket, fish)
		end
	end

	local total = 0
	for _, rarity in rarityOrder do
		if byRarity[rarity] then
			total += rarityWeights[rarity] or 0
		end
	end
	if total <= 0 then
		return nil
	end

	local target = roll * total
	local cumulative = 0
	for _, rarity in rarityOrder do
		local bucket = byRarity[rarity]
		local weight = rarityWeights[rarity] or 0
		if bucket and weight > 0 then
			if target < cumulative + weight then
				-- Reuse the position inside this rarity's slice to choose the species.
				local inside = (target - cumulative) / weight
				local index = math.clamp(math.floor(inside * #bucket) + 1, 1, #bucket)
				return bucket[index]
			end
			cumulative += weight
		end
	end

	-- roll was 1 or rounding pushed past the end: return the last available fish.
	for i = #rarityOrder, 1, -1 do
		local bucket = byRarity[rarityOrder[i]]
		if bucket then
			return bucket[#bucket]
		end
	end
	return nil
end

-- Weight of a caught fish in kg, rounded to 0.01.
function Fishing.rollWeight(fish: FishLike, roll: number): number
	local weight = fish.minWeight + (fish.maxWeight - fish.minWeight) * roll
	return math.round(weight * 100) / 100
end

-- Swim speed multiplier for a diver carrying totalWeight kg.
function Fishing.speedMultiplier(
	totalWeight: number,
	penaltyPerKg: number,
	minMultiplier: number
): number
	return math.max(minMultiplier, 1 - totalWeight * penaltyPerKg)
end

return Fishing
