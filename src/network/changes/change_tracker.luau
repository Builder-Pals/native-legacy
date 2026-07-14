type IndexableInstance = Instance & {}

local RunService = game:GetService("RunService")

const SV_COMMIT = "chn"
const CL_COMMIT = "cchn"

local function increment(instance: Instance, attribute: string)
	local current = instance:GetAttribute(attribute) or 0
	assert(typeof(current) == "number")
	local new_value = current + 1
	instance:SetAttribute(attribute, new_value)
	return new_value
end

local function set(instance: Instance, attribute: string, value: number)
	instance:SetAttribute(attribute, value)
	return value
end

local function get(instance: Instance, attribute: string): number
	local current = instance:GetAttribute(attribute) or 0
	assert(typeof(current) == "number")
	return current
end

type CommitMap = { [string]: number }
type CommitMetadata = {
	id: number,
	prop: string,
	instance: Instance,
	timestamp: number,
	connection: RBXScriptConnection?,
	latest_value: any,
}

local commits: { [Instance]: CommitMap } = {}
local commit_metadata: { [number]: CommitMetadata } = {}

local function clean_commit(id: number)
	local metadata = commit_metadata[id]

	if metadata then
		commits[metadata.instance][metadata.prop] = nil
		commit_metadata[id] = nil

		if metadata.connection then
			metadata.connection:Disconnect()
		end
	end
end

local change_tracker = { commits = commits }

function change_tracker.client_change(instance: Instance, prop: string, value: any)
	if prop:sub(1, 1) == "_" then
		return
	end

	local cl = `{CL_COMMIT}{prop}`
	local sv = `{SV_COMMIT}{prop}`

	local new_commit_id = math.max(get(instance, cl), get(instance, sv)) + 1
	set(instance, cl, new_commit_id)

	commits[instance] = commits[instance] or {}

	local already_backlogged = commits[instance][prop]

	if already_backlogged then
		-- future: this means we're disconnecting/connecting a signal EVERY property change.
		-- def something we could optimise
		clean_commit(already_backlogged)
	end

	local metadata: CommitMetadata = {
		id = new_commit_id,
		prop = prop,
		instance = instance,
		timestamp = os.clock(),
		connection = nil,
		latest_value = value,
	}

	do
		const MAX_RE_ENTRIES = 500
		local re_entries = 0
		local last_server_commit = get(instance, sv)

		metadata.connection = instance:GetPropertyChangedSignal(prop):Connect(function()
			local latest_server_commit = get(instance, sv)

			if last_server_commit == latest_server_commit then
                -- the property was likely not changed by a server script
				return
			end

            local latest_cl = get(instance, cl)

            if latest_cl > new_commit_id then
                clean_commit(new_commit_id)
                return
            end

			local too_many_re_entries = re_entries > MAX_RE_ENTRIES

			if latest_server_commit >= new_commit_id or too_many_re_entries then
				if too_many_re_entries then
					warn(`[change_tracker] id={new_commit_id} max re-entries exceeded for {instance}.{prop}`)
				end

				clean_commit(new_commit_id)
				return
			end

			re_entries += 1

			local curr_value = (instance :: IndexableInstance)[prop]

            -- defer to prevent against re-parenting errors
			task.defer(function()
                local updated_value = (instance :: IndexableInstance)[prop]
                local is_unmodified = curr_value == updated_value

				if is_unmodified and metadata.latest_value ~= updated_value then
					print(`[change_tracker] id={new_commit_id} server applied an outdated commit ({instance}.{prop} = {updated_value}) - reverting to {metadata.latest_value}`);
					(instance :: IndexableInstance)[prop] = metadata.latest_value
				end
			end)

			last_server_commit = latest_server_commit
		end)
	end

	commits[instance][prop] = new_commit_id
	commit_metadata[new_commit_id] = metadata
end

function change_tracker.server_change(instance: Instance, prop: string)
	increment(instance, `{SV_COMMIT}{prop}`)
end

function change_tracker.client_gc_commits()
	const TIMEOUT = 10
	const now = os.clock()

	for id, metadata in commit_metadata do
		if now - metadata.timestamp > TIMEOUT then
			clean_commit(id)
			warn(
				`[change_tracker] id={metadata.id} dropped {metadata.instance:GetFullName()}.{metadata.prop} = {metadata.latest_value} - the server likely didn't handle the data.`
			)
		end
	end

    for instance in commits do
        if not next(commits[instance]) then
            print(`[change_tracker] stopped tracking {instance:GetFullName()}`)
            commits[instance] = nil
        end
    end
end

if RunService:IsClient() then
	task.spawn(function()
		while true do
			change_tracker.client_gc_commits()
			task.wait(5)
		end
	end)
end

return change_tracker
