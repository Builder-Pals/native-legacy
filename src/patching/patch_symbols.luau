local new_symbol = require("@layer/util/new_symbol")

-- TODO: Hide these from iteration with pairs/ipairs
return {
    SETTER_PATCHES_SYMBOL = new_symbol("Setter Patches"),
    GETTER_PATCHES_SYMBOL = new_symbol("Getter Patches"),
    PATCH_STORAGE_SYMBOL = new_symbol("Patch Storage"),
    UNSANDBOXED_OBJECT = new_symbol("Unsandboxed Object"),
    SANDBOX_CONTEXT = new_symbol("Sandbox Context")
}