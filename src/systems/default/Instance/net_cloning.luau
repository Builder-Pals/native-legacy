local ReflectionService = game:GetService("ReflectionService")
local RunService = game:GetService("RunService")
local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local rbx_types = require("@layer/rbx_types")
local network_properties = require("./network_properties")

type ReflectedProperty = rbx_types.ReflectedProperty
type ReflectionType = rbx_types.ReflectionType

type IndexableInstance = Instance & {}

local PROP_SETS = {
	ExcludeDisplay = true,
	ExcludeInherited = false
}

local prop_cache: { [string]: { ReflectedProperty } } = {}

local function filter_props(props: { ReflectedProperty }): { ReflectedProperty }
	local output = {}

	for _, prop in props do
		if prop.Permits and prop.Permits.Write and prop.Permits.Read then
			table.insert(output, prop)
		end
	end

	return output
end

local function get_props(class: string): { ReflectedProperty }
	if prop_cache[class] then
		return prop_cache[class]
	end

	print(`Getting properties for {class}`)
	local props = ReflectionService:GetPropertiesOfClass(class, PROP_SETS)

	if props == nil then
		warn(`{class} has no properties or is invalid!`)
		prop_cache[class] = {}
		return prop_cache[class]
	end

	prop_cache[class] = filter_props(props)
	return prop_cache[class]
end

-- Calls to Instance:Clone() on the client will not be replicated to the server without this patch.
app.add_patch(
	"net_copy",
	patching.getter_patch {
		types = { "Instance" },
		keys = { "Clone", "clone" },
		run = function(context, _key)
			return function(sandboxed_self)
				local unsandboxed = sandbox.sandboxer.unsandbox(sandboxed_self)
				assert(typeof(unsandboxed) == "Instance")

				local refs_to_update = {}

				local function net_copy(instance: IndexableInstance)
					local copy = context.sandbox_context.client_pool(instance.ClassName)

					for _, property in get_props(instance.ClassName) do
						if not instance:IsPropertyModified(property.Name) then
							continue
						end

						local ok, err = pcall(function()
							local value = instance[property.Name]

							if typeof(value) == "Instance" then
								-- Instance references will need to be changed to use
								-- their copied counterparts.
								table.insert(refs_to_update, { copy, property.Name, value})
							else
								network_properties.net_set(copy, property.Name, value)
							end
						end)

						if not ok then
							warn(
								`failed to set {property.Name} on {instance.ClassName}: {err}\n🧵{debug.traceback()}`
							)
						end
					end

					return copy
				end

				local to_copy = unsandboxed:GetDescendants()
				table.insert(to_copy, unsandboxed)

				local net_copies = {}

				-- make copies
				for _, child in to_copy do
					net_copies[child] = net_copy(child)
				end

                -- update Instance references
                for _, ref_pack in refs_to_update do
                    local copy: Instance, property: string, value: any = unpack(ref_pack :: { any })
					network_properties.net_set(copy, property, net_copies[value] or value)
                end

				return net_copies[unsandboxed]
			end
		end,
	},
	RunService:IsClient()
)

return nil
