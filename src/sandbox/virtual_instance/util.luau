--nolint Luau1037

local defiltering = require("@layer/sandbox/defiltering")
local Action = require("@layer/util/Action")
local sandboxer = require("../sandboxer")
local virtual_constants = require("./virtual_constants")

local MAX = 500
local holder_index = 0

-- luau hack. cant turn off dynaimc property access lints afaik.
type AllowDynamicProperty = Instance & {}

type Call = {
	key: string,
	args: { [any]: any },
}

-- holders store properties that will be redirected when the time comes
local holders: { Instance } = {}
local value_storage: { { [any]: any } } = {}
local call_storage: { [number]: { Call } } = {}

local virtual_instance = {
    holders = holders,
    value_storage = value_storage,
    call_storage = call_storage,
}

function virtual_instance.new(class: string)
	holder_index = holder_index + 1 % MAX

	local existing = holders[holder_index]

	if existing then
		holders[holder_index]:Destroy()
	end

	local instance = Instance.new(class)

	local highlight = Instance.new("Highlight")
	highlight.Parent = workspace.CurrentCamera
	highlight.FillTransparency = 0.5
	highlight.OutlineTransparency = 1
	highlight.FillColor = Color3.fromRGB(59, 132, 216)
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = instance

	instance.Destroying:Once(function()
		highlight:Destroy()
	end)

	holders[holder_index] = instance
	value_storage[holder_index] = {}
	call_storage[holder_index] = {}

	return instance
end

function virtual_instance.resolve(virtual: Instance, to: Instance)
	local index = table.find(holders, virtual)

	local pointer = Instance.new("ObjectValue")
	pointer.Name = virtual_constants.POINTER_NAME
	pointer.Value = to

	virtual.Parent = pointer

	if not index then
		error(`invalid holder {virtual}`)
		return
	end

	print("DUMPING", virtual:GetFullName(), virtual, to)

	for key, value in value_storage[index] do
		print("\tsetting", key, sandboxer.unsandbox(value));
		-- fire the action to replicate changes
		Action.invoke(defiltering.events.send_property, to, key, sandboxer.unsandbox(value));
		(to :: AllowDynamicProperty)[key] = sandboxer.unsandbox(value)
	end

	for _, call in call_storage[index] do
		print("\tcalling", call.key, sandboxer.unsandbox_tuple(table.unpack(call.args)))

		local fn = (to :: AllowDynamicProperty)[call.key]
		assert(fn, `invalid method {call.key} on {to:GetFullName()}`);
		(fn :: (...any) -> ...any)(to, sandboxer.unsandbox_tuple(table.unpack(call.args)))
	end

	for _, child in virtual:GetChildren() do
		print("\tparenting", child:GetFullName(), "to", to:GetFullName())
		child.Parent = to
		Action.invoke(defiltering.events.send_property, virtual, "Parent", to)
	end
end

return virtual_instance
