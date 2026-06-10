local RunService = game:GetService("RunService")

type TypedValueBase = ValueBase & { Value: unknown }
export type TypedValue<T> = { value: T }

local IS_STUDIO = RunService:IsStudio()

local typed_values = {}
typed_values.UNSET = {} :: TypedValue<unknown>
table.freeze(typed_values.UNSET)

function typed_values.sync(scope, instance: Instance, dict: { [string]: TypedValue<unknown> })
    for key in dict do
        local valueObject = instance:WaitForChild(key) :: TypedValueBase

        table.insert(scope, valueObject:GetPropertyChangedSignal("Value"):Connect(function()
            dict[key] = { value = valueObject.Value }
        end))

        dict[key] = { value = valueObject.Value }
    end
end

function typed_values.studio_sync(_scope, _instance: Instance, _dict: { [string]: TypedValue<unknown> }) end

if IS_STUDIO then
    function typed_values.studio_sync(scope, instance: Instance, dict: { [string]: TypedValue<unknown> })
        typed_values.sync(scope, instance, dict)
    end
end

return typed_values