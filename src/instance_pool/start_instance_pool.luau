local RunService = game:GetService("RunService")

local instance_pool_runtime_client = require("./instance_pool_runtime_client")
local instance_pool_runtime_server = require("./instance_pool_runtime_server")

return function(): instance_pool_runtime_client.RuntimeClient?
    if RunService:IsClient() then
        return instance_pool_runtime_client()
    else
        instance_pool_runtime_server()
        return nil
    end
end