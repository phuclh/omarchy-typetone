# Third-party notices

TypeTone is an independent Omarchy integration built on top of external
software and keyboard sound assets. Those third-party items are not included
in this repository or relicensed by TypeTone. Bundled mouse recordings are
identified separately below.

## Wayvibes

- Project: [sahaj-b/wayvibes](https://github.com/sahaj-b/wayvibes)
- Role: reads Linux `evdev` keyboard or pointing-device events and plays sound
  samples
- Distribution: installed separately by the user

TypeTone starts the `wayvibes` executable but does not copy or modify its
source. Review the upstream project and its terms before installing, using, or
redistributing it. At the time of TypeTone 1.3.2, the upstream repository does
not expose a root license file.

## Sound packs

TypeTone recognizes the pre-converted sound-pack directory names published in
the Wayvibes repository. The audio files and their `config.json` mappings are
downloaded separately by the user and are not included here. Sound recordings
may have pack-specific authors or terms; TypeTone's MIT license does not apply
to them. When a config references an absent sample, TypeTone may create a
relative compatibility symlink inside that pack to another mapped sample from
the same pack; it does not alter or redistribute the recordings.

## Bundled mouse recordings

The source audio under `third_party/mouse-sounds/` and the processed WAV files
under `mouse-sounds/` are derived from the following recordings:

- **mouse_click.wav** by Six Ways on Freesound — cleaned mouse-click recording,
  [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Mouse clicks** by Breviceps on Freesound — real mouse-click sequence,
  [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **mouse click (double click) — Razer DeathAdder Essential** by Katsuhira on
  Freesound — recorded with a Blue Yeti,
  [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Mouse Clicks & Scrolls** by OwlStorm on Freesound — Logitech three-button
  mouse recorded with a Zoom H4n,
  [CC0](https://creativecommons.org/publicdomain/zero/1.0/)
- **Middle Mouse Click** by 1j01 on OpenGameArt — close-mic press and release
  recordings, [CC0](https://creativecommons.org/publicdomain/zero/1.0/)

CC0 does not require attribution; TypeTone includes it to preserve provenance
and thank the recordists. Exact source links, local filenames, and checksums are
in [`third_party/mouse-sounds/README.md`](third_party/mouse-sounds/README.md).
TypeTone's processing script is distributed under the MIT license.
