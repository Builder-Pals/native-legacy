local new_server_pool = require("./new_server_pool")

local function new_server_pool_factory(container: Instance)
    local pools: { [string]: new_server_pool.ServerPool } = {}
    
    local function pop(class_name: string)
        local pool = pools[class_name]
        
        if not pool then
            local sub_container = Instance.new("Folder")
            sub_container.Name = class_name
            pool = new_server_pool(class_name, sub_container)
            pools[class_name] = pool
            sub_container.Parent = container

            local debounce = false

            sub_container.ChildRemoved:Connect(function(_)
                if debounce then
                    return
                end

                debounce = true
                
                task.delay(.1, function()
                    debounce = false
                    assert(pool)
                    pool.refill()
                end)

                assert(pool)

                -- the pool shouldn't reach zero unless it's under heavy use
                -- we'll expand to compensate
                if pool.get_capacity() == 0 then
                    print("pool has been exhausted, expanding...")
                    pool.expand()
                end
            end)
        end

        return pool.pop()
    end

    local function remove(instance: Instance)
        local pool = pools[instance.ClassName]

        if pool then
            return pool.remove(instance)
        end
    end

    local function expand(className: string)
        local pool = pools[className]

        if pool then
            return pool.expand()
        end
    end

    return {
        pop = pop,
        remove = remove,
        expand = expand,
        container = container
    }
end

return new_server_pool_factory