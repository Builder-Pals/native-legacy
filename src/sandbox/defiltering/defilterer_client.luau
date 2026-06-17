local remotes = require("@layer/network/remotes")
local virtual_constants = require("../virtual_instance/virtual_constants")
local defilter_serdes = require("./defilter_serdes")
local defilterer_events = require("@layer/sandbox/defiltering/defilterer_events")
local Action = require("@layer/util/Action")

local UPDATE_RATE = 1 / 20

return function()
	local queue = {}

	Action.subscribe(defilterer_events.send_property, function(instance, property, value)
		if not queue[instance] then
			queue[instance] = {}
		end

		if instance:HasTag(virtual_constants.VIRTUAL_INSTANCE_TAG) then
			warn(`Attempted to send property {property} on virtual instance {instance:GetFullName()}. This is not supported and will be ignored.`)
			return
		end

		queue[instance][property] = if value == nil then {} else value
	end)

	local function update()
		if next(queue) then
			remotes.reliable.client.send(
				remotes.ids.reliable.defiltering.send_properties,
				defilter_serdes.serialize_payload(queue)
			)
		end

		table.clear(queue)
		task.delay(UPDATE_RATE, update)
	end

	update()
end
