#!/usr/bin/env bash
set -euo pipefail

if (( $# < 3 )) || [[ $2 != -- ]]; then
  echo "Usage: run-exclusive-wayvibes.sh <keyboard|mouse> -- wayvibes [args...]" >&2
  exit 2
fi

role=$1
shift 2

case "$role" in
  keyboard | mouse) ;;
  *)
    echo "Unsupported TypeTone process role: $role" >&2
    exit 2
    ;;
esac

if [[ $1 != wayvibes ]]; then
  echo "TypeTone's process guard only starts wayvibes." >&2
  exit 2
fi

command -v flock >/dev/null 2>&1 || {
  echo "flock is required to manage TypeTone processes." >&2
  exit 1
}

runtime_root=${XDG_RUNTIME_DIR:-}
if [[ -z $runtime_root || ! -d $runtime_root || ! -w $runtime_root ]]; then
  echo "TypeTone cannot access XDG_RUNTIME_DIR." >&2
  exit 1
fi

runtime_dir="$runtime_root/typetone"
mkdir -p -- "$runtime_dir"
chmod 700 "$runtime_dir"

lock_path="$runtime_dir/$role.lock"
pid_path="$runtime_dir/$role.pid"
exec {lock_fd}>"$lock_path"

if ! flock -n "$lock_fd"; then
  old_pid=""
  old_start=""
  if [[ -r $pid_path ]]; then
    read -r old_pid old_start < "$pid_path" || true
  fi

  if [[ $old_pid =~ ^[0-9]+$ && $old_start =~ ^[0-9]+$ && -r /proc/$old_pid/stat ]]; then
    current_start=$(awk '{print $22}' "/proc/$old_pid/stat" 2>/dev/null || true)
    current_executable=$(readlink -f "/proc/$old_pid/exe" 2>/dev/null || true)
    if [[ $current_start == "$old_start" && ${current_executable##*/} == wayvibes ]]; then
      kill "$old_pid" 2>/dev/null || true
    fi
  fi

  if ! flock -w 3 "$lock_fd"; then
    echo "Another TypeTone $role process is still running." >&2
    exit 1
  fi
fi

start_ticks=$(awk '{print $22}' "/proc/$$/stat")
pid_tmp="$runtime_dir/.$role.pid.$$"
printf '%s %s\n' "$$" "$start_ticks" > "$pid_tmp"
mv -f -- "$pid_tmp" "$pid_path"

exec "$@"
