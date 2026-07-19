local ReflectionService = game:GetService("ReflectionService")
local RunService = game:GetService("RunService")

local app = require("@layer/app")
local sandbox = require("@layer/sandbox")
local nl_tags = require("@layer/nl_tags")
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

const PROP_SETS: ReflectionMemberFilter = {
	ExcludeDisplay = true,
	ExcludeInherited = false,
}

const ATTRIBUTE_PREFIX = "__a:"
const TAG_PREFIX = "__t:"
const SCRIPT_TYPES = { "LocalScript", "Script", "ModuleScript" }

local prop_cache: { [string]: { ReflectedProperty } } = {}

local function is_snap_external(cloneable: { [Instance]: true }, snap: Snap)
	if snap.Part0 and not cloneable[snap.Part0] then
		return true
	end

	if snap.Part1 and not cloneable[snap.Part1] then
		return true
	end

	return false
end

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

	local filtered = filter_props(props :: { ReflectedProperty })
	prop_cache[class] = filtered
	return filtered
end

local function collect_archivable_graph(root: Instance): { Instance }
	local cloneable: { [Instance]: true } = { [root] = true }

	local function collect_cloneable(parent: Instance)
		for _, child in parent:GetChildren() do
			if not child.Archivable then
				continue
			end

			cloneable[child] = true
			collect_cloneable(child)
		end
	end

	collect_cloneable(root)

	local graph = { root }

	local function collect_filtered(parent: Instance)
		for _, child in parent:GetChildren() do
			if not cloneable[child] then
				continue
			end

			-- Legacy Clone omitted Snap joints which crossed the cloned graph.
			-- Other external Instance references intentionally remain intact.
			if child:IsA("Snap") and is_snap_external(cloneable, child) then
				continue
			end

			table.insert(graph, child)
			collect_filtered(child)
		end
	end

	collect_filtered(root)
	return graph
end

local function shift_scripts(graph: { Instance }): { [Instance]: Instance }
	local remapping: { [Instance]: Instance } = {}

	for _, item in graph do
		if item:HasTag(nl_tags.POINTER_SCRIPT) and item.Parent then
			remapping[item.Parent] = item
		end
	end

	return remapping
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

-- Calls to Instance:Clone() on the client used to replicate before FilteringEnabled.
-- This patch restores that behaviour, with instance pooling and server-auth control over
-- what sources can be copied.
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
				local script_remapping = shift_scripts(originals)
				local copies: { Instance } = {}
				local copy_for: { [Instance]: Instance } = {}
				local pending_references: { PendingReference } = {}
				-- note: cant send instance keys over the network, so we use arrays
				local scripts_to_fill: { { Instance } } = {}

				local ok, result = xpcall(function()
					-- Reserve every identity before applying references or hierarchy.
					for _, original in originals do
						local copy = context.sandbox_context.client_pool(original.ClassName)
						table.insert(copies, copy)
						copy_for[original] = copy
					end

					for _, original in originals do
						local copy = copy_for[original]

						if script_remapping[original] then
							network_properties.net_set_unlocked(copy, "Name", original.Name)
						end

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

						if table.find(SCRIPT_TYPES, original.ClassName) then
							table.insert(scripts_to_fill, { copy, script_remapping[original] or original })
						end
					end

					-- only apply references after each instance has been created
					for _, pending in pending_references do
						network_properties.net_set_unlocked(
							pending.copy,
							pending.property,
							copy_for[pending.value] or pending.value
						)
					end

					-- apply parenting last (for performance, and to avoid firing off events)
					for _, original in originals do
						if original == original_root then
							continue
						end

						if not original.Parent then
							warn(`[net_cloning] missing parent for {original:GetFullName()}`)
							continue
						end

						local parent_copy = copy_for[original.Parent]
						assert(parent_copy, `missing cloned parent for {original:GetFullName()}`)
						network_properties.net_set(copy_for[original], "Parent", parent_copy)
					end

					network_properties.request_script_fill(scripts_to_fill)

					return copy_for[original_root]
				end, debug.traceback :: (string) -> ())

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
