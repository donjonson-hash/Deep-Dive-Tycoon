--!strict
-- Pure helpers for the diver's net (the catch carried during a dive).

export type ItemLike = {
	weight: number, -- kg
}

local Net = {}

function Net.isFull(count: number, capacity: number): boolean
	return count >= capacity
end

function Net.totalWeight(items: { ItemLike }): number
	local total = 0
	for _, item in items do
		total += item.weight
	end
	return total
end

return Net
