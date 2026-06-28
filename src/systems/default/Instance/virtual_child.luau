local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local Composite = require("../../../util/Composite")
local patching = sandbox.patching
local sandboxer = sandbox.sandboxer

local TAG = "_pardir"

-- old games often parented vehicles to characters. in the modern client, this causes weird humanoid physics issues and flinging when you jump.
-- this script re-parents vehicles to th workspace, and (crudely) makes them appear like they're still parented to the character.

CollectionService:GetInstanceRemovedSignal(TAG):Connect(function(instance)
	assert(instance:IsA("ObjectValue"))

	if instance.Value then
		instance.Value:Destroy()
	end
end)

local function make_redirect(instance: Instance, new_parent)
	local reference = Instance.new("ObjectValue")
	reference.Name = instance.Name
	reference:AddTag(TAG)
	reference.Archivable = false
	reference.Value = instance
	reference.Parent = instance.Parent

	instance.Parent = new_parent

	local name_hook = instance:GetPropertyChangedSignal("Name"):Connect(function()
		reference.Name = instance.Name
	end)

	instance:GetPropertyChangedSignal("Parent"):Once(function()
		name_hook:Disconnect()
		reference.Value = nil
		reference:Destroy()
	end)
end

local function vehicle_from_seat(character: Model, seat: Instance): Instance?
	for _, child in character:GetChildren() do
		if seat:IsDescendantOf(child) or seat == child then
			return child
		end
	end

	return nil
end

local function should_patch(instance: Instance)
	return instance:IsA("Model") or instance:IsA("HopperBin")
end

local vehicle_folder: Folder?

local function new_vehicle_folder()
	local folder = Instance.new("Folder")
	folder.Name = "nl_reparented_vehicles"
	folder.Archivable = false
	folder.Parent = workspace
	return folder
end

local function get_vehicle_folder(): Folder
	if vehicle_folder and vehicle_folder.Parent == workspace then
		return vehicle_folder
	end

	local new_folder = new_vehicle_folder()
	vehicle_folder = new_folder
	return new_folder
end

local function break_joints(instance: Model | BasePart)
	-- BreakJoints is deprecated?? whatevs...
	(instance :: any):BreakJoints()
end

app.add_system("virtual_child_runtime", function(_)
	Composite.common.player_added:connect(function(player: Player)
		Composite.new():listen(player.CharacterAdded):add(player.Character):connect(function(character: Model)
			local function with_child(humanoid: Instance): nil
				if not humanoid:IsA("Humanoid") then
					return nil
				end

				local last_seat = humanoid.SeatPart

				local function redirect(seat: Instance?)
					if not seat then
						return
					end

					local vehicle = vehicle_from_seat(character, seat)

					if not vehicle then
						return
					end

					make_redirect(vehicle, get_vehicle_folder())
				end

				local function on_seat_changed()
					redirect(last_seat)
					last_seat = humanoid.SeatPart
				end

				local function on_death()
					for _, child in character:GetChildren() do
						if child:IsA("ObjectValue") and CollectionService:HasTag(child, TAG) then
							if child.Value and (child.Value:IsA("Model") or child.Value:IsA("BasePart")) then
								break_joints(child.Value)
							end
						end
					end
				end

				humanoid:GetPropertyChangedSignal("SeatPart"):Connect(on_seat_changed)
				humanoid.Died:Connect(on_death)

				return nil
			end

			Composite.new():listen(character.ChildAdded):add_array(character:GetChildren()):connect(with_child)

			for _, child in character:GetChildren() do
				with_child(child)
			end

			return nil
		end)

		return nil
	end)
end, RunService:IsServer())

app.add_patch(
	"virtual_child",
	patching.getter_patch {
		types = { "Instance" },
		keys = { "getChildren", "GetChildren" },
		run = function(context, _key)
			local instance = context.unsandboxed_object

			if not should_patch(instance) then
				return context.snapshot
			end

			return function(self)
				local unsandboxed = sandboxer.unsandbox(self) :: any
				local children = unsandboxed.GetChildren(unsandboxed)
				local output = {}

				for _, child in children do
					if child:HasTag(TAG) then
						table.insert(output, sandboxer.sandbox_from_dom(context.sandbox_context, child.Value))
					else
						table.insert(output, sandboxer.sandbox_from_dom(context.sandbox_context, child))
					end
				end

				return output
			end
		end,
	}
)

app.add_patch(
	"virtual_child",
	patching.getter_patch {
		types = { "Instance" },
		keys = { "FindFirstChild", "findFirstChild" },
		run = function(context, _key)
			local instance = context.unsandboxed_object

			if not should_patch(instance) then
				return context.snapshot
			end

			return function(self, name: string)
				local unsandboxed = sandboxer.unsandbox(self) :: any
				local result = unsandboxed.FindFirstChild(unsandboxed, name) :: any
				return sandboxer.sandbox(
					context.sandbox_context,
					if result and result:HasTag(TAG) then result.Value else result
				)
			end
		end,
	}
)

return {
	make_redirect = make_redirect,
}
