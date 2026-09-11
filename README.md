# Sequence

An animation plugin for Roblox Studio.

## Layout

```
plugin/Sequence/
  Plugin.legacy.luau     bootstrap: loads settings, mounts the app, tears it down on unload
  Config.luau            name, version, widget id, icon font
  Settings.luau          plugin settings as vide sources, saved through plugin:SetSetting
  Format.luau            duration and clock formatting
  App/
    App.luau             creates the widget and toolbar, mounts the page tree
    Widget.luau          the dock widget
    Toolbar.luau         the toolbar button
    Theme.luau           colours bound to Studio's own theme, repaints on theme change
    Components/          Button, IconButton, Icon, Toggle, Slider
    Pages/Main.luau      the page the widget opens on
  Packages/
    vide                 the UI framework; create() is how UI is built, no cloned templates
    sift                 immutable table utilities
    typed                runtime schema validation
    reel                 custom animation solver, unityjaeger/reel 0.2.0 at commit e01ca4a
  Testing/               the harness below
```

## Working on it

Studio's Script Sync is pointed at `plugin/` so that `ServerStorage.Sequence` mirrors the folder. Edits on disk land in the place and edits in the place land on disk. Do not create instances under `ServerStorage.Sequence` at runtime and expect them to survive: the sync only keeps what came from disk.

Every script follows the shared Roblox ruleset in the vault. The short version: PascalCase everywhere, `const` for every immutable local and local function, guard clauses, no comments, no trailing newline, no speculative API, string interpolation over concatenation, and vide `create()` for UI.

`Packages/` is vendor code and stays as it came. reel is `snake_case` and that is correct; do not rename it.

## Testing harness

`Testing` mounts a copy of the plugin from the current source without reinstalling, so a change can be looked at in seconds.

```lua
const Testing = require(game:GetService("ServerStorage").Sequence.Testing)

Testing.Mount(plugin)       -- clone the source beside itself and open it in a test widget
Testing.Show("MainPage")    -- stage that element on a SurfaceGui the viewport can photograph
Testing.Hide()              -- clear the stage and put the camera back
Testing.Paint("Light")      -- repaint the mount as the other theme without changing Studio
Testing.Colours()           -- every colour drawn, counted, so hardcoded ones stand out
Testing.With({TextSize = 10}, function() end)
Testing.Leftovers()         -- anything the mount left in the place
Testing.Unmount()
```

A dock widget cannot be captured from the viewport, which is why `Show` exists. Restore the camera in the same call as every screenshot, and `Unmount` before installing for real.

The mount destroys the bootstrap script, so anything that only the installed plugin does has to be verified on a real install, not on the mount.

## Installing for real

Export `ServerStorage.Sequence` as `Sequence.rbxm` into the Studio plugins folder and reload plugins. Studio reads that folder at launch and on reload, not when the file changes.