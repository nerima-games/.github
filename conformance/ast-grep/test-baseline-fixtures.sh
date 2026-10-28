#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
fixture_root="$script_dir/baseline-fixtures"

run_case() {
  local name=$1 status=0 output marker
  local expected_status
  shift
  expected_status=$1
  shift
  output=$(bash "$script_dir/scan.sh" "$fixture_root/$name/project" baseline.json 2>&1) || status=$?
  printf '%s\n' "$output"

  if [[ $expected_status == pass ]]; then
    if [[ $status -ne 0 ]] || ! grep -Fq 'Public-api baseline matches the current findings.' <<< "$output"; then
      printf 'Case %s expected a matching baseline, got status %s.\n' "$name" "$status" >&2
      exit 1
    fi
  else
    if [[ $status -ne 1 ]]; then
      printf 'Case %s expected a conformance failure with status 1, got %s.\n' "$name" "$status" >&2
      exit 1
    fi
    for marker in "$@"; do
      if ! grep -Fq -- "$marker" <<< "$output"; then
        printf 'Case %s did not report %s.\n' "$name" "$marker" >&2
        exit 1
      fi
    done
  fi
  printf 'Baseline fixture case passed: %s\n' "$name"
}

if [[ $# -gt 1 ]]; then
  printf 'Usage: test-baseline-fixtures.sh [new-finding|stale-baseline|exact-match|core-finding]\n' >&2
  exit 2
fi

case ${1:-all} in
  all)
    run_case new-finding fail 'New public-api occurrence' 'no-raw-exported-function-parameter' 'src/api.ts'
    run_case stale-baseline fail 'Stale public-api baseline occurrence' 'remove these tuples' 'no-raw-exported-function-parameter' 'src/api.ts'
    run_case exact-match pass
    run_case core-finding fail 'findings are not allowed' 'no-throw-in-src-ts' 'src/core.ts'
    ;;
  new-finding)
    run_case new-finding fail 'New public-api occurrence' 'no-raw-exported-function-parameter' 'src/api.ts'
    ;;
  stale-baseline)
    run_case stale-baseline fail 'Stale public-api baseline occurrence' 'remove these tuples' 'no-raw-exported-function-parameter' 'src/api.ts'
    ;;
  exact-match)
    run_case exact-match pass
    ;;
  core-finding)
    run_case core-finding fail 'findings are not allowed' 'no-throw-in-src-ts' 'src/core.ts'
    ;;
  *)
    printf 'Unknown baseline fixture case: %s\n' "$1" >&2
    exit 2
    ;;
esac
