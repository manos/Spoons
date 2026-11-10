# PasteToPicker

Attach a clipboard image when a website offers **Choose File** but does not accept image paste. Instead of saving a screenshot, browsing to it, and clicking Open, use one shortcut inside the native file picker.

For example: copy a screenshot with **Control–Shift–Command–4**, open an attachment picker, then press **⌃⌥⌘V**. PasteToPicker creates a temporary PNG, selects it, presses Open/Upload, and waits for the picker to close. The app receives the image; any separate Send or Publish button remains yours to press.

## Install and configure

Install `PasteToPicker.spoon` in `~/.hammerspoon/Spoons/`, then add:

```lua
hs.loadSpoon("PasteToPicker")
spoon.PasteToPicker:bindHotkeys({
  pasteImageToPicker = {{"ctrl", "alt", "cmd"}, "V"},
})
```

Copy an image, open the app's file picker, press Control–Option–Command–V, and release the keys. The Spoon saves a PNG, selects its path, and automatically presses the picker’s Open/Upload button. Hammerspoon needs Accessibility permission.

Calling `spoon.PasteToPicker:bindHotkeys()` without a mapping uses this default. With SpoonInstall, use `hotkeys = "default"`. Explicit mappings remain supported.

It waits for modifier release and the native path field, verifies the typed filename, then confirms the path and presses the enabled Open/Upload button once. It waits for the picker to close and cancels on an app switch or timeout. The clipboard stays unchanged. Designed for native Open dialogs, including Safari upload pickers; custom file pickers and Save dialogs are not supported.

## Privacy and temporary files

Images are written locally to `/tmp/clipboard-YYYYMMDD-HHMMSS.png`. The shortcut automatically accepts the picker, so the destination app may immediately upload the image. The Spoon itself makes no network requests. Files are not automatically removed by this Spoon; remove them when you no longer need them. Permissions follow the Hammerspoon process's file-creation defaults. Filenames have one-second precision, so repeated invocations within one second can reuse a filename.

`spoon.PasteToPicker.lastResult` contains progress, timing and path-match status, without image contents or filenames. A `submitted` result means the picker closed after its Open/Upload button was pressed; it does not verify a network upload or send a message. No window-content dump shortcut is included in this distribution.

## Checks

```sh
lua tests/test.lua init.lua
```
