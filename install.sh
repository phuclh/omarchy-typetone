#!/usr/bin/env bash
set -euo pipefail

plugin_id="io.github.phuclh.typetone"
wayvibes_url="https://github.com/sahaj-b/wayvibes.git"
wayvibes_commit="b43b76fd3a4181b7bd9029372b93d503ce91dced"
wayvibes_tree="41bc4e1951ddcffe96b359368a0412a2ced1c046"
wayvibes_soundpack_file_count=1480
wayvibes_soundpack_manifest_sha256="a98e6268a3b1025b178249224d7c0abfdfb6678fda854b328bca397eaabd458b"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
vendor_parent="$data_root/typetone/vendor/wayvibes"
vendor_dir="$vendor_parent/$wayvibes_commit"
settings_file="$config_root/wayvibes/omarchy.json"
plugins_root="$config_root/omarchy/plugins"
plugin_dir="$plugins_root/$plugin_id"
expected_typetone_commit=""
assume_yes=false
needs_relogin=false
setup_tmp=""
vendor_stage=""
plugin_stage=""

fail() {
  echo "TypeTone setup: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh --typetone-commit <40-character-commit> [--yes]

Install the verified TypeTone checkout and its pinned Wayvibes dependency on
Omarchy. The checkout must be clean, detached, and exactly match the supplied
commit.
EOF
}

confirm() {
  local prompt=$1
  $assume_yes && return 0
  [[ -t 0 && -t 1 ]] || fail "confirmation requires a terminal; rerun with --yes"
  if command -v gum >/dev/null 2>&1; then
    gum confirm "$prompt"
  else
    local answer
    read -r -p "$prompt [y/N] " answer
    [[ $answer == [yY] || $answer == [yY][eE][sS] ]]
  fi
}

cleanup() {
  local exit_status=$?
  trap - EXIT
  if [[ -n $plugin_stage && -d $plugin_stage ]]; then
    rm -rf -- "$plugin_stage"
  fi
  if [[ -n $vendor_stage && -d $vendor_stage ]]; then
    rm -rf -- "$vendor_stage"
  fi
  if [[ -n $setup_tmp && -d $setup_tmp ]]; then
    rm -rf -- "$setup_tmp"
  fi
  exit "$exit_status"
}
trap cleanup EXIT

while (( $# > 0 )); do
  case "$1" in
  --typetone-commit)
    (( $# >= 2 )) || fail "--typetone-commit requires a full commit"
    expected_typetone_commit=$2
    shift
    ;;
  --yes | -y)
    assume_yes=true
    ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    fail "unknown option: $1"
    ;;
  esac
  shift
done

[[ $expected_typetone_commit =~ ^[0-9a-f]{40}$ ]] \
  || fail "pass the exact 40-character reviewed commit with --typetone-commit"
[[ $data_root == /* && $config_root == /* ]] \
  || fail "XDG_DATA_HOME and XDG_CONFIG_HOME must be absolute paths"

for required_command in find git jq omarchy omarchy-shell omarchy-plugin-validate \
  sha256sum sort xargs; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "$required_command is required"
done

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
repo_root=$(git -C "$script_dir" rev-parse --show-toplevel 2>/dev/null) \
  || fail "run this installer from the commit-verified TypeTone Git checkout"
repo_root=$(cd -- "$repo_root" && pwd -P)
[[ $repo_root == "$script_dir" ]] \
  || fail "install.sh must be run from the TypeTone repository root"

source_head=$(git -C "$repo_root" rev-parse --verify HEAD^{commit}) \
  || fail "could not resolve the TypeTone checkout commit"
[[ $source_head == "$expected_typetone_commit" ]] \
  || fail "checkout is $source_head, not reviewed commit $expected_typetone_commit"
if git -C "$repo_root" symbolic-ref -q HEAD >/dev/null; then
  fail "the TypeTone checkout must be detached at the reviewed commit"
fi
[[ -z $(git -C "$repo_root" status --porcelain=v1 --untracked-files=all) ]] \
  || fail "the TypeTone checkout has local changes; refusing a non-reviewed tree"
git -C "$repo_root" fsck --strict --no-dangling "$expected_typetone_commit" \
  >/dev/null || fail "the TypeTone Git object failed integrity verification"

vendor_is_verified() {
  local source_record expected_source_record binary_record binary_hash
  local manifest_hash file_count

  [[ -d $vendor_dir && ! -L $vendor_dir \
    && -f $vendor_dir/wayvibes && ! -L $vendor_dir/wayvibes \
    && -x $vendor_dir/wayvibes \
    && -f $vendor_dir/SOURCE && ! -L $vendor_dir/SOURCE \
    && -f $vendor_dir/SHA256SUMS && ! -L $vendor_dir/SHA256SUMS \
    && -f $vendor_dir/SOUNDPACK_SHA256SUMS \
    && ! -L $vendor_dir/SOUNDPACK_SHA256SUMS \
    && -d $vendor_dir/soundpacks && ! -L $vendor_dir/soundpacks ]] || return 1

  source_record=$(<"$vendor_dir/SOURCE")
  expected_source_record=$(printf 'repository=%s\ncommit=%s\ntree=%s' \
    "$wayvibes_url" "$wayvibes_commit" "$wayvibes_tree")
  [[ $source_record == "$expected_source_record" ]] || return 1

  binary_record=$(<"$vendor_dir/SHA256SUMS")
  [[ $binary_record =~ ^[0-9a-f]{64}\ \ wayvibes$ ]] || return 1
  binary_hash=$(sha256sum "$vendor_dir/wayvibes") || return 1
  [[ "$binary_hash" == "${binary_record%  wayvibes}  $vendor_dir/wayvibes" ]] \
    || return 1

  manifest_hash=$(sha256sum "$vendor_dir/SOUNDPACK_SHA256SUMS") || return 1
  [[ ${manifest_hash%% *} == "$wayvibes_soundpack_manifest_sha256" ]] \
    || return 1
  file_count=$(find "$vendor_dir/soundpacks" -type f | wc -l)
  [[ $file_count == "$wayvibes_soundpack_file_count" ]] || return 1
  (
    cd -- "$vendor_dir/soundpacks"
    sha256sum --quiet --check ../SOUNDPACK_SHA256SUMS
  ) || return 1
}

cat <<EOF
TypeTone verified setup will:
  1. Install signed Arch build dependencies if they are missing.
  2. Fetch Wayvibes at the immutable commit below and compile it as your user.
  3. Grant your user global input-device access if needed.
  4. Install the pinned Wayvibes sound packs and select a keyboard.
  5. Install this exact TypeTone snapshot and enable it.

  TypeTone: $expected_typetone_commit
  Wayvibes: $wayvibes_commit

No remote shell script, AUR recipe, upstream installer, or moving Git branch is
executed. Wayvibes is compiled directly from its verified Git commit using a
fixed compiler command. Official Arch packages are verified by pacman.

Omarchy plugins run as unsandboxed user code. Membership in the Linux input
group lets every application running as your user read global keyboard and
mouse events, not only TypeTone.
EOF

confirm "Continue with this reviewed TypeTone setup?" || fail "cancelled"

echo "[1/5] Installing signed build dependencies if needed…"
omarchy pkg add gcc libevdev nlohmann-json pkgconf
for required_command in c++ pkg-config; do
  command -v "$required_command" >/dev/null 2>&1 \
    || fail "$required_command is unavailable after dependency installation"
done
pkg-config --exists libevdev || fail "the libevdev development files are unavailable"
[[ -f /usr/include/nlohmann/json.hpp ]] \
  || fail "the nlohmann-json development headers are unavailable"

if vendor_is_verified; then
  echo "[2/5] Reusing verified Wayvibes commit $wayvibes_commit."
else
  echo "[2/5] Fetching and building Wayvibes commit $wayvibes_commit…"
  setup_tmp=$(mktemp -d "${TMPDIR:-/tmp}/typetone-setup.XXXXXX")
  wayvibes_source="$setup_tmp/wayvibes"
  git -C "$setup_tmp" init --quiet wayvibes
  git -C "$wayvibes_source" remote add origin "$wayvibes_url"
  git -C "$wayvibes_source" fetch --quiet --depth=1 origin "$wayvibes_commit"
  fetched_wayvibes_commit=$(git -C "$wayvibes_source" rev-parse --verify FETCH_HEAD^{commit})
  [[ $fetched_wayvibes_commit == "$wayvibes_commit" ]] \
    || fail "Wayvibes resolved to $fetched_wayvibes_commit instead of $wayvibes_commit"
  git -C "$wayvibes_source" sparse-checkout init --cone
  git -C "$wayvibes_source" sparse-checkout set src soundpacks
  git -C "$wayvibes_source" checkout --quiet --detach "$wayvibes_commit"
  [[ $(git -C "$wayvibes_source" rev-parse HEAD) == "$wayvibes_commit" ]] \
    || fail "Wayvibes checkout verification failed"
  [[ $(git -C "$wayvibes_source" rev-parse "$wayvibes_commit^{tree}") \
    == "$wayvibes_tree" ]] || fail "Wayvibes tree verification failed"
  [[ -z $(git -C "$wayvibes_source" status --porcelain=v1 --untracked-files=all) ]] \
    || fail "Wayvibes checkout is not clean"
  git -C "$wayvibes_source" fsck --strict --no-dangling "$wayvibes_commit" \
    >/dev/null || fail "the Wayvibes Git object failed integrity verification"

  read -r -a evdev_flags <<< "$(pkg-config --cflags --libs libevdev)"
  c++ -std=c++17 -I"$wayvibes_source/src" \
    -o "$setup_tmp/wayvibes-bin" \
    "$wayvibes_source/src/main.cpp" \
    "$wayvibes_source/src/audio.cpp" \
    "$wayvibes_source/src/device.cpp" \
    "$wayvibes_source/src/config.cpp" \
    "${evdev_flags[@]}"
  "$setup_tmp/wayvibes-bin" --help >/dev/null

  install -d -m 0755 "$vendor_parent"
  vendor_stage=$(mktemp -d "$vendor_parent/.install.XXXXXX")
  install -m 0755 "$setup_tmp/wayvibes-bin" "$vendor_stage/wayvibes"
  cp -a "$wayvibes_source/soundpacks" "$vendor_stage/soundpacks"
  printf 'repository=%s\ncommit=%s\ntree=%s\n' \
    "$wayvibes_url" "$wayvibes_commit" "$wayvibes_tree" \
    > "$vendor_stage/SOURCE"
  (
    cd -- "$vendor_stage"
    sha256sum wayvibes > SHA256SUMS
    cd -- soundpacks
    find . -type f -print0 | LC_ALL=C sort -z | xargs -0 sha256sum \
      > ../SOUNDPACK_SHA256SUMS
  )
  generated_manifest_hash=$(sha256sum "$vendor_stage/SOUNDPACK_SHA256SUMS")
  [[ ${generated_manifest_hash%% *} == "$wayvibes_soundpack_manifest_sha256" ]] \
    || fail "the Wayvibes sound-pack manifest did not match the reviewed commit"
fi

current_user=$(id -un)
current_uid=$(id -u)
if id -nG | tr ' ' '\n' | grep -Fxq input; then
  echo "[3/5] $current_user already has active input-device access."
elif getent group input | awk -F: -v user="$current_user" '
  $4 != "" {
    count = split($4, members, ",")
    for (i = 1; i <= count; i++) if (members[i] == user) found = 1
  }
  END { exit found ? 0 : 1 }
  '; then
  needs_relogin=true
  echo "[3/5] Input-device access is configured but needs a new login session."
else
  echo "[3/5] Adding $current_user to the input group (sudo may ask for your password)…"
  sudo usermod -aG input "$current_user"
  needs_relogin=true
fi

keyboard_name=""
if [[ -f $settings_file ]] && jq -e '
  (.deviceName // "") | type == "string" and length > 0
  ' "$settings_file" >/dev/null 2>&1; then
  keyboard_name=$(jq -r '.deviceName' "$settings_file")
  echo "[4/5] Keeping the configured keyboard: $keyboard_name"
else
  mapfile -t keyboards < <(awk '
    BEGIN { RS = ""; FS = "\n" }
    {
      name = ""
      handlers = ""
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^N: Name=/) {
          name = $i
          sub(/^N: Name="/, "", name)
          sub(/"$/, "", name)
        }
        if ($i ~ /^H: Handlers=/) handlers = $i
      }
      if (handlers ~ /(^|[[:space:]])kbd([[:space:]]|$)/ && name != "" &&
          name !~ /^(Power Button|Sleep Button|Video Bus)$/) print name
    }
  ' /proc/bus/input/devices | awk '!seen[$0]++')

  if (( ${#keyboards[@]} == 1 )); then
    keyboard_name=${keyboards[0]}
  elif (( ${#keyboards[@]} > 1 )) && [[ -t 0 && -t 1 ]] && command -v gum >/dev/null 2>&1; then
    keyboard_name=$(printf '%s\n' "${keyboards[@]}" |
      gum choose --header="Keyboard TypeTone should listen to") || true
  fi

  if [[ -n $keyboard_name ]]; then
    mkdir -p "$(dirname -- "$settings_file")"
    settings_tmp=$(mktemp "$(dirname -- "$settings_file")/.omarchy.json.XXXXXX")
    if [[ -f $settings_file ]] && jq -e 'type == "object"' "$settings_file" >/dev/null 2>&1; then
      jq --arg keyboard "$keyboard_name" '.deviceName = $keyboard' \
        "$settings_file" > "$settings_tmp"
    else
      jq -n --arg keyboard "$keyboard_name" '{deviceName: $keyboard}' > "$settings_tmp"
    fi
    mv "$settings_tmp" "$settings_file"
    echo "[4/5] Selected keyboard: $keyboard_name"
  else
    echo "[4/5] No keyboard was selected; choose one from TypeTone settings."
  fi
fi

echo "[5/5] Installing TypeTone commit $expected_typetone_commit…"
mkdir -p "$plugins_root"
plugin_stage=$(mktemp -d "$plugins_root/.typetone.install.XXXXXX")
git -C "$plugin_stage" init --quiet
git -C "$plugin_stage" fetch --quiet --depth=1 "$repo_root" \
  "$expected_typetone_commit"
[[ $(git -C "$plugin_stage" rev-parse FETCH_HEAD) == "$expected_typetone_commit" ]] \
  || fail "staged TypeTone fetch did not resolve to the reviewed commit"
git -C "$plugin_stage" checkout --quiet --detach "$expected_typetone_commit"
[[ $(git -C "$plugin_stage" rev-parse HEAD) == "$expected_typetone_commit" ]] \
  || fail "staged TypeTone commit verification failed"
[[ -z $(git -C "$plugin_stage" remote) ]] \
  || fail "staged TypeTone snapshot unexpectedly has a remote"
[[ -z $(git -C "$plugin_stage" status --porcelain=v1 --untracked-files=all) ]] \
  || fail "staged TypeTone snapshot is not clean"
omarchy-plugin-validate "$plugin_stage"

was_installed=false
was_enabled=false
if [[ -e $plugin_dir || -L $plugin_dir ]]; then
  was_installed=true
  if omarchy plugin list --json | jq -e --arg id "$plugin_id" \
    'any(.[]; .id == $id and .enabled == true)' >/dev/null 2>&1; then
    was_enabled=true
  fi
fi

plugin_backup=""
if $was_installed; then
  backup_base="$plugins_root/.$plugin_id.backup.$(date -u +%Y%m%d%H%M%S)"
  plugin_backup=$backup_base
  suffix=1
  while [[ -e $plugin_backup || -L $plugin_backup ]]; do
    plugin_backup="$backup_base-$suffix"
    suffix=$((suffix + 1))
  done
  if $was_enabled; then
    omarchy plugin disable "$plugin_id"
    playback_stopped=false
    for attempt in {1..100}; do
      guard_found=false
      for process_path in /proc/[0-9]*; do
        process_owner=$(stat -Lc '%u' -- "$process_path" 2>/dev/null) || continue
        [[ $process_owner == "$current_uid" ]] || continue
        mapfile -d '' -t process_args < "$process_path/cmdline" 2>/dev/null \
          || continue
        if (( ${#process_args[@]} >= 5 )) \
          && [[ ${process_args[0]##*/} == bash \
            && ${process_args[1]} == "$plugin_dir/scripts/run-exclusive-wayvibes.sh" \
            && ( ${process_args[2]} == keyboard || ${process_args[2]} == mouse ) \
            && ${process_args[3]} == -- ]]; then
          guard_found=true
          break
        fi
      done
      if ! $guard_found; then
        playback_stopped=true
        break
      fi
      sleep 0.05
    done
    if ! $playback_stopped; then
      omarchy plugin enable "$plugin_id" || true
      fail "TypeTone playback supervisors did not stop before the verified upgrade"
    fi
  fi
fi

cleanup_typetone_playback() {
  local role

  [[ -x $vendor_dir/wayvibes && ! -L $vendor_dir/wayvibes ]] || return 0
  for role in keyboard mouse; do
    "$plugin_stage/scripts/run-exclusive-wayvibes.sh" \
      "$role" -- "$vendor_dir/wayvibes" --help >/dev/null
  done
}

# Stop the loaded plugin before replacing a binary it may still be executing.
# Otherwise Linux correctly keeps the old unlinked executable alive, which
# prevents a later guard from proving that the process uses the reviewed path.
if [[ -n $vendor_stage ]]; then
  vendor_backup=""
  if [[ -e $vendor_dir || -L $vendor_dir ]]; then
    [[ -d $vendor_dir && ! -L $vendor_dir ]] \
      || fail "refusing to replace an unexpected Wayvibes vendor path: $vendor_dir"
    vendor_backup="$vendor_parent/.previous-$wayvibes_commit-$$"
    mv -- "$vendor_dir" "$vendor_backup"
  fi
  if ! mv -- "$vendor_stage" "$vendor_dir"; then
    if [[ -n $vendor_backup && -d $vendor_backup ]]; then
      mv -- "$vendor_backup" "$vendor_dir"
    fi
    if $was_enabled; then
      omarchy plugin enable "$plugin_id" || true
    fi
    fail "could not install the pinned Wayvibes build"
  fi
  vendor_stage=""
  if [[ -n $vendor_backup && -d $vendor_backup ]]; then
    rm -rf -- "$vendor_backup"
  fi
fi

# The staged, reviewed guard validates and stops any legacy or pinned audio
# process stranded when Quickshell unloaded the prior plugin. Its short --help
# invocation also proves the installed binary can start before the QML swap.
if $was_installed; then
  cleanup_typetone_playback
fi

if $was_installed; then
  if ! mv -- "$plugin_dir" "$plugin_backup"; then
    if $was_enabled; then
      omarchy plugin enable "$plugin_id" || true
    fi
    fail "could not preserve the previous TypeTone checkout"
  fi
fi
if ! mv -- "$plugin_stage" "$plugin_dir"; then
  if [[ -n $plugin_backup && ( -e $plugin_backup || -L $plugin_backup ) ]]; then
    mv -- "$plugin_backup" "$plugin_dir"
    omarchy-shell shell rescanPlugins >/dev/null || true
    if $was_enabled; then
      omarchy plugin enable "$plugin_id" || true
    fi
  fi
  fail "could not install the TypeTone snapshot"
fi
plugin_stage=""

if ! omarchy-shell shell rescanPlugins >/dev/null; then
  failed_plugin="$plugins_root/.$plugin_id.failed.$$"
  mv -- "$plugin_dir" "$failed_plugin" || true
  if [[ -n $plugin_backup && ( -e $plugin_backup || -L $plugin_backup ) ]]; then
    mv -- "$plugin_backup" "$plugin_dir"
    plugin_backup=""
    omarchy-shell shell rescanPlugins >/dev/null || true
    if $was_enabled; then
      omarchy plugin enable "$plugin_id" || true
    fi
  fi
  fail "Omarchy rejected the installed snapshot; failed files are at $failed_plugin"
fi
if ! $was_installed; then
  omarchy plugin enable "$plugin_id"
elif $was_enabled; then
  echo "Reloading the Omarchy shell so the reviewed QML snapshot is active…"
  omarchy restart shell
  shell_ready=false
  for attempt in {1..100}; do
    if omarchy-shell shell listPlugins >/dev/null 2>&1; then
      shell_ready=true
      break
    fi
    sleep 0.1
  done
  $shell_ready || fail "the Omarchy shell did not become ready after reloading"
  omarchy plugin enable "$plugin_id"
fi

echo
echo "TypeTone setup is complete at commit $expected_typetone_commit."
if [[ -n $plugin_backup ]]; then
  echo "The previous plugin checkout is preserved at: $plugin_backup"
fi
if $needs_relogin; then
  echo "Restart your computer once so TypeTone can access input devices."
else
  echo "TypeTone is ready in the Omarchy bar."
fi
