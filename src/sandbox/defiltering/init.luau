const RunService = game:GetService("RunService")

const IS_CLIENT = RunService:IsClient()

const events = require("@self/defilterer_events")
const Action = require("../util/Action")

return {
	events = events,
	start_client = require("@self/defilterer_client"),
	start_server = require("@self/defilterer_server"),

	--[[
		Replicates `Instance:Destroy()` over the network
	--]]
	net_destroy = function(instance: Instance)
		if IS_CLIENT then
			Action.invoke(events.send_property, instance, "__d", true)
		end

		instance:Destroy()
	end,
}
