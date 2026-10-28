#!/usr/bin/env bash
set -euo pipefail

action_root=${GITHUB_ACTION_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)}
consumer_root=${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}
baseline=${PUBLIC_API_BASELINE:-}

cd -- "$consumer_root"
nix develop --command bash "$action_root/run-in-consumer-devshell.sh" "$consumer_root" "$baseline"
