--!nonstrict

local layer = require(script:WaitForChild("module").Value)

return function(environment: any)
    layer.enter_sandbox(environment)
end