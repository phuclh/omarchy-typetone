#!/usr/bin/env bash
set -euo pipefail

if (( $# < 2 || $# > 3 )); then
  echo "Usage: run-keyboard-wayvibes.sh <soundpack> <volume> [device-name]" >&2
  exit 2
fi

soundpack_path=$1
volume=$2
device_name=${3:-}
script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

"$script_dir/repair-keyboard-soundpack.sh" "$soundpack_path"

command=(wayvibes)
if [[ -n $device_name ]]; then
  command+=(--device-name "$device_name")
fi
command+=("$soundpack_path" -v "$volume")

exec "${command[@]}"
