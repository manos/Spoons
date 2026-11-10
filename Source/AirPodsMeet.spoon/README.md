# AirPodsMeet

You're walking around during a Google Meet call in Safari and want to mute or
unmute without returning to the keyboard. Safari rejects the AirPods microphone
control; this Spoon detects that rejected request and presses Meet's microphone
button through macOS Accessibility, even when Safari is behind another app.

Keep the active call in Safari's selected tab. Press the normal AirPods mute
control once. After confirming that the button changed state, the Spoon says
“Muted” or “Unmuted” using bundled ElevenLabs Lily voice clips at 95% speed.
macOS's rejection sound/banner still occurs: this bridge reacts after that rejection and does not
suppress it.

The Spoon ignores requests from other attributed apps, pages outside Meet,
prejoin screens, and ambiguous call controls. It does not activate Safari or
switch tabs. If the call is in a background tab, bring that tab to the front
before walking away. Multiple simultaneous calls are not supported.

## Setup

Drop `AirPodsMeet.spoon` into `~/.hammerspoon/Spoons/` (or double-click the Spoon
folder), then add this to your Hammerspoon configuration and reload:

```lua
hs.loadSpoon('AirPodsMeet'):start()
```

Set `spoon.AirPodsMeet.speakStatus = false` to disable spoken feedback.
Set `spoon.AirPodsMeet.soundVolume = 0.5` to make the announcements quieter
(range 0–1; default 0.8). The WAV files live in `sounds/` and can be replaced with
your own recordings using the same filenames. Missing or unplayable clips fall
back to the macOS speech voice.

Announcements wait 0.6 seconds after Meet confirms the new state, leaving room
for the macOS rejection tones. Adjust `spoon.AirPodsMeet.announcementDelay` (in
seconds) if needed. A new gesture or stopping the Spoon cancels any queued
announcement so it cannot speak an outdated state.

No separate app, compiler, voice download, browser extension, or microphone
permission is required. Hammerspoon needs Accessibility permission. The package
contains the two audio clips; no ElevenLabs API key or internet connection is
needed for playback. See [voice provenance](sounds/README.md).

The bundled clips are for noncommercial use with attribution under
[ElevenLabs' audio terms](sounds/LICENSE.txt); the code is MIT licensed.
Remove or replace the WAV files for uses their terms do not cover.

Run `spoon.AirPodsMeet:stop()` to disable the listener.

## Privacy and limits

A filtered `log stream` process listens only for the AirPods mute-request,
rejection and app-attribution messages. No audio is captured. No logs or page
contents are saved. Safari Accessibility is inspected only in response to a
matching gesture. No browser extension, JavaScript permission, or menu-bar
item is added.

This uses undocumented macOS log messages and English
Meet Accessibility labels. OS or Meet changes may break detection. A button
label change confirms the displayed mute state, not what another participant
hears. Mute and unmute have been verified in an empty Safari Meet call,
including while Safari is in the background.

`spoon.AirPodsMeet.lastResult` exposes only detection/control status, without
meeting addresses or participant names. The listener stops on Hammerspoon
shutdown/reload. If it exits unexpectedly, an alert asks you to reload.

## Checks

```sh
lua tests/test.lua init.lua
```
