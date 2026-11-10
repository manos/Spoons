# SafariTabGroups

Jump between Safari tab groups without opening the sidebar or scanning a menu. Useful when you keep separate groups for projects, research, shopping, or travel and want to switch by name.

For example, press **⌃⌥⌘L**, type `trav`, and hit **Enter** to switch the current window to your Travel group. Use **↑/↓** to choose between matches and **Escape** to dismiss. The chooser includes the window's ungrouped tabs and marks the active group.

It searches group names rather than individual tabs. It uses Safari's own Tab Group picker through Accessibility, follows the current window's profile, and does not read Safari databases or page content.

## Installation

Place this folder at `~/.hammerspoon/Spoons/SafariTabGroups.spoon/`, then add to your Hammerspoon configuration:

```lua
hs.loadSpoon('SafariTabGroups')
spoon.SafariTabGroups:bindHotkeys({
  show = {{'ctrl', 'alt', 'cmd'}, 'L'},
})
```

With Safari focused, press Control–Option–Command–L. Type to filter, use Up/Down to select, and press Return to switch. Escape dismisses the chooser. The list includes the window's ungrouped tabs and marks the current group.

The shortcut does nothing outside Safari. No menu-bar item or Dock icon is added. Safari's native group menu briefly opens while its entries are read and when a selection is applied; the sidebar need not be opened. The original window must still be focused when the selection is applied. Names are read fresh on each invocation, and commands that create groups are excluded.

Requires Hammerspoon Accessibility permission and Safari's `TabGroupPickerButton`/`TabGroupPickerMenu` Accessibility controls. Tested against the locally installed Safari; these undocumented identifiers may change in later Safari versions.

## Checks

```sh
lua tests/test.lua ./init.lua
luac -p init.lua
```

`spoon.SafariTabGroups.lastResult` reports progress without recording group names or page addresses.
