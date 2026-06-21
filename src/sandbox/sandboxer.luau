local sandbox_types = require("./sandbox_types")
local patch_symbols = require("@layer/sandbox/patching/patch_symbols")

local sandboxers = {}

local function sandbox(context: sandbox_types.App, value: any)
	local sandboxer = sandboxers[typeof(value)]
	return if sandboxer then sandboxer(context, value) else value
end

--- For pulling values in/out of the Sandbox
local sandboxer = {}

--- Registers a sandboxer for a specific type.
--- For unsandboxing, add the `UNSANDBOXER` or `UNSANDBOXED_OBJECT` symbol to the table.
function sandboxer.register(type: string, fn: (context: sandbox_types.App, value: any) -> any)
	assert(sandboxers[type] == nil, `sandboxer for type {type} already registered`)
	sandboxers[type] = fn
end

function sandboxer.is_sandboxed(value: any)
	return typeof(value) == "table" and rawget(value, patch_symbols.UNSANDBOXED_OBJECT)
end

--- Puts a value into the sandbox using any currently registered sandboxers.
function sandboxer.sandbox(context: sandbox_types.App, value: unknown)
	if typeof(value) == "table" and getmetatable(value) == nil then
		local output = {}

		for key, value_2 in value do
			-- if the table contains sandboxed values, we must have already touched it.
			-- sandboxed values should NEVER come directly from the DOM.
			if sandboxer.is_sandboxed(key) or sandboxer.is_sandboxed(value_2) then
				return value
			end

			output[sandbox(context, key)] = sandbox(context, value_2)
		end

		return output
	end

	return sandbox(context, value)
end

--- Optimised sandboxer, specifically for values coming from the Data Object Model.
function sandboxer.sandbox_from_dom(context: sandbox_types.App, value: unknown)
	if typeof(value) == "table" then
		local output = {}

		for key, value_2 in value do
			output[sandbox(context, key)] = sandbox(context, value_2)
		end

		return output
	end

	return sandbox(context, value)
end

function sandboxer.unsandbox(value: any)
	if typeof(value) == "table" then
		local unsandboxed = rawget(value, patch_symbols.UNSANDBOXED_OBJECT)

		if unsandboxed ~= nil then
			return unsandboxed
		end

		local unsandboxer = rawget(value, patch_symbols.UNSANDBOXER)

		if unsandboxer ~= nil then
			return (unsandboxer :: (any) -> any)(value)
		end
	end

	return value
end

--- Sandboxes multiple values
function sandboxer.sandbox_tuple(context: sandbox_types.App)
	return function(...: any)
		local packed = table.pack(...)
		local result = {}

		for key, value in packed do
			result[key] = sandboxer.sandbox(context, value)
		end

		return table.unpack(result)
	end
end

--- Sandboxes multiple values (specifically for values coming from the Data Object Model - micro optimisation :P)
function sandboxer.sandbox_tuple_dom(context: sandbox_types.App)
	return function(...: any)
		local packed = table.pack(...)
		local result = {}

		for key, value in packed do
			result[key] = sandboxer.sandbox_from_dom(context, value)
		end

		return table.unpack(result)
	end
end

--- Unsandboxes multiple values
function sandboxer.unsandbox_tuple(...: any)
	local packed = table.pack(...)
	local result = {}

	for key, value in packed do
		result[key] = sandboxer.unsandbox(value)
	end

	return table.unpack(result)
end

return sandboxer
