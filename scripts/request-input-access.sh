#!/usr/bin/env bash
set -euo pipefail

if (( $# != 0 )); then
  echo "Usage: request-input-access.sh" >&2
  exit 2
fi

current_user=$(/usr/bin/id -un)
if [[ ! $current_user =~ ^[a-z_][a-z0-9_-]*[$]?$ ]]; then
  echo "TypeTone cannot safely determine the current user." >&2
  exit 1
fi

[[ -x /usr/bin/pkexec ]] || {
  echo "pkexec is required to request input access." >&2
  exit 1
}

[[ -x /usr/bin/usermod ]] || {
  echo "usermod is required to grant input access." >&2
  exit 1
}

if /usr/bin/id -nG "$current_user" | tr ' ' '\n' | grep -Fxq input; then
  exit 0
fi

exec /usr/bin/pkexec /usr/bin/usermod -aG input -- "$current_user"
