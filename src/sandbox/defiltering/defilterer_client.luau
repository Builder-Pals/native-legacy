const network = require("@layer/network")
const remotes = network.remotes
const defilter_serdes = require("./defilter_serdes")
const defilterer_events = require("@layer/sandbox/defiltering/defilterer_events")
const net_locker = require("../../network/net_locker")
const Action = require("@layer/util/Action")

const UPDATE_RATE = 1 / 20
-- server property changes will be ignored for this period after the lock is released.
const NET_LOCK_DURATION = 0.1

type Queue = { [Instance]: { [string]: unknown } }

return function()
	local queue: Queue = {}

	Action.subscribe(defilterer_events.send_property, function(instance, property, value)
		if not queue[instance] then
			queue[instance] = {}
		end

		queue[instance][property] = if value == nil then {} else value
		network.locker.set(instance, property, value)
	end)

	remotes.reliable.client.subscribe({}, remotes.ids.reliable.defiltering.send_properties, function(ak: number)
		task.delay(NET_LOCK_DURATION, function()
			network.locker.release(ak)
		end)
	end)

	local function update()
		local ak = net_locker.get_ak()

		if next(queue) then
			remotes.reliable.client.send(
				remotes.ids.reliable.defiltering.send_properties,
				defilter_serdes.serialize_payload(queue, ak)
			)

			net_locker.next_ak()
		end

		table.clear(queue)
		task.delay(UPDATE_RATE, update)
	end

	update()
end
