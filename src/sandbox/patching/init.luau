local patch_creator = require("@self/patch_creator")
local patch_symbols = require("@self/patch_symbols")

return {
    getter_patch = patch_creator.new_getter_patch,
    setter_patch = patch_creator.new_setter_patch,
    symbols = patch_symbols,
    utils = require("@self/patch_utils"), 

    --- Applies a patch to ALL classes. Currently the same as providing an empty table
    ALL_CLASSES = {} :: { string }
}