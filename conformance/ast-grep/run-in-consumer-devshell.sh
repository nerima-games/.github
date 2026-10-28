#!/usr/bin/env bash
set -euo pipefail

[[ $# -ge 1 && $# -le 2 ]] || {
  printf 'Usage: run-in-consumer-devshell.sh <consumer-root> [public-api-baseline]\n' >&2
  exit 2
}

action_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
consumer_root=$1
baseline=${2:-}

cd -- "$consumer_root"
ast-grep test --config "$action_root/sgconfig.yml"
bash "$action_root/scan.sh" "$consumer_root" "$baseline"
