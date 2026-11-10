--!strict
-- Pure egg rules: affording one and rolling what hatches from it.

export type HatchLike = {
	fishId: string,
	chance: number, -- percent
}

local Eggs = {}

function Eggs.canBuy(coins: number, price: number): boolean
	return coins >= price
end

-- Picks the species an egg hatches into. `roll` is in [0, 1); chances are
-- percentages walked in order, so the table itself is the odds shown to players.
function Eggs.hatch(chances: { HatchLike }, roll: number): string?
	local total = 0
	for _, entry in chances do
		total += entry.chance
	end
	if total <= 0 then
		return nil
	end

	local target = roll * total
	local cumulative = 0
	for _, entry in chances do
		cumulative += entry.chance
		if target < cumulative then
			return entry.fishId
		end
	end
	return chances[#chances].fishId
end

-- "Сардина 70% · Тунец 30%" for labels; names come from the caller.
function Eggs.describeChances(chances: { HatchLike }, nameOf: (string) -> string): string
	local parts = {}
	for _, entry in chances do
		table.insert(parts, `{nameOf(entry.fishId)} {entry.chance}%`)
	end
	return table.concat(parts, " · ")
end

return Eggs
