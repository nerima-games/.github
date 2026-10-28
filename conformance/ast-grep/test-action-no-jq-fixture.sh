#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
fixture_root="$script_dir/public-api/path-fixtures/no-jq-consumer"
jq_flake=github:NixOS/nixpkgs/624af665418d3c65d544145b4d34ad696439570e#jq

if (
  cd -- "$fixture_root"
  nix develop --ignore-environment --command bash -euo pipefail -c '
    if command -v jq >/dev/null 2>&1; then
      printf "Fixture devShell unexpectedly provides jq.\\n" >&2
      exit 1
    fi
    command -v ast-grep >/dev/null
  '
); then
  :
else
  printf 'Fixture devShell must provide ast-grep and omit jq.\n' >&2
  exit 1
fi

(
  cd -- "$fixture_root"
  export GITHUB_ACTION_PATH="$script_dir"
  export GITHUB_WORKSPACE="$fixture_root"
  export PUBLIC_API_BASELINE=
  nix shell "$jq_flake" --command bash "$script_dir/run-consumer.sh"
)

printf 'Action wrapper passed with jq supplied outside the consumer devShell.\n'
