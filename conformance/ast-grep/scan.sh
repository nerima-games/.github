#!/usr/bin/env bash
set -euo pipefail

consumer_root=${1:?usage: scan.sh <consumer-root>}
action_root=${GITHUB_ACTION_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
temporary=$(mktemp "$consumer_root/.ast-grep-conformance.XXXXXX")
config="$temporary.yml"
trap 'rm -f "$temporary" "$config"' EXIT
mv "$temporary" "$config"

yaml_quote() {
  local value=${1//\\/\\\\}
  value=${value//\"/\\\"}
  printf '"%s"' "$value"
}

{
  printf 'ruleDirs:\n'
  printf '  - %s\n' "$(yaml_quote "$action_root/core/rules")"
  printf '  - %s\n' "$(yaml_quote "$action_root/effect3/rules")"
  printf '  - %s\n' "$(yaml_quote "$action_root/public-api/rules")"
} > "$config"

ast-grep scan --config "$config" "$consumer_root"
