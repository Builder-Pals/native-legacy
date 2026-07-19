const network = require("@layer/network")
const remotes = network.remotes
const defilter_serdes = require("./defilter_serdes")
const defilterer_events = require("@layer/sandbox/defiltering/defilterer_events")
const net_locker = require("../../network/net_locker")
const Action = require("@layer/util/Action")

const UPDATE_RATE = 1 / 20
-- server property changes will be ignored for this period after the lock is released.
const NET_LOCK_DURATION = 0.1

type PropertyOperation = defilter_serdes.PropertyOperation
type LatestOperations = { [Instance]: { [string]: PropertyOperation } }
type SendPropertyOptions = defilterer_events.SendPropertyOptions

return function()
	local queue: { PropertyOperation } = {}
	local latest_operations: LatestOperations = {}
	local active_operations = 0

	Action.subscribe(defilterer_events.send_property, function(instance, property, value, options: SendPropertyOptions?)
		if not latest_operations[instance] then
			latest_operations[instance] = {}
		end

		local existing = latest_operations[instance][property]

		if existing then
			existing.active = false
		else
			active_operations += 1
		end

		local operation: PropertyOperation = {
			instance = instance,
			property = property,
			value = if value == nil then {} else value,
			active = true,
		}

		table.insert(queue, operation)
		latest_operations[instance][property] = operation

		local local_value = if options and options.use_local_value then options.local_value else value

		if options and options.locking == false then
			network.locker.set_unlocked(instance, property, local_value)
		else
			network.locker.set(instance, property, local_value)
		end
	end)

	Action.subscribe(defilterer_events.cancel_instance, function(instance)
		local operations = latest_operations[instance]

		if operations then
			for _, operation in operations do
				operation.active = false
				active_operations -= 1
			end

			latest_operations[instance] = nil
		end

		network.locker.cancel(instance)
	end)

	remotes.reliable.client.subscribe({}, remotes.ids.reliable.defiltering.send_properties, function(ak: number)
		task.delay(NET_LOCK_DURATION, function()
			network.locker.release(ak)
		end)
	end)

	local function update()
		local ak = net_locker.get_ak()

		if active_operations > 0 then
			remotes.reliable.client.send(
				remotes.ids.reliable.defiltering.send_properties,
				defilter_serdes.serialize_payload(queue, ak)
			)

			net_locker.next_ak()
		end

		table.clear(queue)
		table.clear(latest_operations)
		active_operations = 0
		task.delay(UPDATE_RATE, update)
	end

	update()
end
