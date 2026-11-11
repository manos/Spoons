# TorrentToQbit

Download a `.torrent` file in your browser, choose where it belongs, and let
qBittorrent handle the download on your server. A searchable category chooser
appears once the file is complete. Type to filter, use the arrow keys, and press
Enter to add it. Escape cancels that file.

Categories are read from your server each time, including an Uncategorized
option. The chosen category is sent with the torrent; save locations and
download management follow your qBittorrent settings. The local `.torrent`
file stays in Downloads.

## Install

Put `TorrentToQbit.spoon` in `~/.hammerspoon/Spoons/` and create a separate
`~/.hammerspoon/torrent-to-qbit.json` using your own server and Web UI login:

```json
{
  "baseURL": "https://qbittorrent.example.test",
  "username": "your-web-ui-username",
  "password": "your-web-ui-password"
}
```

Keep this file private and outside the Spoon folder and any published repository.
Restrict its permissions with `chmod 600 ~/.hammerspoon/torrent-to-qbit.json`.
Then add this to `~/.hammerspoon/init.lua`:

```lua
hs.loadSpoon('TorrentToQbit'):start()
```

Reload Hammerspoon. No extra software is required. The server must be reachable
from your Mac, including any VPN or Tailscale connection it requires.

## Configuration

`baseURL` is the HTTPS origin of your qBittorrent Web UI. This Spoon uses the
Web UI username/password login, including the current qBittorrent 5.2 session
cookie and older `SID` sessions. It does not need an API key. If the server
already permits unauthenticated requests, omit both login fields.

Optional JSON settings:

- `watchDirectory`: absolute folder path; defaults to your Downloads folder.
- `addStopped`: set to `true` to add torrents in the stopped state. Omit it to
  use the server's default behavior.

For a different config location, call `:start('/absolute/path/to/config.json')`.
Run `spoon.TorrentToQbit:stop()` to stop watching. To retry a retained file,
run `spoon.TorrentToQbit:addFile('/absolute/path/to/file.torrent')` in the
Hammerspoon Console. A rejected login is not attempted repeatedly; correct the
private config and reload Hammerspoon before retrying.

## Behavior and privacy

- Watches only new or changed `.torrent` files directly in the chosen folder.
  Files already present when the Spoon starts are ignored. Magnet links and
  nested folders are not watched.
- Waits for the file to stop changing and checks its torrent metadata before
  prompting. Symlinks and files larger than 16 MiB are skipped.
- Keeps downloads in a queue so several files get separate category choices.
- Checks whether the torrent already exists before uploading. Successful
  torrent hashes are remembered locally for seven days, up to 2,000 entries.
- Verifies the torrent appears in qBittorrent after upload. An uncertain network
  result triggers a read-only check, never an automatic resend.
- Stores no credentials in the Spoon, logs, or processed-torrent history.
  The private JSON file contains your login; session cookies stay in memory.
  Torrent metadata is sent only to your configured server over HTTPS, with
  redirects disabled. The Spoon does not read other download file contents.
- Stopping or reloading dismisses pending choices and ignores late callbacks.

Source and packaging contain no personal server addresses, credentials,
category names, torrent files, or local configuration.

## Checks

```sh
lua tests/test.lua init.lua
```

The tests use synthetic metadata and an isolated API fixture; they do not
add torrents to a real server.
