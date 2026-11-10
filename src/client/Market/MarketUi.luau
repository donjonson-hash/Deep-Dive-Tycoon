--!strict
-- Market panel: opens while the player stands in the stall's SellZone. Left
-- column lists every species with its price, right column shows the net and
-- the sell button. The server re-checks the zone and does the actual payout;
-- this file only draws and asks.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local RarityColors = require(Shared:WaitForChild("RarityColors"))
local Logic = Shared:WaitForChild("Logic")
local Bounds = require(Logic:WaitForChild("Bounds"))
local Market = require(Logic:WaitForChild("Market"))

local PANEL = Color3.fromRGB(10, 30, 60)
local ROW = Color3.fromRGB(20, 50, 90)
local MUTED = Color3.fromRGB(170, 195, 220)
local BUTTON = Color3.fromRGB(60, 180, 90)
local BUTTON_DISABLED = Color3.fromRGB(80, 90, 100)

local ROW_HEIGHT = 28
local ROW_GAP = 4
local COLUMN_GAP = 20
local PANEL_WIDTH = 580
local TITLE_HEIGHT = 34
local HEADER_HEIGHT = 24

local MarketUi = {}

type NetItem = { id: string, weight: number }

type Ui = {
	panel: Frame,
	netRows: Frame,
	total: TextLabel,
	button: TextButton,
}

local fishById: { [string]: Config.Fish } = {}
for _, fish in Config.Fish do
	fishById[fish.id] = fish
end
local zoneNames: { [string]: string } = {}
for _, zone in Config.Zones do
	zoneNames[zone.id] = zone.name
end
local prices = Market.priceTable(Config.Fish)

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

local function makeRow(parent: Instance, order: number): Frame
	local row = Instance.new("Frame")
	row.LayoutOrder = order
	row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	row.BackgroundColor3 = ROW
	row.Parent = parent
	round(row, 6)
	return row
end

local function makeList(parent: Instance, position: UDim2, size: UDim2): Frame
	local list = Instance.new("Frame")
	list.Position = position
	list.Size = size
	list.BackgroundTransparency = 1
	list.Parent = parent

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, ROW_GAP)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return list
end

-- Price list: every species, colored by rarity, with its zone and fixed price.
local function fillPriceList(list: Frame)
	for index, fish in Config.Fish do
		local row = makeRow(list, index)
		makeLabel({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.55, -8, 1, 0),
			Text = fish.name,
			TextColor3 = RarityColors[fish.rarity] or Color3.new(1, 1, 1),
		}, row)
		makeLabel({
			Position = UDim2.fromScale(0.55, 0),
			Size = UDim2.fromScale(0.25, 1),
			Text = zoneNames[fish.zoneId] or fish.zoneId,
			TextColor3 = MUTED,
			Font = Enum.Font.Gotham,
		}, row)
		makeLabel({
			Position = UDim2.fromScale(0.8, 0),
			Size = UDim2.new(0.2, -8, 1, 0),
			Text = tostring(prices[fish.id] or 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
	end
end

local function build(parent: Instance): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MarketUi"
	gui.ResetOnSpawn = false

	local listHeight = (ROW_HEIGHT + ROW_GAP) * math.max(#Config.Fish, Config.Inventory.netCapacity)
	local panelHeight = 12 + TITLE_HEIGHT + 8 + HEADER_HEIGHT + listHeight + 96

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -24)
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, panelHeight)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.1
	panel.Visible = false
	panel.Parent = gui
	round(panel, 10)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 14)
	padding.PaddingRight = UDim.new(0, 14)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = panel

	makeLabel({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, TITLE_HEIGHT),
		Text = "Рынок · цены фиксированные",
		TextXAlignment = Enum.TextXAlignment.Center,
	}, panel)

	local columnWidth = (PANEL_WIDTH - 28 - COLUMN_GAP) / 2
	local headerY = TITLE_HEIGHT + 8
	local listY = headerY + HEADER_HEIGHT + 4

	-- Left: prices.
	makeLabel({
		Position = UDim2.fromOffset(0, headerY),
		Size = UDim2.fromOffset(columnWidth, HEADER_HEIGHT),
		Text = "Цены на рыбу",
		TextColor3 = MUTED,
	}, panel)
	local priceRows =
		makeList(panel, UDim2.fromOffset(0, listY), UDim2.fromOffset(columnWidth, listHeight))
	fillPriceList(priceRows)

	-- Right: the net and the sell button.
	local rightX = columnWidth + COLUMN_GAP
	makeLabel({
		Position = UDim2.fromOffset(rightX, headerY),
		Size = UDim2.fromOffset(columnWidth, HEADER_HEIGHT),
		Text = "Твой улов",
		TextColor3 = MUTED,
	}, panel)
	local netRows =
		makeList(panel, UDim2.fromOffset(rightX, listY), UDim2.fromOffset(columnWidth, listHeight))

	local total = makeLabel({
		Name = "Total",
		Position = UDim2.new(0, rightX, 1, -84),
		Size = UDim2.fromOffset(columnWidth, 28),
		Text = "",
	}, panel)

	local button = Instance.new("TextButton")
	button.Name = "Sell"
	button.Position = UDim2.new(0, rightX, 1, -48)
	button.Size = UDim2.fromOffset(columnWidth, 44)
	button.BackgroundColor3 = BUTTON
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = "Продать всё"
	button.AutoButtonColor = true
	button.Parent = panel
	round(button, 8)

	gui.Parent = parent
	return { panel = panel, netRows = netRows, total = total, button = button }
end

local function readNet(player: Player): { NetItem }
	local raw = player:GetAttribute(Attributes.Net)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, items = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(items) == "table" then items else {}
end

local function refreshNet(ui: Ui, net: { NetItem })
	for _, child in ui.netRows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if #net == 0 then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundTransparency = 1
		row.Parent = ui.netRows
		makeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = "Садок пуст — ныряй за рыбой",
			TextColor3 = MUTED,
			TextXAlignment = Enum.TextXAlignment.Center,
		}, row)
	end

	for index, item in net do
		local fish = fishById[item.id]
		local row = makeRow(ui.netRows, index)
		makeLabel({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.65, -8, 1, 0),
			Text = string.format(
				"%s · %.2f кг",
				if fish then fish.name else item.id,
				item.weight
			),
			TextColor3 = if fish
				then RarityColors[fish.rarity] or Color3.new(1, 1, 1)
				else Color3.new(1, 1, 1),
		}, row)
		makeLabel({
			Position = UDim2.fromScale(0.65, 0),
			Size = UDim2.new(0.35, -8, 1, 0),
			Text = tostring(prices[item.id] or 0),
			TextXAlignment = Enum.TextXAlignment.Right,
		}, row)
	end

	local total = Market.totalValue(net, prices)
	ui.total.Text = `Итого: {total} монет`
	ui.button.Active = #net > 0
	ui.button.BackgroundColor3 = if #net > 0 then BUTTON else BUTTON_DISABLED
end

local function isInside(zone: BasePart, position: Vector3): boolean
	local p = zone.CFrame:PointToObjectSpace(position)
	local half = zone.Size / 2
	return Bounds.contains(p.X, p.Y, p.Z, half.X, half.Y, half.Z, 0)
end

function MarketUi.start()
	local player = Players.LocalPlayer
	local ui = build(player:WaitForChild("PlayerGui"))

	local map = Workspace:WaitForChild("Map")
	local zone = map:WaitForChild("Market"):WaitForChild("SellZone")
	local remotes = ReplicatedStorage:WaitForChild(Remotes.Folder)
	local sell = remotes:WaitForChild(Remotes.SellCatch)

	refreshNet(ui, readNet(player))
	player:GetAttributeChangedSignal(Attributes.Net):Connect(function()
		refreshNet(ui, readNet(player))
	end)

	ui.button.MouseButton1Click:Connect(function()
		if ui.button.Active and sell:IsA("RemoteEvent") then
			sell:FireServer()
		end
	end)

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		local inside = root ~= nil
			and root:IsA("BasePart")
			and zone:IsA("BasePart")
			and isInside(zone, root.Position)
		if ui.panel.Visible ~= inside then
			ui.panel.Visible = inside
		end
	end)
end

return MarketUi
