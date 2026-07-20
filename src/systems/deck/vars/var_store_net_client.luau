local app = require("@layer/app")
local vars = require("@layer/vars")
local network = require("@layer/network")
local var_store_net = require("./var_store_net")

local client = network.remotes.reliable.client
local ids = network.remotes.ids

const SEND_RATE = 1 / 10

local function get_net_ids()
	local net_ids = {}

	for index, value in pairs(vars.def_array) do
		net_ids[value.id] = index
	end

	return net_ids
end

app.add_system("var_store_client", function(ctx)
	local net_ids = get_net_ids()

	client.subscribe({}, ids.reliable.vars.pull_all, function(data)
		var_store_net.unpack_to(ctx.vars, data)
	end)

	-- tell the server to send us an initial payload
	client.send(ids.reliable.vars.pull_all)

	local function net_pulse()
		if not next(ctx.vars.dirty) then
			return
		end

		local dirty_values = {}

		for def in ctx.vars.dirty do
			dirty_values[net_ids[def.id]] = vars.modifier.get_var(ctx.vars, def)
		end

		client.send(ids.reliable.vars.push_values, dirty_values)
	end

	task.spawn(function()
		while true do
			net_pulse()
			task.wait(SEND_RATE)
		end
	end)
end, app.run_flags.CLIENT)

return nil
