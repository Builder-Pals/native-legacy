--!nonstrict

local linked_sources = require("./linked_sources")
local layer = require(script:WaitForChild("module").Value)

return function(environment: any)
    local linked_source

	if typeof(environment.script) == "Instance" then
		linked_source = linked_sources.from_url(environment.script.LinkedSource)

        if not linked_source then
            warn(`an unrecognised LinkedSource was detected in {environment.script:GetFullName()} - it may fail to load`)
        end
	end

	layer.enter_sandbox(environment)

	if linked_source then
		setfenv(linked_source, environment)
		linked_source()
	end
end
