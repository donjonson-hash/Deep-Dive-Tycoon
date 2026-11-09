--!strict
-- Nests on the seabed sell eggs for coins. Each nest shows the egg, its price
-- and the hatch odds (the platform rule: odds before purchase). Buying is a
-- ProximityPrompt: the server checks the coins, moves the egg into the
-- player's inventory and restocks the nest later. Guards and hatching come
-- with the next roadmap items.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local Eggs = require(ReplicatedStorage.Shared.Logic.Eggs)
local PlayerState = require(script.Parent.Parent.Player.PlayerState)

local EggService = {}

local NEST_SEED = 5
local EDGE_MARGIN = 16 -- studs kept clear of the ring edges
local SINK = 0.5
local HOLD_SECONDS = 0.5
local REACH_STUDS = 10

local ROCK = Color3.fromRGB(120, 115, 105)
local SAND = Color3.fromRGB(225, 205, 160)
local SHELL = Color3.fromRGB(245, 235, 210)
local SPOT = Color3.fromRGB(120, 170, 200)
local GLOW = Color3.fromRGB(150, 220, 255)

type Nest = {
	egg: Config.Egg,
	model: Model,
	position: Vector3,
	eggModel: Model?,
	label: TextLabel,
}

local fishNames: { [string]: string } = {}
for _, fish in Config.Fish do
	fishNames[fish.id] = fish.name
end

local function makePart(props: { [string]: any }, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
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

local function blob(
	name: string,
	size: Vector3,
	cframe: CFrame,
	color: Color3,
	parent: Instance
): BasePart
	local part = makePart({ Name = name, Size = size, CFrame = cframe, Color = color }, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function zoneOf(egg: Config.Egg): Config.Zone?
	for _, zone in Config.Zones do
		if zone.id == egg.zoneId then
			return zone
		end
	end
	return nil
end

local function oddsText(egg: Config.Egg): string
	return Eggs.describeChances(egg.hatch, function(id)
		return fishNames[id] or id
	end)
end

-- Rocks in a ring around a sand mound; the egg sits on the mound.
local function buildNest(egg: Config.Egg, position: Vector3, parent: Instance): Nest
	local model = Instance.new("Model")
	model.Name = `Nest_{egg.id}`
	model:SetAttribute("EggId", egg.id)

	local mound = blob(
		"Mound",
		Vector3.new(6, 1.6, 6),
		CFrame.new(position + Vector3.new(0, 0.4 - SINK, 0)),
		SAND,
		model
	)
	mound.Material = Enum.Material.Sand
	for i = 1, 7 do
		local angle = (i / 7) * 2 * math.pi
		local size = 1.2 + 0.4 * ((i % 3) / 2)
		local rock = blob(
			"Rock",
			Vector3.new(size, size * 0.8, size * 1.1),
			CFrame.new(
				position
					+ Vector3.new(math.cos(angle) * 3.2, size * 0.3 - SINK, math.sin(angle) * 3.2)
			),
			ROCK,
			model
		)
		rock.Material = Enum.Material.Slate
	end

	-- Sign above the nest: name, price and odds. Text changes when empty.
	local gui = Instance.new("BillboardGui")
	gui.Name = "NestLabel"
	gui.Size = UDim2.fromOffset(240, 70)
	gui.StudsOffset = Vector3.new(0, 6, 0)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Parent = gui
	gui.Parent = mound

	model.Parent = parent
	return { egg = egg, model = model, position = position, eggModel = nil, label = label }
end

local purchase: (player: Player, nest: Nest) -> ()

-- The egg itself: a glowing speckled shell with the buy prompt.
local function stockNest(nest: Nest)
	local eggModel = Instance.new("Model")
	eggModel.Name = "Egg"
	local center = nest.position + Vector3.new(0, 1.6, 0)
	local shell = blob("Shell", Vector3.new(2, 2.6, 2), CFrame.new(center), SHELL, eggModel)
	for i = 1, 5 do
		local angle = i * 1.3
		local y = -0.6 + (i % 3) * 0.5
		blob(
			"Spot",
			Vector3.one * 0.45,
			CFrame.new(center + Vector3.new(math.cos(angle) * 0.95, y, math.sin(angle) * 0.95)),
			SPOT,
			eggModel
		)
	end
	local light = Instance.new("PointLight")
	light.Color = GLOW
	light.Brightness = 1.5
	light.Range = 10
	light.Parent = shell

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "BuyPrompt"
	prompt.ObjectText = nest.egg.name
	prompt.ActionText = `Купить · {nest.egg.price} монет`
	prompt.HoldDuration = HOLD_SECONDS
	prompt.MaxActivationDistance = REACH_STUDS
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		purchase(player, nest)
	end)
	prompt.Parent = shell

	eggModel.Parent = nest.model
	nest.eggModel = eggModel
	nest.label.Text = `{nest.egg.name} · {nest.egg.price} монет\n{oddsText(nest.egg)}`
end

purchase = function(player: Player, nest: Nest)
	local eggModel = nest.eggModel
	if not eggModel then
		return -- already sold, waiting for restock
	end
	if not Eggs.canBuy(PlayerState.getCoins(player), nest.egg.price) then
		return
	end
	if not PlayerState.spendCoins(player, nest.egg.price) then
		return
	end
	PlayerState.addEgg(player, nest.egg.id)

	nest.eggModel = nil
	eggModel:Destroy()
	nest.label.Text =
		`Гнездо пустое\nновое яйцо через {nest.egg.restockSeconds} с`
	task.delay(nest.egg.restockSeconds, function()
		if nest.model.Parent then
			stockNest(nest)
		end
	end)
end

function EggService.start(): Folder
	local existing = Workspace:FindFirstChild("Nests")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "Nests"

	local world = Config.World
	local rng = Random.new(NEST_SEED)
	for _, egg in Config.Eggs do
		local zone = zoneOf(egg)
		local ring = if zone then zone.spawn else nil
		if not ring then
			warn(`[EggService] {egg.id}: zone {egg.zoneId} has no spawn ring; no nests`)
			continue
		end
		local seabedY = world.surfaceY - ring.floorMeters * world.studsPerMeter
		for i = 1, egg.nestCount do
			-- Spread nests evenly around the ring, with a little jitter.
			local angle = (i / egg.nestCount) * 2 * math.pi + rng:NextNumber(-0.3, 0.3)
			local radius =
				rng:NextNumber(ring.minRadius + EDGE_MARGIN, ring.maxRadius - EDGE_MARGIN)
			local position =
				Vector3.new(math.cos(angle) * radius, seabedY, math.sin(angle) * radius)
			local nest = buildNest(egg, position, folder)
			stockNest(nest)
		end
	end

	folder.Parent = Workspace
	return folder
end

return EggService
