# Mouse recording sources

TypeTone vendors public preview or download files from five CC0 recordings so
its mouse profiles work offline and can be regenerated deterministically. CC0
permits copying, modifying, and redistributing the recordings, including for
commercial use, without attribution. Attribution is retained here for
provenance and thanks.

| Local file | Recording and author | Source | SHA-256 |
| --- | --- | --- | --- |
| `sixways-clean.mp3` | **mouse_click.wav** by Six Ways | [Freesound 223445](https://freesound.org/people/Six%20Ways/sounds/223445/) | `e709209560da92c4c8c695aeb74aec67fa5896807c3fa99a49779f4c135582d3` |
| `breviceps-clicks.mp3` | **Mouse clicks** by Breviceps | [Freesound 447938](https://freesound.org/people/Breviceps/sounds/447938/) | `bbbddc66710313d67f0c8d8dc37f68c62728c041ccb3820f04c45554dd9f46e5` |
| `katsuhira-razer.mp3` | **mouse click (double click) — Razer DeathAdder Essential** by Katsuhira | [Freesound 555394](https://freesound.org/people/Katsuhira/sounds/555394/) | `96fe850f26500abcbb592d6b8ce1b388234a6c860a0d76c8285557febee75dd7` |
| `owlstorm-logitech.mp3` | **Mouse Clicks & Scrolls** by OwlStorm | [Freesound 320146](https://freesound.org/people/OwlStorm/sounds/320146/) | `e9eee3be84ab292b92e03bdb25930545a1051e43e31c2dc8dc49b6fa44b3a1cb` |
| `middle-click-press.wav` | **Middle Mouse Click** by 1j01 | [OpenGameArt](https://opengameart.org/content/middle-mouse-click) | `8a0ec2e7341f70b33f0802aadeb6a0689aed893048a600bfd46b1a6716fbe8fe` |
| `middle-click-release.wav` | **Middle Mouse Click** by 1j01 | [OpenGameArt](https://opengameart.org/content/middle-mouse-click) | `189005834fc3fef2fd4f024d503fbf98d313111b86bbf9904808aa276383a0f3` |

All five source pages identify their files as
[Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The four Freesound files here are the site's public high-quality MP3 previews;
the OpenGameArt files are the provided WAV downloads.

Run `tools/generate-mouse-sounds.sh` from any directory to rebuild the mono,
48 kHz PCM WAV files in `mouse-sounds/`. The script trims, filters, pitch-shifts,
and peak-limits the recordings; it does not download anything.
