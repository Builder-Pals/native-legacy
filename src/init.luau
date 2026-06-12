local sandbox = require("@layer/sandbox")

return {
    enter_sandbox = sandbox.environment_sandboxer.sandbox_environment_default,
    boot = require("@self/boot")
}