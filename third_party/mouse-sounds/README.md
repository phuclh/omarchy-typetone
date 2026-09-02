# Mouse recording sources

TypeTone vendors public preview or download files from five CC0 recordings so
its mouse profiles work offline and can be regenerated deterministically. CC0
permits copying, modifying, and redistributing the recordings, including for
commercial use, without attribution. Attribution is retained here for
provenance and thanks.

| Local file | Recording and author | License evidence | Exact vendored download | SHA-256 |
| --- | --- | --- | --- | --- |
| `sixways-clean.mp3` | **mouse_click.wav** by Six Ways | [Freesound 223445](https://freesound.org/s/223445/) | [HQ MP3](https://cdn.freesound.org/previews/223/223445_1482559-hq.mp3) | `e709209560da92c4c8c695aeb74aec67fa5896807c3fa99a49779f4c135582d3` |
| `breviceps-clicks.mp3` | **Mouse clicks** by Breviceps | [Freesound 447938](https://freesound.org/s/447938/) | [HQ MP3](https://cdn.freesound.org/previews/447/447938_9159316-hq.mp3) | `bbbddc66710313d67f0c8d8dc37f68c62728c041ccb3820f04c45554dd9f46e5` |
| `katsuhira-razer.mp3` | **mouse click (double click) — Razer DeathAdder Essential** by Katsuhira | [Freesound 555394](https://freesound.org/s/555394/) | [HQ MP3](https://cdn.freesound.org/previews/555/555394_7593953-hq.mp3) | `96fe850f26500abcbb592d6b8ce1b388234a6c860a0d76c8285557febee75dd7` |
| `owlstorm-logitech.mp3` | **Mouse Clicks & Scrolls** by OwlStorm | [Freesound 320146](https://freesound.org/s/320146/) | [HQ MP3](https://cdn.freesound.org/previews/320/320146_140737-hq.mp3) | `e9eee3be84ab292b92e03bdb25930545a1051e43e31c2dc8dc49b6fa44b3a1cb` |
| `middle-click-press.wav` | **Middle Mouse Click** by 1j01 | [OpenGameArt](https://opengameart.org/content/middle-mouse-click) | [WAV](https://opengameart.org/sites/default/files/middle-click-press.wav) | `8a0ec2e7341f70b33f0802aadeb6a0689aed893048a600bfd46b1a6716fbe8fe` |
| `middle-click-release.wav` | **Middle Mouse Click** by 1j01 | [OpenGameArt](https://opengameart.org/content/middle-mouse-click) | [WAV](https://opengameart.org/sites/default/files/middle-click-release.wav) | `189005834fc3fef2fd4f024d503fbf98d313111b86bbf9904808aa276383a0f3` |

All five source pages identify their files as
[Creative Commons Zero 1.0](https://creativecommons.org/publicdomain/zero/1.0/).
The four Freesound files here are the site's public high-quality MP3 previews;
the OpenGameArt files are the provided WAV downloads. On 2026-09-02, every
vendored file was downloaded again from the exact asset URL above and matched
the recorded SHA-256 digest byte-for-byte.

Run `tools/verify-mouse-sounds.sh` to check the vendored source hashes, rebuild
all 18 mono 48 kHz PCM WAV files in a temporary directory, and compare them to
the shipped output hashes. Add `--remote` to also download each exact public
source asset and compare it to the vendored file hash. Verification never
executes downloaded content.

Run `tools/generate-mouse-sounds.sh` from any directory to rebuild the shipped
files. The generator trims, filters, pitch-shifts, and peak-limits the
recordings; it does not download anything.
