--!strict
-- Pure helpers for the oxygen training pools on the pier.

export type PoolLike = {
	id: string,
	unlockMaxO2: number,
	gainPerTick: number,
}

local Pools = {}

function Pools.isUnlocked(pool: PoolLike, maxO2: number): boolean
	return maxO2 >= pool.unlockMaxO2
end

-- MaxO2 gained per tick by a player with maxO2 standing in the pool; 0 while locked.
function Pools.gainFor(pool: PoolLike, maxO2: number): number
	return if Pools.isUnlocked(pool, maxO2) then pool.gainPerTick else 0
end

-- Unlocked pool with the highest gain; used by auto-training. Nil if none is unlocked.
function Pools.bestUnlocked<P>(pools: { P & PoolLike }, maxO2: number): (P & PoolLike)?
	local best: (P & PoolLike)? = nil
	for _, pool in pools do
		if
			Pools.isUnlocked(pool, maxO2) and (best == nil or pool.gainPerTick > best.gainPerTick)
		then
			best = pool
		end
	end
	return best
end

return Pools
