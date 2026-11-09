--!strict
-- Top-left panel: oxygen bar and coin count. Reads the Player attributes the
-- server writes (shared/Attributes) and never computes game state itself.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Logic = Shared:WaitForChild("Logic")
local Oxygen = require(Logic:WaitForChild("Oxygen"))
local Net = require(Logic:WaitForChild("Net"))

local PANEL = Color3.fromRGB(10, 30, 60)
local BAR_BACK = Color3.fromRGB(5, 15, 30)
local COIN = Color3.fromRGB(255, 200, 40)
local NET_FULL = Color3.fromRGB(255, 120, 120)
local BAR_COLORS: { [Oxygen.WarningLevel]: Color3 } = {
	Ok = Color3.fromRGB(70, 180, 255),
	Low = Color3.fromRGB(255, 170, 40),
	Critical = Color3.fromRGB(230, 60, 60),
}

local StatsHud = {}

type Ui = {
	o2Fill: Frame,
	o2Text: TextLabel,
	coinsText: TextLabel,
	netText: TextLabel,
	eggsText: TextLabel,
}

local function round(parent: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = parent
end

local function makeLabel(props: { [string]: any }, parent: Instance): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextXAlignment = Enum.TextXAlignment.Left
	for key, value in props do
		(label :: any)[key] = value
	end
	label.Parent = parent
	return label
end

local function build(parent: Instance): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "StatsHud"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Position = UDim2.fromOffset(12, 12)
	panel.Size = UDim2.fromOffset(240, 146)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	round(panel, 8)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.PaddingTop = UDim.new(0, 10)
	padding.Parent = panel

	-- Oxygen row: "O₂" title, then a bar with the numbers on top of it.
	makeLabel({
		Name = "O2Title",
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.fromOffset(32, 28),
		Text = "O₂",
	}, panel)

	local bar = Instance.new("Frame")
	bar.Name = "O2Bar"
	bar.Position = UDim2.fromOffset(40, 0)
	bar.Size = UDim2.new(1, -40, 0, 28)
	bar.BackgroundColor3 = BAR_BACK
	bar.Parent = panel
	round(bar, 6)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = BAR_COLORS.Ok
	fill.BorderSizePixel = 0
	fill.Parent = bar
	round(fill, 6)

	local o2Text = makeLabel({
		Name = "O2Text",
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.5,
		Text = "",
		ZIndex = 2,
	}, bar)

	-- Coins row: a yellow disc and the amount.
	local coin = Instance.new("Frame")
	coin.Name = "CoinIcon"
	coin.Position = UDim2.fromOffset(4, 40)
	coin.Size = UDim2.fromOffset(24, 24)
	coin.BackgroundColor3 = COIN
	coin.Parent = panel
	round(coin, 12)

	local coinsText = makeLabel({
		Name = "CoinsText",
		Position = UDim2.fromOffset(40, 38),
		Size = UDim2.new(1, -40, 0, 28),
		Text = "0",
	}, panel)

	-- Net row: how many fish are carried and how much they weigh.
	local netText = makeLabel({
		Name = "NetText",
		Position = UDim2.fromOffset(4, 74),
		Size = UDim2.new(1, -4, 0, 24),
		Text = "",
	}, panel)

	-- Eggs row: bought eggs waiting to hatch.
	local eggsText = makeLabel({
		Name = "EggsText",
		Position = UDim2.fromOffset(4, 102),
		Size = UDim2.new(1, -4, 0, 24),
		Text = "",
	}, panel)

	gui.Parent = parent
	return {
		o2Fill = fill,
		o2Text = o2Text,
		coinsText = coinsText,
		netText = netText,
		eggsText = eggsText,
	}
end

local function readEggs(player: Player): { string }
	local raw = player:GetAttribute(Attributes.Eggs)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, items = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(items) == "table" then items else {}
end

local function readNet(player: Player): { Net.ItemLike }
	local raw = player:GetAttribute(Attributes.Net)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, items = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(items) == "table" then items else {}
end

local function readNumber(player: Player, name: string): number
	local value = player:GetAttribute(name)
	return if type(value) == "number" then value else 0
end

function StatsHud.start()
	local player = Players.LocalPlayer
	local ui = build(player:WaitForChild("PlayerGui"))
	local tweenInfo = TweenInfo.new(Config.Oxygen.tickSeconds, Enum.EasingStyle.Linear)

	local function refresh()
		local max = readNumber(player, Attributes.MaxO2)
		local current = readNumber(player, Attributes.CurrentO2)
		local coins = readNumber(player, Attributes.Coins)

		local fraction = if max > 0 then math.clamp(current / max, 0, 1) else 0
		local level = Oxygen.warningLevel(
			current,
			max,
			Config.Oxygen.warningFraction,
			Config.Oxygen.criticalFraction
		)

		ui.o2Fill.BackgroundColor3 = BAR_COLORS[level]
		TweenService:Create(ui.o2Fill, tweenInfo, { Size = UDim2.fromScale(fraction, 1) }):Play()
		ui.o2Text.Text = `{math.ceil(current)} / {max}`
		ui.coinsText.Text = tostring(math.floor(coins))

		local net = readNet(player)
		local capacity = Config.Inventory.netCapacity
		local full = Net.isFull(#net, capacity)
		local weight = Net.totalWeight(net)
		ui.netText.Text = string.format(
			"Садок %d/%d · %.1f кг%s",
			#net,
			capacity,
			weight,
			if full then " · полон" else ""
		)
		ui.netText.TextColor3 = if full then NET_FULL else Color3.new(1, 1, 1)

		ui.eggsText.Text = `Яйца: {#readEggs(player)}`
	end

	for _, name in Attributes do
		player:GetAttributeChangedSignal(name):Connect(refresh)
	end
	refresh()
end

return StatsHud
