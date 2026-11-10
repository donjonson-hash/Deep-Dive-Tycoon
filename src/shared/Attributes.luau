--!strict
-- Names of the Player attributes that carry per-player state to clients.
-- Only the server writes them; clients read and draw. Attributes replicate on
-- their own, so no Remotes are needed for display.

return {
	MaxO2 = "MaxO2",
	CurrentO2 = "CurrentO2",
	Coins = "Coins",
	-- JSON array of { id: string, weight: number }: the fish in the player's net.
	Net = "Net",
	-- JSON array of egg ids (Config.Eggs) the player has bought and not hatched.
	Eggs = "Eggs",
}
