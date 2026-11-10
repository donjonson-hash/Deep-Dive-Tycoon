--!strict
-- Puts a pair of yellow fins on every character's feet. Purely visual: the
-- speed boost lives in PlayerState (Config.Gear.finsSwimMultiplier). Fins are
-- welded, massless and non-colliding, so they never change how the character
-- walks, climbs ladders or touches anything.

local Players = game:GetService("Players")

local Fins = {}

local BLADE = Color3.fromRGB(255, 200, 40)
local POCKET = Color3.fromRGB(220, 160, 20)
local APPEARANCE_TIMEOUT = 5 -- seconds to wait for avatar scaling before sizing the fins

local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = false
	part.Massless = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	part.Parent = parent
	return part
end

local function weld(foot: BasePart, part: BasePart)
	local joint = Instance.new("WeldConstraint")
	joint.Part0 = foot
	joint.Part1 = part
	joint.Parent = part
end

-- One fin under `foot` (an R15 foot or an R6 leg; both face -Z). Sized from
-- the foot so scaled avatars get matching fins.
local function attach(foot: BasePart, parent: Instance)
	local size = foot.Size
	local soleY = -size.Y / 2
	local width = size.X * 0.95
	local length = size.Z * 2.2 -- about 0.7 m for a default avatar
	local heelZ = size.Z / 2

	-- Foot pocket around the sole.
	local pocketHeight = math.min(size.Y, 0.6) * 1.1
	weld(
		foot,
		makePart({
			Name = "FinPocket",
			Size = Vector3.new(size.X * 1.08, pocketHeight, size.Z * 1.05),
			CFrame = foot.CFrame * CFrame.new(0, soleY + pocketHeight / 2 - 0.02, 0),
			Color = POCKET,
		}, parent)
	)
	-- Flat blade from the heel forward past the toes.
	weld(
		foot,
		makePart({
			Name = "FinBlade",
			Size = Vector3.new(width, 0.08, length),
			CFrame = foot.CFrame * CFrame.new(0, soleY + 0.04, heelZ - length / 2),
			Color = BLADE,
		}, parent)
	)
	-- Wider rounded tip.
	local tip = makePart({
		Name = "FinTip",
		Size = Vector3.new(width * 1.4, 0.08, length * 0.35),
		CFrame = foot.CFrame * CFrame.new(0, soleY + 0.04, heelZ - length),
		Color = BLADE,
	}, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = tip
	weld(foot, tip)
end

-- Avatar scaling can resize the feet after spawn; size the fins after it.
local function waitForAppearance(player: Player)
	if player:HasAppearanceLoaded() then
		return
	end
	local loaded = false
	local connection = player.CharacterAppearanceLoaded:Connect(function()
		loaded = true
	end)
	local started = os.clock()
	while not loaded and os.clock() - started < APPEARANCE_TIMEOUT do
		task.wait(0.1)
	end
	connection:Disconnect()
end

local function equip(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", APPEARANCE_TIMEOUT)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	waitForAppearance(player)
	if player.Character ~= character or not character.Parent then
		return -- respawned or left while we waited
	end

	local names = if humanoid.RigType == Enum.HumanoidRigType.R15
		then { "LeftFoot", "RightFoot" }
		else { "Left Leg", "Right Leg" }

	local fins = Instance.new("Model")
	fins.Name = "Fins"
	for _, name in names do
		local foot = character:WaitForChild(name, APPEARANCE_TIMEOUT)
		if foot and foot:IsA("BasePart") then
			attach(foot, fins)
		end
	end
	fins.Parent = character
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(equip, player, character)
	end)
	if player.Character then
		task.spawn(equip, player, player.Character)
	end
end

function Fins.start()
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
end

return Fins
