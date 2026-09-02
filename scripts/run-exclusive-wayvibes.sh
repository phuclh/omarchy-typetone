#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "$1" >&2
  exit 1
}

if (( $# < 3 )) || [[ $2 != -- ]]; then
  echo "Usage: run-exclusive-wayvibes.sh <keyboard|mouse> -- <pinned-wayvibes> [args...]" >&2
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

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=wayvibes-path.sh
source "$script_dir/wayvibes-path.sh"

if [[ $1 != "$typetone_wayvibes_bin" ]]; then
  echo "TypeTone's process guard only starts its pinned Wayvibes build." >&2
  exit 2
fi

for required_command in dd stat realpath; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "$required_command is required to manage TypeTone processes."
done
typetone_legacy_wayvibes_bin=$(command -v wayvibes 2>/dev/null || true)
if [[ -n $typetone_legacy_wayvibes_bin ]]; then
  typetone_legacy_wayvibes_bin=$(realpath -e -- "$typetone_legacy_wayvibes_bin" 2>/dev/null) \
    || typetone_legacy_wayvibes_bin=""
fi

current_uid=$(id -u)
script_path=$(realpath -e -- "${BASH_SOURCE[0]}")
plugin_root=$(realpath -e -- "$script_dir/..")
runtime_root=${XDG_RUNTIME_DIR:-}

[[ -n $runtime_root && $runtime_root == /* ]] \
  || fail "TypeTone requires an absolute XDG_RUNTIME_DIR."

# Open directories only after an explicit O_NOFOLLOW/O_DIRECTORY check. Keeping
# their descriptors open anchors every later path below the objects we verified,
# even if a pathname is replaced while TypeTone is running.
open_verified_directory() {
  local path=$1
  local expected_mode=$2
  local label=$3
  local fd_name=$4
  local opened_fd path_record fd_record type owner mode _device _inode

  dd if="$path" of=/dev/null count=0 iflag=directory,nofollow status=none \
    2>/dev/null || fail "$label must be a real directory, not a symlink."
  exec {opened_fd}<"$path"

  path_record=$(stat -c '%F|%u|%a|%d|%i' -- "$path")
  fd_record=$(stat -Lc '%F|%u|%a|%d|%i' -- "/proc/self/fd/$opened_fd")
  [[ $path_record == "$fd_record" ]] \
    || fail "$label changed while TypeTone was opening it."

  IFS='|' read -r type owner mode _device _inode <<< "$fd_record"
  [[ $type == directory && $owner == "$current_uid" && $mode == "$expected_mode" ]] \
    || fail "$label must be an owner-only $expected_mode directory."

  printf -v "$fd_name" '%s' "$opened_fd"
}

open_verified_regular_file() {
  local path=$1
  local allowed_modes=$2
  local label=$3
  local fd_name=$4
  local opened_fd path_record fd_record type owner mode _device _inode

  dd if="$path" of=/dev/null count=0 iflag=nofollow status=none \
    2>/dev/null || fail "$label must be a real file, not a symlink."
  exec {opened_fd}<"$path"

  path_record=$(stat -c '%F|%u|%a|%d|%i' -- "$path")
  fd_record=$(stat -Lc '%F|%u|%a|%d|%i' -- "/proc/self/fd/$opened_fd")
  [[ $path_record == "$fd_record" ]] \
    || fail "$label changed while TypeTone was opening it."

  IFS='|' read -r type owner mode _device _inode <<< "$fd_record"
  [[ $type == regular* && $owner == "$current_uid" \
    && "|$allowed_modes|" == *"|$mode|"* ]] \
    || fail "$label has an unsafe type, owner, or mode."

  printf -v "$fd_name" '%s' "$opened_fd"
}

remove_open_regular_file() {
  local path=$1
  local opened_fd=$2
  local label=$3
  local path_record fd_record

  path_record=$(stat -c '%F|%u|%a|%d|%i' -- "$path" 2>/dev/null) \
    || fail "$label disappeared before cleanup."
  fd_record=$(stat -Lc '%F|%u|%a|%d|%i' -- "/proc/self/fd/$opened_fd" 2>/dev/null) \
    || fail "$label descriptor became invalid."
  [[ $path_record == "$fd_record" ]] \
    || fail "$label changed before cleanup."
  rm -- "$path"
}

open_verified_owner_file() {
  local lock_anchor=$1
  local owner_path="$lock_anchor/owner"
  local before after type owner mode _device _inode contents

  before=$(stat -c '%F|%u|%a|%d|%i' -- "$owner_path" 2>/dev/null) \
    || return 1
  IFS='|' read -r type owner mode _device _inode <<< "$before"
  [[ $type == regular* && $owner == "$current_uid" && $mode == 600 ]] \
    || fail "TypeTone found unsafe owner metadata for the $role process."

  contents=$(dd if="$owner_path" iflag=nofollow status=none 2>/dev/null) \
    || fail "TypeTone refused to follow $role owner metadata."
  after=$(stat -c '%F|%u|%a|%d|%i' -- "$owner_path" 2>/dev/null) \
    || fail "TypeTone $role owner metadata disappeared during validation."
  [[ $before == "$after" ]] \
    || fail "TypeTone $role owner metadata changed during validation."

  printf '%s' "$contents"
}

is_expected_guard_process() {
  local pid=$1
  local expected_start=$2
  local process_owner process_start process_executable process_script
  local -a process_args=()

  [[ $pid =~ ^[0-9]+$ && $expected_start =~ ^[0-9]+$ ]] || return 1
  [[ -r /proc/$pid/stat && -r /proc/$pid/cmdline ]] || return 1

  process_owner=$(stat -Lc '%u' -- "/proc/$pid" 2>/dev/null) || return 1
  [[ $process_owner == "$current_uid" ]] || return 1
  process_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || return 1
  [[ $process_start == "$expected_start" ]] || return 1
  process_executable=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null) || return 1
  if [[ ${process_executable##*/} != bash ]]; then
    is_expected_orphaned_pinned_wayvibes "$pid"
    return
  fi

  mapfile -d '' -t process_args < "/proc/$pid/cmdline" || return 1
  (( ${#process_args[@]} >= 5 )) || return 1
  [[ ${process_args[0]##*/} == bash ]] || return 1
  process_script=$(realpath -e -- "${process_args[1]}" 2>/dev/null) || return 1
  [[ $process_script == "$script_path" ]] || return 1
  [[ ${process_args[2]} == "$role" && ${process_args[3]} == -- ]] || return 1
  # TypeTone 1.3.3 used the PATH-resolved name. Accept it only while identifying
  # and stopping an already-running same-user guard during this migration.
  [[ ${process_args[4]} == "$typetone_wayvibes_bin" \
    || ${process_args[4]} == wayvibes ]]
}

is_expected_legacy_wayvibes() {
  local pid=$1
  local expected_start=$2
  local process_owner process_start process_executable

  [[ $pid =~ ^[0-9]+$ && $expected_start =~ ^[0-9]+$ ]] || return 1
  [[ -r /proc/$pid/stat ]] || return 1
  process_owner=$(stat -Lc '%u' -- "/proc/$pid" 2>/dev/null) || return 1
  [[ $process_owner == "$current_uid" ]] || return 1
  process_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || return 1
  [[ $process_start == "$expected_start" ]] || return 1
  process_executable=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null) || return 1
  [[ ${process_executable##*/} == wayvibes ]]
}

is_expected_orphaned_pinned_wayvibes() {
  local pid=$1
  local process_owner process_executable pack_path expected_argv0
  local -a process_args=()

  [[ $pid =~ ^[0-9]+$ && -r /proc/$pid/cmdline ]] || return 1
  process_owner=$(stat -Lc '%u' -- "/proc/$pid" 2>/dev/null) || return 1
  [[ $process_owner == "$current_uid" ]] || return 1
  process_executable=$(readlink -f -- "/proc/$pid/exe" 2>/dev/null) || return 1
  case "$process_executable" in
    "$typetone_wayvibes_bin") expected_argv0="$typetone_wayvibes_bin" ;;
    "$typetone_wayvibes_vendor_parent/.previous-$typetone_wayvibes_commit-"[0-9]*/wayvibes\ \(deleted\))
      expected_argv0="$typetone_wayvibes_bin"
      ;;
    "$typetone_legacy_wayvibes_bin") expected_argv0=wayvibes ;;
    *) return 1 ;;
  esac

  mapfile -d '' -t process_args < "/proc/$pid/cmdline" || return 1
  [[ ${process_args[0]:-} == "$expected_argv0" \
    || ${process_args[0]:-} == "$process_executable" ]] || return 1

  case "$role" in
  keyboard)
    if (( ${#process_args[@]} == 4 )) && [[ ${process_args[2]} == -v ]]; then
      pack_path=${process_args[1]}
    elif (( ${#process_args[@]} == 6 )) \
      && [[ ${process_args[1]} == --device-name && ${process_args[4]} == -v ]]; then
      pack_path=${process_args[3]}
    else
      return 1
    fi
    case "$pack_path" in
      "$typetone_wayvibes_soundpacks"/* | "$typetone_data_root/wayvibes/soundpacks"/*) ;;
      *) return 1 ;;
    esac
    ;;
  mouse)
    (( ${#process_args[@]} == 4 )) || return 1
    [[ ${process_args[2]} == -v ]] || return 1
    case "${process_args[1]}" in
      "$plugin_root/mouse-sounds"/*) ;;
      *) return 1 ;;
    esac
    ;;
  esac
}

stop_orphaned_pinned_wayvibes() {
  local process_path pid process_start current_start process_state index
  local -a orphaned_pids=()
  local -a orphaned_starts=()

  for process_path in /proc/[0-9]*; do
    pid=${process_path##*/}
    if is_expected_orphaned_pinned_wayvibes "$pid"; then
      process_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || continue
      orphaned_pids+=("$pid")
      orphaned_starts+=("$process_start")
      kill "$pid" 2>/dev/null || true
    fi
  done

  sleep 0.1
  for index in "${!orphaned_pids[@]}"; do
    pid=${orphaned_pids[$index]}
    process_start=${orphaned_starts[$index]}
    [[ -e /proc/$pid ]] || continue
    current_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || continue
    [[ $current_start == "$process_start" ]] || continue
    process_state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) || continue
    [[ $process_state == Z ]] && continue
    is_expected_orphaned_pinned_wayvibes "$pid" \
      || fail "TypeTone refused to force-stop a changed $role process."
    kill -KILL "$pid" 2>/dev/null || true
  done

  for index in "${!orphaned_pids[@]}"; do
    pid=${orphaned_pids[$index]}
    process_start=${orphaned_starts[$index]}
    for attempt in {1..60}; do
      [[ ! -e /proc/$pid ]] && break
      current_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || break
      [[ $current_start != "$process_start" ]] && break
      process_state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) || break
      [[ $process_state == Z ]] && break
      sleep 0.05
    done
    if [[ -e /proc/$pid ]]; then
      current_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || continue
      process_state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) || continue
      [[ $current_start != "$process_start" || $process_state == Z ]] \
        || fail "An orphaned TypeTone $role process did not stop."
    fi
  done
}

stop_expected_managed_process() {
  local pid=$1
  local expected_start=$2
  local current_start process_state

  is_expected_guard_process "$pid" "$expected_start" \
    || fail "TypeTone refused to signal a changed $role process."
  kill "$pid" 2>/dev/null || true
  sleep 0.1

  if [[ -e /proc/$pid ]]; then
    current_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || return 0
    [[ $current_start == "$expected_start" ]] || return 0
    process_state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) || return 0
    if [[ $process_state != Z ]]; then
      is_expected_guard_process "$pid" "$expected_start" \
        || fail "TypeTone refused to force-stop a changed $role process."
      kill -KILL "$pid" 2>/dev/null || true
    fi
  fi

  for attempt in {1..60}; do
    [[ ! -e /proc/$pid ]] && return 0
    current_start=$(awk '{print $22}' "/proc/$pid/stat" 2>/dev/null) || return 0
    [[ $current_start != "$expected_start" ]] && return 0
    process_state=$(awk '{print $3}' "/proc/$pid/stat" 2>/dev/null) || return 0
    [[ $process_state == Z ]] && return 0
    sleep 0.05
  done
  fail "The previous TypeTone $role process did not stop."
}

[[ -d $runtime_root && -w $runtime_root ]] \
  || fail "TypeTone cannot access XDG_RUNTIME_DIR."
open_verified_directory "$runtime_root" 700 "XDG_RUNTIME_DIR" runtime_fd
runtime_anchor="/proc/self/fd/$runtime_fd"

state_path="$runtime_anchor/typetone"
if [[ ! -e $state_path && ! -L $state_path ]]; then
  mkdir -m 700 -- "$state_path" \
    || [[ -e $state_path || -L $state_path ]] \
    || fail "TypeTone could not create its runtime directory."
fi
open_verified_directory "$state_path" 700 "TypeTone's runtime directory" state_fd
state_anchor="/proc/self/fd/$state_fd"
lock_path="$state_anchor/$role.lock"
legacy_pid_path="$state_anchor/$role.pid"

# TypeTone 1.2–1.3.2 used regular lock/PID files. Migrate them only through the
# verified state-directory descriptor. If the old lock is active, validate the
# same-user Wayvibes PID and start time before signaling it, then acquire the
# old advisory lock before removing either regular file.
if [[ -e $lock_path || -L $lock_path ]]; then
  lock_type=$(stat -c '%F' -- "$lock_path" 2>/dev/null) \
    || fail "TypeTone could not inspect its existing $role lock."
  if [[ $lock_type != directory ]]; then
    command -v flock >/dev/null 2>&1 \
      || fail "flock is required to migrate TypeTone's legacy process state."
    open_verified_regular_file "$lock_path" "600|644" \
      "TypeTone's legacy $role lock" legacy_lock_fd

    if ! flock -n "$legacy_lock_fd"; then
      open_verified_regular_file "$legacy_pid_path" "600|644" \
        "TypeTone's legacy $role PID metadata" legacy_pid_fd
      read -r legacy_pid legacy_start legacy_extra <&"$legacy_pid_fd" || true
      exec {legacy_pid_fd}<&-
      [[ -z ${legacy_extra:-} ]] \
        || fail "TypeTone found malformed legacy $role PID metadata."
      is_expected_legacy_wayvibes "${legacy_pid:-}" "${legacy_start:-}" \
        || fail "TypeTone refused to signal an unverified legacy $role process."
      kill "$legacy_pid" 2>/dev/null || true
      flock -w 3 "$legacy_lock_fd" \
        || fail "Legacy TypeTone $role process did not stop."
    fi

    if [[ -e $legacy_pid_path || -L $legacy_pid_path ]]; then
      open_verified_regular_file "$legacy_pid_path" "600|644" \
        "TypeTone's legacy $role PID metadata" legacy_pid_fd
      remove_open_regular_file "$legacy_pid_path" "$legacy_pid_fd" \
        "TypeTone's legacy $role PID metadata"
      exec {legacy_pid_fd}<&-
    fi
    remove_open_regular_file "$lock_path" "$legacy_lock_fd" \
      "TypeTone's legacy $role lock"
    exec {legacy_lock_fd}<&-
  fi
fi

lock_fd=""
lock_owned=false
guard_pid=$BASHPID

for attempt in {1..80}; do
  if mkdir -m 700 -- "$lock_path" 2>/dev/null; then
    open_verified_directory "$lock_path" 700 "TypeTone's $role lock" lock_fd
    lock_owned=true
    start_ticks=$(awk '{print $22}' "/proc/$guard_pid/stat")
    printf '%s %s\n' "$guard_pid" "$start_ticks" \
      | (umask 077; dd of="/proc/self/fd/$lock_fd/owner" \
          conv=excl oflag=nofollow status=none) \
      || fail "TypeTone could not create secure $role owner metadata."
    break
  fi

  open_verified_directory "$lock_path" 700 "TypeTone's $role lock" existing_lock_fd
  existing_anchor="/proc/self/fd/$existing_lock_fd"

  if owner_record=$(open_verified_owner_file "$existing_anchor"); then
    read -r old_pid old_start extra <<< "$owner_record"
    [[ -z ${extra:-} ]] \
      || fail "TypeTone found malformed $role owner metadata."

    if is_expected_guard_process "${old_pid:-}" "${old_start:-}"; then
      stop_expected_managed_process "$old_pid" "$old_start"
      exec {existing_lock_fd}<&-
      continue
    fi

    rm -f -- "$existing_anchor/owner"
  elif (( attempt < 6 )); then
    exec {existing_lock_fd}<&-
    sleep 0.05
    continue
  fi

  exec {existing_lock_fd}<&-
  rmdir -- "$lock_path" 2>/dev/null || fail \
    "TypeTone refused to remove an unexpected $role lock directory."
done

$lock_owned || fail "Another TypeTone $role process is still running."

# Remove only same-user orphans whose executable and complete role-specific
# argument shape prove they came from TypeTone's pinned or legacy invocation.
stop_orphaned_pinned_wayvibes

# Keep the recorded PID and start time while replacing Bash with Wayvibes.
# Quickshell now owns the actual audio process, so disabling the plugin cannot
# strand a child even if it stops the Process object with SIGKILL.
exec {lock_fd}<&-
exec {state_fd}<&-
exec {runtime_fd}<&-
exec "$@"
