local RunService = game:GetService("RunService")

return {
	client_pool = require("@self/client_pool"),
	server_pool = require("@self/server_pool"),
	new_instance_lib = if RunService:IsClient()
		then require("@self/instance_lib_client")
		else require("@self/instance_lib_server"),
}
