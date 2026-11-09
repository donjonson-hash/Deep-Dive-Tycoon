--!strict
-- Spawns greybox fish for every species in its zone and swims them around the
-- island. The server moves the fish so catching can later be validated against
-- real positions; clients only see the replicated models.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Config = require(ReplicatedStorage.Shared.Config)
local FishMotion = require(ReplicatedStorage.Shared.Logic.FishMotion)
local FishBuilder = require(script.Parent.FishBuilder)

local FishService = {}

-- Look-and-feel constants; the numbers that affect gameplay live in Config.FishSpawn.
local TURN_RATE = 2 -- fraction of the remaining turn completed per second
local ARRIVE_DISTANCE = 2 -- studs; pick a new target this close to the current one
local BOB_AMPLITUDE = 0.3 -- studs
local BOB_FREQUENCY = 0.8 -- Hz
local TAIL_WAG_RADIANS = 0.5
local TAIL_WAG_FREQUENCY = 2.5 -- Hz

type FishState = {
	parts: FishBuilder.FishParts,
	position: Vector3,
	heading: CFrame, -- rotation only; position is applied separately
	target: Vector3,
	minY: number,
	maxY: number,
	phase: number, -- so fish do not bob and wag in lockstep
	tailPivotZ: number, -- half body length: where the tail hinges
	tailHalfLength: number,
}

local rng = Random.new()
local fish: { FishState } = {}

local function pickTarget(minY: number, maxY: number): Vector3
	local spawn = Config.FishSpawn
	local x, y, z = FishMotion.randomPoint(
		spawn.minRadius,
		spawn.maxRadius,
		minY,
		maxY,
		rng:NextNumber(),
		rng:NextNumber(),
		rng:NextNumber()
	)
	return Vector3.new(x, y, z)
end

local function zoneById(zoneId: string): Config.Zone?
	for _, zone in Config.Zones do
		if zone.id == zoneId then
			return zone
		end
	end
	return nil
end

local function spawnFish(species: Config.Fish, minY: number, maxY: number, parent: Instance)
	local parts = FishBuilder.build(species)
	local position = pickTarget(minY, maxY)
	local target = pickTarget(minY, maxY)
	local state: FishState = {
		parts = parts,
		position = position,
		heading = CFrame.lookAt(position, target).Rotation,
		target = target,
		minY = minY,
		maxY = maxY,
		phase = rng:NextNumber() * 10,
		tailPivotZ = parts.body.Size.Z / 2,
		tailHalfLength = parts.tail.Size.Z / 2,
	}
	parts.model:PivotTo(state.heading + position)
	parts.model.Parent = parent
	table.insert(fish, state)
end

local function step(dt: number)
	local now = os.clock()
	local speed = Config.FishSpawn.swimSpeed
	local turn = math.min(1, TURN_RATE * dt)

	for _, f in fish do
		local toTarget = f.target - f.position
		if toTarget.Magnitude < ARRIVE_DISTANCE then
			f.target = pickTarget(f.minY, f.maxY)
			toTarget = f.target - f.position
		end

		f.position += toTarget.Unit * math.min(speed * dt, toTarget.Magnitude)
		f.heading = f.heading:Lerp(CFrame.lookAt(f.position, f.target).Rotation, turn)

		local time = now + f.phase
		local bob = FishMotion.bob(time, BOB_AMPLITUDE, BOB_FREQUENCY)
		local bodyCFrame = f.heading + f.position + Vector3.new(0, bob, 0)
		f.parts.model:PivotTo(bodyCFrame)

		-- Swing the tail around its hinge at the back of the body.
		local wag = FishMotion.tailAngle(time, TAIL_WAG_RADIANS, TAIL_WAG_FREQUENCY)
		f.parts.tail.CFrame = bodyCFrame
			* CFrame.new(0, 0, f.tailPivotZ)
			* CFrame.Angles(0, wag, 0)
			* CFrame.new(0, 0, f.tailHalfLength)
	end
end

function FishService.start(): Folder
	local existing = Workspace:FindFirstChild("Fish")
	if existing then
		existing:Destroy()
	end
	table.clear(fish)

	local folder = Instance.new("Folder")
	folder.Name = "Fish"

	local spawn = Config.FishSpawn
	for _, species in Config.Fish do
		local zone = zoneById(species.zoneId)
		if not zone then
			continue
		end
		local minY, maxY = FishMotion.zoneBounds(
			zone,
			Config.World,
			spawn.surfaceMarginMeters,
			spawn.floorMarginMeters
		)
		if minY == nil or maxY == nil then
			continue -- zone is below the prototype ocean floor
		end
		for _ = 1, spawn.perSpecies do
			spawnFish(species, minY, maxY, folder)
		end
	end

	folder.Parent = Workspace
	RunService.Heartbeat:Connect(step)
	return folder
end

return FishService
