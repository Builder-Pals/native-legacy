export type ServerSends<T...> = string

local current_id = 0

local function next_id<T...>(): ServerSends<T...>
    current_id += 1
    return tostring(current_id)
end

local remote_ids = {
    unreliable = {
        defiltering = {
            send_properties = next_id()
        }
    },

    reliable = {
        instance_pool = {
            pop = next_id()
        },

        defiltering = {
            send_properties = next_id()
        }
    },
}

return remote_ids