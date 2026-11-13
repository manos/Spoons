# MissionControlSend

Open Mission Control with **Control–↑**, then **Shift-click a window thumbnail**
to send that window to the **next desktop** on the same display, wrapping from
the last desktop to the first. Release Shift after
clicking. The Spoon automates dragging the thumbnail to the desktop strip and
checks that the window actually moved. It is intended to leave Mission Control
open on the original desktop.

**Experimental:** physical Shift-click and next-desktop movement have been
confirmed on macOS 27.2.1. Accessibility layouts can vary across macOS versions
and applications; ambiguous windows are deliberately skipped.

## Install

Place `MissionControlSend.spoon` in `~/.hammerspoon/Spoons/` and add:

```lua
hs.loadSpoon('MissionControlSend'):start()
```

To always use a fixed destination instead, set it before starting:

```lua
hs.loadSpoon('MissionControlSend')
spoon.MissionControlSend.desktop = 2
spoon.MissionControlSend:start()
```

The default (`desktop = nil`) chooses the next ordinary desktop. Explicit
desktop numbers mean ordinary desktops in their current Mission Control order
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
  skipped. Matching prefers exposed window IDs, then a single eligible window
  from the identified app on the source desktop. If that app has several
  eligible windows, a unique title match is required. App and window names are
  never logged.
- If macOS reports a hidden thumbnail from another desktop under the pointer,
  the Spoon uses the sole visible thumbnail at that position on the active
  desktop. Overlapping or ambiguous visible thumbnails are still skipped.
- Desktop-thumbnail animation is followed without changing the destination's
  identity. A change to the actual desktop order still cancels the drag.
- Moves are checked against actual desktop membership. A failed move is reported
  without an automatic retry. Mission Control or desktop-layout changes abort
  the operation. Interrupting an in-progress drag may close Mission Control.
- `spoon.MissionControlSend:stop()` removes the click handler and cancels pending
  work. No menu-bar item, credentials, helper process, or external service is
  required. Hammerspoon needs Accessibility permission.

The Spoon supports the WindowManager accessibility layout used by recent macOS
versions and the older Dock layout. These interfaces are undocumented and can
change. `lastResult` and `lastCaptureReason` expose status strings for
troubleshooting; they contain no window titles or contents. `lastError` keeps
the most recent Lua error in memory, without writing a log file.

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
