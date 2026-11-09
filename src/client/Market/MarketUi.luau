--!strict
-- Market panel: opens while the player stands in the stall's SellZone, lists the
-- net with prototype prices and sends the sell intent. The server re-checks the
-- zone and does the actual payout; this file only draws and asks.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Attributes = require(Shared:WaitForChild("Attributes"))
local Remotes = require(Shared:WaitForChild("Remotes"))
local Logic = Shared:WaitForChild("Logic")
local Bounds = require(Logic:WaitForChild("Bounds"))
local Market = require(Logic:WaitForChild("Market"))

local PANEL = Color3.fromRGB(10, 30, 60)
local ROW = Color3.fromRGB(20, 50, 90)
local BUTTON = Color3.fromRGB(60, 180, 90)
local BUTTON_DISABLED = Color3.fromRGB(80, 90, 100)
local ROW_HEIGHT = 30

local MarketUi = {}

type NetItem = { id: string, weight: number }

type Ui = {
	panel: Frame,
	rows: Frame,
	total: TextLabel,
	button: TextButton,
}

local fishById: { [string]: Config.Fish } = {}
for _, fish in Config.Fish do
	fishById[fish.id] = fish
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

local function build(parent: Instance): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "MarketUi"
	gui.ResetOnSpawn = false

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.Position = UDim2.new(1, -16, 0.5, 0)
	panel.Size = UDim2.fromOffset(320, 260)
	panel.BackgroundColor3 = PANEL
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	round(panel, 10)

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 12)
	padding.PaddingRight = UDim.new(0, 12)
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = panel

	makeLabel({
		Name = "Title",
		Size = UDim2.new(1, 0, 0, 30),
		Text = "Рынок",
		TextXAlignment = Enum.TextXAlignment.Center,
	}, panel)

	local rows = Instance.new("Frame")
	rows.Name = "Rows"
	rows.Position = UDim2.fromOffset(0, 40)
	rows.Size = UDim2.new(1, 0, 0, ROW_HEIGHT * Config.Inventory.netCapacity + 8)
	rows.BackgroundTransparency = 1
	rows.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = rows

	local total = makeLabel({
		Name = "Total",
		Position = UDim2.new(0, 0, 1, -90),
		Size = UDim2.new(1, 0, 0, 28),
		Text = "",
	}, panel)

	local button = Instance.new("TextButton")
	button.Name = "Sell"
	button.Position = UDim2.new(0, 0, 1, -50)
	button.Size = UDim2.new(1, 0, 0, 44)
	button.BackgroundColor3 = BUTTON
	button.TextColor3 = Color3.new(1, 1, 1)
	button.TextScaled = true
	button.Font = Enum.Font.GothamBold
	button.Text = "Продать всё"
	button.AutoButtonColor = true
	button.Parent = panel
	round(button, 8)

	gui.Parent = parent
	return { panel = panel, rows = rows, total = total, button = button }
end

local function readNet(player: Player): { NetItem }
	local raw = player:GetAttribute(Attributes.Net)
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, items = pcall(HttpService.JSONDecode, HttpService, raw)
	return if ok and type(items) == "table" then items else {}
end

local function refresh(ui: Ui, net: { NetItem })
	for _, child in ui.rows:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if #net == 0 then
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundTransparency = 1
		row.Parent = ui.rows
		makeLabel({
			Size = UDim2.fromScale(1, 1),
			Text = "Садок пуст — ныряй за рыбой",
			TextColor3 = Color3.fromRGB(180, 200, 220),
			TextXAlignment = Enum.TextXAlignment.Center,
		}, row)
	end

	for index, item in net do
		local fish = fishById[item.id]
		local name = if fish then fish.name else item.id
		local price = prices[item.id] or 0

		local row = Instance.new("Frame")
		row.LayoutOrder = index
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.BackgroundColor3 = ROW
		row.Parent = ui.rows
		round(row, 6)

		makeLabel({
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(0.6, -8, 1, 0),
			Text = string.format("%s · %.2f кг", name, item.weight),
		}, row)
		makeLabel({
			Position = UDim2.fromScale(0.6, 0),
			Size = UDim2.new(0.4, -8, 1, 0),
			Text = `{price} монет`,
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

	refresh(ui, readNet(player))
	player:GetAttributeChangedSignal(Attributes.Net):Connect(function()
		refresh(ui, readNet(player))
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
