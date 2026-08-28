# TypeTone

Mechanical keyboard sounds for the Omarchy desktop, powered by
[Wayvibes](https://github.com/sahaj-b/wayvibes).

TypeTone is an Omarchy Quattro service and bar widget. It manages a Wayvibes
process, provides controls that match the Omarchy shell, and remembers the
preferred volume for each sound pack. TypeTone does not synthesize keyboard
audio itself: Wayvibes reads Linux keyboard events and plays recorded sound
samples.

## Features

- Global mechanical-keyboard sounds on Wayland through Wayvibes
- Omarchy bar control with click-to-toggle and right-click settings
- Scrollable selector for 20 upstream sound packs
- Independent volume memory for every sound pack
- Mouse-wheel volume control from the bar
- Persistent enabled state, selected pack, device override, and volume profiles
- Automatic Wayvibes process lifecycle and visible error/status feedback
- No network access or telemetry in the TypeTone plugin

## Requirements

- Omarchy Quattro with the plugin-capable Omarchy shell
- [Wayvibes](https://github.com/sahaj-b/wayvibes)
- A Wayvibes-compatible sound-pack collection at
  `~/.local/share/wayvibes/soundpacks`
- Permission to read the selected keyboard through Linux `evdev`

Wayvibes and its sound packs are external dependencies. They are not included
in this repository and are not covered by TypeTone's license. See
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

## Install

### 1. Install Wayvibes

From an Omarchy terminal:

```bash
omarchy pkg aur add wayvibes-git
```

Your user must be in the `input` group so Wayvibes can read keyboard events:

```bash
sudo usermod -aG input "$USER"
```

Log out and back in after changing group membership.

### 2. Download the upstream sound packs

For a new installation, use a sparse clone so only the `soundpacks` directory
is checked out:

```bash
git clone --depth 1 --filter=blob:none --sparse \
  https://github.com/sahaj-b/wayvibes.git \
  "$HOME/.local/share/wayvibes"
git -C "$HOME/.local/share/wayvibes" sparse-checkout set soundpacks
```

If `~/.local/share/wayvibes` already exists, keep it and place compatible packs
inside its `soundpacks` directory instead of running the clone command.

### 3. Select a keyboard once

Run Wayvibes interactively before enabling TypeTone:

```bash
wayvibes --device "$HOME/.local/share/wayvibes/soundpacks/nk-cream" -v 0
```

Choose the keyboard in the terminal, then press `Ctrl+C`. Wayvibes remembers
the selection. Users of `keyd` or another remapper should normally select its
virtual keyboard. TypeTone also supports an explicit `deviceName` override in
its settings file.

### 4. Install TypeTone

```bash
omarchy plugin add https://github.com/phuclh/omarchy-typetone.git --enable
```

TypeTone appears on the right side of the Omarchy bar by default.

## Use

- **Left-click TypeTone:** enable or disable keyboard sounds
- **Right-click TypeTone:** open sound, volume, status, and restart controls
- **Mouse wheel over TypeTone:** adjust the current sound's volume
- **Sound selector:** open or close the inline list and choose a pack

Each pack starts with the current volume the first time it is selected. After
you adjust it once, TypeTone restores that pack's own level whenever you return
to it.

## Configuration

TypeTone stores user settings at:

```text
~/.config/wayvibes/omarchy.json
```

The `packVolumes` object contains the remembered level for each pack. The
top-level `volume` remains as the current/legacy value. An empty `deviceName`
uses the keyboard selected by Wayvibes; set it to an exact evdev device name to
override that selection.

Service status is available over Omarchy shell IPC:

```bash
omarchy-shell typetone status
```

## Update

```bash
omarchy plugin update io.github.phuclh.typetone --yes
```

## Remove

```bash
omarchy plugin remove io.github.phuclh.typetone
```

Removing TypeTone does not delete Wayvibes, downloaded sound packs, or
`~/.config/wayvibes/omarchy.json`. Remove those separately only if no other
application uses them.

## Security and privacy

Omarchy plugins run as unsandboxed user code. TypeTone starts and stops the
`wayvibes` executable, reads and writes only its settings file, and does not
make network requests. Wayvibes requires global access to keyboard events via
`evdev`; do not run it as root. Review the Wayvibes source and use only sound
packs you trust.

TypeTone does not store typed text or key-event history. It reacts to process
status and delegates key-event handling and audio playback to Wayvibes.

## Credits and license

TypeTone is built on top of
[Wayvibes by sahaj-b](https://github.com/sahaj-b/wayvibes), which provides the
keyboard-event and audio engine. TypeTone provides the Omarchy integration,
controls, persistence, and per-pack volume profiles.

TypeTone's original source code and documentation are released under the
[MIT License](LICENSE). External software and sound recordings remain under
their respective authors' terms.
