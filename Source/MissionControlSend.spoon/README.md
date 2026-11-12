# MissionControlSend

Open Mission Control with **Control–↑**, then **Shift-click a window thumbnail**
to send that window to **Desktop 2** on the same display. Release Shift after
clicking. The Spoon automates dragging the thumbnail to the desktop strip and
checks that the window actually moved. It is intended to leave Mission Control
open on the original desktop.

**Experimental: automated checks pass, but a physical Shift-click and window
move on the target Mac have not yet been verified.**

## Install

Place `MissionControlSend.spoon` in `~/.hammerspoon/Spoons/` and add:

```lua
hs.loadSpoon('MissionControlSend'):start()
```

To choose another destination, set it before starting:

```lua
hs.loadSpoon('MissionControlSend')
spoon.MissionControlSend.desktop = 2
spoon.MissionControlSend:start()
```

Desktop numbers mean ordinary desktops in their current Mission Control order
on the clicked window's display. Full-screen app spaces do not count. The target
desktop must already exist. This does not create desktops or change macOS's
setting for automatically reordering Spaces.

## Behavior

- Only Shift-clicks on identifiable window thumbnails in Mission Control are
  intercepted. Ordinary clicks, other modifier combinations, Stage Manager,
  the desktop strip, and App Exposé without a desktop strip remain native.
- Release Shift within a second of clicking. Shift-drag cancels the move.
- The cursor briefly visits the desktop strip and drags the thumbnail, then
  returns to the clicked position. Real mouse or keyboard input cancels work.
- Windows already on the target desktop stay there. Full-screen windows,
  windows assigned to multiple desktops, and ambiguous thumbnail matches are
  skipped. Matching prefers exposed window IDs and otherwise requires a unique
  app/title/source-desktop match. App and window names are never logged.
- Moves are checked against actual desktop membership. A failed move is reported
  without an automatic retry. Mission Control or desktop-layout changes abort
  the operation. Interrupting an in-progress drag may close Mission Control.
- `spoon.MissionControlSend:stop()` removes the click handler and cancels pending
  work. No menu-bar item, credentials, helper process, or external service is
  required. Hammerspoon needs Accessibility permission.

The Spoon supports the WindowManager accessibility layout used by recent macOS
versions and the older Dock layout. These interfaces are undocumented and can
change. `lastResult` exposes a status string for troubleshooting; it contains no
window titles or contents.

## Implementation notes

The macOS WindowManager layout and the need for a shared mouse-event number and
small drag steps were researched in
[PaperWM's Mission Control implementation](https://github.com/mogenson/PaperWM.spoon/blob/release/mission_control.lua)
and its [macOS 27 investigation](https://github.com/mogenson/PaperWM.spoon/issues/173).
This Spoon implements a separate click-driven workflow and does not require
PaperWM. It does not use `hs.spaces.moveWindowToSpace()` as proof of success:
that API can return success without moving a window on recent macOS.

## Checks

```sh
lua tests/test.lua init.lua
```

Tests use synthetic windows, desktop strips and mouse events. They cover
selection, hidden/ambiguous thumbnails, modifier release, cancellation,
destination verification, and failure without automatic retries. They do not
substitute for a live test on the installed macOS version.
