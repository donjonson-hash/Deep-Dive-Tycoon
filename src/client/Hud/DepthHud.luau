--!strict
-- Shows the current depth and zone at the top of the screen. Display only:
-- the server computes depth on its own for anything that matters (oxygen, fish).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Depth = require(Shared:WaitForChild("Logic"):WaitForChild("Depth"))

local DepthHud = {}

local function createLabel(parent: Instance): TextLabel
	local gui = Instance.new("ScreenGui")
	gui.Name = "DepthHud"
	gui.ResetOnSpawn = false

	local label = Instance.new("TextLabel")
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(340, 36)
	label.BackgroundColor3 = Color3.fromRGB(10, 30, 60)
	label.BackgroundTransparency = 0.3
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	gui.Parent = parent
	return label
end

function DepthHud.start()
	local player = Players.LocalPlayer
	local label = createLabel(player:WaitForChild("PlayerGui"))

	local function setText(text: string)
		if label.Text ~= text then
			label.Text = text
		end
	end

	RunService.RenderStepped:Connect(function()
		local character = player.Character
		local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
		if not root or not root:IsA("BasePart") then
			setText("")
			return
		end

		local depth =
			Depth.toMeters(root.Position.Y, Config.World.surfaceY, Config.World.studsPerMeter)
		if depth < Config.World.surfaceToleranceMeters then
			setText("На поверхности")
			return
		end

		local zone = Depth.zoneAt(Config.Zones, depth)
		local zoneName = if zone then zone.name else "?"
		setText(string.format("Глубина: %d м · %s", math.floor(depth), zoneName))
	end)
end

return DepthHud
