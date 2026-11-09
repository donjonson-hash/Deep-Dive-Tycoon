--!strict
-- Pure market math. The prototype sells at fixed base prices; the exchange
-- formula from the GDD replaces priceOf() in the MVP.

export type FishLike = {
	id: string,
	basePrice: number,
}

export type ItemLike = {
	id: string,
}

local Market = {}

function Market.priceOf(fish: FishLike): number
	return fish.basePrice
end

-- Species lookup for a fish list; unknown ids are worth nothing.
function Market.priceTable<F>(fishList: { F & FishLike }): { [string]: number }
	local prices: { [string]: number } = {}
	for _, fish in fishList do
		prices[fish.id] = Market.priceOf(fish)
	end
	return prices
end

function Market.totalValue(items: { ItemLike }, prices: { [string]: number }): number
	local total = 0
	for _, item in items do
		total += prices[item.id] or 0
	end
	return total
end

return Market
