local MIN_POOL_SIZE = 5
local MAX_POOL_SIZE = 25

local function new_server_pool(class_name: string, parent: Instance)
    local items = {}
    local size = MIN_POOL_SIZE

    local function populate()
        local instance = Instance.new(class_name)
        instance.Parent = parent
        table.insert(items, instance)
    end
    
    local function expand()
        if size < MAX_POOL_SIZE then
            size += 1
            populate()
        end
    end

    local function pop()
        local item = table.remove(items)

        if #items == 0 then
            print("pool is struggling - expand")
            expand()
        end

        while #items < size do
            populate()
        end

        if item == nil then
            return pop()
        end

        return item :: Instance
    end

    local function remove(item)
        local index = table.find(items, item)

        if index then
            table.remove(items, index)
        end

        while #items < size do
            populate()
        end
    end

    while #items < MIN_POOL_SIZE do
        populate()
    end
    
    return {
        pop = pop,
        expand = expand,
        remove = remove
    }
end

export type ServerPool = typeof(new_server_pool("", workspace))

return new_server_pool