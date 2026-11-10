--!strict
-- Sells the net at the market stall. The client only asks ("SellCatch"); the
-- server checks the rate limit and that the player stands in the stall's
-- SellZone, then pays fixed prototype prices and empties the net.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Bounds = require(ReplicatedStorage.Shared.Logic.Bounds)
local Market = require(ReplicatedStorage.Shared.Logic.Market)
local PlayerState = require(script.Parent.Parent.Player.PlayerState)

local MarketService = {}

local lastSell: { [Player]: number } = {}
local prices = Market.priceTable(Config.Fish)

local function findSellZone(): BasePart?
	local map = Workspace:FindFirstChild("Map")
	local market = if map then map:FindFirstChild("Market") else nil
	local zone = if market then market:FindFirstChild("SellZone") else nil
	return if zone and zone:IsA("BasePart") then zone else nil
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return Bounds.contains(p.X, p.Y, p.Z, half.X, half.Y, half.Z, 0)
end

local function onSellCatch(player: Player, zone: BasePart)
	local now = os.clock()
	if now - (lastSell[player] or 0) < Config.Market.sellCooldownSeconds then
		return
	end
	lastSell[player] = now

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") or not isInside(zone, root.Position) then
		return
	end

	local net = PlayerState.getNet(player)
	if #net == 0 then
		return
	end

	local total = Market.totalValue(net, prices)
	PlayerState.addCoins(player, total)
	PlayerState.clearNet(player)
end

function MarketService.start()
	local zone = findSellZone()
	if not zone then
		warn("[MarketService] No Map.Market.SellZone; selling is disabled")
		return
	end

	local remotes = Instance.new("Folder")
	remotes.Name = Remotes.Folder

	local sell = Instance.new("RemoteEvent")
	sell.Name = Remotes.SellCatch
	sell.OnServerEvent:Connect(function(player)
		onSellCatch(player, zone)
	end)
	sell.Parent = remotes

	remotes.Parent = ReplicatedStorage

	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSell[player] = nil
	end)
end

return MarketService
