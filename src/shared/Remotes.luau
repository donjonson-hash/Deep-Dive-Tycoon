--!strict
-- Names of the RemoteEvents the server creates under ReplicatedStorage.Remotes.
-- Clients send intents only; the server validates and changes state.

return {
	Folder = "Remotes",
	-- Client → server, no arguments: sell everything in the net at the market.
	SellCatch = "SellCatch",
}
