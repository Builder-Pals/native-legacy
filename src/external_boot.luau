local environment_sandboxer = require("@layer/sandbox/environment_sandboxer")
local boot = require("./boot")
local is_booted = false

return function(environment: any)
    environment_sandboxer.sandbox_environment_default(environment)

    if is_booted then
        return
    end

    is_booted = true
    boot()
end