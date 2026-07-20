local app = require("@layer/app")
local network = require("@layer/network")
local var_store_net = require("./var_store_net")

local server = network.remotes.reliable.server
local ids = network.remotes.ids

const SEND_RATE = 1 / 20

app.add_system("var_store_server", function(ctx)
	server.subscribe({}, ids.reliable.vars.pull_all, function(player: Player)
		server.send(ids.reliable.vars.pull_all, player, var_store_net.pack(ctx.vars))
	end)

	local function net_pulse()
		if not next(ctx.vars.dirty) then
			return
		end

		local dirty = var_store_net.build_dirty_table(ctx.vars)
		server.send_all(ids.reliable.vars.push_values, dirty)
	end

	task.spawn(function()
		while true do
			net_pulse()
			task.wait(SEND_RATE)
		end
	end)
end, app.run_flags.SERVER)

return nil
