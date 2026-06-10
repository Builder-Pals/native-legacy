export type Action<Args...> = {
    subscribers: { [Subscriber<Args...>]: true },
}

type Subscriber<Args...> = (Args...) -> ()

local Action = {}

function Action.new<Args...>(): Action<Args...>
    return { subscribers = {} }
end

function Action.subscribe<Args...>(action: Action<Args...>, callback: Subscriber<Args...>)
    action.subscribers[callback] = true

    --- Unsubscribes from an action
    return function()
        action.subscribers[callback] = nil
    end
end

function Action.scoped_subscribe<Args...>(scope: { [any]: any } & { any }, action: Action<Args...>, callback: Subscriber<Args...>)
    action.subscribers[callback] = true

    --- Unsubscribes from an action
    local function unsubscribe()
        action.subscribers[callback] = nil
    end

    table.insert(scope, unsubscribe)
end

function Action.invoke<Args...>(action: Action<Args...>, ...: Args...)
    for subscriber in action.subscribers do
        subscriber(...)
    end
end

function Action.invoker<Args...>(action: Action<Args...>)
    return function(...)
        Action.invoke(action, ...)
    end
end

function Action.invoke_safe<Args...>(action: Action<Args...>, ...: Args...)
    for subscriber in action.subscribers do
        task.spawn(subscriber, ...)
    end
end

return Action