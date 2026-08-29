#!/usr/bin/env bash
set -euo pipefail

if (( $# != 1 )); then
  echo "Usage: repair-keyboard-soundpack.sh <soundpack>" >&2
  exit 2
fi

soundpack_path=$1
config_path="$soundpack_path/config.json"

if [[ ! -d $soundpack_path || ! -f $config_path ]]; then
  echo "Keyboard sound pack is missing: $soundpack_path" >&2
  exit 1
fi

command -v jq >/dev/null 2>&1 || {
  echo "jq is required to validate keyboard sound packs." >&2
  exit 1
}

if ! jq -e '.defines | type == "object"' "$config_path" >/dev/null 2>&1; then
  echo "Keyboard sound pack has an invalid config: $config_path" >&2
  exit 1
fi

is_safe_sample_name() {
  local sample_name=$1
  [[ -n $sample_name && $sample_name != /* && $sample_name != */* &&
    $sample_name != . && $sample_name != .. ]]
}

declare -a mapped_samples=()
declare -A seen_samples=()

while IFS= read -r -d '' sample_name; do
  is_safe_sample_name "$sample_name" || continue
  [[ -n ${seen_samples[$sample_name]+present} ]] && continue
  seen_samples[$sample_name]=1
  mapped_samples+=("$sample_name")
done < <(jq -j '.defines[]? | select(type == "string") | ., "\u0000"' "$config_path")

fallback_sample=""
for sample_name in "${mapped_samples[@]}"; do
  if [[ -f "$soundpack_path/$sample_name" ]]; then
    fallback_sample=$sample_name
    break
  fi
done

if [[ -z $fallback_sample ]]; then
  echo "Keyboard sound pack has no usable mapped samples: $soundpack_path" >&2
  exit 1
fi

repaired_count=0
for sample_name in "${mapped_samples[@]}"; do
  sample_path="$soundpack_path/$sample_name"
  [[ -e $sample_path ]] && continue

  if [[ -L $sample_path ]]; then
    echo "Cannot repair dangling sample link: $sample_path" >&2
    exit 1
  fi

  if ! ln -s -- "$fallback_sample" "$sample_path" 2>/dev/null; then
    [[ -e $sample_path ]] && continue
    echo "Cannot add compatibility sample: $sample_path" >&2
    exit 1
  fi
  ((repaired_count += 1))
done

if (( repaired_count > 0 )); then
  echo "TypeTone repaired $repaired_count missing sample mapping(s) in ${soundpack_path##*/}."
fi
