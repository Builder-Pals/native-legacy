--!strict
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local defiltering = require("../sandbox/defiltering")
local Action = require("./Action")

--[[
	a replacement for the deprecated Model:MakeJoints() and
	BasePart:MakeJoints() surface-joint behaviour.

	the subject must be inside a WorldRoot. a BasePart subject processes that
	part; any other Instance processes all of its descendant BaseParts. Parts
	touching the subject from outside of it are eligible for joining.
]]

local CONTACT_TOLERANCE = 0.001
local NORMAL_DOT_TOLERANCE = 0.9999
local MIN_FACE_OVERLAP = 0.00001

type JointClass = "Glue" | "Rotate" | "RotateV" | "Snap" | "Weld"

type FaceDefinition = {
	normal_id: Enum.NormalId,
	normal: Vector3,
	u: Vector3,
	v: Vector3,
	get_surface: (BasePart) -> Enum.SurfaceType,
}

type Face = {
	definition: FaceDefinition,
	center: Vector3,
	normal: Vector3,
	u: Vector3,
	v: Vector3,
	halfU: number,
	halfV: number,
	surface: Enum.SurfaceType,
}

local FACE_DEFINITIONS: { FaceDefinition } = {
	{
		normal_id = Enum.NormalId.Right,
		normal = Vector3.xAxis,
		u = Vector3.yAxis,
		v = Vector3.zAxis,
		get_surface = function(part)
			return part.RightSurface
		end,
	},
	{
		normal_id = Enum.NormalId.Left,
		normal = -Vector3.xAxis,
		u = Vector3.yAxis,
		v = -Vector3.zAxis,
		get_surface = function(part)
			return part.LeftSurface
		end,
	},
	{
		normal_id = Enum.NormalId.Top,
		normal = Vector3.yAxis,
		u = Vector3.zAxis,
		v = Vector3.xAxis,
		get_surface = function(part)
			return part.TopSurface
		end,
	},
	{
		normal_id = Enum.NormalId.Bottom,
		normal = -Vector3.yAxis,
		u = Vector3.zAxis,
		v = -Vector3.xAxis,
		get_surface = function(part)
			return part.BottomSurface
		end,
	},
	{
		normal_id = Enum.NormalId.Back,
		normal = Vector3.zAxis,
		u = Vector3.yAxis,
		v = -Vector3.xAxis,
		get_surface = function(part)
			return part.BackSurface
		end,
	},
	{
		normal_id = Enum.NormalId.Front,
		normal = -Vector3.zAxis,
		u = Vector3.yAxis,
		v = Vector3.xAxis,
		get_surface = function(part)
			return part.FrontSurface
		end,
	},
}

const IS_CLIENT = RunService:IsClient()

const new_instance = if IS_CLIENT
	then function(class_name)
		return app.context.client_pool(class_name)
	end
	else Instance.new

local make_joints = {}

local function component_for_direction(vector: Vector3, direction: Vector3): number
	return math.abs(vector:Dot(direction))
end

local function half_extent(size: Vector3, direction: Vector3): number
	return 0.5
		* (
			size.X * component_for_direction(Vector3.xAxis, direction)
			+ size.Y * component_for_direction(Vector3.yAxis, direction)
			+ size.Z * component_for_direction(Vector3.zAxis, direction)
		)
end

local function has_planar_face(part: BasePart, normalId: Enum.NormalId): boolean
	if not part:IsA("Part") then
		return true
	end

	if part.Shape == Enum.PartType.Ball then
		return true
	elseif part.Shape == Enum.PartType.Cylinder then
		-- A Part cylinder's length is its local X axis. Only its end caps are
		-- planar; its four other named sides describe the curved surface.
		return normalId == Enum.NormalId.Left or normalId == Enum.NormalId.Right
	end

	return true
end

local function get_faces(part: BasePart): { Face }
	local faces: { Face } = {}
	local cframe = part.CFrame

	for _, definition in FACE_DEFINITIONS do
		if part:IsA("WedgePart") then
			if definition.normal_id == Enum.NormalId.Front then
				-- This is the edge where the sloped top meets the bottom, so
				-- there is no planar Front face.
				continue
			elseif definition.normal_id == Enum.NormalId.Top then
				local local_normal = Vector3.new(0, part.Size.Z, -part.Size.Y).Unit
				local local_u = Vector3.xAxis
				local local_v = local_normal:Cross(local_u)

				table.insert(faces, {
					definition = definition,
					center = part.Position,
					normal = cframe:VectorToWorldSpace(local_normal),
					u = cframe:VectorToWorldSpace(local_u),
					v = cframe:VectorToWorldSpace(local_v),
					halfU = part.Size.X * 0.5,
					halfV = Vector2.new(part.Size.Y, part.Size.Z).Magnitude * 0.5,
					surface = definition.get_surface(part),
				})
				continue
			end
		end

		if not has_planar_face(part, definition.normal_id) then
			continue
		end

		local local_normal = definition.normal
		local normal = cframe:VectorToWorldSpace(local_normal)
		local normal_half_extent = half_extent(part.Size, local_normal)

		table.insert(faces, {
			definition = definition,
			center = part.Position + normal * normal_half_extent,
			normal = normal,
			u = cframe:VectorToWorldSpace(definition.u),
			v = cframe:VectorToWorldSpace(definition.v),
			halfU = half_extent(part.Size, definition.u),
			halfV = half_extent(part.Size, definition.v),
			surface = definition.get_surface(part),
		})
	end

	return faces
end

local function projected_radius(face: Face, axis: Vector3): number
	return face.halfU * math.abs(face.u:Dot(axis)) + face.halfV * math.abs(face.v:Dot(axis))
end

local function face_rectangles_overlap(face0: Face, face1: Face): boolean
	local delta = face1.center - face0.center
	local axes = { face0.u, face0.v, face1.u, face1.v }

	for _, axis in axes do
		local centerDistance = math.abs(delta:Dot(axis))
		local overlap = projected_radius(face0, axis) + projected_radius(face1, axis) - centerDistance
		if overlap <= MIN_FACE_OVERLAP then
			return false
		end
	end

	return true
end

local function get_touching_faces(part0: BasePart, part1: BasePart): (Face?, Face?)
	local best_face0: Face? = nil
	local best_face1: Face? = nil
	local best_plane_distance = math.huge

	for _, face0 in get_faces(part0) do
		for _, face1 in get_faces(part1) do
			if face0.normal:Dot(face1.normal) > -NORMAL_DOT_TOLERANCE then
				continue
			end

			local plane_distance = math.abs((face1.center - face0.center):Dot(face0.normal))
			if plane_distance > CONTACT_TOLERANCE or plane_distance >= best_plane_distance then
				continue
			end

			if not face_rectangles_overlap(face0, face1) then
				continue
			end

			best_face0 = face0
			best_face1 = face1
			best_plane_distance = plane_distance
		end
	end

	return best_face0, best_face1
end

local function is_motor(surface: Enum.SurfaceType): boolean
	return surface == Enum.SurfaceType.Motor or surface == Enum.SurfaceType.SteppingMotor
end

local function is_snap_surface(surface: Enum.SurfaceType): boolean
	return surface == Enum.SurfaceType.Studs
		or surface == Enum.SurfaceType.Inlet
		or surface == Enum.SurfaceType.Universal
end

-- The boolean result says that the second face owns the directional joint.
-- RotateV reads its input from Part0, so Motor/SteppingMotor must be Part0.
local function choose_joint(surface0: Enum.SurfaceType, surface1: Enum.SurfaceType): (JointClass?, boolean)
	if is_motor(surface0) then
		return "RotateV", false
	elseif is_motor(surface1) then
		return "RotateV", true
	elseif surface0 == Enum.SurfaceType.Hinge then
		return "Rotate", false
	elseif surface1 == Enum.SurfaceType.Hinge then
		return "Rotate", true
	elseif surface0 == Enum.SurfaceType.Weld or surface1 == Enum.SurfaceType.Weld then
		return "Weld", false
	elseif surface0 == Enum.SurfaceType.Glue or surface1 == Enum.SurfaceType.Glue then
		return "Glue", false
	elseif is_snap_surface(surface0) and is_snap_surface(surface1) and surface0 ~= surface1 then
		return "Snap", false
	end

	return nil, false
end

local function find_world_root(instance: Instance): WorldRoot?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("WorldRoot") then
			return current :: WorldRoot
		end
		current = current.Parent
	end

	return nil
end

local function collect_parts(subject: Instance): { BasePart }
	if subject:IsA("BasePart") then
		return { subject }
	end

	local parts: { BasePart } = {}
	for _, descendant in subject:GetDescendants() do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end

	return parts
end

local function remember_pair(pairs: { [BasePart]: { [BasePart]: boolean } }, part0: BasePart, part1: BasePart)
	local part0_pairs = pairs[part0]
	if part0_pairs == nil then
		part0_pairs = {}
		pairs[part0] = part0_pairs
	end
	part0_pairs[part1] = true

	local part1_pairs = pairs[part1]
	if part1_pairs == nil then
		part1_pairs = {}
		pairs[part1] = part1_pairs
	end
	part1_pairs[part0] = true
end

local function already_paired(pairs: { [BasePart]: { [BasePart]: boolean } }, part0: BasePart, part1: BasePart): boolean
	local part0_pairs = pairs[part0]
	return part0_pairs ~= nil and part0_pairs[part1] == true
end

local function index_existing_joints(parts: { BasePart }): { [BasePart]: { [BasePart]: boolean } }
	local pairs: { [BasePart]: { [BasePart]: boolean } } = {}

	for _, part in parts do
		for _, joint in part:GetJoints() do
			if not joint:IsA("JointInstance") then
				continue
			end

			local part0 = joint.Part0
			local part1 = joint.Part1
			if part0 ~= nil and part1 ~= nil then
				remember_pair(pairs, part0, part1)
			end
		end
	end

	return pairs
end

local function index_parts(parts: { BasePart }): { [BasePart]: boolean }
	local indexed: { [BasePart]: boolean } = {}
	for _, part in parts do
		indexed[part] = true
	end

	return indexed
end

local function make_joint(
	joint_class: JointClass,
	part0: BasePart,
	part1: BasePart,
	face0: Face,
	face1: Face,
	directional_face_is_second: boolean
)
	if directional_face_is_second then
		part0, part1 = part1, part0
		face0, face1 = face1, face0
	end

	local joint = new_instance(joint_class) :: JointInstance
	local joint_position = if joint_class == "Rotate" or joint_class == "RotateV"
		then face0.center
		else (face0.center + face1.center) * 0.5
	local joint_frame = CFrame.fromMatrix(joint_position, face0.normal, face0.u, face0.normal:Cross(face0.u))

	joint.C0 = part0.CFrame:ToObjectSpace(joint_frame)
	joint.C1 = part1.CFrame:ToObjectSpace(joint_frame)
	joint.Part0 = part0
	joint.Part1 = part1
	joint.Parent = part0
end

local function make_surface_joints(
	worldRoot: WorldRoot,
	parts: { BasePart },
	partsToExclude: { [BasePart]: boolean }?
): ()
	local paired = index_existing_joints(parts)
	local overlap_params = OverlapParams.new()
	overlap_params.MaxParts = 0
	overlap_params.RespectCanCollide = false
	overlap_params.Tolerance = CONTACT_TOLERANCE

	for _, part0 in parts do
		if part0:IsA("Terrain") then
			continue
		end

		for _, part1 in worldRoot:GetPartsInPart(part0, overlap_params) do
			if part1:IsA("Terrain") or (partsToExclude ~= nil and partsToExclude[part1]) then
				continue
			end

			if already_paired(paired, part0, part1) then
				continue
			end

			-- Mark the pair before inspecting it so it is processed only once,
			-- even when its surfaces are not joinable.
			remember_pair(paired, part0, part1)

			local face0, face1 = get_touching_faces(part0, part1)
			if face0 == nil or face1 == nil then
				continue
			end

			local joint_class, directional_face_is_second = choose_joint(face0.surface, face1.surface)
			if joint_class ~= nil then
				make_joint(joint_class, part0, part1, face0, face1, directional_face_is_second)
			end
		end
	end
end

--[[
	Creates legacy surface joints for a BasePart, or for every BasePart below a
	container. Like Model:MakeJoints(), parts outside the subject may be joined
	when they touch one of its parts.
]]
function make_joints.make_joints(subject: Instance): ()
	local world_root = if subject:IsA("WorldRoot") then subject else find_world_root(subject)
	if world_root == nil then
		return
	end

	local parts = collect_parts(subject)
	make_surface_joints(world_root, parts, nil)
end

--[[
	Replicates Model:BreakJoints() and BasePart:BreakJoints() by destroying every
	joint or constraint connected to a part in the subject.
]]
function make_joints.break_joints(subject: Instance): ()
	local joints: { [Instance]: boolean } = {}

	for _, part in collect_parts(subject) do
		for _, joint in part:GetJoints() do
			joints[joint] = true
		end
	end

	for joint in joints do
		defiltering.net_destroy(joint)
	end
end

--[[
	Replicates the legacy Surface mode of Workspace:JoinToOutsiders(). Only
	creates surface joints between the supplied parts and parts outside the
	selection. Unlike the current Roblox API, Hinge, Motor, and SteppingMotor
	surfaces create Rotate and RotateV joints instead of Welds.
]]
function make_joints.join_to_outsiders(parts: { BasePart }): ()
	local selected_parts = index_parts(parts)
	local parts_by_world_root: { [WorldRoot]: { BasePart } } = {}

	for part in selected_parts do
		local worldRoot = find_world_root(part)

		if worldRoot == nil then
			continue
		end

		local world_root_parts = parts_by_world_root[worldRoot]

		if world_root_parts == nil then
			world_root_parts = {}
			parts_by_world_root[worldRoot] = world_root_parts
		end

		table.insert(world_root_parts, part)
	end

	for worldRoot, world_root_parts in parts_by_world_root do
		make_surface_joints(worldRoot, world_root_parts, selected_parts)
	end
end

return make_joints
