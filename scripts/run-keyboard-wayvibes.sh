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
# shellcheck source=wayvibes-path.sh
source "$script_dir/wayvibes-path.sh"

[[ -f $typetone_wayvibes_bin && ! -L $typetone_wayvibes_bin \
  && -x $typetone_wayvibes_bin ]] || {
  echo "Pinned Wayvibes is missing. Run TypeTone's reviewed install steps again." >&2
  exit 1
}

"$script_dir/repair-keyboard-soundpack.sh" "$soundpack_path"

command=("$typetone_wayvibes_bin")
if [[ -n $device_name ]]; then
  command+=(--device-name "$device_name")
fi
command+=("$soundpack_path" -v "$volume")

exec "$script_dir/run-exclusive-wayvibes.sh" keyboard -- "${command[@]}"
