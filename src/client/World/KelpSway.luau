--!strict
-- Sways the kelp the server built. Purely visual and local: anchored parts
-- moved on the client are not replicated, so this costs no network. Stalks
-- are found by tag (KelpRig.TAG) and posed with the same KelpRig math the
-- server used for the initial pose; far stalks are skipped and the update
-- runs at a fixed rate, with one BulkMoveTo per tick.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local KelpRig = require(Shared:WaitForChild("KelpRig"))
local Sway = require(Shared:WaitForChild("Logic"):WaitForChild("Sway"))

local KelpSway = {}

local UPDATE_INTERVAL = 1 / 20 -- seconds
local MAX_DISTANCE = 260 -- studs from the camera

type Stalk = {
	base: CFrame,
	spec: KelpRig.Spec,
	phase: number,
	parts: { BasePart }, -- segments first, then leaves
}

local models: { [Model]: true } = {}
local stalks: { [Model]: Stalk } = {}

-- Reads a stalk's attributes and parts; nil while anything is missing.
local function read(model: Model): Stalk?
	local base = model:GetAttribute("BaseCFrame")
	local segments = model:GetAttribute("Segments")
	local segLength = model:GetAttribute("SegLength")
	local leafLength = model:GetAttribute("LeafLength")
	local phase = model:GetAttribute("Phase")
	if
		typeof(base) ~= "CFrame"
		or type(segments) ~= "number"
		or type(segLength) ~= "number"
		or type(leafLength) ~= "number"
		or type(phase) ~= "number"
	then
		return nil
	end

	local parts: { BasePart } = {}
	for _, prefix in { "S", "L" } do
		for i = 1, segments do
			local part = model:FindFirstChild(`{prefix}{i}`)
			if not part or not part:IsA("BasePart") then
				return nil
			end
			table.insert(parts, part)
		end
	end

	return {
		base = base,
		spec = { segments = segments, segLength = segLength, leafLength = leafLength },
		phase = phase,
		parts = parts,
	}
end

local function track(instance: Instance)
	if instance:IsA("Model") then
		models[instance] = true
	end
end

local function untrack(instance: Instance)
	if instance:IsA("Model") then
		models[instance] = nil
		stalks[instance] = nil
	end
end

function KelpSway.start()
	for _, instance in CollectionService:GetTagged(KelpRig.TAG) do
		track(instance)
	end
	CollectionService:GetInstanceAddedSignal(KelpRig.TAG):Connect(track)
	CollectionService:GetInstanceRemovedSignal(KelpRig.TAG):Connect(untrack)

	local sway = KelpRig.SWAY
	local parts: { BasePart } = {}
	local cframes: { CFrame } = {}
	local elapsed = 0

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < UPDATE_INTERVAL then
			return
		end
		elapsed = 0

		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPosition = camera.CFrame.Position
		local now = os.clock()
		table.clear(parts)
		table.clear(cframes)

		for model in models do
			local stalk = stalks[model]
			if not stalk then
				-- Streaming may deliver attributes or parts a little later.
				stalk = read(model)
				if not stalk then
					continue
				end
				stalks[model] = stalk
			end
			if (stalk.base.Position - cameraPosition).Magnitude > MAX_DISTANCE then
				continue
			end

			local spec = stalk.spec
			local angles = Sway.angles(
				now,
				stalk.phase,
				spec.segments,
				sway.amplitude,
				sway.frequency,
				sway.lag,
				sway.lean
			)
			local segments, leaves = KelpRig.pose(stalk.base, spec, angles)
			for i, cframe in segments do
				table.insert(parts, stalk.parts[i])
				table.insert(cframes, cframe)
			end
			for i, cframe in leaves do
				table.insert(parts, stalk.parts[spec.segments + i])
				table.insert(cframes, cframe)
			end
		end

		if #parts > 0 then
			Workspace:BulkMoveTo(parts, cframes, Enum.BulkMoveMode.FireCFrameChanged)
		end
	end)
end

return KelpSway
