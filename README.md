# Omaclippr

A passive instant-replay clip buffer for the Omarchy Quattro bar. It captures
your screen to a **RAM-only ring buffer** and saves the last few moments as a
clip on demand — exactly like Medal.tv's clipping, but without persistent
recording or touching your SSD until you ask for it.

- 🟢 Status pill in the bar — a dot that colours when the buffer is live
- ⏱ 30s / 60s / 120s replay windows
- 🎛 Three quality presets (Low / Balanced / High)
- 🖥 Pick your screen, microphone, and system-audio sources
- 🎬 Clip Now saves the rolling buffer instantly (no re-encode)
- 🗂 Recent-clips shelf with play, edit (Omacut), folder, copy-path, and delete

## How it works

Omaclippr drives `gpu-screen-recorder` in its native instant-replay mode:
`-replay-storage ram` keeps the last N seconds in memory only, and saving a
clip is a fast stream-copy mux from that in-memory ring — no disk writes while
idle, no re-encoding on save.

## Install

```sh
omarchy plugin add https://github.com/Dooooooks/omaclippr.git --enable
```

## Usage

| Action | What it does |
| --- | --- |
| **Left-click** the dot | Toggle the details panel |
| **Middle-click** the dot | Start / stop the buffer directly |
| **Clip Now** (in panel) | Save the active rolling buffer |
| **Edit** (clip row) | Open the clip in Omacut |

### Global hotkey

The clip trigger is a plain CLI, so you can bind it in Hyprland (or any WM)
independently of the panel:

```ini
# ~/.config/hypr/bindings.lua — save the active buffer
bind = SUPER, C, exec, ~/.config/omarchy/plugins/dooooooks.omaclippr/bin/omaclippr --clip
```

Other CLI flags: `--start`, `--stop`, `--toggle`.

## Configure

```sh
# Move the pill somewhere else on the bar
omarchy bar move dooooooks.omaclippr --section right
```

Quality presets and replay length are set from the panel (they lock while the
buffer is active), and sources choose which monitor, microphone, and system
sound get captured.

## Requirements

- `gpu-screen-recorder` (provides the hardware-accelerated replay buffer)

## Remove

```sh
omarchy plugin remove dooooooks.omaclippr
```

## Support

If you like Omaclippr, consider buying me a coffee:

[☕ buymeacoffee.com/dook13s](https://buymeacoffee.com/dook13s)

## License

MIT — see [LICENSE](LICENSE).
