local stalled: { [Script]: true | nil } = {}
local timestamps: { [Script]: number } = {}

local TIMEOUT = 15
local last_gc = 0

local function gc()
	if os.clock() - last_gc < TIMEOUT then
		return
	end

	last_gc = os.clock()

	for script, timestamp in timestamps do
		if last_gc - timestamp > TIMEOUT then
			stalled[script] = nil
			timestamps[script] = nil
		end
	end
end

local script_stalling = {}

--- Stalls a script until the operation is complete, with error handling to ensure scripts are unstalled in the event
--- of an error.
function script_stalling.with<X>(script: Script, op: () -> X): X
	script_stalling.stall(script)
	local ok, result = pcall(function()
		return op()
	end)

	script_stalling.unstall(script)
	assert(ok, tostring(result) .. "\n" .. debug.traceback())
	return result :: X
end

function script_stalling.yield_if_stalled(script: Script)
	if stalled[script] then
		print(`{script} is stalled!`)

		while stalled[script] do
			gc()
			task.wait()
		end
		
		print(`resuming execution of {script}...`)
	end
end

function script_stalling.stall(script: Script)
	stalled[script] = true
end

function script_stalling.unstall(script: Script)
	stalled[script] = nil
end

return script_stalling
