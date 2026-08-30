#!/usr/bin/env bash
# Check nerima-games repositories against the org-wide Wave 0 standard
# (PACKAGE_STANDARD.md, DOCS_STANDARD.md, TEST_STANDARD.md, RELEASE_STANDARD.md
# — see ../CONFORMANCE.md for the checklist this script implements).
#
#   ./check-conformance.sh <dir-containing-the-repos> [repo ...]
#
# Exit status is 1 if any non-skipped check fails, so this is usable as a gate.
# Read-only: it runs no git command that writes.

set -uo pipefail

command -v jq >/dev/null 2>&1 || {
  echo "check-conformance.sh: jq is required to parse package.json (main/exports/publishConfig are nested since the Wave 0 dist migration; a line-oriented grep cannot match them reliably)." >&2
  exit 2
}

ROOT="${1:?usage: check-conformance.sh <dir-containing-the-repos> [repo ...]}"
shift || true

# The 16 repositories in this org, in the order PACKAGE_STANDARD.md lists them.
# Used as the default set when no repo names are given on the command line.
DEFAULT_REPOS=(
  mc-audio mc-compose mc-dev-meta mc-kernel mc-meshing mc-noise mc-physics
  mc-playground-kit mc-render mc-save mc-sim mc-worldgen
  mx-gameplay mx-multiplayer mx-redstone mx-ui
)

# ---------------------------------------------------------------------------
# Named exceptions. Each list is a per-repository, per-reason carve-out from
# one specific check — never a blanket skip of everything for that repo — and
# each has a *_reason() function so the printed skip line says WHY, the same
# shape nerima-lisp's check-conformance.sh uses for NON_LISP_PACKAGES.
# ---------------------------------------------------------------------------

# docs/porting.md (§5 of CONFORMANCE.md / DOCS_STANDARD.md §2-2): mc-kernel
# synthesizes vocabulary from multiple reference-impl locations rather than
# porting one identifiable module, so "porting source -> measured LOC" does
# not apply to it. This is a permanent, intentional exemption, not a
# migration-in-progress gap.
PORTING_EXEMPT=" mc-kernel "

porting_exempt_reason() {
  case $1 in
    mc-kernel) printf 'kernel synthesizes vocabulary from multiple reference-impl locations, not a single ported module' ;;
    *) printf 'porting.md does not apply to this repository' ;;
  esac
}

# docs/ page set (DOCS_STANDARD.md §2-3): mc-dev-meta sits outside the 4-tier
# dependency graph (it is the pnpm-workspace bundler for the other 15 repos)
# and its docs/README.md documents its own replacement page set
# (workflow.md / manifest.md / step2-status.md) instead of design-notes.md and
# porting.md. Its absence of those two pages is a declared exemption, not a
# conformance gap.
DEV_TOOL_REPOS=" mc-dev-meta "

dev_tool_reason() {
  case $1 in
    mc-dev-meta) printf 'dev-tooling repo outside the 4-tier dependency graph; DOCS_STANDARD.md §2-3 gives it its own page set (workflow.md/manifest.md/step2-status.md) in place of this page' ;;
    *) printf 'dev-tooling repository, standard page set does not apply' ;;
  esac
}

# vitest.config.ts coverage thresholds (TEST_STANDARD.md §3): Wave 0 rolled
# the 4-metric gate out to all 16 repositories at 99% with no staged
# exceptions, then raised the bar to 100% once the last stragglers closed the
# gap. There are currently no named exemptions; this list stays as the
# mechanism (not deleted) so a future genuine known-gap has somewhere to go
# without re-inventing the skip/reason plumbing.
COVERAGE_EXEMPT=""

coverage_exempt_reason() {
  case $1 in
    *) printf 'coverage gate known-gap' ;;
  esac
}

# .github/workflows/release.yaml (RELEASE_STANDARD.md): mc-dev-meta is
# "private": true and explicitly out of RELEASE_STANDARD.md's scope (its own
# §0 excludes it by name) — it is never published, so it has no release
# workflow to check for.
RELEASE_EXEMPT=" mc-dev-meta "

release_exempt_reason() {
  case $1 in
    mc-dev-meta) printf 'private, unpublished pnpm-workspace binder; RELEASE_STANDARD.md scopes itself to the other 15 repositories' ;;
    *) printf 'release workflow does not apply to this repository' ;;
  esac
}

red() { printf '\033[31m%s\033[0m' "$1"; }
green() { printf '\033[32m%s\033[0m' "$1"; }
yellow() { printf '\033[33m%s\033[0m' "$1"; }

fail_count=0
check_count=0

# ok <condition-exit-status> <label> [detail]
ok() {
  local status=$1 label=$2 detail=${3:-}
  check_count=$((check_count + 1))
  if [[ $status -eq 0 ]]; then
    printf '  %s %s\n' "$(green ✓)" "$label"
  else
    fail_count=$((fail_count + 1))
    printf '  %s %s%s\n' "$(red ✗)" "$label" "${detail:+ — $detail}"
  fi
}

skip() {
  printf '  %s %s\n' "$(yellow –)" "$1"
}

check_repo() {
  local repo=$1 dir="$ROOT/$repo"

  local is_porting_exempt=0 is_dev_tool=0 is_coverage_exempt=0 is_release_exempt=0
  [[ $PORTING_EXEMPT == *" $repo "* ]] && is_porting_exempt=1
  [[ $DEV_TOOL_REPOS == *" $repo "* ]] && is_dev_tool=1
  [[ $COVERAGE_EXEMPT == *" $repo "* ]] && is_coverage_exempt=1
  [[ $RELEASE_EXEMPT == *" $repo "* ]] && is_release_exempt=1

  printf '\n\033[1m%s\033[0m\n' "$repo"

  # ---------- 1. git ----------
  local branch dirty
  branch=$(git -C "$dir" rev-parse --abbrev-ref HEAD 2>/dev/null)
  [[ $branch == main ]]
  ok $? "branch is main" "on '${branch:-unknown}'"

  dirty=$(git -C "$dir" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
  [[ ${dirty:-1} -eq 0 ]]
  ok $? "working tree clean" "$dirty uncommitted files"

  # ---------- 2. directory shape ----------
  [[ -f "$dir/src/index.ts" ]]
  ok $? "src/index.ts exists"

  [[ -d "$dir/src/domain" ]]
  ok $? "src/domain/ exists"

  # apps/ is a conditional sibling of src/, never a child of it (PACKAGE_STANDARD.md
  # "apps/ は src/ の外、リポジトリ直下のきょうだいです"). Only judged when the
  # repository has an apps/ concept at all — a repo with neither src/apps nor
  # a root apps/ has nothing to check here.
  if [[ -d "$dir/apps" || -d "$dir/src/apps" ]]; then
    [[ ! -d "$dir/src/apps" ]]
    ok $? "apps/ is not nested inside src/" "found src/apps/"
  else
    skip "apps/ (repository has no apps/ directory)"
  fi

  for d in test scripts docs; do
    [[ -d "$dir/$d" ]]
    ok $? "$d/ exists at repo root"
  done

  # ---------- 3. absence checks (removed post-migration) ----------
  [[ ! -f "$dir/api-lock.md" ]]
  ok $? "api-lock.md removed"

  [[ ! -f "$dir/scripts/api-lock.ts" ]]
  ok $? "scripts/api-lock.ts removed"

  [[ ! -f "$dir/scripts/check-dependency-whitelist.ts" ]]
  ok $? "scripts/check-dependency-whitelist.ts removed"

  # ---------- 4. package.json (dist shape, PACKAGE_STANDARD.md "package.json の必須フィールドとスクリプト") ----------
  local pkg="$dir/package.json"
  if [[ -f $pkg ]]; then
    if [[ $repo == mc-compose ]]; then
      # PACKAGE_STANDARD.md "package.json の必須フィールドとスクリプト": mc-compose has no downstream importer
      # (it ships a web bundle via `vite build`, not a library) and keeps
      # publishing its source entry point directly. Encoded explicitly here
      # as its own pair of checks, rather than loosening the dist check for
      # every repository.
      jq -e '.main == "./src/index.ts"' "$pkg" >/dev/null 2>&1
      ok $? "package.json main stays ./src/index.ts (mc-compose exception)"

      jq -e '.exports["."] == "./src/index.ts"' "$pkg" >/dev/null 2>&1
      ok $? "package.json exports[\".\"] stays ./src/index.ts (mc-compose exception)"
    else
      jq -e '.main == "./dist/index.js"' "$pkg" >/dev/null 2>&1
      ok $? "package.json main points to ./dist/index.js"

      jq -e '(.exports["."].types == "./dist/index.d.ts") and (.exports["."].import == "./dist/index.js")' "$pkg" >/dev/null 2>&1
      ok $? "package.json exports[\".\"] points to ./dist/index.{js,d.ts}"
    fi

    ! grep -qE '"(api:check|api:update|check:deps)"[[:space:]]*:' "$pkg"
    ok $? "no api:check/api:update/check:deps scripts remain"
  else
    ok 1 "package.json exists"
  fi

  # ---------- 5. docs/ required pages ----------
  for page in README.md architecture.md responsibility.md public-api.md testing.md versioning.md; do
    [[ -f "$dir/docs/$page" ]]
    ok $? "docs/$page exists"
  done

  if [[ $is_dev_tool -eq 1 ]]; then
    skip "docs/design-notes.md ($(dev_tool_reason "$repo"))"
  else
    [[ -f "$dir/docs/design-notes.md" ]]
    ok $? "docs/design-notes.md exists"
  fi

  if [[ $is_porting_exempt -eq 1 ]]; then
    skip "docs/porting.md ($(porting_exempt_reason "$repo"))"
  elif [[ $is_dev_tool -eq 1 ]]; then
    skip "docs/porting.md ($(dev_tool_reason "$repo"))"
  else
    [[ -f "$dir/docs/porting.md" ]]
    ok $? "docs/porting.md exists"
  fi

  # ---------- 6. CI ----------
  local ci="$dir/.github/workflows/ci.yaml"
  if [[ -f $ci ]]; then
    grep -q 'permissions:' "$ci"
    ok $? "ci.yaml declares a permissions: block"

    # packages: read (PACKAGE_STANDARD.md "package.json の必須フィールドとスクリプト" / workflow-templates/ci.yml): needed so
    # `pnpm install` can resolve @nerima-games/* siblings published to GitHub
    # Packages. Checked uniformly across all 16 repos, same as D.1 itself —
    # mc-kernel is the one repo expected to still be red here (it is the
    # source D.1 was derived from, has zero @nerima-games/* deps, and Wave 0
    # does not add this to kernel's own ci.yaml).
    grep -qE '^[[:space:]]*packages:[[:space:]]*read\b' "$ci"
    ok $? "ci.yaml permissions include packages: read"

    # Every `uses:` line that is not pinned to a 40-char commit SHA, naming the
    # action so the fix is obvious. Local composite actions (./.github/...)
    # have no SHA to pin and are excluded, same as the nerima-lisp reference.
    local unpinned_list=""
    while IFS= read -r u; do
      [[ -z $u ]] && continue
      [[ $u == ./* ]] && continue
      if ! [[ $u =~ @[0-9a-f]{40}([[:space:]]|$) ]]; then
        unpinned_list="$unpinned_list ${u%%@*}"
      fi
    done < <(grep -E '^[[:space:]]*(-[[:space:]]*)?uses:' "$ci" | perl -pe 's/^\s*(-\s*)?uses:\s*//')
    unpinned_list=$(tr ' ' '\n' <<<"$unpinned_list" | grep -v '^$' | sort -u | tr '\n' ' ')
    unpinned_list=${unpinned_list% }
    [[ -z $unpinned_list ]]
    ok $? "all ci.yaml actions SHA-pinned" "tag-only: ${unpinned_list:-none}"
  else
    ok 1 ".github/workflows/ci.yaml exists"
  fi

  # ---------- 7. dependabot ----------
  [[ -f "$dir/.github/dependabot.yml" ]]
  ok $? ".github/dependabot.yml exists"

  # ---------- 8. release workflow (RELEASE_STANDARD.md §3; workflow-templates/release.yml) ----------
  if [[ $is_release_exempt -eq 1 ]]; then
    skip ".github/workflows/release.yaml ($(release_exempt_reason "$repo"))"
  else
    [[ -f "$dir/.github/workflows/release.yaml" ]]
    ok $? ".github/workflows/release.yaml exists"
  fi

  # ---------- 9. coverage gate ----------
  if [[ $is_coverage_exempt -eq 1 ]]; then
    skip "vitest.config.ts coverage thresholds ($(coverage_exempt_reason "$repo"))"
  else
    local vitest="$dir/vitest.config.ts" vitest_code thresholds_block
    if [[ -f $vitest ]]; then
      # Strip comment-only lines first: a commented-out
      # `//   thresholds: { ... 100 ... }` must not read as an active gate.
      vitest_code=$(grep -v '^[[:space:]]*//' "$vitest")
      thresholds_block=$(grep -oE 'thresholds:[[:space:]]*\{[^}]*\}' <<<"$vitest_code")
      if [[ -n $thresholds_block ]] \
        && grep -qE 'branches:[[:space:]]*100\b' <<<"$thresholds_block" \
        && grep -qE 'functions:[[:space:]]*100\b' <<<"$thresholds_block" \
        && grep -qE 'lines:[[:space:]]*100\b' <<<"$thresholds_block" \
        && grep -qE 'statements:[[:space:]]*100\b' <<<"$thresholds_block"; then
        ok 0 "vitest.config.ts has an active thresholds block at 100"
      else
        ok 1 "vitest.config.ts has an active thresholds block at 100"
      fi
    else
      ok 1 "vitest.config.ts has an active thresholds block at 100" "vitest.config.ts not found"
    fi
  fi
}

packages=()
if [[ $# -gt 0 ]]; then
  packages=("$@")
else
  packages=("${DEFAULT_REPOS[@]}")
fi

missing_count=0
for repo in "${packages[@]}"; do
  if [[ -d "$ROOT/$repo" ]]; then
    check_repo "$repo"
  else
    printf '\n%s %s: not found under %s\n' "$(red ✗)" "$repo" "$ROOT"
    missing_count=$((missing_count + 1))
  fi
done

printf '\n\033[1m%d/%d checks passed\033[0m across %d repo(s)' \
  "$((check_count - fail_count))" "$check_count" "$((${#packages[@]} - missing_count))"
if [[ $missing_count -gt 0 ]]; then
  printf ', %d not found' "$missing_count"
fi
printf '\n'

[[ $fail_count -eq 0 && $missing_count -eq 0 ]]
