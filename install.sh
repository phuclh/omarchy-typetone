#!/usr/bin/env bash
set -euo pipefail

plugin_id="io.github.phuclh.typetone"
plugin_url="https://github.com/phuclh/omarchy-typetone.git"
wayvibes_url="https://github.com/sahaj-b/wayvibes.git"
data_root="${XDG_DATA_HOME:-$HOME/.local/share}"
config_root="${XDG_CONFIG_HOME:-$HOME/.config}"
soundpack_root="$data_root/wayvibes/soundpacks"
settings_file="$config_root/wayvibes/omarchy.json"
plugin_dir="$config_root/omarchy/plugins/$plugin_id"
assume_yes=false
needs_relogin=false

fail() {
  echo "TypeTone setup: $*" >&2
  exit 1
}

usage() {
  cat <<'EOF'
Usage: install.sh [--yes]

Install TypeTone and its Wayvibes dependency on Omarchy.
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

while (( $# > 0 )); do
  case "$1" in
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

command -v omarchy >/dev/null 2>&1 || fail "Omarchy is required"
command -v git >/dev/null 2>&1 || fail "git is required"
command -v jq >/dev/null 2>&1 || fail "jq is required"

cat <<'EOF'
TypeTone guided setup will:
  1. Install wayvibes-git from the AUR if needed.
  2. Grant your user access to keyboard and mouse input events if needed.
  3. Download the upstream Wayvibes keyboard sound packs if needed.
  4. Select a detected keyboard and install the TypeTone plugin from GitHub.

Omarchy plugins run as unsandboxed user code. Continue only if you trust and
have reviewed TypeTone and Wayvibes.
EOF

confirm "Continue with TypeTone setup?" || fail "cancelled"

if command -v wayvibes >/dev/null 2>&1; then
  echo "[1/4] Wayvibes is already installed."
else
  echo "[1/4] Installing wayvibes-git from the AUR…"
  omarchy pkg aur add wayvibes-git
fi

current_user=$(id -un)
if id -nG | tr ' ' '\n' | grep -Fxq input; then
  echo "[2/4] $current_user already has active input-device access."
elif getent group input | awk -F: -v user="$current_user" '
  $4 != "" {
    count = split($4, members, ",")
    for (i = 1; i <= count; i++) if (members[i] == user) found = 1
  }
  END { exit found ? 0 : 1 }
  '; then
  needs_relogin=true
  echo "[2/4] Input-device access is configured but needs a new login session."
else
  echo "[2/4] Adding $current_user to the input group (sudo may ask for your password)…"
  sudo usermod -aG input "$current_user"
  needs_relogin=true
fi

if [[ -f "$soundpack_root/nk-cream/config.json" ]]; then
  echo "[3/4] Wayvibes keyboard sound packs are already available."
else
  echo "[3/4] Downloading Wayvibes keyboard sound packs…"
  setup_tmp=$(mktemp -d "${TMPDIR:-/tmp}/typetone-setup.XXXXXX")
  cleanup() {
    [[ -n ${setup_tmp:-} && -d $setup_tmp ]] && rm -rf -- "$setup_tmp"
  }
  trap cleanup EXIT

  git clone --depth 1 --filter=blob:none --sparse "$wayvibes_url" "$setup_tmp/wayvibes"
  git -C "$setup_tmp/wayvibes" sparse-checkout set soundpacks
  mkdir -p "$soundpack_root"
  cp -a "$setup_tmp/wayvibes/soundpacks/." "$soundpack_root/"
fi

keyboard_name=""
if [[ -f $settings_file ]] && jq -e '
  (.deviceName // "") | type == "string" and length > 0
  ' "$settings_file" >/dev/null 2>&1; then
  keyboard_name=$(jq -r '.deviceName' "$settings_file")
  echo "[4/4] Keeping the configured keyboard: $keyboard_name"
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
    echo "[4/4] Selected keyboard: $keyboard_name"
  else
    echo "[4/4] No keyboard was selected; Wayvibes will ask on its first interactive run."
  fi
fi

if [[ -d $plugin_dir ]]; then
  echo "TypeTone is already installed; updating it…"
  if [[ -d $plugin_dir/.git ]]; then
    omarchy plugin update "$plugin_id" --yes
  else
    echo "The existing TypeTone directory is not git-managed; leaving its files unchanged."
  fi
  omarchy-shell shell rescanPlugins >/dev/null
  omarchy plugin enable "$plugin_id"
else
  echo "Installing and enabling TypeTone…"
  omarchy plugin add "$plugin_url" --enable --yes
fi

echo
echo "TypeTone setup is complete."
if $needs_relogin; then
  echo "Log out and back in once so TypeTone can access input devices."
else
  echo "TypeTone is ready in the Omarchy bar."
fi
