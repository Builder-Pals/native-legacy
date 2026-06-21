local RunService = game:GetService("RunService")
local not_running = true

return {
    client = require("@self/console_client"),
    server = require("@self/console_server"),
    init = function()
        assert(not_running, "already initialized!")
        not_running = false

        if RunService:IsServer() then
            require("@self/console_server")()
        else
            require("@self/console_client")()
        end
    end
}