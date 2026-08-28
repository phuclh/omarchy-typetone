#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_root="$repo_dir/third_party/mouse-sounds"
output_root="$repo_dir/mouse-sounds"

command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg is required to regenerate the TypeTone mouse sounds." >&2
  exit 1
}

render_click() {
  local source=$1
  local output=$2
  local start=$3
  local duration=$4
  local pitch=$5
  local lowpass=$6
  local gain=$7

  [[ -f "$source" ]] || {
    echo "Missing source recording: $source" >&2
    exit 1
  }

  mkdir -p "$(dirname -- "$output")"
  ffmpeg -hide_banner -loglevel error -y \
    -ss "$start" -t "$duration" -i "$source" \
    -af "aformat=sample_fmts=fltp:sample_rates=48000:channel_layouts=mono,\
highpass=f=80,lowpass=f=${lowpass},volume=${gain},\
asetrate=48000*${pitch},aresample=48000,\
afade=t=in:st=0:d=0.001,areverse,afade=t=in:st=0:d=0.006,areverse,\
alimiter=limit=0.50:attack=1:release=5:level=false" \
    -ar 48000 -ac 1 -c:a pcm_s16le "$output"
}

render_variants() {
  local pack=$1
  local source=$2
  local start=$3
  local duration=$4
  local lowpass=$5
  local gain=$6
  local left_pitch=${7:-1.0}
  local right_pitch=${8:-1.035}
  local middle_pitch=${9:-0.92}

  render_click "$source" "$output_root/$pack/left.wav" \
    "$start" "$duration" "$left_pitch" "$lowpass" "$gain"
  render_click "$source" "$output_root/$pack/right.wav" \
    "$start" "$duration" "$right_pitch" "$lowpass" "$gain"
  render_click "$source" "$output_root/$pack/middle.wav" \
    "$start" "$duration" "$middle_pitch" "$lowpass" "$gain"
}

# Clean: a tightly edited, noise-free mouse recording.
render_variants crisp "$source_root/sixways-clean.mp3" 0 0.132 14000 2.00

# Soft: a rounded real-mouse recording with the high end gently reduced.
render_variants soft "$source_root/breviceps-clicks.mp3" 0.035 0.170 6500 7.00 \
  0.97 1.01 0.90

# Deep: a lower, weightier treatment of a Razer mouse recording.
render_variants deep "$source_root/katsuhira-razer.mp3" 0.380 0.220 5200 3.50 \
  0.84 0.88 0.78

# Named hardware profiles retain more of each original recording's character.
render_variants razer "$source_root/katsuhira-razer.mp3" 0.380 0.220 12000 1.85 \
  1.00 1.04 0.93
render_variants logitech "$source_root/owlstorm-logitech.mp3" 2.470 0.320 12000 1.60 \
  1.00 1.035 0.92

# Studio uses a close-mic middle-button recording with separate press/release
# takes for a little more left/right variation.
render_click "$source_root/middle-click-press.wav" \
  "$output_root/studio/left.wav" 0 0.075 1.00 13000 10.0
render_click "$source_root/middle-click-release.wav" \
  "$output_root/studio/right.wav" 0 0.073 1.04 13000 12.0
render_click "$source_root/middle-click-press.wav" \
  "$output_root/studio/middle.wav" 0 0.075 0.90 9000 10.0

echo "Regenerated six recorded TypeTone mouse packs in $output_root"
