local ReflectionService = game:GetService("ReflectionService")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local rbx_types = require("@layer/rbx_types")
local network_properties = require("./network_properties")

local patching = sandbox.patching

type ReflectedProperty = rbx_types.ReflectedProperty
type IndexableInstance = Instance & { [string]: any }

type PendingReference = {
	copy: Instance,
	property: string,
	value: Instance,
}

local PROP_SETS = {
	ExcludeDisplay = true,
	ExcludeInherited = false,
}

local ATTRIBUTE_PREFIX = "__a:"
local TAG_PREFIX = "__t:"

local prop_cache: { [string]: { ReflectedProperty } } = {}

local function filter_props(props: { ReflectedProperty }): { ReflectedProperty }
	local output = {}

	for _, property in props do
		if property.Name ~= "Parent" and property.Permits and property.Permits.Write and property.Permits.Read then
			table.insert(output, property)
		end
	end

	return output
end

local function get_props(class: string): { ReflectedProperty }
	local cached = prop_cache[class]

	if cached then
		return cached
	end

	local props = ReflectionService:GetPropertiesOfClass(class, PROP_SETS)

	if props == nil then
		error(`cannot reflect cloneable properties for {class}`, 2)
	end

	local filtered = filter_props(props)
	prop_cache[class] = filtered
	return filtered
end

local function collect_archivable_graph(root: Instance): { Instance }
	local graph = { root }

	local function collect_children(parent: Instance)
		for _, child in parent:GetChildren() do
			if not child.Archivable then
				continue
			end

			table.insert(graph, child)
			collect_children(child)
		end
	end

	collect_children(root)
	return graph
end

local function copy_metadata(original: Instance, copy: Instance)
	for name, value in original:GetAttributes() do
		copy:SetAttribute(name, value)
		network_properties.send_property(copy, ATTRIBUTE_PREFIX .. name, value)
	end

	for _, tag in original:GetTags() do
		copy:AddTag(tag)
		network_properties.send_property(copy, TAG_PREFIX .. tag, true)
	end
end

local function discard_all(context: sandbox.PatchedContext, copies: { Instance })
	-- Children were reserved after their parents. Discarding in reverse keeps a
	-- parent destruction from cascading through identities that still have
	-- queued rollback work of their own.
	for index = #copies, 1, -1 do
		context.sandbox_context.discard_client_instance(copies[index])
	end
end

-- Calls to Instance:Clone() on the client did replicate before FilteringEnabled.
-- Pooled server-backed identities preserve that behaviour, while this patch
-- reconstructs the native clone graph on the client before returning it.
app.add_patch(
	"net_copy",
	patching.getter_patch {
		types = { "Instance" },
		keys = { "Clone", "clone" },
		run = function(context: sandbox.PatchedContext)
			return function(sandboxed_self): Instance?
				local original_root = sandbox.sandboxer.unsandbox(sandboxed_self)
				assert(typeof(original_root) == "Instance")

				if not original_root.Archivable then
					return nil
				end

				local originals = collect_archivable_graph(original_root)
				local copies: { Instance } = {}
				local copy_for: { [Instance]: Instance } = {}
				local pending_references: { PendingReference } = {}

				local ok, result = xpcall(function()
					-- Reserve every identity before applying references or hierarchy.
					for _, original in originals do
						local copy = context.sandbox_context.client_pool(original.ClassName)
						table.insert(copies, copy)
						copy_for[original] = copy
					end

					for _, original in originals do
						local copy = copy_for[original]

						for _, property in get_props(original.ClassName) do
							if not original:IsPropertyModified(property.Name) then
								continue
							end

							local value = (original :: IndexableInstance)[property.Name]

							if typeof(value) == "Instance" then
								table.insert(pending_references, {
									copy = copy,
									property = property.Name,
									value = value,
								})
							else
								network_properties.net_set_unlocked(copy, property.Name, value)
							end
						end

						copy_metadata(original, copy)
					end

					-- References are applied only after every counterpart exists.
					for _, pending in pending_references do
						network_properties.net_set_unlocked(
								pending.copy,
								pending.property,
								copy_for[pending.value] or pending.value
							)
					end

					-- Parent last. The pool claim already keeps the root logically nil.
					for _, original in originals do
						if original == original_root then
							continue
						end

						local parent_copy = copy_for[original.Parent]
						assert(parent_copy, `missing cloned parent for {original:GetFullName()}`)
						network_properties.net_set(copy_for[original], "Parent", parent_copy)
					end

					return copy_for[original_root]
				end, debug.traceback)

				if not ok then
					discard_all(context, copies)
					error(`failed to clone {original_root:GetFullName()}:\n{result}`, 0)
				end

				return result
			end
		end,
	},
	RunService:IsClient()
)

return nil
