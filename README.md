# Spoons

Three keyboard-driven [Hammerspoon](https://www.hammerspoon.org/) plugins for Safari and native macOS file pickers. No extra menu-bar items by default.

- **[SafariTabGroups](Source/SafariTabGroups.spoon/README.md)** — press **⌃⌥⌘L**, type to filter Safari's tab groups, select with ↑/↓ and Enter. Escape dismisses. [Download](https://github.com/manos/Spoons/raw/main/Spoons/SafariTabGroups.spoon.zip).
- **[PersonalSafari](Source/PersonalSafari.spoon/README.md)** — select a Safari window with **⌃⌥⌘P**, then Shift-click links to send them there as background tabs, even across desktops. [Download](https://github.com/manos/Spoons/raw/main/Spoons/PersonalSafari.spoon.zip).
- **[PasteToPicker](Source/PasteToPicker.spoon/README.md)** — press **⌃⌥⌘V** in a native file picker to select an image from the clipboard. You control the final Open/Upload action. [Download](https://github.com/manos/Spoons/raw/main/Spoons/PasteToPicker.spoon.zip).

All shortcuts are configurable. macOS, Hammerspoon, and Accessibility permission are required. PersonalSafari also requires permission to control Safari. These are independently distributed Spoons, not part of the official Hammerspoon collection.

## Install

Download a ZIP above or from [Releases](https://github.com/manos/Spoons/releases), unzip it, then double-click the `.spoon` folder to install it with Hammerspoon. Add only the Spoons you want to your `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("SafariTabGroups")
spoon.SafariTabGroups:bindHotkeys({
  show = {{"ctrl", "alt", "cmd"}, "L"},
})

hs.loadSpoon("PersonalSafari")
spoon.PersonalSafari:bindHotkeys({
  selectWindow = {{"ctrl", "alt", "cmd"}, "P"},
}):start()

hs.loadSpoon("PasteToPicker")
spoon.PasteToPicker:bindHotkeys({
  pasteImageToPicker = {{"ctrl", "alt", "cmd"}, "V"},
})
```

See PersonalSafari's README for its one-time target-window selection and optional default-browser setup. To keep Hammerspoon out of the Dock and app switcher, add `hs.dockIcon(false)` to your own configuration; this affects Hammerspoon globally.

### SpoonInstall

If you already use [SpoonInstall](https://www.hammerspoon.org/Spoons/SpoonInstall.html), register this repository and install the desired Spoon:

```lua
hs.loadSpoon("SpoonInstall")
spoon.SpoonInstall.repos.manos = {
  url = "https://github.com/manos/Spoons",
  desc = "Safari and clipboard utilities",
  branch = "main",
}
spoon.SpoonInstall:andUse("SafariTabGroups", {
  repo = "manos",
  hotkeys = {show = {{"ctrl", "alt", "cmd"}, "L"}},
})
```

Use either manual setup or SpoonInstall for a given Spoon. SpoonInstall's `andUse` installs missing packages; it is not an automatic updater for already installed versions.

## Privacy

This repository contains reusable source, synthetic tests, documentation, and installable archives. It does not include personal Hammerspoon configuration, settings, browser profiles, browsing history, clipboard images, diagnostic captures, or credentials.

The Spoons contain no analytics or telemetry. PersonalSafari reads clicked link addresses to open them in Safari and stores the selected window/process identity and previous browser handler in local Hammerspoon settings. SafariTabGroups reads group names from Safari's native menu while the chooser is in use. PasteToPicker writes the clipboard image to a local temporary PNG and leaves final submission to the user; see its README for retention and file-permission details. Opening a web link or submitting a file through the destination application has that application's normal network behavior.

## Development

Sources live under `Source/`, installable ZIPs under `Spoons/`, and the SpoonInstall index at `docs/docs.json`.

Run all Lua checks (Lua 5.3 or newer):

```sh
./scripts/check.sh
```

Rebuild ZIPs and catalog using Python 3's standard library:

```sh
python3 -m venv .venv
.venv/bin/python scripts/package.py
```

Archives use an explicit file allowlist and fixed timestamps. They omit macOS extended attributes and other local metadata. Tests use synthetic data and do not control real applications. All three utilities have also been exercised interactively in Safari; Accessibility identifiers can change between macOS/Safari versions.

MIT licensed. See [LICENSE](LICENSE).
