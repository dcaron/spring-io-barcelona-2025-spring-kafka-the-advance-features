#!/usr/bin/env bash
#
# advisor-upgrade.sh — run a Spring Application Advisor upgrade on a target repo.
#
# Part of the advisor-kit. Generic: point it at any Maven Spring Boot repo.
#
# What it does, in order:
#   1. Preflight checks (advisor CLI, Maven wrapper, rewrite-plugin guard,
#      Maven credentials).
#   2. Copy the kit's curated mappings into <target>/.advisor/mappings/ when
#      they are absent (the target repo's copies are the source of truth).
#   3. Export the SPRING_ADVISOR_MAPPING_CUSTOM_* env vars from the wiring
#      manifest (mappings/order.txt).
#   4. Run `advisor build-config get`.
#   5. Loop: `advisor upgrade-plan get` -> `advisor upgrade-plan apply`
#      -> build check, until the plan converges or --max-steps is reached.
#      Missing mappings for blocked dependencies are auto-created and wired.
#
# IMPORTANT: plain `apply` is known to no-op on projects whose upgrades are all
# transitive/BOM-managed (BUG-1, see docs/known-issues.md). Use --force to run
# `apply --accept-no-alignment` repeatedly until convergence. That mode is the
# verified way to make the full upgrade land.
#
# Usage:
#   advisor-upgrade.sh [options] [target-repo-dir]
#
#   target-repo-dir  Repo to upgrade (default: current directory).
#                    Must contain pom.xml.
#
# Options:
#   -y, --yes           Do not prompt before applying each step (CI mode).
#       --dry-run       Preflight + mappings + build-config + print the plan.
#                       Never applies anything. Do this first.
#       --force         Apply with --accept-no-alignment, repeatedly, until
#                       the worktree stops changing. Alias: --accept-no-alignment.
#       --refresh-mappings
#                       Overwrite the target's kit-provided mappings with the
#                       kit versions (existing files are saved as *.bak).
#       --skip-guard-check
#                       Skip the rewrite-maven-plugin guard preflight (unsafe).
#       --verify        Run full `mvnw verify` after each applied step.
#       --no-build      Skip the build check after each applied step.
#       --max-steps N   Safety cap on upgrade steps (default: 25).
#       --no-auto-mappings
#                       Do NOT auto-create mappings for blocked dependencies.
#       --max-mappings N
#                       Cap on auto-created mappings per run (default: 40).
#   -h, --help          Show this help and exit.
#
# Exit codes:
#   0 success / converged     2 stopped on BUG-1 no-op (re-run with --force)
#   1 any other failure
#
# Environment:
#   NO_COLOR            Disable coloured output (auto-disabled when not a TTY).
#
set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Directory this script lives in == the kit root.
KIT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
KIT_MAPPINGS_DIR="${KIT_DIR}/mappings"

# Defaults (overridable by flags).
ASSUME_YES=0
DRY_RUN=0
FORCE_MODE=0
REFRESH_MAPPINGS=0
SKIP_GUARD_CHECK=0
BUILD_MODE="install"   # install | verify | none
MAX_STEPS=25
AUTO_RESOLVE_MAPPINGS=1 # auto-create mappings for blocked deps and re-plan
MAX_MAPPINGS=40         # cap on auto-created mappings per run
TARGET_DIR=""

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'; RED=$'\033[31m'; GREEN=$'\033[32m'
  YELLOW=$'\033[33m'; BLUE=$'\033[34m'; RESET=$'\033[0m'
else
  BOLD=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; RESET=""
fi

banner()  { printf '\n%s========== %s ==========%s\n' "${BOLD}${BLUE}" "$*" "${RESET}"; }
info()    { printf '%s\n' "$*"; }
ok()      { printf '%s✅ %s%s\n' "${GREEN}" "$*" "${RESET}"; }
warn()    { printf '%s⚠️  %s%s\n' "${YELLOW}" "$*" "${RESET}"; }
err()     { printf '%s❌ %s%s\n' "${RED}" "$*" "${RESET}" >&2; }
run()     { printf '%s$ %s%s\n' "${BOLD}" "$*" "${RESET}"; "$@"; }

die()     { err "$*"; exit 1; }

usage() {
  # Print the leading comment block: skip the shebang, print comment lines
  # (stripping the leading "# "), stop at the first non-comment line.
  awk 'NR==1 {next} /^#/ {sub(/^# ?/, ""); print; next} {exit}' "${BASH_SOURCE[0]}"
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

while [[ $# -gt 0 ]]; do
  case "$1" in
    -y|--yes)        ASSUME_YES=1 ;;
    --dry-run)       DRY_RUN=1 ;;
    --force|--accept-no-alignment) FORCE_MODE=1 ;;
    --refresh-mappings) REFRESH_MAPPINGS=1 ;;
    --skip-guard-check) SKIP_GUARD_CHECK=1 ;;
    --verify)        BUILD_MODE="verify" ;;
    --no-build)      BUILD_MODE="none" ;;
    --max-steps)     shift; [[ "${1:-}" =~ ^[0-9]+$ ]] || die "--max-steps needs a number"; MAX_STEPS="$1" ;;
    --max-steps=*)   MAX_STEPS="${1#*=}"; [[ "$MAX_STEPS" =~ ^[0-9]+$ ]] || die "--max-steps needs a number" ;;
    --no-auto-mappings) AUTO_RESOLVE_MAPPINGS=0 ;;
    --max-mappings)  shift; [[ "${1:-}" =~ ^[0-9]+$ ]] || die "--max-mappings needs a number"; MAX_MAPPINGS="$1" ;;
    --max-mappings=*) MAX_MAPPINGS="${1#*=}"; [[ "$MAX_MAPPINGS" =~ ^[0-9]+$ ]] || die "--max-mappings needs a number" ;;
    -h|--help)       usage; exit 0 ;;
    -*)              err "Unknown option: $1"; echo; usage; exit 1 ;;
    *)               [[ -z "${TARGET_DIR}" ]] || die "Only one target directory is allowed (got '${TARGET_DIR}' and '$1')."
                     TARGET_DIR="$1" ;;
  esac
  shift
done

TARGET_DIR="${TARGET_DIR:-$(pwd)}"
TARGET_DIR="$(cd -- "${TARGET_DIR}" >/dev/null 2>&1 && pwd -P)" \
  || die "Target directory does not exist."
[[ -f "${TARGET_DIR}/pom.xml" ]] || die "No pom.xml in ${TARGET_DIR} — not a Maven repo root."

MAPPINGS_DIR="${TARGET_DIR}/.advisor/mappings"

cd "${TARGET_DIR}"

# ---------------------------------------------------------------------------
# 1. Preflight
# ---------------------------------------------------------------------------

banner "Preflight"
info "Target repo: ${TARGET_DIR}"
info "Kit:         ${KIT_DIR}"

command -v advisor >/dev/null 2>&1 || die "advisor CLI not found on PATH. Install Spring Application Advisor first."
ADVISOR_VERSION="$(advisor --version 2>/dev/null | sed -n 's/^Version: //p' | head -1)"
info "Spring Application Advisor: ${ADVISOR_VERSION:-unknown}"
case "${ADVISOR_VERSION}" in
  1.6.*) ok "advisor version looks good" ;;
  *)     warn "This kit was verified against advisor 1.6.x; behaviour may differ." ;;
esac

if [[ -x "${TARGET_DIR}/mvnw" ]]; then
  MVN="${TARGET_DIR}/mvnw"
  ok "Maven wrapper present"
else
  command -v mvn >/dev/null 2>&1 || die "Neither ./mvnw nor mvn found."
  MVN="mvn"
  warn "No ./mvnw in the target repo; falling back to system mvn."
fi

command -v git >/dev/null 2>&1 && HAVE_GIT=1 || HAVE_GIT=0

# --- rewrite-maven-plugin guard check ---------------------------------------
#
# Maven merges a build-level rewrite-maven-plugin declaration (its
# <dependencies> AND <executions>) into Advisor's own forced invocation of
# that plugin, which breaks the upgrade (BUG-2a/BUG-2b). The declaration must
# be removed or moved into an explicitly-activated profile before running
# apply. We check every pom in the Maven reactor (root + <module> tree).

# Print the pom paths of the reactor: the root pom plus every <module> pom,
# recursively.
reactor_poms() {
  local pom="$1" dir mod
  [[ -f "${pom}" ]] || return 0
  printf '%s\n' "${pom}"
  dir="$(dirname "${pom}")"
  while IFS= read -r mod; do
    [[ -n "${mod}" ]] || continue
    reactor_poms "${dir}/${mod}/pom.xml"
  done < <(sed -n 's/.*<module>\(.*\)<\/module>.*/\1/p' "${pom}")
}

# True if the pom declares rewrite-maven-plugin OUTSIDE any <profiles> block.
# Matches the <artifactId> element only, so prose/comments that merely mention
# the plugin name do not trigger it.
pom_has_unguarded_rewrite_plugin() {
  awk '
    /<profiles>/  { depth++ }
    /<\/profiles>/ { depth-- }
    /<artifactId>[[:space:]]*rewrite-maven-plugin[[:space:]]*<\/artifactId>/ && depth == 0 { found = 1 }
    END { exit found ? 0 : 1 }
  ' "$1"
}

if [[ "${SKIP_GUARD_CHECK}" -eq 1 ]]; then
  warn "Skipping the rewrite-maven-plugin guard check (--skip-guard-check)."
else
  unguarded=""
  while IFS= read -r pom; do
    pom_has_unguarded_rewrite_plugin "${pom}" && unguarded="${unguarded}  ${pom#${TARGET_DIR}/}"$'\n'
  done < <(reactor_poms "${TARGET_DIR}/pom.xml")
  if [[ -n "${unguarded}" ]]; then
    err "rewrite-maven-plugin is declared in the active build of:"
    printf '%s' "${unguarded}" >&2
    err "Advisor's apply inherits that declaration and fails (BUG-2a/BUG-2b)."
    err "Move the declaration into a profile first. Use the template:"
    err "  ${KIT_DIR}/snippets/rewrite-plugin-profile-guard.xml"
    exit 1
  fi
  ok "No unguarded rewrite-maven-plugin in the reactor."
fi

# --- Maven credentials (warn only) ------------------------------------------
if [[ ! -f "${HOME}/.m2/settings.xml" ]] || ! grep -q '<server>' "${HOME}/.m2/settings.xml" 2>/dev/null; then
  warn "No <server> credentials found in ~/.m2/settings.xml."
  warn "Advisor needs access to the Spring Enterprise Maven repository."
fi

# ---------------------------------------------------------------------------
# 2. Sync kit mappings into the target repo (copy-on-first-run)
# ---------------------------------------------------------------------------

banner "Syncing kit mappings"
[[ -d "${KIT_MAPPINGS_DIR}" ]] || die "Kit mappings directory missing: ${KIT_MAPPINGS_DIR}"
mkdir -p "${MAPPINGS_DIR}"

sync_kit_file() {
  local src="$1" bn dest
  bn="$(basename "${src}")"
  dest="${MAPPINGS_DIR}/${bn}"
  if [[ ! -e "${dest}" ]]; then
    cp "${src}" "${dest}"
    ok "  copied ${bn}"
  elif [[ "${REFRESH_MAPPINGS}" -eq 1 ]] && ! cmp -s "${src}" "${dest}"; then
    cp "${dest}" "${dest}.bak"
    cp "${src}" "${dest}"
    ok "  refreshed ${bn} (previous saved as ${bn}.bak)"
  else
    info "  kept existing ${bn}"
  fi
}

for f in "${KIT_MAPPINGS_DIR}"/*.json "${KIT_MAPPINGS_DIR}/order.txt"; do
  [[ -e "${f}" ]] && sync_kit_file "${f}"
done

# The kit's mappings are curated by the framework team. Never regenerate them.
PRESERVED_MAPPINGS=()
for f in "${KIT_MAPPINGS_DIR}"/*.json; do
  PRESERVED_MAPPINGS+=("$(basename "${f}")")
done

# ---------------------------------------------------------------------------
# 3. Export SPRING_ADVISOR_MAPPING_CUSTOM_* env vars from the manifest
# ---------------------------------------------------------------------------

banner "Wiring custom mappings into advisor"

# The manifest in the target repo wins; the kit's is the fallback.
MANIFEST="${MAPPINGS_DIR}/order.txt"
[[ -f "${MANIFEST}" ]] || MANIFEST="${KIT_MAPPINGS_DIR}/order.txt"
[[ -f "${MANIFEST}" ]] || die "No wiring manifest (order.txt) found."
info "Manifest: ${MANIFEST#${TARGET_DIR}/}"

MAPPING_ENV_ORDER=()
while IFS= read -r line; do
  line="${line%%#*}"                      # strip comments
  line="$(printf '%s' "${line}" | tr -d '[:space:]')"
  [[ -n "${line}" ]] && MAPPING_ENV_ORDER+=("${line}")
done < "${MANIFEST}"
[[ "${#MAPPING_ENV_ORDER[@]}" -gt 0 ]] || die "Wiring manifest is empty: ${MANIFEST}"

idx=0
for entry in "${MAPPING_ENV_ORDER[@]}"; do
  file="${entry%%:*}"
  strategy=""
  [[ "${entry}" == *:* ]] && strategy="${entry##*:}"
  path=".advisor/mappings/${file}"
  if [[ ! -f "${TARGET_DIR}/${path}" ]]; then
    warn "mapping file not found, skipping from env: ${path}"
    continue
  fi
  export "SPRING_ADVISOR_MAPPING_CUSTOM_${idx}_FILEPATH=${path}"
  line="SPRING_ADVISOR_MAPPING_CUSTOM_${idx}_FILEPATH=${path}"
  if [[ -n "${strategy}" ]]; then
    export "SPRING_ADVISOR_MAPPING_CUSTOM_${idx}_MERGE_STRATEGY=${strategy}"
    line="${line}  (merge: ${strategy})"
  fi
  info "  ${line}"
  idx=$((idx + 1))
done
ok "Configured ${idx} custom mapping(s)."
# Next free SPRING_ADVISOR_MAPPING_CUSTOM_ index, used when auto-adding mappings.
ENV_IDX="${idx}"

# ---------------------------------------------------------------------------
# 4. Build config
# ---------------------------------------------------------------------------

banner "Generating build configuration"
run advisor build-config get
ok "build-config generated."

# ---------------------------------------------------------------------------
# 5. Upgrade loop
# ---------------------------------------------------------------------------

# Heuristic: does the `upgrade-plan get` output contain an actionable upgrade?
#
# advisor lists concrete upgrades under "Projects discovered:" as lines like
#   - micrometer-context-propagation: 1.1.x → 1.2.x
# (the arrow is a Unicode "→"; older/other output may use "->"). The rest of
# the output — the "… could not be included …/blocking upgrades for:" section —
# is always present boilerplate that mentions "upgrade" and version-ish tokens,
# so we must NOT key on those. We key strictly on a "version → version" line:
# its absence means nothing is left to apply (only blocked transitives remain).
plan_is_actionable() {
  local plan_output="$1"
  [[ -n "${plan_output}" ]] || return 1
  grep -qE '[0-9]+\.[0-9]+\.[0-9xX]+[[:space:]]*(→|->|=>)[[:space:]]*[0-9]+\.[0-9]+\.[0-9xX]+' <<<"${plan_output}" \
    && return 0
  return 1
}

# Snapshot of tracked changes, to detect whether an apply actually did anything.
worktree_signature() {
  [[ "${HAVE_GIT}" -eq 1 ]] || { echo "no-git"; return; }
  git -C "${TARGET_DIR}" status --porcelain 2>/dev/null | sort | cksum
}

build_check() {
  case "${BUILD_MODE}" in
    none)    info "Build check skipped (--no-build)." ;;
    verify)  run "${MVN}" -q verify ;;
    install) run "${MVN}" -q -DskipTests install ;;
  esac
}

# Run one apply. --force adds --accept-no-alignment (the verified way to make
# the full plan land; plain apply no-ops on transitive-only plans — BUG-1).
apply_step() {
  if [[ "${FORCE_MODE}" -eq 1 ]]; then
    run advisor upgrade-plan apply --accept-no-alignment
  else
    run advisor upgrade-plan apply
  fi
}

# --- Mapping helpers (validation, generation, collision tracking) ------------
#
# True if the given text is a usable mapping: JSON with a "rewrite" section that
# has at least one "<version>":{...} entry. advisor sometimes emits empty
# mappings for internal/transitive modules, and wiring an empty one makes every
# later advisor call fail with "One of the custom mappings provided is empty".
is_valid_mapping() {
  local content="$1"
  [[ -n "${content}" ]] || return 1
  grep -q '"rewrite"' <<<"${content}" || return 1
  grep -qE '"[0-9]+\.[0-9]+\.[0-9xX]+"[[:space:]]*:' <<<"${content}" || return 1
  return 0
}

# Restore the mappings dir to a snapshot: drop any *.json advisor newly created
# and restore every pre-existing file. This is what protects curated mappings —
# advisor names its output .advisor/mappings/<slug>.json and that slug can
# collide with an existing file (e.g. `mapping create` for an internal Kafka
# module emits slug "kafka"), which would otherwise clobber a curated mapping
# and dangle its env reference.
restore_mappings_from() {
  local backup="$1" f bn
  while IFS= read -r f; do
    [[ -n "${f}" ]] || continue
    bn="$(basename "${f}")"
    [[ -e "${backup}/${bn}" ]] || rm -f "${f}"
  done < <(find "${MAPPINGS_DIR}" -maxdepth 1 -type f -name '*.json' 2>/dev/null)
  cp -a "${backup}/." "${MAPPINGS_DIR}/" 2>/dev/null || true
}

# Regenerate a single mapping into .advisor/mappings/<target_file>.
#
# `advisor mapping create -c=<coord>` writes the mapping into
# .advisor/mappings/<slug>.json (slug is advisor's own project name and MAY be
# empty -> ".json", and MAY collide with an existing file). It does not print
# the mapping to stdout. We therefore: snapshot the mappings dir, run the
# command, capture the content of the file advisor wrote (newest json), then
# restore the snapshot (undoing any collision) and write the captured content
# to our chosen target filename — but only if it is a valid, non-empty mapping.
#
# Returns 0 on success, 1 on (tolerated) failure.
generate_mapping() {
  local target_file="$1" coordinate="$2"
  local target_path="${MAPPINGS_DIR}/${target_file}"
  local marker log_out backup produced content slug
  marker="$(mktemp)"; log_out="$(mktemp)"; backup="$(mktemp -d)"
  cp -a "${MAPPINGS_DIR}/." "${backup}/" 2>/dev/null || true

  info "  coordinate: ${coordinate} -> ${target_file} (resolving, may take a minute)…"
  # Redirect stdin from /dev/null: advisor would otherwise consume the caller's
  # stdin (e.g. the here-string driving resolve_missing_mappings' read loop).
  if ! advisor mapping create -c="${coordinate}" </dev/null >"${log_out}" 2>&1; then
    warn "mapping create failed for ${coordinate} (keeping existing ${target_file} if present)"
    sed 's/^/    /' "${log_out}" | tail -4
    restore_mappings_from "${backup}"
    rm -rf "${marker}" "${log_out}" "${backup}"
    return 1
  fi

  # The file advisor just wrote is the newest json in the mappings dir.
  produced="$(find "${MAPPINGS_DIR}" -maxdepth 1 -type f -name '*.json' -newer "${marker}" 2>/dev/null | head -1)"
  content=""; slug=""
  if [[ -n "${produced}" ]]; then
    content="$(cat "${produced}" 2>/dev/null || true)"
    slug="$(basename "${produced}" .json)"
  fi

  # Undo any file changes advisor made (protects curated + earlier mappings).
  restore_mappings_from "${backup}"
  rm -rf "${marker}" "${log_out}" "${backup}"

  if ! is_valid_mapping "${content}"; then
    warn "  advisor produced no usable mapping for ${coordinate} (empty/invalid) — skipping"
    return 1
  fi

  printf '%s\n' "${content}" > "${target_path}"
  if [[ "${slug}" != "${target_file%.json}" ]]; then
    ok "  wrote ${target_file} (advisor slug: '${slug}')"
  else
    ok "  wrote ${target_file}"
  fi
  return 0
}

# --- Self-healing: auto-create mappings for blocked dependencies -------------
#
# When a dependency has no configured upgrade, advisor lists it under
#   "… could not be included … Please … configure the projects of the
#    following dependencies:" as a top-level (single-tab) bullet:
#       <TAB>- org.apache.kafka:kafka-storage-api
# Nested "uses:"/"blocking upgrades for:" entries are indented deeper (>= 2
# tabs) and are plain project names (no group:artifact), and advisor's
# "please report" notes are 2-tab and carry a :version suffix — so a strict
# "exactly one leading tab, group:artifact, end-of-line" match selects only
# the coordinates we should try to map.

# Coordinates we've already attempted, so we never loop on the same one twice.
# Seeded below from the coordinates the wired mappings already cover.
TRIED_COORDS=" "
MAPPINGS_CREATED=0

is_tried()   { case "${TRIED_COORDS}" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }
mark_tried() { TRIED_COORDS="${TRIED_COORDS}$1 "; }

# groupIds whose generated mapping collided with an existing one. All artifacts
# of such a group (e.g. every org.apache.kafka:* internal module) belong to the
# same advisor project and would collide too — so we skip them without paying
# for a slow `mapping create` we know we can't wire.
CONFLICTED_GROUPS=" "
group_conflicted() { case "${CONFLICTED_GROUPS}" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# advisor refuses to load two custom mappings that share a project slug or a
# coordinate (RaiseErrorOnDuplicatesCoordinatesMerger -> "Some projects were
# already defined"). Internal Kafka modules all collapse to slug 'kafka' and
# re-claim kafka-clients, which the kit's apache-kafka.json already owns — so we
# must NOT wire a generated mapping that collides. Track what's already wired.
WIRED_SLUGS=" "
WIRED_COORDS=" "
slug_wired()  { [[ -n "$1" ]] && case "${WIRED_SLUGS}" in *" $1 "*) return 0 ;; esac; return 1; }
coord_wired() { case "${WIRED_COORDS}" in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# Read the slug / coordinates declared inside a mapping file.
mapping_slug()   { grep -m1 '"slug"' "$1" 2>/dev/null | sed -E 's/.*"slug"[[:space:]]*:[[:space:]]*"([^"]*)".*/\1/'; }
mapping_coords() { grep '"coordinates"' "$1" 2>/dev/null | grep -oE '"[A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+"' | tr -d '"'; }

# Record a mapping's slug + coordinates as wired, so later generated mappings
# that would collide with it are skipped instead of crashing advisor. The
# covered coordinates are also marked as tried: they need no new mapping.
register_wired_mapping() {
  local path="$1" s c
  s="$(mapping_slug "${path}")"
  [[ -n "${s}" ]] && ! slug_wired "${s}" && WIRED_SLUGS="${WIRED_SLUGS}${s} "
  while IFS= read -r c; do
    [[ -n "${c}" ]] || continue
    coord_wired "${c}" || WIRED_COORDS="${WIRED_COORDS}${c} "
    is_tried "${c}" || mark_tried "${c}"
  done < <(mapping_coords "${path}")
}

# group:artifact -> a stable target filename (based on the artifactId).
coord_to_filename() {
  local artifact="${1#*:}"
  printf '%s.json' "$(printf '%s' "${artifact}" | tr -c 'A-Za-z0-9._-' '_')"
}

# Add an already-written mapping file to the advisor env at the next index.
add_mapping_env() {
  export "SPRING_ADVISOR_MAPPING_CUSTOM_${ENV_IDX}_FILEPATH=.advisor/mappings/$1"
  ENV_IDX=$((ENV_IDX + 1))
}

# Seed WIRED_SLUGS/WIRED_COORDS/TRIED_COORDS from the mappings wired in step 3.
for _m in "${MAPPING_ENV_ORDER[@]}"; do
  _mf="${_m%%:*}"
  [[ -f "${MAPPINGS_DIR}/${_mf}" ]] && register_wired_mapping "${MAPPINGS_DIR}/${_mf}"
done
unset _m _mf

# Print the blocked coordinates found in the given plan text (one per line).
# Always succeeds (grep finding nothing is normal, not an error).
extract_blocked_coords() {
  printf '%s\n' "$1" \
    | grep -E "^${TAB}- [A-Za-z0-9_.-]+:[A-Za-z0-9_.-]+$" \
    | sed "s/^${TAB}- //" \
    | sort -u || true
}

# Try to create mappings for every not-yet-tried blocked coordinate in the plan.
# Returns 0 if at least one new mapping was created (caller should re-plan),
# 1 if there was nothing new to create.
resolve_missing_mappings() {
  local plan="$1" coord file created=0 coords
  coords="$(extract_blocked_coords "${plan}")"
  [[ -n "${coords}" ]] || return 1

  while IFS= read -r coord; do
    [[ -n "${coord}" ]] || continue
    is_tried "${coord}" && continue
    if group_conflicted "${coord%%:*}"; then
      mark_tried "${coord}"
      info "  ↷ skipping ${coord} (project '${coord%%:*}' already conflicts with a wired mapping)"
      continue
    fi
    if [[ "${MAPPINGS_CREATED}" -ge "${MAX_MAPPINGS}" ]]; then
      warn "Reached --max-mappings=${MAX_MAPPINGS}; not creating more this run."
      break
    fi
    mark_tried "${coord}"
    file="$(coord_to_filename "${coord}")"
    info "  🔍 missing mapping: ${coord} -> ${file}"
    generate_mapping "${file}" "${coord}" || continue

    # Advisor rejects mappings that duplicate a slug or coordinate already
    # loaded. Inspect what this mapping declares; if it collides with an
    # already-wired mapping, skip wiring it (but record the coordinates it
    # covers as tried so we don't keep retrying its siblings).
    local newslug newcoords conflict="" cc
    newslug="$(mapping_slug "${MAPPINGS_DIR}/${file}")"
    newcoords="$(mapping_coords "${MAPPINGS_DIR}/${file}" | sort -u)"
    if slug_wired "${newslug}"; then
      conflict="project slug '${newslug}' already defined"
    else
      while IFS= read -r cc; do
        [[ -n "${cc}" ]] || continue
        if coord_wired "${cc}"; then conflict="coordinate ${cc} already mapped"; break; fi
      done <<< "${newcoords}"
    fi

    # Whatever the mapping covers, don't re-attempt those sibling coordinates.
    while IFS= read -r cc; do
      [[ -n "${cc}" ]] && ! is_tried "${cc}" && mark_tried "${cc}"
    done <<< "${newcoords}"

    if [[ -n "${conflict}" ]]; then
      warn "  skipping ${file}: ${conflict} (advisor allows each only once)"
      rm -f "${MAPPINGS_DIR}/${file}"
      CONFLICTED_GROUPS="${CONFLICTED_GROUPS}${coord%%:*} "
      continue
    fi

    add_mapping_env "${file}"
    register_wired_mapping "${MAPPINGS_DIR}/${file}"
    MAPPINGS_CREATED=$((MAPPINGS_CREATED + 1))
    created=1
  done <<< "${coords}"

  [[ "${created}" -eq 1 ]]
}

# A literal tab, used by the grep/sed patterns above.
TAB=$'\t'

banner "Upgrade plan"
step=0
applied=0

iter=0
while :; do
  iter=$((iter + 1))
  if [[ "${iter}" -gt "$(( (MAX_STEPS + MAX_MAPPINGS) * 2 + 10 ))" ]]; then
    warn "Too many planning iterations; stopping as a safety measure."
    break
  fi

  info ""
  info "${BOLD}--- Reading upgrade plan (applied: ${applied}, mappings created: ${MAPPINGS_CREATED}) ---${RESET}"
  plan_output="$(advisor upgrade-plan get 2>&1 || true)"

  # Condensed view: the actionable "→" upgrades, plus how many deps are blocked.
  printf '%s\n' "${plan_output}" | grep -E 'Projects (discovered|to upgrade):|(→|->|=>)' | sed 's/^/  /' || true
  blocked_now="$(extract_blocked_coords "${plan_output}" | tr '\n' ' ' || true)"
  [[ -n "${blocked_now// /}" ]] && info "  blocked (no upgrade configured): ${blocked_now}"

  # Self-heal: create mappings for any not-yet-tried blocked dependency, then
  # regenerate the build config and re-plan with the new mappings in place.
  if [[ "${AUTO_RESOLVE_MAPPINGS}" -eq 1 ]] && resolve_missing_mappings "${plan_output}"; then
    info ""
    ok "Created new mapping(s); regenerating build configuration and re-planning…"
    run advisor build-config get
    continue
  fi

  if ! plan_is_actionable "${plan_output}"; then
    ok "No further upgrades to apply — the repository is upgraded as far as the available mappings allow."
    break
  fi

  # Signature of the actionable upgrades in this plan, to detect a plan that
  # keeps recurring unchanged after an apply that changes no files (stuck).
  action_sig="$(printf '%s\n' "${plan_output}" | grep -E '(→|->|=>)' | sort -u | cksum || true)"
  if [[ -n "${stuck_sig:-}" && "${action_sig}" == "${stuck_sig}" ]]; then
    if [[ "${FORCE_MODE}" -eq 1 ]]; then
      ok "Converged: the forced apply no longer changes any file for this plan."
      break
    fi
    warn "The plan is unchanged after an apply that produced no file changes."
    warn "This is known BUG-1: plain apply no-ops on transitive-only projects."
    warn "Re-run with --force to apply with --accept-no-alignment."
    exit 2
  fi

  if [[ "${DRY_RUN}" -eq 1 ]]; then
    warn "Dry run: stopping before applying (upgrade plan shown above)."
    break
  fi

  step=$((step + 1))
  if [[ "${step}" -gt "${MAX_STEPS}" ]]; then
    warn "Reached --max-steps=${MAX_STEPS}; stopping. Re-run to continue."
    break
  fi

  if [[ "${ASSUME_YES}" -ne 1 ]]; then
    printf '%sApply this upgrade step? [y/N] %s' "${BOLD}${YELLOW}" "${RESET}"
    read -r reply </dev/tty || reply=""
    case "${reply}" in
      y|Y|yes|YES) ;;
      *) warn "Stopping at your request. ${applied} step(s) applied."; break ;;
    esac
  fi

  sig_before="$(worktree_signature)"
  banner "Applying upgrade step ${step}"
  if ! apply_step; then
    die "advisor upgrade-plan apply failed on step ${step}. Review output above; fix and re-run."
  fi
  sig_after="$(worktree_signature)"

  if [[ "${HAVE_GIT}" -eq 1 && "${sig_before}" == "${sig_after}" ]]; then
    warn "This step changed no files (BOM-managed or no-op). Re-planning to check for further steps…"
    stuck_sig="${action_sig}"   # if the same plan recurs unchanged, we'll stop
    continue
  fi
  stuck_sig=""                   # made real progress; clear the stuck guard

  applied=$((applied + 1))
  ok "Step ${step} applied."

  banner "Verifying build after step ${step}"
  if ! build_check; then
    err "Build check failed after step ${step}."
    err "Inspect the changes (git diff), fix, then re-run. Applied ${applied} step(s) so far."
    err "Known post-upgrade compile breaks and their fixes:"
    err "  ${KIT_DIR}/docs/app-team-runbook.md (step 4)"
    exit 1
  fi
  ok "Build check passed after step ${step}."
done

# ---------------------------------------------------------------------------
# 6. Summary
# ---------------------------------------------------------------------------

banner "Summary"
info "Steps applied this run:    ${applied}"
info "Mappings auto-created:     ${MAPPINGS_CREATED}"
if [[ "${MAPPINGS_CREATED}" -gt 0 && "${HAVE_GIT}" -eq 1 ]]; then
  new_maps="$(git -C "${TARGET_DIR}" status --porcelain -- .advisor/mappings/ 2>/dev/null | sed 's/^/    /' || true)"
  [[ -n "${new_maps}" ]] && { info "New/updated mapping files:"; printf '%s\n' "${new_maps}"; }
fi

# Best-effort: report the Spring Boot version now declared in a leaf app pom.
leaf_pom="$(grep -rl 'spring-boot-starter-parent' "${TARGET_DIR}" --include=pom.xml 2>/dev/null | grep -v '/target/' | head -1 || true)"
if [[ -n "${leaf_pom}" ]]; then
  boot_ver="$(grep -A2 'spring-boot-starter-parent' "${leaf_pom}" | sed -n 's:.*<version>\(.*\)</version>.*:\1:p' | head -1 || true)"
  [[ -n "${boot_ver}" ]] && info "Spring Boot version in ${leaf_pom#${TARGET_DIR}/}: ${boot_ver}"
fi

if [[ "${applied}" -gt 0 || "${MAPPINGS_CREATED}" -gt 0 ]]; then
  info ""
  info "Next steps:"
  info "  • Review the changes:  git diff  (and git status for new mapping files)"
  info "  • Fix any compile breaks: see docs/app-team-runbook.md, step 4."
  info "  • Commit .advisor/mappings/ so the run is reproducible."
  info "  • Run the apps / tests to validate behaviour."
  info "  • Re-run this script to continue if more steps remain."
elif [[ "${DRY_RUN}" -eq 1 ]]; then
  info "Dry run complete — no changes were made."
fi
ok "Done."
