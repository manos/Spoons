# PersonalSafari

Keep personal browsing in its own window while you work elsewhere. When a link arrives in a chat or appears in your work browser, **Shift-click** it to add a background tab to your chosen Safari window—even on another desktop—without switching away from what you are doing.

For example, select a personal Safari window once with **⌃⌥⌘P**. Later, Shift-click a recipe or travel link from your work desktop. It waits in the personal window for you to read later. Ordinary clicks continue to use normal routing.

## First use

1. Focus the Safari window where you want personal links to open and press **Control–Option–Command–P**. A confirmation appears.
2. Open Hammerspoon's Console from its existing menu-bar icon, run `spoon.PersonalSafari:makeDefaultBrowser()`, and accept macOS's request to use Hammerspoon for web links.
3. Return to your other window or desktop and **Shift-click a link**. The new tab opens in your selected window without activating it. Ordinary clicks continue to open in Safari normally.

Allow Hammerspoon to control Safari if macOS asks. Accessibility access is also required; enable it in **System Settings → Privacy & Security → Accessibility**.

## Installation

Copy `PersonalSafari.spoon` into `~/.hammerspoon/Spoons/`, then add this to `~/.hammerspoon/init.lua` and reload Hammerspoon:

```lua
-- Keep Hammerspoon out of the Dock and the macOS app switcher.
hs.dockIcon(false)

hs.loadSpoon("PersonalSafari")
spoon.PersonalSafari:bindHotkeys({
  selectWindow = {{"ctrl", "alt", "cmd"}, "P"},
}):start()
```

The Spoon adds no menu-bar item and does not change the default browser just by loading. Run `spoon.PersonalSafari:makeDefaultBrowser()` once in the Hammerspoon console. Ordinary URLs explicitly open in Safari, avoiding a routing loop. An existing Hammerspoon URL callback, if present, receives ordinary URLs instead.

External links can activate their default handler. `hs.dockIcon(false)` runs Hammerspoon as a background utility so it does not become an app-switcher entry when handling links. Its existing menu-bar icon still provides access to the Console. If you want the Spoon's optional setup menu, set `spoon.PersonalSafari.showMenu = true` before `:start()`.

## How it behaves

- For accessible web links, it intercepts Shift-click directly in Safari and other apps. Safari's usual Shift-click action (adding a link to Reading List) is replaced for those links.
- Apps that do not expose their links can still send them through Hammerspoon as the default browser. The Spoon remembers the click for 1.5 seconds, including when Shift is released before the URL arrives. When the app supplies its sender identity, it must match the clicked app.
- Command-Shift-click, Option-click, non-web links, and plain text clicks retain their native behavior. On links Safari does not expose to Accessibility, Shift-click retains Safari's Reading List behavior.
- The chosen window survives Hammerspoon config reloads. After closing that window or restarting Safari, select your personal window again. A failed personal link shows an alert and never opens in a different window; click it again after selecting the correct window.
- Hammerspoon must be running. Apps that delay opening links beyond the gesture timeout, or forward links through another process, may use ordinary routing instead.
- No Safari extension or “Allow JavaScript from Apple Events” setting is required. The Spoon does not save or log the URLs you click.

To use another modifier, set `spoon.PersonalSafari.modifier = "alt"` before `:start()`. Supported modifier names are `shift`, `alt`, `ctrl`, `cmd`, and `fn`; only that modifier alone triggers personal routing.

## Disable or remove

Before removing the Spoon, run this in Hammerspoon's Console:

```lua
spoon.PersonalSafari:restoreDefaultBrowser():stop()
```

Then remove its startup lines and reload Hammerspoon. `:stop()` stops click interception; if Hammerspoon is still the default browser, a simple Safari forwarding callback keeps ordinary links working until you restore the browser.

## Validation

The included tests cover ordinary routing, released modifiers, stale and unrelated clicks, nested links, plain text, other modifier combinations, dragging, missing targets, script escaping, and callback ownership. Run them from this directory:

```sh
lua tests/test.lua init.lua
```

Validated with a real Safari Shift-click: Safari's structured Accessibility URL was recognized, the native click was suppressed, and a background tab was created in the selected window. Regression tests cover both structured and plain-text Accessibility URLs.

API references: [Hammerspoon URL events](https://www.hammerspoon.org/docs/hs.urlevent.html), [input events](https://www.hammerspoon.org/docs/hs.eventtap.html), [Accessibility elements](https://www.hammerspoon.org/docs/hs.axuielement.html), and [Safari's native shortcuts](https://support.apple.com/guide/safari/keyboard-shortcuts-and-gestures-cpsh003/mac).
