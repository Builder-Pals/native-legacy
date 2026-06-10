local CollectionService = game:GetService("CollectionService")

local bin_utils = require("./bin_utils")

local function observe_tag(tag: string, callback: (scope: bin_utils.Bin, instance: Instance) -> ())
    local cleanup: { [Instance]: bin_utils.Bin } = {}
    
    CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
        cleanup[instance] = cleanup[instance] or {} :: bin_utils.Bin
        callback(cleanup[instance], instance)
    end)

    CollectionService:GetInstanceRemovedSignal(tag):Connect(function(instance)
        bin_utils.empty(cleanup[instance])
        cleanup[instance] = nil
    end)

    for _, instance in ipairs(CollectionService:GetTagged(tag)) do
        cleanup[instance] = {}
        callback(cleanup[instance], instance)
    end
end

return observe_tag