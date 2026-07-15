local RunService = game:GetService("RunService")

const IS_CLIENT = RunService:IsClient()

type Lock = {
	ak: number,
	latest_client_value: unknown,
	applying_client_value: boolean,
	rejects: number,
	connections: { RBXScriptConnection },
}

type ReleasingLock = {
	instance: Instance,
	property: string,
	lock: Lock,
}

local locks: { [Instance]: { [string]: Lock } } = {}

local function instance_set(instance: Instance, property: string, value: unknown)
	(instance :: Instance & { [string]: unknown })[property] = value
end

local function instance_get(instance: Instance, property: string)
	return (instance :: Instance & { [string]: unknown })[property]
end

local function disconnect_lock(instance: Instance, property: string, expected_lock: Lock)
	local lock_map = locks[instance]

	if not lock_map or lock_map[property] ~= expected_lock then
		return
	end

	lock_map[property] = nil

	for _, connection in expected_lock.connections do
		connection:Disconnect()
	end

	if not next(lock_map) then
		locks[instance] = nil
	end
end

local function set_client_value(lock: Lock, instance: Instance, property: string, value: unknown)
	lock.applying_client_value = true
	local success, message = pcall(instance_set, instance, property, value)
	lock.applying_client_value = false

	if not success then
		error(message, 2)
	end
end

local ak = 1

local net_locker = {}

function net_locker.get_ak()
	return ak
end

function net_locker.next_ak()
	ak += 1
end

function net_locker.set(instance: Instance, property: string, value: unknown)
	assert(IS_CLIENT)

	local is_symbol = property:sub(1, 2) == "__" -- prefixes for remove/delete functions (not real properties)

	if is_symbol then
		return
	end

	-- can't network functions
	if typeof(value) == "function" then
		instance_set(instance, property, value)
		return
	end

	if not locks[instance] then
		locks[instance] = {}
	end

	local existing_lock = locks[instance][property]

	if existing_lock then
		existing_lock.ak = ak
		existing_lock.latest_client_value = value
		existing_lock.rejects = 0
		set_client_value(existing_lock, instance, property, value)
		return
	end

	local lock: Lock = {
		ak = ak,
		latest_client_value = value,
		applying_client_value = false,
		rejects = 0,
		connections = {},
	}

	locks[instance][property] = lock

	table.insert(
		lock.connections,
		instance:GetPropertyChangedSignal(property):Connect(function()
			local lock_map = locks[instance]

			-- A disconnected signal can already have been queued when a lock is
			-- replaced. Never let that stale callback act on the new lock.
			if not lock_map or lock_map[property] ~= lock then
				return
			end

			-- Property signals caused by our own immediate write/rejection are not
			-- server replication and must not affect the lock's server history.
			if lock.applying_client_value then
				return
			end

			if lock.rejects >= 200 then
				warn(
					`[net_locker] WARN: ak={lock.ak} rejected {instance}.{property} being set too many times!\n{debug.traceback()}`
				)
				disconnect_lock(instance, property, lock)
				return
			end

			local latest = instance_get(instance, property)

			if latest ~= lock.latest_client_value then
				lock.rejects += 1
				--print(`[net_locker] ak={lock.ak} rejected {instance}.{property} being set`)
				set_client_value(lock, instance, property, lock.latest_client_value)
			else
				--print(`[net_locker] ak={lock.ak} accepted {instance}.{property} being set`)
			end
		end)
	)

	table.insert(
		lock.connections,
		instance.Destroying:Connect(function()
			disconnect_lock(instance, property, lock)
		end)
	)

	set_client_value(lock, instance, property, value)
end

function net_locker.release(ak: number)
	local releasing: { ReleasingLock } = {}

	for instance, lock_map in locks do
		for property, lock in lock_map do
			if lock.ak == ak then
				table.insert(releasing, {
					instance = instance,
					property = property,
					lock = lock,
				})
			end
		end
	end

	for _, entry in releasing do
		-- the acknowledgement (ak) confirms that the server received the batch containing latest_client_value.
		-- values before the ak are intermediate, and can be disregarded.
		set_client_value(entry.lock, entry.instance, entry.property, entry.lock.latest_client_value)
		disconnect_lock(entry.instance, entry.property, entry.lock)
	end
end

return net_locker
