#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root="$repo_dir/third_party/mouse-sounds"
output_root="$repo_dir/mouse-sounds"
verify_tmp=$(mktemp -d "${TMPDIR:-/tmp}/typetone-audio-verify.XXXXXX")

if (( $# > 1 )) || (( $# == 1 )) && [[ $1 != --remote ]]; then
  echo "Usage: verify-mouse-sounds.sh [--remote]" >&2
  exit 2
fi

cleanup() {
  case "$verify_tmp" in
    "${TMPDIR:-/tmp}"/typetone-audio-verify.*) rm -rf -- "$verify_tmp" ;;
  esac
}
trap cleanup EXIT

(cd "$source_root" && sha256sum -c SHA256SUMS)
(cd "$output_root" && sha256sum -c SHA256SUMS)

TYPETONE_MOUSE_OUTPUT_ROOT="$verify_tmp" \
  "$repo_dir/tools/generate-mouse-sounds.sh"
(cd "$verify_tmp" && sha256sum -c "$output_root/SHA256SUMS")

if [[ ${1:-} == --remote ]]; then
  command -v curl >/dev/null 2>&1 || {
    echo "curl is required for remote source verification." >&2
    exit 1
  }

  verify_remote() {
    local expected=$1
    local url=$2
    local actual

    actual=$(curl --proto '=https' --tlsv1.2 --location --fail --silent \
      --show-error "$url" | sha256sum | awk '{print $1}')
    [[ $actual == "$expected" ]] || {
      echo "Remote source checksum mismatch: $url" >&2
      exit 1
    }
    echo "remote source: OK — $url"
  }

  verify_remote e709209560da92c4c8c695aeb74aec67fa5896807c3fa99a49779f4c135582d3 \
    https://cdn.freesound.org/previews/223/223445_1482559-hq.mp3
  verify_remote bbbddc66710313d67f0c8d8dc37f68c62728c041ccb3820f04c45554dd9f46e5 \
    https://cdn.freesound.org/previews/447/447938_9159316-hq.mp3
  verify_remote 96fe850f26500abcbb592d6b8ce1b388234a6c860a0d76c8285557febee75dd7 \
    https://cdn.freesound.org/previews/555/555394_7593953-hq.mp3
  verify_remote e9eee3be84ab292b92e03bdb25930545a1051e43e31c2dc8dc49b6fa44b3a1cb \
    https://cdn.freesound.org/previews/320/320146_140737-hq.mp3
  verify_remote 8a0ec2e7341f70b33f0802aadeb6a0689aed893048a600bfd46b1a6716fbe8fe \
    https://opengameart.org/sites/default/files/middle-click-press.wav
  verify_remote 189005834fc3fef2fd4f024d503fbf98d313111b86bbf9904808aa276383a0f3 \
    https://opengameart.org/sites/default/files/middle-click-release.wav
fi

echo "Verified vendored source hashes and reproducible TypeTone mouse WAV files"
