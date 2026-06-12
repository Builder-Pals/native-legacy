local network = require("./network")
local sandbox = require("./sandbox")
local RunService = game:GetService("RunService")

local IS_CLIENT = RunService:IsClient()

return function()
	if IS_CLIENT then
		network.init()
		sandbox.instance_pool.start_client()
	else
		network.init()
		sandbox.instance_pool.start_server()
	end

    print("nl layer booted!")
end
