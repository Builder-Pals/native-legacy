local ReflectionService = game:GetService("ReflectionService")
local RunService = game:GetService("RunService")
local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local patching = sandbox.patching
local rbx_types = require("@layer/rbx_types")
local network_properties = require("./network_properties")

type ReflectedProperty = rbx_types.ReflectedProperty
type ReflectionType = rbx_types.ReflectionType

local PROP_SETS = {
	Security = SecurityCapabilities.new(Enum.SecurityCapability.Basic),
	ExcludeDisplay = true,
}

local prop_cache: { [string]: { ReflectedProperty } } = {}

local function filter_props(props: { ReflectedProperty }): { ReflectedProperty }
	local output = {}

	for _, prop in props do
		if prop.Permits.Write and prop.Permits.Read then
			table.insert(output, prop)
		end
	end

	return output
end

local function get_props(class: string): { ReflectedProperty }
	if prop_cache[class] then
		return prop_cache[class]
	end

	local props = ReflectionService:GetPropertiesOfClass(class, PROP_SETS)
	prop_cache[class] = table.freeze(filter_props(props))

	return prop_cache[class]
end

print(game:GetService("ReflectionService"):GetPropertiesOfClass("Part", PROP_SETS))

-- Calls to Instance:Clone() on the client will not be replicated to the server without this patch.
app.add_patch(
	"net_copy",
	patching.getter_patch {
		types = { "Instance" },
		keys = { "Clone", "clone" },
		run = function(context, _key)
			print("net copy will occur")

			return function(sandboxed_self)
				print("Performing a net copy...")
				local unsandboxed = sandbox.sandboxer.unsandbox(sandboxed_self)
				assert(typeof(unsandboxed) == "Instance")

				local refs_to_update = {}

				local function net_copy(instance: Instance)
					local copy = context.sandbox_context.client_pool(instance.ClassName)

					for _, property in get_props(instance.ClassName) do
						if not instance:IsPropertyModified(property.Name) then
							continue
						end

						local ok, err = pcall(function()
							local value = instance[property.Name]

							if typeof(value) == "Instance" then
								refs_to_update[copy] = { property.Name, value }
							else
								copy[property.Name] = value
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
					print("copying", child)
					net_copies[child] = net_copy(child)
                    task.wait()
				end

                -- update Instance references
                for instance, ref_pack in refs_to_update do
                    local property, value = unpack(ref_pack)
                    instance[property] = value
                end

				print("made all copies", "originals:", to_copy, "copies:", net_copies)

				-- build hierarchy
				for original, copy in net_copies do
					network_properties.net_set(copy, "Parent", net_copies[original.Parent])
				end

				print("net copy finished. instances:", net_copies)

				return net_copies[unsandboxed]
			end
		end,
	},
	RunService:IsClient()
)

return nil
