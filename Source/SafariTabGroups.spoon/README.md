# SafariTabGroups

A searchable keyboard switcher for the tab groups available in the current Safari window. Uses Safari's own Tab Group picker through macOS Accessibility, so it follows the window's profile and does not read Safari databases or page content.

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
