#!/usr/bin/env bash
set -euo pipefail

# Emit priority, event path, and display name for click-capable pointing devices.
# TypeTone stores the name and resolves the event path again on every scan so
# renumbered /dev/input/event* nodes do not break saved settings.
awk '
  BEGIN { RS = ""; FS = "\n" }

  {
    name = ""
    handlers = ""

    for (i = 1; i <= NF; i++) {
      if ($i ~ /^N: Name=/) {
        name = $i
        sub(/^N: Name="/, "", name)
        sub(/"$/, "", name)
      } else if ($i ~ /^H: Handlers=/) {
        handlers = $i
      }
    }

    lower = tolower(name)
    if (lower !~ /(mouse|touchpad|trackpoint|trackball)/) next
    if (!match(handlers, /event[0-9]+/)) next

    event = substr(handlers, RSTART, RLENGTH)
    priority = lower ~ /touchpad/ ? 1 : 2
    print priority "\t/dev/input/" event "\t" name
  }
' /proc/bus/input/devices | sort -t $'\t' -k1,1n -k3,3 | cut -f2-
