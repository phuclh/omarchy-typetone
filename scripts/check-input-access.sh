#!/usr/bin/env bash
set -euo pipefail

if (( $# > 2 )); then
  echo "Usage: check-input-access.sh [keyboard-name] [mouse-device-path]" >&2
  exit 2
fi

keyboard_name=${1:-}
mouse_path=${2:-}
current_user=$(/usr/bin/id -un)

keyboard_path=$(TARGET_KEYBOARD_NAME="$keyboard_name" awk '
  BEGIN { RS = ""; FS = "\n"; target = ENVIRON["TARGET_KEYBOARD_NAME"] }
  {
    name = ""
    handlers = ""
    for (i = 1; i <= NF; i++) {
      if ($i ~ /^N: Name=/) {
        name = $i
        sub(/^N: Name="/, "", name)
        sub(/"$/, "", name)
      }
      if ($i ~ /^H: Handlers=/) {
        handlers = $i
        sub(/^H: Handlers=/, "", handlers)
      }
    }

    matches = 0
    if (target != "") matches = name == target
    else if (handlers ~ /(^|[[:space:]])kbd([[:space:]]|$)/ &&
             name !~ /^(Power Button|Sleep Button|Video Bus)$/) matches = 1
    if (!matches) next

    count = split(handlers, values, /[[:space:]]+/)
    for (j = 1; j <= count; j++) {
      if (values[j] ~ /^event[0-9]+$/) {
        print "/dev/input/" values[j]
        exit
      }
    }
  }
' /proc/bus/input/devices)

keyboard_present=false
keyboard_readable=false
if [[ -n $keyboard_path && -e $keyboard_path ]]; then
  keyboard_present=true
  [[ -r $keyboard_path ]] && keyboard_readable=true
fi

mouse_present=false
mouse_readable=false
case "$mouse_path" in
  /dev/input/event[0-9]* | /dev/input/by-id/* | /dev/input/by-path/*)
    if [[ -e $mouse_path ]]; then
      mouse_present=true
      [[ -r $mouse_path ]] && mouse_readable=true
    fi
    ;;
  "") ;;
  *) mouse_path="" ;;
esac

input_group_active=false
if /usr/bin/id -nG | tr ' ' '\n' | grep -Fxq input; then
  input_group_active=true
fi

input_group_configured=false
if /usr/bin/id -nG "$current_user" | tr ' ' '\n' | grep -Fxq input; then
  input_group_configured=true
fi

jq -n \
  --arg user "$current_user" \
  --arg keyboardPath "$keyboard_path" \
  --arg mousePath "$mouse_path" \
  --argjson keyboardPresent "$keyboard_present" \
  --argjson keyboardReadable "$keyboard_readable" \
  --argjson mousePresent "$mouse_present" \
  --argjson mouseReadable "$mouse_readable" \
  --argjson inputGroupActive "$input_group_active" \
  --argjson inputGroupConfigured "$input_group_configured" \
  '{
    user: $user,
    keyboardPath: $keyboardPath,
    keyboardPresent: $keyboardPresent,
    keyboardReadable: $keyboardReadable,
    mousePath: $mousePath,
    mousePresent: $mousePresent,
    mouseReadable: $mouseReadable,
    inputGroupActive: $inputGroupActive,
    inputGroupConfigured: $inputGroupConfigured
  }'
