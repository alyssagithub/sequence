# Sequence

An animation plugin for Roblox Studio.

## Layout

```
plugin/sequence/
  Plugin.legacy.luau     bootstrap: loads settings, mounts the app, tears it down on unload
  Config.luau            name, version, widget id, toolbar icon
  Settings.luau          plugin settings as vide sources, saved through plugin:SetSetting
  Format.luau            timecode and degree formatting
  Editor/
    Session.luau         every piece of editor state as vide sources: the loaded rigs, the active clip,
                         undo, playback, selection, pins, auto key, scratch poses, property tracks
    Clip.luau            the animation data: tracks of keys per joint or per property, markers, length
    Rig.luau             scans a model for Motor6D or AnimationConstraint joints, anchors it, writes poses
    Pose.luau            samples a clip at a time, blends any value type, mirrors a pose
    Easing.luau          every easing style, the five Roblox keeps measured against a playtest
    Ik.luau              cyclic coordinate descent for pinned parts
    Saver/               clip to KeyframeSequence or CurveAnimation and back, three save locations,
                         publish, import by asset id, the emote export with Roblox's R15 rig data
    Emote.luau           the Marketplace emote rules, numbers taken from Studio's own validator
    Gizmo/               ArcHandles and Handles on the selected joint
    PoseTool.luau        click a part in the viewport and drag to pose it
    OnionSkin/           ghost copies of the rig at the previous and next keyframe
    Reference.luau       images, image sequences and videos loaded as references
    Playtest/            the reel driven runner that plays the clip on your character without uploading
    Bake.luau            frozen posed copies of the rig
    Inserter/            character builder behind the insert window: any account with a body override, plus the bundled dummies
    ClipSchema.luau      typed schema used when reading an animation back in
    EmoteRigData.fragment.xml   an AnimationRigData for R15, taken from a published emote; plugins cannot build one
  App/
    App.luau             creates the widget and toolbar, starts the editor, mounts the page tree
    Widget.luau          the dock widget, bottom docked
    Toolbar.luau         the toolbar button
    Theme.luau           colours bound to Studio's own theme, repaints on theme change
    Overlay.luau         the popup layer that menus and dropdowns open into
    Hotkeys.luau         keyboard shortcuts while the widget has the mouse
    Components/          Button, IconButton, Icon, Toggle, Dropdown, NumberField, TextField
    Pages/               Main, Header, Timeline, CurveView, Inspector, ReferencePanel, EmotePanel, InsertWindow
  Packages/
    vide, sift, typed, reel, lucide-icons, scythe, vow, testez   thin modules that require into _Index, the layout Loom writes
    _Index/                                 one folder per package at its pinned version, vendor code, never edited
  Tests/                 TestEZ specs for the pure modules: Clip, Easing, Pose, the Saver round trips
  Testing/               the harness below
tools/build_rbxmx.py     builds plugin/ into an rbxmx that the Studio bridge can load, without Rojo
```

## What it does

With nothing loaded, selecting a jointed model asks whether to animate it. After that the + button
adds whatever rigs are selected, so you can move models around without keying them. The Insert button opens a window with a live
preview you can turn, an Account tab that builds any player by name or id (yours when empty) as their
Original body or on an R6 or R15 rig, and Presets: the R6, R15, TemplateR6 and TemplateR15 dummies,
shipped inside the plugin. Every Motor6D or AnimationConstraint joint becomes a track,
grouped under its rig. Move a part with Studio's own Move and Rotate tools, with the gizmo on the
selected joint, or with the pose tool that lets you click and drag parts straight in the viewport,
and a keyframe lands at the playhead. Turn auto key off to pose freely and press K to keep it.

Pin a hand or a foot and its parents move around it: the chain between the moved joint and the pin is
re-solved every edit so the pinned part stays where it was. Mirror swaps a pose left to right.
Any property of any selected object can be a track as well, so a door's light or a part's colour
animates alongside the rig, previewed live and saved next to the clip.

Keys carry an easing style and direction. Linear, Constant, Cubic, Elastic and Bounce preview
exactly as the engine plays them. Sine, Quad, Quart, Quint, Expo, Circ, Back and Smooth are the
Blender styles; they preview in the editor and are baked into per frame keys on save so the file
plays back the same. The curve view shows the selected joint's position and rotation channels as
editable curves. Box select in the sheet, scale a selection with the span field, copy, paste,
duplicate and reverse.

Save writes a KeyframeSequence or a CurveAnimation to the rig's AnimSaves, to ServerStorage.AnimSaves
the way Roblox's editor does, or to ServerStorage.MoonAnimatorExport, where Moon Animator's Export All puts its files. Open lists all three. Any saved
animation can be converted between keyframes and curves in place. Publish saves then opens Studio's
upload window, and an asset id can be imported through the name box.

The reference panel loads images from disk through EditableImage and videos from disk or by asset id
without uploading anything, playing video in step with the playhead, and can put the same picture on a
board beside the rig. The emote panel checks the clip against the Marketplace emote validator's rules
and previews the thumbnail on the Rthro mannequin Roblox renders it with. The playtest button writes a
reel driven runner into the place so the clip plays on your own character when you press Play, no
upload needed. Bake writes frozen posed copies of the rig for scenery that never plays.

Snap has three modes in the menu: off, frames, or keyframes and events with frames as the fallback.

Keys: Space plays, K keys the selected joint or every joint, P pins the selected joint, Shift+M
mirrors, Tab flips between the sheet and the curves, Delete removes selected keys, Left and Right
step a frame (Shift for five), Home and End jump, R and T switch the gizmo, Ctrl+Z, Ctrl+Y, Ctrl+C,
Ctrl+V, Ctrl+D and Ctrl+A do what they say, Escape clears the selection or leaves the pose tool.
Ctrl+wheel over the timeline zooms, Shift+wheel pans, right click opens the menus.

## Testing harness

`Testing` mounts a copy of the plugin from the current source without reinstalling, so a change can be looked at in seconds.

```lua
const Testing = require(game:GetService("ServerStorage").Sequence.Testing)

Testing.Mount(plugin)       -- clone the source beside itself and open it in a test widget
Testing.Show("MainPage", 960, 420)   -- stage a clone of that element on a SurfaceGui the viewport can photograph, at an optional width and height
Testing.Show("MainPage", 960, 420, true)   -- stage a live mount instead, for anything that lays itself out from its own size
```

The stage is for layout at a size of your choosing. The viewport runs it through Roblox's tone curve, so
colours come out darker than they are; when colour matters, capture the Studio window through the
Claudio bridge (`capture` with `of: window`, cropped to the dock with x, y, width and height), which
shows the widget as the user sees it and can save the PNG to a file.

```lua
Testing.Hide()              -- clear the stage and put the camera back
Testing.Paint("Light")      -- repaint the mount as the other theme without changing Studio
Testing.Colours()           -- every colour drawn, counted, so hardcoded ones stand out
Testing.With({TextSize = 10}, function() end)
Testing.Leftovers()         -- anything the mount left in the place
Testing.RunTests()          -- run every spec under Tests against the mounted copy
Testing.Unmount()
```

A dock widget cannot be captured from the viewport, which is why `Show` exists. Restore the camera in the same call as every screenshot, and `Unmount` before installing for real.

The mount destroys the bootstrap script, so anything that only the installed plugin does has to be verified on a real install, not on the mount.

## Installing for real

Export `ServerStorage.sequence` as `Sequence.rbxm` into the Studio plugins folder and reload plugins. Studio reads that folder at launch and on reload, not when the file changes.