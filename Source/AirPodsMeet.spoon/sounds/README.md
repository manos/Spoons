# Lily voice clips — elevenlabs.io

`muted.wav` and `unmuted.wav` use ElevenLabs' **Lily — Velvety Actress** voice.
Both clips are bundled and play locally. Installing or using the Spoon requires
no ElevenLabs account, API key, voice download, or network request.

Generation details:

- Text: `Muted. Unmuted.`, synthesized together and split into two clips using word timing.
- Voice: Lily (`pFZP5JQG7iQjIQuC4Bku`)
- Model: `eleven_multilingual_v2`
- Speed: 0.95; stability: 0.8; similarity: 0.75; style: 0; speaker boost: on; seed: 42.
- Source: MP3 at 44,100 Hz / 128 kbps, decoded to 16-bit PCM WAV.

Only these two text phrases were sent for synthesis. The files contain no
user microphone recording, personal information, or embedded credential. The
voice model and generation tools are not part of the Spoon.

These clips were generated on ElevenLabs' free plan. They are supplied for
noncommercial use with attribution, separately from the code's MIT license.
See [audio terms](LICENSE.txt). Clip titles are **Muted — elevenlabs.io** and
**Unmuted — elevenlabs.io**; retain attribution when sharing them.

To customize the announcements, replace the WAV files while keeping their
names. The Spoon reads them each time it announces a confirmed microphone
state. `spoon.AirPodsMeet.soundVolume` controls playback volume (0–1, default 0.8).
`spoon.AirPodsMeet.announcementDelay` controls the pause after confirmation
(default 0.6 seconds).
