# Third-party notices

TypeTone is an independent Omarchy integration built on top of external
software and sound assets. None of the items below are included in this
repository or relicensed by TypeTone.

## Wayvibes

- Project: [sahaj-b/wayvibes](https://github.com/sahaj-b/wayvibes)
- Role: reads Linux `evdev` keyboard events and plays sound samples
- Distribution: installed separately by the user

TypeTone starts the `wayvibes` executable but does not copy or modify its
source. Review the upstream project and its terms before installing, using, or
redistributing it. At the time of TypeTone 1.0.0, the upstream repository does
not expose a root license file.

## Sound packs

TypeTone recognizes the pre-converted sound-pack directory names published in
the Wayvibes repository. The audio files and their `config.json` mappings are
downloaded separately by the user and are not included here. Sound recordings
may have pack-specific authors or terms; TypeTone's MIT license does not apply
to them.
