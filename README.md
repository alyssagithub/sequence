# Sequence

An animation plugin for Roblox Studio.

## Layout

```
plugin/sequence/
  Plugin.legacy.luau     bootstrap: loads settings, mounts the app, tears it down on unload
  Config.luau            name, version, widget id
  Settings.luau          plugin settings as vide sources, saved through plugin:SetSetting
  Format.luau            timecode and degree formatting
  Editor/
    Session.luau         every piece of editor state as vide sources, plus undo, playback, selection
    Clip.luau            the animation data: tracks of keys per joint, markers, length, priority
    Rig.luau             scans a model for Motor6D joints, anchors it, writes poses as part CFrames
    Pose.luau            samples a clip at a time
    Easing.luau          the engine's own pose easing curves, measured against a playtest
    Saver/               clip to KeyframeSequence and back, AnimSaves, publish, import by asset id
    Gizmo/               ArcHandles and Handles on the selected joint
    OnionSkin/           ghost copies of the rig at the previous and next keyframe
    ClipSchema.luau      typed schema used when reading a sequence back in
  App/
    App.luau             creates the widget and toolbar, starts the editor, mounts the page tree
    Widget.luau          the dock widget, bottom docked
    Toolbar.luau         the toolbar button
    Theme.luau           colours bound to Studio's own theme, repaints on theme change
    Overlay.luau         the popup layer that menus and dropdowns open into
    Hotkeys.luau         keyboard shortcuts while the widget has the mouse
    Components/          Button, IconButton, Icon, Toggle, Dropdown, NumberField, TextField
    Pages/               Main, TopBar, Transport, Timeline, Inspector
  Packages/
    vide, sift, typed, reel, lucide-icons   thin modules that require into _Index, the layout Loom writes
    _Index/                                 one folder per package at its pinned version, vendor code, never edited
  Testing/               the harness below
tools/build_rbxmx.py     builds plugin/ into an rbxmx that the Studio bridge can load, without Rojo
```

## What it does

Pick a model with Motor6D joints, and every joint becomes a track. Move a part with Studio's own
Move and Rotate tools, or with the gizmo on the selected joint, and a keyframe lands at the
playhead. Keyframes carry an easing style and direction that preview exactly as the engine plays
them (Cubic is written out as CubicV2 so In means accelerate). Events go on the lane above the
summary row. Save writes a KeyframeSequence into the rig's AnimSaves, Open lists what is there,
Publish saves then opens Studio's upload window, and an asset id can be imported through the
name box. Onion skin shows the neighbouring keyframes as tinted ghosts. Undo and redo are the
plugin's own and do not go through Studio's history.

Keys: Space plays, K keys the selected joint or every joint, Delete removes selected keys, Left
and Right step a frame (Shift for five), Home and End jump, R and T switch the gizmo, Ctrl+Z,
Ctrl+Y, Ctrl+C, Ctrl+V, Ctrl+D and Ctrl+A do what they say, Escape clears the selection.
Ctrl+wheel over the timeline zooms, Shift+wheel pans, right click opens the menus.

## Testing harness

`Testing` mounts a copy of the plugin from the current source without reinstalling, so a change can be looked at in seconds.

```lua
const Testing = require(game:GetService("ServerStorage").Sequence.Testing)

Testing.Mount(plugin)       -- clone the source beside itself and open it in a test widget
Testing.Show("MainPage", 960, 420)   -- stage that element on a SurfaceGui the viewport can photograph, at an optional width and height
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

Export `ServerStorage.sequence` as `Sequence.rbxm` into the Studio plugins folder and reload plugins. Studio reads that folder at launch and on reload, not when the file changes.