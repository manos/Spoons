# PasteToPicker

Select a clipboard image in a native macOS file picker with one shortcut. Useful for attaching a screenshot where a website offers a file upload rather than image paste.

## Install and configure

Install `PasteToPicker.spoon` in `~/.hammerspoon/Spoons/`, then add:

```lua
hs.loadSpoon("PasteToPicker")
spoon.PasteToPicker:bindHotkeys({
  pasteImageToPicker = {{"ctrl", "alt", "cmd"}, "V"},
})
```

Copy an image, open the app's file picker, press Control–Option–Command–V, and release the keys. The Spoon saves a PNG, selects its path, and leaves the final Open/Upload action to you. Hammerspoon needs Accessibility permission.

Calling `spoon.PasteToPicker:bindHotkeys()` without a mapping uses this default. With SpoonInstall, use `hotkeys = "default"`. Explicit mappings remain supported.

It waits for modifier release and the native path field, verifies the typed filename, then confirms the path. It cancels on an app switch or timeout. The clipboard stays unchanged. Tested interactively in Safari; custom file pickers and Save dialogs are not supported.

## Privacy and temporary files

Images are written locally to `/tmp/clipboard-YYYYMMDD-HHMMSS.png`. The Spoon does not upload them, but clicking your app's Open/Upload button may do so. Files are not automatically removed by this Spoon; remove them when you no longer need them. Permissions follow the Hammerspoon process's file-creation defaults. Filenames have one-second precision, so repeated invocations within one second can reuse a filename.

`spoon.PasteToPicker.lastResult` contains progress, timing and path-match status, without image contents or filenames. No window-content dump shortcut is included in this distribution.

## Checks

```sh
lua tests/test.lua init.lua
```
