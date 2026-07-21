local app = require("@layer/app")
local network = require("@layer/network")
local var_store_net = require("./var_store_net")

local client = network.remotes.reliable.client
local ids = network.remotes.ids

const SEND_RATE = 1 / 10

app.add_system("var_store_client", function(ctx)
	client.subscribe({}, ids.reliable.vars.pull_all, function(data)
		var_store_net.unpack_to(ctx.vars, data)
	end)
	client.subscribe({}, ids.reliable.vars.push_values, function(data)
		var_store_net.unpack_to(ctx.vars, data)
	end)

	-- tell the server to send us an initial payload
	client.send(ids.reliable.vars.pull_all)

	local function net_pulse()
		if not next(ctx.vars.dirty) then
			return
		end

		client.send(ids.reliable.vars.push_values, var_store_net.take_dirty_table(ctx.vars))
	end

	task.spawn(function()
		while true do
			net_pulse()
			task.wait(SEND_RATE)
		end
	end)
end, app.run_flags.CLIENT)

return nil
