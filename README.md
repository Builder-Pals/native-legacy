# Native Legacy
![Logo](brand/logo.webp)

a backwards compatibility layer for Roblox that allows people to play their old favourite games again!

---

## What?

Native Legacy restores legacy engine behaivour on the modern Roblox client (hence the name) by modifying scripts and creating a sandbox.

Examples of things NL does:

- Grants access to some VIP rooms and admin features through Badge/Friend spoofing. 
- Restores Flag functionality.
- Fixes HopperBins.
- Emulates the Sets API.
- Redirects `InsertService` calls to `AssetService`.
- Provides a pseudo version of `BadgeService`.

## What Makes it Work?

The scripts inside of games/models have an injector appended to the top of them. Example below.

Before: 

```lua
local MOUSE_ICON = 'rbxasset://textures/GunCursor.png'
local RELOADING_ICON = 'rbxasset://textures/GunWaitCursor.png'
```

After: 

```lua
require(game:WaitForChild("native_legacy"))(getfenv());local MOUSE_ICON = __STRDEC 'rbxasset://textures/GunCursor.png'
local RELOADING_ICON = __STRDEC 'rbxasset://textures/GunWaitCursor.png'
```

The required module replaces all data model references in the script's environment with sandboxed alternatives, and applies **patches** modify what happens when properties/methods are requested.

If you've ever played Script Builder games, this is how they're able to keep you in the sandbox - accept in our case, sandbox escapes are an issue due to compatibility, not safety :P.

## Licensing & Contributions

Native Legacy is currently provided in a **source public** state - this means *all rights are reserved* and the project is not technically open source. This will change once we reach our MVP - please stay tuned!

## Attribution

[Classic Build Tools](https://create.roblox.com/store/asset/1148735607/Classic-Build-Tools) by MaximumADHD - A modified version of this model is used. The NL version uses Accessories in-place of tools.