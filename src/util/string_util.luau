local string_util = {}

function string_util.to_camel(str: string)
    return str:sub(1, 1):lower() .. str:sub(2)
end

function string_util.to_pascal(str: string)
    return str:sub(1, 1):upper() .. str:sub(2)
end

return string_util