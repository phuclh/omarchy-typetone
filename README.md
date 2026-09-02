# TypeTone

Mechanical keyboard and mouse-click sounds for the Omarchy desktop, powered by
[Wayvibes](https://github.com/sahaj-b/wayvibes).

TypeTone is an Omarchy Quattro service and bar widget. It manages Wayvibes
processes, provides controls that match the Omarchy shell, and remembers the
preferred volume for each keyboard and mouse sound pack. TypeTone does not
synthesize keyboard audio itself: Wayvibes reads Linux input events and plays
audio samples. The bundled mouse clicks are processed from redistributable CC0
recordings and work offline.

![TypeTone settings with the sound picker expanded](preview.png)

## Features

- Global mechanical-keyboard sounds on Wayland through Wayvibes
- Left, right, middle, side, and extra mouse-button sounds
- Automatic mouse and touchpad detection with a device selector
- Six recorded mouse-click profiles: Clean, Soft, Deep, Razer, Logitech, and
  Studio
- Omarchy bar control with left-click settings and right-click master mute
- Scrollable selector for 20 upstream sound packs
- Independent volume memory for every keyboard and mouse sound pack
- Live profile updates while dragging either volume control
- Mouse-wheel volume control from the bar
- Separate keyboard and mouse toggles, packs, devices, and volume profiles
- Icon-only bar control with a master mute that restores the previous toggles
- Commit-verified setup for Wayvibes, sound packs, permissions, and TypeTone
- In-widget input-access detection and administrator-authenticated repair
- Automatic compatibility repair for upstream packs with missing mapped samples
- One guarded keyboard process and one guarded mouse process after shell reloads
- Automatic Wayvibes process lifecycle and visible error/status feedback
- No network access or telemetry in the TypeTone plugin

## Requirements

- Omarchy Quattro with the plugin-capable Omarchy shell
- Git and a C++17 compiler
- `libevdev` and `nlohmann-json` development files
- Permission to read the selected keyboard and pointing device through Linux
  `evdev`

The reviewed installer obtains the compiler and development files from signed
official Arch packages when they are missing. It fetches Wayvibes and its
keyboard packs directly from upstream at the immutable full commit
`b43b76fd3a4181b7bd9029372b93d503ce91dced`, verifies the Git object, and builds
it locally. Wayvibes and its keyboard packs are not covered by TypeTone's
license. The bundled mouse recordings use CC0; see
[THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).

Some upstream keyboard-pack configs reference sample filenames that are not
included in the pack. Before starting keyboard playback, TypeTone fills only
those missing filenames with relative symlinks to an existing short per-key
sample from the same pack. It does not rewrite the pack's config or audio.

## Install

### Install a reviewed snapshot

Copy the exact 40-character commit from the latest **Marketplace validation**
comment in the [TypeTone submission](https://github.com/omacom/omarchy-plugin-marketplace/issues/3180),
replace the placeholder below, and paste the block into an Omarchy terminal:

```bash
(
  set -euo pipefail
  TYPETONE_COMMIT='<PASTE-40-CHARACTER-VALIDATED-COMMIT>'
  [[ $TYPETONE_COMMIT =~ ^[0-9a-f]{40}$ ]]
  TYPETONE_CHECKOUT=$(mktemp -d)
  git -C "$TYPETONE_CHECKOUT" init --quiet
  git -C "$TYPETONE_CHECKOUT" remote add origin \
    https://github.com/phuclh/omarchy-typetone.git
  git -C "$TYPETONE_CHECKOUT" fetch --quiet --depth=1 origin "$TYPETONE_COMMIT"
  [[ $(git -C "$TYPETONE_CHECKOUT" rev-parse FETCH_HEAD) == "$TYPETONE_COMMIT" ]]
  git -C "$TYPETONE_CHECKOUT" checkout --quiet --detach "$TYPETONE_COMMIT"
  "$TYPETONE_CHECKOUT/install.sh" --typetone-commit "$TYPETONE_COMMIT"
)
```

The repository cannot embed the hash of the commit that contains that same
hash, so the reviewed commit is supplied by the marketplace validation record.
The block fetches only that content-addressed commit and verifies it before
executing the local installer. It never streams a script from a moving branch.

The installer shows both pinned commits and every privileged effect before it
asks whether to continue. It installs signed build dependencies if necessary,
compiles Wayvibes with a fixed command instead of executing its build or
installer scripts, installs its sound packs in a commit-specific directory,
selects a detected keyboard, and installs the same detached TypeTone commit.
The installed checkout has no Git remote, so the generic Omarchy updater cannot
silently move it to an unreviewed branch. When replacing an enabled version, it
reloads the Omarchy shell so no cached QML from the prior snapshot remains.
Future updates reuse an unchanged Wayvibes snapshot only after checking its
source record, binary checksum, fixed sound-pack manifest checksum, all 1,480
sound-pack files, and the absence of unexpected regular files. If access to the
network is removed after the two exact Git fetches, the remaining setup is
local except for signed Arch packages that were missing.

If the installer adds your user to the `input` group, restart your computer once
when it finishes. A restart also handles desktop sessions that remain alive
after a normal logout.

Membership in the Linux `input` group lets applications running as your user
read global keyboard and pointing-device events. The installer discloses this
before requesting administrator authentication.

Review [`install.sh`](install.sh) before running it. Omarchy plugins and this
installer run as unsandboxed user code. For a manual installation, perform the
same fetch verification and then follow the fixed commands in that reviewed
installer; do not substitute a branch name, the AUR `wayvibes-git` recipe, or
Wayvibes' upstream installer.

#### Input permission and administrator access

Wayvibes itself and the TypeTone audio processes always run as your normal
user. The only privileged change TypeTone needs is persistent membership in
Linux's `input` group:

- The terminal installer runs `sudo usermod -aG input "$USER"` after disclosing
  the scope and asking whether to continue.
- The settings widget's **Grant access** action runs the fixed command
  `/usr/bin/pkexec /usr/bin/usermod -aG input -- <current-user>` after deriving
  and validating the current account name. It accepts no caller arguments.
- Both paths require explicit administrator authentication. Neither creates a
  sudoers rule, and TypeTone never runs Wayvibes as root.
- Group membership remains active until an administrator removes it. To revoke
  it, run `sudo gpasswd -d "$USER" input`, then restart the computer.

This broad group permission is required because Wayvibes reads raw `evdev`
devices. It allows every process running as the account—not just TypeTone—to
observe global keyboard and mouse events. Restart once after granting or
revoking it so every desktop process receives the new group list.

TypeTone appears on the right side of the Omarchy bar by default. Existing
installations keep mouse sounds disabled until they are turned on from the
Mouse tab.

## Use

- **Left-click TypeTone:** open sound, volume, status, and restart controls
- **Right-click TypeTone:** mute both sound sources or restore their previous
  keyboard/mouse combination
- **Mouse wheel over TypeTone:** adjust the current sound's volume
- **Keyboard tab:** choose a switch pack and its volume
- **Mouse tab:** enable mouse clicks, select a mouse or touchpad, choose a click
  style, and adjust its volume

If TypeTone detects an existing keyboard or mouse that the current session
cannot read, the settings widget displays an **Input access required** card.
**Grant access** opens the system administrator-authentication dialog and adds
the current account to the `input` group. TypeTone never grants this access
silently. After authorization, **Restart computer** asks for confirmation before
using Omarchy's standard reboot action. TypeTone then starts automatically.

Each keyboard or mouse pack starts with the current volume the first time it is
selected. After you adjust it once, TypeTone restores that pack's own level
whenever you return to it.

## Mouse-click sounds

Wayvibes officially targets keyboards, but its audio loop can map any Linux
`EV_KEY` button code to a sample. TypeTone runs a second isolated Wayvibes
process for the selected pointing device and maps the standard left, right,
middle, side, and extra button codes. Keyboard behavior and Wayvibes' saved
keyboard selection remain independent.

TypeTone includes six profiles built from real mouse recordings: Clean, Soft,
Deep, Razer, Logitech, and Studio. Clean, Soft, and Deep retain the old
internal pack IDs so existing per-pack volume preferences continue to work
after upgrading from 1.1.

The processed WAV files are reproducible with
[`tools/generate-mouse-sounds.sh`](tools/generate-mouse-sounds.sh). `ffmpeg` is
needed only to regenerate them, not to use TypeTone. Source recordings,
authors, exact asset URLs, checksums, and license links are documented in
[`third_party/mouse-sounds/README.md`](third_party/mouse-sounds/README.md).
Run [`tools/verify-mouse-sounds.sh`](tools/verify-mouse-sounds.sh) to verify the
vendored sources and reproduce every processed WAV; its optional `--remote`
mode also compares the official downloads byte-for-byte.

## Configuration

TypeTone stores user settings at:

```text
~/.config/wayvibes/omarchy.json
```

The `packVolumes` and `mousePackVolumes` objects contain the remembered levels
for keyboard and mouse packs. The top-level `volume` and `mouseVolume` values
are the current selections. An empty `deviceName` uses the keyboard selected
by Wayvibes; set it to an exact evdev device name to override that selection.
TypeTone resolves `mouseDeviceName` to its current `/dev/input/event*` path on
every scan, so normal event-number changes do not invalidate the selection.
The `resumeKeyboardEnabled` and `resumeMouseEnabled` values remember which
sources a right-click should restore after master mute.

Service status is available over Omarchy shell IPC:

```bash
omarchy-shell typetone status
```

## Update

Wait for the desired release to receive a new marketplace validation, then run
the verified installation block again with that new full commit. The installer
preserves the prior plugin checkout as a hidden backup and keeps its enabled or
disabled state. Do not use `omarchy plugin update` for TypeTone: it follows the
repository's moving default branch rather than a reviewed commit.

## Remove

```bash
omarchy plugin remove io.github.phuclh.typetone
```

Removing TypeTone does not delete the pinned Wayvibes build and sound packs
under `~/.local/share/typetone/vendor/wayvibes`, prior hidden plugin backups, or
`~/.config/wayvibes/omarchy.json`. It also leaves any small compatibility
symlinks created for missing upstream samples. Remove those separately only if
no other application uses them.

## Security and privacy

Omarchy plugins run as unsandboxed user code. TypeTone starts and stops the
commit-pinned `wayvibes` executable, reads Linux keyboard and pointing-device
events, writes its settings plus an isolated Wayvibes mouse-device selection,
and may add relative symlinks for missing mapped samples inside the selected
keyboard sound pack. It also replaces an earlier TypeTone-managed Wayvibes
process if one survives a shell reload. It does not make network requests.
Wayvibes requires global access to input events via `evdev`; TypeTone may
request administrator authentication to add the current account to the Linux
`input` group. This grants every process running as that user permission to
read input events, not only TypeTone. Do not run Wayvibes as root. Review the
Wayvibes source and use only sound packs you trust.

TypeTone's process guard stores only same-user runtime state below the
owner-only `$XDG_RUNTIME_DIR/typetone` directory. It rejects symlinked,
wrong-owner, wrong-type, permission-relaxed, or inode-swapped state before
trusting it. Lock paths remain anchored to verified open directory descriptors.
When replacing a previous instance, it signals only an unprivileged process
owned by the current user after matching the recorded start time and either the
legacy Bash guard's executable, script path, role, and command or the exact
pinned Wayvibes executable and complete role-specific argument shape. The
launcher replaces itself with Wayvibes so Quickshell directly owns and stops
the audio process. Runtime PIDs are never passed across a privilege boundary.

The reviewed installer fetches both TypeTone and Wayvibes only by immutable
full Git commits, verifies the resolved objects, and never executes a remotely
streamed script, Wayvibes build script, AUR recipe, or moving Git branch. Its
fixed C++ build links against signed Arch dependencies, and TypeTone invokes
the resulting binary by its commit-specific absolute path.

TypeTone does not store typed text, pointer movement, clicks, or input-event
history. It reacts to process status and delegates input-event handling and
audio playback to Wayvibes.

## Credits and license

Created by [Phuc Le (@phuclh93)](https://x.com/phuclh93).

TypeTone is built on top of
[Wayvibes by sahaj-b](https://github.com/sahaj-b/wayvibes), which provides the
keyboard-event and audio engine. TypeTone provides the Omarchy integration,
controls, mouse-device adapter, processed mouse packs, persistence, and
per-pack volume profiles.

TypeTone's original source code and documentation are released under the
[MIT License](LICENSE). External software and bundled CC0 sound recordings
remain under their respective authors' terms.
