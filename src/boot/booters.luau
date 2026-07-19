local routing = require("@layer/routing")
local nl_tags = require("@layer/nl_tags")

local external_boot_prefab = script.Parent:WaitForChild("external_boot")

local function make_booter(name: string)
	-- Create a module underneath game that's easy to call from sandboxed scripts
	local external_boot = external_boot_prefab:Clone()
	external_boot.Name = name

	external_boot:AddTag(nl_tags.RELOAD_PROTECTION)

	local ref = Instance.new("ObjectValue")
	ref.Value = routing.ROOT
	ref.Name = "module"
	ref.Parent = external_boot

	external_boot.Parent = game
end

--- Yields new scripts that attempt to load until thawed.
local function freeze()
    routing.ROOT:SetAttribute("frozen", true)
end

--- Resumes all script affected by the freeze.
local function thaw()
    routing.ROOT:SetAttribute("frozen", nil)
end

return {
    freeze = freeze,
    thaw = thaw,
    new = make_booter,
}