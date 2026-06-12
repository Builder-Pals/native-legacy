local patch_creator = require("@self/patch_creator")
local patch_module_creator = require("@self/patch_module_creator")

return {
    getter_patch = patch_creator.new_getter_patch,
    setter_patch = patch_creator.new_setter_patch,
    
    module = patch_module_creator.simple,
    group_module = patch_module_creator.group,

    --- Applies a patch to ALL classes. Currently the same as providing an empty table
    ALL_CLASSES = {} :: { string }
}