# Spoons

Small [Hammerspoon](https://www.hammerspoon.org/) tools for Safari and everyday macOS tasks.

- **[AirPodsMeet](#airpodsmeet--mute-meet-without-reaching-for-your-mac)** — Mute or unmute a Safari Google Meet call with your AirPods, with spoken confirmation.
- **[PasteToPicker](#pastetopicker--attach-a-screenshot-without-saving-it-yourself)** — Attach a clipboard image through a file picker with **⌃⌥⌘V**.
- **[PersonalSafari](#personalsafari--keep-personal-links-in-your-personal-window)** — **Shift-click** links into your chosen personal Safari window, even on another desktop.
- **[SafariTabGroups](#safaritabgroups--jump-to-a-group-by-typing-its-name)** — Search and switch Safari tab groups with **⌃⌥⌘L**.

## AirPodsMeet — mute Meet without reaching for your Mac

You're walking around during a Google Meet call in Safari and want to mute or unmute from your AirPods. Safari rejects that control, so AirPodsMeet detects the rejected request and presses Meet's microphone button for you, even while Safari is behind another app.

Keep the call in Safari's selected tab and press the normal AirPods mute control. Once Meet confirms the change, a bundled Lily voice clip says **“Muted”** or **“Unmuted.”** The clips play at 95% speed after a configurable 0.6-second pause. No ElevenLabs account, API key, or voice download is needed to use the Spoon.

The macOS rejection tones still play; this Spoon reacts after the rejection. Detection relies on macOS log messages and English Meet controls, and requires the call to remain in the selected Safari tab.

**Control:** AirPods mute gesture · [Download](https://github.com/manos/Spoons/raw/main/Spoons/AirPodsMeet.spoon.zip) · [Setup and details](Source/AirPodsMeet.spoon/README.md)

## PasteToPicker — attach a screenshot without saving it yourself

You have an image on the clipboard, but a website only offers **Choose File**. Normally you would save the image, find it in the upload dialog, and click Open. PasteToPicker handles those steps from the keyboard.

For example, copy a screenshot with **Control–Shift–Command–4**, click a website's upload button, then press **⌃⌥⌘V** in the native file picker and release the keys. The Spoon saves a temporary PNG, enters its path, and presses the picker's Open/Upload button. The dialog closes and the image is handed to the app.

It works with clipboard images and native macOS Open dialogs, including Safari upload pickers. It does not paste text or operate custom website file choosers. Accepting the picker may start an upload immediately; a separate Send or Publish button in the app remains yours to press.

**Shortcut:** ⌃⌥⌘V · [Download](https://github.com/manos/Spoons/raw/main/Spoons/PasteToPicker.spoon.zip) · [Setup and details](Source/PasteToPicker.spoon/README.md)

## PersonalSafari — keep personal links in your personal window

You keep work and personal browsing in separate Safari windows, perhaps on different desktops. A personal link arrives in a chat or appears while you're browsing for work, and opening it normally puts it in the wrong window.

Focus the Safari window you want to use for personal browsing and press **⌃⌥⌘P** once. Then **Shift-click a link** to add it as a background tab in that window. Your current window and desktop stay in place, so you can read the link later without interrupting what you're doing.

Accessible links can be intercepted directly in Safari and other apps. The optional default-browser setup also handles external links from apps that do not expose them to Accessibility. Ordinary clicks keep their normal routing. Select the destination again after closing it or restarting Safari.

**Choose destination:** ⌃⌥⌘P · **Send a link:** Shift-click · [Download](https://github.com/manos/Spoons/raw/main/Spoons/PersonalSafari.spoon.zip) · [Setup and details](Source/PersonalSafari.spoon/README.md)

## SafariTabGroups — jump to a group by typing its name

You organize Safari into groups such as Research, Shopping, and Travel, but switching means opening the sidebar or hunting through a menu. SafariTabGroups puts those group names in a searchable keyboard chooser.

While in Safari, press **⌃⌥⌘L**, type part of a group name, and press **Enter**. Use **↑/↓** to move through matches or **Escape** to cancel. The selected group opens in the window where you invoked the shortcut.

The list follows that window's available groups and profile, includes its ungrouped tabs, and marks the current group. It searches group names, not individual tab titles or browsing history.

**Shortcut:** ⌃⌥⌘L · [Download](https://github.com/manos/Spoons/raw/main/Spoons/SafariTabGroups.spoon.zip) · [Setup and details](Source/SafariTabGroups.spoon/README.md)

## Requirements

macOS, Hammerspoon, and Accessibility permission are required. PersonalSafari also requires permission to control Safari. These are independently distributed Spoons, not part of the official Hammerspoon collection.

## Install

Download a ZIP above or from [Releases](https://github.com/manos/Spoons/releases), unzip it, then double-click the `.spoon` folder to install it with Hammerspoon. Add only the Spoons you want to your `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon("AirPodsMeet"):start()

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

The Spoons contain no analytics or telemetry. PersonalSafari reads clicked link addresses to open them in Safari and stores the selected window/process identity and previous browser handler in local Hammerspoon settings. SafariTabGroups reads group names from Safari's native menu while the chooser is in use. PasteToPicker writes the clipboard image to a local temporary PNG and automatically accepts the file picker, which may start an upload through the destination app; see its README for retention and file-permission details. Opening a web link or submitting a file through the destination application has that application's normal network behavior.

AirPodsMeet listens to a narrowly filtered local system-log stream and inspects Safari's accessible call controls after a matching gesture. It does not capture microphone audio or save logs, meeting addresses, or page contents. Its two bundled voice clips were synthesized from the fixed words “Muted” and “Unmuted”; playback is entirely local.

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

Archives use an explicit file allowlist and fixed timestamps. They omit macOS extended attributes and other local metadata. Tests use synthetic data and do not control real applications. Accessibility identifiers can change between macOS/Safari versions; automated checks do not replace testing in a real native picker or Safari window.

Code and documentation are MIT licensed. AirPodsMeet's bundled Lily clips were generated on ElevenLabs' free plan and are for noncommercial use with attribution; see the [audio terms](Source/AirPodsMeet.spoon/sounds/LICENSE.txt). Replace or remove those clips for uses their terms do not cover; missing clips fall back to the system voice.
