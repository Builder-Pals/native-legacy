local network = require("./network")
local sandbox = require("./sandbox")
local RunService = game:GetService("RunService")

local external_boot_prefab = script.Parent.external_boot

local IS_CLIENT = RunService:IsClient()

return function()
	print("booting nl...")

	if IS_CLIENT then
		print("init network")
		network.init()
		print("init client")
		sandbox.instance_pool.start_client()
	else
		print("init network")
		network.init()
		print("init server")
		sandbox.instance_pool.start_server()
	end

	-- Create a module underneath game that's easy to call from sandboxed scripts
	local external_boot = external_boot_prefab:Clone()
	external_boot.Name = "native_legacy"

	local ref = Instance.new("ObjectValue")
	ref.Value = script.Parent
	ref.Name = "module"
	ref.Parent = external_boot

	external_boot.Parent = game

    print("nl layer booted!")
end
