# KSheet

You know an app has a keyboard shortcut for a command, but cannot remember it.
Press **⌃⌥⌘K** to see the current app's menu shortcuts together in one sheet,
organized by menu. Press **Escape**, or the shortcut again, to close it.

This is a fork of [ashfinal's KSheet in Hammerspoon/Spoons](https://github.com/Hammerspoon/Spoons/tree/master/Source/KSheet.spoon),
with the original cheatsheet layout credited to [Dharma Poudel](https://github.com/dharmapoudel).
Our version adds Escape dismissal, replaces the external layout script with
local CSS, and treats app and menu labels as text when rendering them.

## Install

Install `KSheet.spoon` into `~/.hammerspoon/Spoons/`, then add this to your
`~/.hammerspoon/init.lua` and reload Hammerspoon:

```lua
hs.loadSpoon("KSheet")
spoon.KSheet:bindHotkeys({
  toggle = {{"ctrl", "alt", "cmd"}, "K"},
})
```

KSheet needs Hammerspoon's Accessibility permission to read app menus. It does
not require credentials, a server, or an internet connection. Installing this
fork replaces any other KSheet in the same Spoons folder; load only one version.

## What it shows

Focus the app you want to inspect before opening the sheet. KSheet reads that
app's native menu shortcuts when the sheet opens. It does not list every hidden
app shortcut, website shortcut, or other Hammerspoon binding. Menus with no
shortcuts may appear as empty headings.

Escape is bound only while the sheet is open. The `show`, `hide`, and `toggle`
actions can also be bound separately or called from the Hammerspoon Console.

## Privacy

App and menu names are rendered locally in Hammerspoon's webview. This fork does
not load external scripts, fonts, or styles, and does not save menu contents or
send them to a server. The attribution link opens its website only if clicked.
The package contains no personal Hammerspoon configuration or captured menus.

## Provenance and license

Based on the upstream KSheet 1.0 source at commit
[`b3e9ff3385b96fbdc379dc2645a36bbd31a5a2e5`](https://github.com/Hammerspoon/Spoons/blob/b3e9ff3385b96fbdc379dc2645a36bbd31a5a2e5/Source/KSheet.spoon/init.lua).
The upstream source declares an MIT license and credits ashfinal; the HTML
layout credits Dharma Poudel. These credits are retained. This fork is maintained
in [manos/Spoons](https://github.com/manos/Spoons) and is not an official
Hammerspoon release. See [LICENSE](LICENSE).

## Checks

```sh
lua tests/test.lua init.lua
```

Tests use synthetic app menus and check opening, toggling, Escape dismissal,
text escaping, and the absence of remote layout scripts.
