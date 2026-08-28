#!/usr/bin/env bash
set -euo pipefail

if (( $# != 4 )); then
  echo "Usage: run-mouse-wayvibes.sh <config-home> <device-path> <soundpack> <volume>" >&2
  exit 2
fi

config_home=$1
device_path=$2
soundpack_path=$3
volume=$4

case "$device_path" in
  /dev/input/event[0-9]* | /dev/input/by-id/* | /dev/input/by-path/*) ;;
  *)
    echo "Refusing unsupported mouse device path: $device_path" >&2
    exit 2
    ;;
esac

if [[ ! -r "$device_path" ]]; then
  echo "Cannot read mouse device $device_path. Log out and back in after joining the input group." >&2
  exit 1
fi

if [[ ! -f "$soundpack_path/config.json" ]]; then
  echo "Mouse sound pack is missing: $soundpack_path" >&2
  exit 1
fi

mkdir -p "$config_home/wayvibes"
printf 'PATH:%s\n' "$device_path" > "$config_home/wayvibes/input_device"

exec env XDG_CONFIG_HOME="$config_home" wayvibes "$soundpack_path" -v "$volume"
