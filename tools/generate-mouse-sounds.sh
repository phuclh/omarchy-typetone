#!/usr/bin/env bash
set -euo pipefail

repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
output_root="$repo_dir/mouse-sounds"

command -v ffmpeg >/dev/null 2>&1 || {
  echo "ffmpeg is required to regenerate the TypeTone mouse sounds." >&2
  exit 1
}

make_click() {
  local output=$1
  local body_frequency=$2
  local release_frequency=$3
  local highpass=$4
  local lowpass=$5
  local body_volume=$6
  local noise_volume=$7
  local release_volume=$8
  local release_delay=$9
  local seed=${10}

  ffmpeg -hide_banner -loglevel error -y \
    -f lavfi -i "sine=frequency=${body_frequency}:sample_rate=48000:duration=0.08" \
    -f lavfi -i "anoisesrc=color=white:sample_rate=48000:duration=0.08:amplitude=0.7:seed=${seed}" \
    -f lavfi -i "sine=frequency=${release_frequency}:sample_rate=48000:duration=0.05" \
    -filter_complex \
      "[0:a]afade=t=out:st=0:d=0.018,volume=${body_volume}[body]; \
       [1:a]highpass=f=${highpass},lowpass=f=${lowpass},afade=t=out:st=0:d=0.011,volume=${noise_volume}[noise]; \
       [2:a]afade=t=out:st=0:d=0.011,volume=${release_volume},adelay=${release_delay}:all=1[release]; \
       [body][noise][release]amix=inputs=3:normalize=0,alimiter=limit=0.88,atrim=0:0.075,asetpts=N/SR/TB[out]" \
    -map "[out]" -ar 48000 -ac 1 -c:a pcm_s16le "$output"
}

# Crisp: bright shell snap with a small release tick.
make_click "$output_root/crisp/left.wav"   3150 4200 1700 10000 0.54 0.30 0.19 24 101
make_click "$output_root/crisp/right.wav"  3500 4550 1900 11000 0.48 0.27 0.17 23 102
make_click "$output_root/crisp/middle.wav" 2700 3700 1400  9000 0.50 0.25 0.18 25 103

# Soft: muted, rounded clicks suitable for long sessions.
make_click "$output_root/soft/left.wav"   1550 2300 550 5200 0.43 0.15 0.13 27 201
make_click "$output_root/soft/right.wav"  1750 2500 650 5600 0.39 0.14 0.12 26 202
make_click "$output_root/soft/middle.wav" 1300 2050 450 4800 0.41 0.13 0.12 28 203

# Deep: lower-pitched, weightier button response.
make_click "$output_root/deep/left.wav"    720 1320 180 3200 0.58 0.17 0.16 29 301
make_click "$output_root/deep/right.wav"   840 1480 220 3500 0.52 0.16 0.15 28 302
make_click "$output_root/deep/middle.wav"  610 1150 150 2900 0.56 0.15 0.15 30 303

echo "Regenerated TypeTone mouse sounds in $output_root"
