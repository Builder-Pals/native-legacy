--!nonstrict

local module_pointer = script:WaitForChild("module").Value

local layer = require(module_pointer)
local linked_sources = require(module_pointer:WaitForChild("linked_sources"))

return function(environment: any)
	local linked_source

	if
		typeof(environment.script) == "Instance"
		and environment.script:IsA("LuaSourceContainer")
		and #environment.script.LinkedSource > 0
	then
		linked_source = linked_sources.from_url(environment.script.LinkedSource)

		if not linked_source then
			warn(
				`an unrecognised LinkedSource was detected in {environment.script:GetFullName()} - it may fail to load. url: {environment.script.LinkedSource}`
			)
		end
	end

	layer.enter_sandbox(environment)

	if linked_source then
		setfenv(linked_source, environment)
		linked_source()
	end
end