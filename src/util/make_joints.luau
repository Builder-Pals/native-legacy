--!strict

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
	normalId: Enum.NormalId,
	normal: Vector3,
	u: Vector3,
	v: Vector3,
	getSurface: (BasePart) -> Enum.SurfaceType,
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
		normalId = Enum.NormalId.Right,
		normal = Vector3.xAxis,
		u = Vector3.yAxis,
		v = Vector3.zAxis,
		getSurface = function(part)
			return part.RightSurface
		end,
	},
	{
		normalId = Enum.NormalId.Left,
		normal = -Vector3.xAxis,
		u = Vector3.yAxis,
		v = -Vector3.zAxis,
		getSurface = function(part)
			return part.LeftSurface
		end,
	},
	{
		normalId = Enum.NormalId.Top,
		normal = Vector3.yAxis,
		u = Vector3.zAxis,
		v = Vector3.xAxis,
		getSurface = function(part)
			return part.TopSurface
		end,
	},
	{
		normalId = Enum.NormalId.Bottom,
		normal = -Vector3.yAxis,
		u = Vector3.zAxis,
		v = -Vector3.xAxis,
		getSurface = function(part)
			return part.BottomSurface
		end,
	},
	{
		normalId = Enum.NormalId.Back,
		normal = Vector3.zAxis,
		u = Vector3.yAxis,
		v = -Vector3.xAxis,
		getSurface = function(part)
			return part.BackSurface
		end,
	},
	{
		normalId = Enum.NormalId.Front,
		normal = -Vector3.zAxis,
		u = Vector3.yAxis,
		v = Vector3.xAxis,
		getSurface = function(part)
			return part.FrontSurface
		end,
	},
}

local make_joints = {}

local function componentForDirection(vector: Vector3, direction: Vector3): number
	return math.abs(vector:Dot(direction))
end

local function halfExtent(size: Vector3, direction: Vector3): number
	return 0.5
		* (size.X * componentForDirection(Vector3.xAxis, direction)
			+ size.Y * componentForDirection(Vector3.yAxis, direction)
			+ size.Z * componentForDirection(Vector3.zAxis, direction))
end

local function hasPlanarFace(part: BasePart, normalId: Enum.NormalId): boolean
	if not part:IsA("Part") then
		return true
	end

	if part.Shape == Enum.PartType.Ball then
		return false
	elseif part.Shape == Enum.PartType.Cylinder then
		-- A Part cylinder's length is its local X axis. Only its end caps are
		-- planar; its four other named sides describe the curved surface.
		return normalId == Enum.NormalId.Left or normalId == Enum.NormalId.Right
	end

	return true
end

local function getFaces(part: BasePart): { Face }
	local faces: { Face } = {}
	local cframe = part.CFrame

	for _, definition in FACE_DEFINITIONS do
		if part:IsA("WedgePart") then
			if definition.normalId == Enum.NormalId.Front then
				-- This is the edge where the sloped top meets the bottom, so
				-- there is no planar Front face.
				continue
			elseif definition.normalId == Enum.NormalId.Top then
				local localNormal = Vector3.new(0, part.Size.Z, -part.Size.Y).Unit
				local localU = Vector3.xAxis
				local localV = localNormal:Cross(localU)

				table.insert(faces, {
					definition = definition,
					center = part.Position,
					normal = cframe:VectorToWorldSpace(localNormal),
					u = cframe:VectorToWorldSpace(localU),
					v = cframe:VectorToWorldSpace(localV),
					halfU = part.Size.X * 0.5,
					halfV = Vector2.new(part.Size.Y, part.Size.Z).Magnitude * 0.5,
					surface = definition.getSurface(part),
				})
				continue
			end
		end

		if not hasPlanarFace(part, definition.normalId) then
			continue
		end

		local localNormal = definition.normal
		local normal = cframe:VectorToWorldSpace(localNormal)
		local normalHalfExtent = halfExtent(part.Size, localNormal)

		table.insert(faces, {
			definition = definition,
			center = part.Position + normal * normalHalfExtent,
			normal = normal,
			u = cframe:VectorToWorldSpace(definition.u),
			v = cframe:VectorToWorldSpace(definition.v),
			halfU = halfExtent(part.Size, definition.u),
			halfV = halfExtent(part.Size, definition.v),
			surface = definition.getSurface(part),
		})
	end

	return faces
end

local function projectedRadius(face: Face, axis: Vector3): number
	return face.halfU * math.abs(face.u:Dot(axis)) + face.halfV * math.abs(face.v:Dot(axis))
end

local function faceRectanglesOverlap(face0: Face, face1: Face): boolean
	local delta = face1.center - face0.center
	local axes = { face0.u, face0.v, face1.u, face1.v }

	for _, axis in axes do
		local centerDistance = math.abs(delta:Dot(axis))
		local overlap = projectedRadius(face0, axis) + projectedRadius(face1, axis) - centerDistance
		if overlap <= MIN_FACE_OVERLAP then
			return false
		end
	end

	return true
end


local function getTouchingFaces(part0: BasePart, part1: BasePart): (Face?, Face?)
	local bestFace0: Face? = nil
	local bestFace1: Face? = nil
	local bestPlaneDistance = math.huge

	for _, face0 in getFaces(part0) do
		for _, face1 in getFaces(part1) do
			if face0.normal:Dot(face1.normal) > -NORMAL_DOT_TOLERANCE then
				continue
			end

			local planeDistance = math.abs((face1.center - face0.center):Dot(face0.normal))
			if planeDistance > CONTACT_TOLERANCE or planeDistance >= bestPlaneDistance then
				continue
			end

			if not faceRectanglesOverlap(face0, face1) then
				continue
			end

			bestFace0 = face0
			bestFace1 = face1
			bestPlaneDistance = planeDistance
		end
	end

	return bestFace0, bestFace1
end

local function isMotor(surface: Enum.SurfaceType): boolean
	return surface == Enum.SurfaceType.Motor or surface == Enum.SurfaceType.SteppingMotor
end

local function isSnapSurface(surface: Enum.SurfaceType): boolean
	return surface == Enum.SurfaceType.Studs
		or surface == Enum.SurfaceType.Inlet
		or surface == Enum.SurfaceType.Universal
end

-- The boolean result says that the second face owns the directional joint.
-- RotateV reads its input from Part0, so Motor/SteppingMotor must be Part0.
local function chooseJoint(surface0: Enum.SurfaceType, surface1: Enum.SurfaceType): (JointClass?, boolean)
	if isMotor(surface0) then
		return "RotateV", false
	elseif isMotor(surface1) then
		return "RotateV", true
	elseif surface0 == Enum.SurfaceType.Hinge then
		return "Rotate", false
	elseif surface1 == Enum.SurfaceType.Hinge then
		return "Rotate", true
	elseif surface0 == Enum.SurfaceType.Weld or surface1 == Enum.SurfaceType.Weld then
		return "Weld", false
	elseif surface0 == Enum.SurfaceType.Glue or surface1 == Enum.SurfaceType.Glue then
		return "Glue", false
	elseif isSnapSurface(surface0) and isSnapSurface(surface1) and surface0 ~= surface1 then
		return "Snap", false
	end

	return nil, false
end

local function findWorldRoot(instance: Instance): WorldRoot?
	local current: Instance? = instance
	while current ~= nil do
		if current:IsA("WorldRoot") then
			return current :: WorldRoot
		end
		current = current.Parent
	end

	return nil
end


local function collectParts(subject: Instance): { BasePart }
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

local function rememberPair(pairs: { [BasePart]: { [BasePart]: boolean } }, part0: BasePart, part1: BasePart)
	local part0Pairs = pairs[part0]
	if part0Pairs == nil then
		part0Pairs = {}
		pairs[part0] = part0Pairs
	end
	part0Pairs[part1] = true

	local part1Pairs = pairs[part1]
	if part1Pairs == nil then
		part1Pairs = {}
		pairs[part1] = part1Pairs
	end
	part1Pairs[part0] = true
end

local function alreadyPaired(pairs: { [BasePart]: { [BasePart]: boolean } }, part0: BasePart, part1: BasePart): boolean
	local part0Pairs = pairs[part0]
	return part0Pairs ~= nil and part0Pairs[part1] == true
end

local function indexExistingJoints(parts: { BasePart }): { [BasePart]: { [BasePart]: boolean } }
	local pairs: { [BasePart]: { [BasePart]: boolean } } = {}

	for _, part in parts do
		for _, joint in part:GetJoints() do
			if not joint:IsA("JointInstance") then
				continue
			end

			local part0 = joint.Part0
			local part1 = joint.Part1
			if part0 ~= nil and part1 ~= nil then
				rememberPair(pairs, part0, part1)
			end
		end
	end

	return pairs
end

local function makeJoint(
	jointClass: JointClass,
	part0: BasePart,
	part1: BasePart,
	face0: Face,
	face1: Face,
	directionalFaceIsSecond: boolean
)
	if directionalFaceIsSecond then
		part0, part1 = part1, part0
		face0, face1 = face1, face0
	end

	local joint = Instance.new(jointClass) :: JointInstance
	local jointPosition = if jointClass == "Rotate" or jointClass == "RotateV"
		then face0.center
		else (face0.center + face1.center) * 0.5
	local jointFrame = CFrame.fromMatrix(jointPosition, face0.normal, face0.u, face0.normal:Cross(face0.u))

	joint.C0 = part0.CFrame:ToObjectSpace(jointFrame)
	joint.C1 = part1.CFrame:ToObjectSpace(jointFrame)
	joint.Part0 = part0
	joint.Part1 = part1
	joint.Parent = part0
end

--[[
	Creates legacy surface joints for a BasePart, or for every BasePart below a
	container. Like Model:MakeJoints(), parts outside the subject may be joined
	when they touch one of its parts.
]]
function make_joints.make_joints(subject: Instance): ()
	local worldRoot = findWorldRoot(subject)
	if worldRoot == nil then
		return
	end

	local parts = collectParts(subject)
	local paired = indexExistingJoints(parts)
	local overlapParams = OverlapParams.new()
	overlapParams.MaxParts = 0
	overlapParams.RespectCanCollide = false
	overlapParams.Tolerance = CONTACT_TOLERANCE

	for _, part0 in parts do
		for _, part1 in worldRoot:GetPartsInPart(part0, overlapParams) do
			if alreadyPaired(paired, part0, part1) then
				continue
			end

			-- Mark the pair before inspecting it so two parts in the subject are
			-- processed only once, even when their surfaces are not joinable.
			rememberPair(paired, part0, part1)

			local face0, face1 = getTouchingFaces(part0, part1)
			if face0 == nil or face1 == nil then
				continue
			end

			local jointClass, directionalFaceIsSecond = chooseJoint(face0.surface, face1.surface)
			if jointClass ~= nil then
				makeJoint(jointClass, part0, part1, face0, face1, directionalFaceIsSecond)
			end
		end
	end
end

return make_joints
