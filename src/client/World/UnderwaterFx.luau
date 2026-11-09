--!strict
-- Local underwater look: once the camera dips below the surface, a color
-- grade tints the view sea-blue and darkens it with depth, a light blur
-- softens distance, and "marine snow" drifts around the camera. All of it is
-- created on the client, so it never replicates.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Depth = require(Shared:WaitForChild("Logic"):WaitForChild("Depth"))

local UnderwaterFx = {}

local SURFACE_TINT = Color3.fromRGB(205, 240, 255)
local DEEP_TINT = Color3.fromRGB(105, 160, 215)
local DEEP_BRIGHTNESS = -0.18
local DEEP_SATURATION = -0.15
local BLUR_SIZE = 2
local SNOW_BOX = Vector3.new(90, 50, 90) -- studs around the camera

local function makeSnow(): (BasePart, ParticleEmitter)
	local box = Instance.new("Part")
	box.Name = "MarineSnow"
	box.Anchored = true
	box.CanCollide = false
	box.CanQuery = false
	box.CanTouch = false
	box.CastShadow = false
	box.Transparency = 1
	box.Size = SNOW_BOX
	box.Parent = Workspace

	local snow = Instance.new("ParticleEmitter")
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Rate = 60
	snow.Lifetime = NumberRange.new(6, 10)
	snow.Speed = NumberRange.new(0.1, 0.4)
	snow.SpreadAngle = Vector2.new(180, 180)
	snow.Acceleration = Vector3.new(0, -0.05, 0) -- sinks slowly
	snow.Size = NumberSequence.new(0.1)
	snow.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.4),
		NumberSequenceKeypoint.new(0.8, 0.4),
		NumberSequenceKeypoint.new(1, 1),
	})
	snow.Color = ColorSequence.new(Color3.fromRGB(230, 240, 235))
	snow.LightEmission = 0.4
	snow.Enabled = false
	snow.Parent = box
	return box, snow
end

function UnderwaterFx.start()
	local world = Config.World

	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "UnderwaterGrade"
	grade.Enabled = false
	grade.Parent = Lighting

	local blur = Instance.new("BlurEffect")
	blur.Name = "UnderwaterBlur"
	blur.Size = BLUR_SIZE
	blur.Enabled = false
	blur.Parent = Lighting

	local snowBox, snow = makeSnow()
	local underwater = false

	RunService.RenderStepped:Connect(function()
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local position = camera.CFrame.Position
		local below = position.Y < world.surfaceY

		if below ~= underwater then
			underwater = below
			grade.Enabled = below
			blur.Enabled = below
			snow.Enabled = below
		end
		if not below then
			return
		end

		local depth = Depth.toMeters(position.Y, world.surfaceY, world.studsPerMeter)
		local t = math.clamp(depth / world.oceanFloorMeters, 0, 1)
		grade.TintColor = SURFACE_TINT:Lerp(DEEP_TINT, t)
		grade.Brightness = DEEP_BRIGHTNESS * t
		grade.Saturation = DEEP_SATURATION * t
		snowBox.CFrame = CFrame.new(position)
	end)
end

return UnderwaterFx
