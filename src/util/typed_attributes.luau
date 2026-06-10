local RunService = game:GetService("RunService")

local IS_STUDIO = RunService:IsStudio()

type AttributeDict<T> = { [string]: unknown } & T
type Observer<T> = (old_dict: T, new_dict: T) -> ()

local typed_attributes = {}

function typed_attributes.sync<T>(scope, instance: Instance, dict: AttributeDict<T>, observer: Observer<AttributeDict<T>>?)
    local ungeneric_dict = dict :: { [string]: unknown }
    
    for key in pairs(dict) do
        if observer then
            table.insert(scope, instance:GetAttributeChangedSignal(key):Connect(function()
                local backup = table.clone(dict) :: AttributeDict<T>
                table.freeze(backup)
                ungeneric_dict[key] = instance:GetAttribute(key)
                observer(backup, dict)
            end))
        else
            table.insert(scope, instance:GetAttributeChangedSignal(key):Connect(function()
                ungeneric_dict[key] = instance:GetAttribute(key)
            end))
        end
    end
end

function typed_attributes.studio_sync<T>(_scope, _instance: Instance, _dict: AttributeDict<T>, _observer: Observer<AttributeDict<T>>?) end

if IS_STUDIO then
    function typed_attributes.studio_sync<T>(scope, instance: Instance, dict: AttributeDict<T>, observer: Observer<AttributeDict<T>>?)
        typed_attributes.sync(scope, instance, dict, observer :: any)
    end
end

function typed_attributes.apply_defaults(instance: Instance, dict)
    for key, value in dict do
        if instance:GetAttribute(key) == nil then
            instance:SetAttribute(key, value)
        end
    end
end

return typed_attributes