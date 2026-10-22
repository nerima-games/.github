#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fixture_root="$script_dir/public-api/path-fixtures/project"

status=0
output=$(bash "$script_dir/scan.sh" "$fixture_root" 2>&1) || status=$?
if [[ $status -ne 1 ]]; then
  printf 'Expected the invalid path fixtures to fail with status 1, got %s.\n%s\n' "$status" "$output" >&2
  exit 1
fi

for path in src/library.ts apps/web/runtime.ts apps/web/runtime.tsx src/api.ts src/api.tsx; do
  if ! grep -Fq "$path" <<< "$output"; then
    printf 'Expected a finding in %s.\n%s\n' "$path" "$output" >&2
    exit 1
  fi
done

for path in apps/web/main.ts apps/web/main.tsx src/browser.ts src/browser.tsx test/service.test.ts tests/integration.test.tsx packages/core/test/service.ts src/exception.ts; do
  if grep -Fq "$path" <<< "$output"; then
    printf 'Unexpected finding in allowed path %s.\n%s\n' "$path" "$output" >&2
    exit 1
  fi
done

printf '%s\n' "$output"
printf 'Path fixtures found the expected violations; entrypoint, test, and exception paths stayed clean.\n'
