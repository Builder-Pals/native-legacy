--!nonstrict

local module_pointer = script:WaitForChild("module").Value

local layer = require(module_pointer)
local linked_sources = require(module_pointer:WaitForChild("linked_sources"))

return function(environment: any)
	if module_pointer:GetAttribute("frozen") then
		module_pointer:GetAttributeChangedSignal("frozen"):Wait()
	end

	local linked_source

	print(
		"[new script]",
		environment.script,
		environment.script:IsA("LuaSourceContainer"),
		environment.script.LinkedSource
	)

	if typeof(environment.script) == "Instance" and environment.script:IsA("LuaSourceContainer") then
		local linked_source_url = environment.script:GetAttribute("LinkedSource")

		if linked_source_url then
			print("LINKED SOURCE DETECTED", environment.script)
			linked_source = linked_sources.from_url(linked_source_url)

			if not linked_source then
				warn(
					`an unrecognised LinkedSource was detected in {environment.script:GetFullName()} - it may fail to load. url: {linked_source_url}`
				)
			end
		end
	end

	layer.enter_sandbox(environment)

	if linked_source then
		setfenv(linked_source, environment)
		linked_source()
	end
end
