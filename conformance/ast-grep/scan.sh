#!/usr/bin/env bash
set -euo pipefail

usage() {
  printf 'Usage:\n  scan.sh <consumer-root> [public-api-baseline]\n  scan.sh --write-baseline <relative-path> [consumer-root]\n' >&2
  exit 2
}

mode="zero"
if [[ ${1:-} == --write-baseline ]]; then
  [[ $# -ge 2 && $# -le 3 ]] || usage
  mode="write"
  baseline_path=$2
  consumer_arg=${3:-.}
else
  [[ $# -ge 1 && $# -le 2 ]] || usage
  consumer_arg=$1
  baseline_path=${2:-}
  [[ -z $baseline_path ]] || mode="compare"
fi

if [[ ! -d $consumer_arg ]]; then
  printf 'Consumer root is not a directory: %s\n' "$consumer_arg" >&2
  exit 2
fi
consumer_root=$(cd -- "$consumer_arg" && pwd -P)

validate_baseline_path() {
  if [[ -z $1 || $1 == /* ]]; then
    printf 'Baseline path must be consumer-repository-relative: %s\n' "$1" >&2
    exit 2
  fi
  case "/$1/" in
    *"/../"*) printf 'Baseline path must stay inside the consumer repository: %s\n' "$1" >&2; exit 2 ;;
  esac
}
if [[ $mode != zero ]]; then
  validate_baseline_path "$baseline_path"
fi

action_root=${GITHUB_ACTION_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)}
temporary=$(mktemp "$consumer_root/.ast-grep-conformance.XXXXXX")
config="$temporary.yml"
scan_json=$(mktemp "${TMPDIR:-/tmp}/ast-grep-scan.XXXXXX")
scan_stderr=$(mktemp "${TMPDIR:-/tmp}/ast-grep-scan-stderr.XXXXXX")
findings=$(mktemp "${TMPDIR:-/tmp}/ast-grep-findings.XXXXXX")
current_public=$(mktemp "${TMPDIR:-/tmp}/ast-grep-public.XXXXXX")
diff_file=$(mktemp "${TMPDIR:-/tmp}/ast-grep-diff.XXXXXX")
baseline_tmp=
cleanup() {
  rm -f "$temporary" "$config" "$scan_json" "$scan_stderr" "$findings" "$current_public" "$diff_file" "${baseline_tmp:-}"
}
trap cleanup EXIT
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

rule_ids_json() {
  local rule_dir=$1 rule_file
  for rule_file in "$rule_dir"/*.yml; do
    [[ -f $rule_file ]] || continue
    sed -n 's/^id:[[:space:]]*//p' "$rule_file"
  done | jq -Rsc 'split("\n") | map(select(length > 0))'
}
core_ids=$(rule_ids_json "$action_root/core/rules")
effect3_ids=$(rule_ids_json "$action_root/effect3/rules")
public_ids=$(rule_ids_json "$action_root/public-api/rules")

scan_status=0
if ast-grep scan --json --config "$config" "$consumer_root" > "$scan_json" 2> "$scan_stderr"; then
  scan_status=0
else
  scan_status=$?
fi
if (( scan_status > 1 )); then
  cat "$scan_stderr" >&2
  printf 'ast-grep scan failed with status %s.\n' "$scan_status" >&2
  exit "$scan_status"
fi
if ! jq -e 'type == "array" and all(.[]; (.ruleId | type) == "string" and (.file | type) == "string" and (.text | type) == "string")' "$scan_json" >/dev/null; then
  cat "$scan_stderr" >&2
  printf 'ast-grep scan did not return the expected JSON findings array.\n' >&2
  exit 2
fi

root_prefix="${consumer_root%/}/"
jq --arg root_prefix "$root_prefix" --argjson core "$core_ids" --argjson effect3 "$effect3_ids" --argjson public "$public_ids" '
  map(
    . as $match
    | {
        ruleId: $match.ruleId,
        pack: (
          if ($public | index($match.ruleId)) != null then "public-api"
          elif (($core + $effect3) | index($match.ruleId)) != null then "core/effect3"
          else "unclassified"
          end
        ),
        file: ($match.file | if startswith($root_prefix) then .[($root_prefix | length):] else error("scan result path is outside consumer root: " + .) end),
        text: ($match.text | gsub("[[:space:]]+"; " ") | sub("^ "; "") | sub(" $"; ""))
      }
  )
' "$scan_json" > "$findings"

finding_count=$(jq 'length' "$findings")
if (( finding_count == 0 && scan_status != 0 || finding_count > 0 && scan_status != 1 )); then
  cat "$scan_stderr" >&2
  printf 'ast-grep status %s does not match its %s JSON finding(s).\n' "$scan_status" "$finding_count" >&2
  exit 2
fi

jq -S '[.[] | select(.pack == "public-api") | {ruleId, file, text, count: 1}]
  | group_by([.ruleId, .file, .text])
  | map({count: length, file: .[0].file, ruleId: .[0].ruleId, text: .[0].text})
  | sort_by([.ruleId, .file, .text])' "$findings" > "$current_public"

strict_count=$(jq '[.[] | select(.pack != "public-api")] | length' "$findings")
if (( strict_count > 0 )); then
  cat "$scan_stderr" >&2
  printf 'Core, effect3, and unclassified findings are not allowed, even with a public-api baseline:\n' >&2
  jq -r '.[] | select(.pack != "public-api") | "  \(.pack): ruleId=\(.ruleId), file=\(.file), text=\(.text | tojson)"' "$findings" >&2
  exit 1
fi

if [[ $mode == zero ]]; then
  if (( finding_count > 0 )); then
    cat "$scan_stderr" >&2
    printf 'Conformance scan found %s violation(s); all packs require zero findings without a baseline:\n' "$finding_count" >&2
    jq -r '.[] | "  \(.pack): ruleId=\(.ruleId), file=\(.file), text=\(.text | tojson)"' "$findings" >&2
    exit 1
  fi
  printf 'Conformance scan passed with no findings.\n'
  exit 0
fi

validate_baseline_json() {
  local path=$1
  if ! jq -e '
    def normalized_text: gsub("[[:space:]]+"; " ") | sub("^ "; "") | sub(" $"; "");
    def valid:
      type == "object"
      and keys == ["count", "file", "ruleId", "text"]
      and (.ruleId | type == "string" and length > 0)
      and (.file | type == "string" and length > 0)
      and (.file | startswith("/") | not)
      and (.file | split("/") | index("..") == null)
      and (.text | type == "string")
      and (.text == (.text | normalized_text))
      and (.count | type == "number" and . > 0 and floor == .);
    type == "array"
    and all(.[]; valid)
    and length == ([.[] | [.ruleId, .file, .text]] | unique | length)
  ' "$path" >/dev/null; then
    printf 'Public-api baseline has an invalid JSON schema or duplicate tuple: %s\n' "$baseline_path" >&2
    return 2
  fi
}

if [[ $mode == write ]]; then
  baseline_file="${consumer_root%/}/$baseline_path"
  if [[ -e $baseline_file || -L $baseline_file ]]; then
    if [[ ! -f $baseline_file ]]; then
      printf 'Existing public-api baseline is not a regular file: %s\n' "$baseline_path" >&2
      exit 2
    fi
    validate_baseline_json "$baseline_file"
    jq -S -n --slurpfile current "$current_public" --slurpfile baseline "$baseline_file" '
      ($current[0]) as $current
      | ($baseline[0]) as $baseline
      | [
          $current[] as $now
          | (($baseline | map(select(.ruleId == $now.ruleId and .file == $now.file and .text == $now.text)) | .[0]) // {count: 0}) as $saved
          | select($now.count > $saved.count)
          | {count: ($now.count - $saved.count), file: $now.file, ruleId: $now.ruleId, text: $now.text}
        ]
    ' > "$diff_file"
    expansion_count=$(jq 'length' "$diff_file")
    if (( expansion_count > 0 )); then
      printf 'Refusing to grow the existing public-api baseline; these occurrences exceed it:\n' >&2
      jq -r '.[] | "  ruleId=\(.ruleId), file=\(.file), text=\(.text | tojson), count=\(.count)"' "$diff_file" >&2
      exit 1
    fi
  fi
  mkdir -p "$(dirname -- "$baseline_file")"
  baseline_tmp=$(mktemp "$baseline_file.XXXXXX")
  jq -S . "$current_public" > "$baseline_tmp"
  chmod 644 "$baseline_tmp"
  mv -f "$baseline_tmp" "$baseline_file"
  baseline_tmp=
  printf 'Wrote public-api baseline with %s tuple(s) to %s.\n' "$(jq 'length' "$current_public")" "$baseline_path"
  exit 0
fi

baseline_file="${consumer_root%/}/$baseline_path"
if [[ ! -f $baseline_file ]]; then
  printf 'Public-api baseline does not exist: %s\n' "$baseline_path" >&2
  exit 2
fi
validate_baseline_json "$baseline_file"

jq -S -n --slurpfile current "$current_public" --slurpfile baseline "$baseline_file" '
  ($current[0]) as $current
  | ($baseline[0]) as $baseline
  | {
      new: [
        $current[] as $now
        | (($baseline | map(select(.ruleId == $now.ruleId and .file == $now.file and .text == $now.text)) | .[0]) // {count: 0}) as $saved
        | select($now.count > $saved.count)
        | {count: ($now.count - $saved.count), file: $now.file, ruleId: $now.ruleId, text: $now.text}
      ],
      stale: [
        $baseline[] as $saved
        | (($current | map(select(.ruleId == $saved.ruleId and .file == $saved.file and .text == $saved.text)) | .[0]) // {count: 0}) as $now
        | select($saved.count > $now.count)
        | {count: ($saved.count - $now.count), file: $saved.file, ruleId: $saved.ruleId, text: $saved.text}
      ]
    }
' > "$diff_file"

new_count=$(jq '.new | length' "$diff_file")
stale_count=$(jq '.stale | length' "$diff_file")
if (( new_count > 0 || stale_count > 0 )); then
  cat "$scan_stderr" >&2
  printf 'Public-api baseline ratchet failed.\n' >&2
  if (( new_count > 0 )); then
    printf 'New public-api occurrence(s) are not allowed; fix them before the baseline can shrink:\n' >&2
    jq -r '.new[] | "  ruleId=\(.ruleId), file=\(.file), text=\(.text | tojson), count=\(.count)"' "$diff_file" >&2
  fi
  if (( stale_count > 0 )); then
    printf 'Stale public-api baseline occurrence(s); remove these tuples from the baseline:\n' >&2
    jq -r '.stale[] | "  remove from baseline: ruleId=\(.ruleId), file=\(.file), text=\(.text | tojson), count=\(.count)"' "$diff_file" >&2
  fi
  exit 1
fi
printf 'Public-api baseline matches the current findings.\n'
