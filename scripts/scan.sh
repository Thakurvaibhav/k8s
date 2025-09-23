#!/bin/bash

set -euo pipefail
IFS=$'\n\t'

# Add error trap in debug mode
DEBUG=${DEBUG:-0}
if (( DEBUG )); then
  trap 'rc=$?; echo "[DEBUG][ERR] Command failed: $BASH_COMMAND (rc=$rc)" >&2' ERR
fi

# ---------------------------------------------
# Config / Defaults
# ---------------------------------------------
STEP=${1:-}
CONFIG_FILE=${CONFIG_FILE:-scan-config.yaml}
ALL_CHARTS=false
CONCURRENCY=${CONCURRENCY:-4}
TRIVY_SEVERITY=${TRIVY_SEVERITY:-CRITICAL}
TRIVY_IGNORE_UNFIXED=${TRIVY_IGNORE_UNFIXED:-false}
KEEP_RENDERED=${KEEP_RENDERED:-0}
YQ_CMD=${YQ_CMD:-yq}
HELM_TEMPLATE_EXTRA_ARGS=${HELM_TEMPLATE_EXTRA_ARGS:-"--include-crds"}
OUTPUT_DIR=${OUTPUT_DIR:-./scan-output}
TEST_RESULTS_DIR="$OUTPUT_DIR/test-results"
SUMMARY_FILE="$OUTPUT_DIR/scan-summary.txt"
TRIVY_IMAGE_REPORT="$OUTPUT_DIR/trivy-image-report.txt"

# Debug helpers
DEBUG=${DEBUG:-0}
debug() { (( DEBUG )) && printf '[DEBUG %s] %s\n' "$(date -u +'%H:%M:%S')" "$*" >&2; }
(( DEBUG )) && { set -x; debug "Debug mode enabled"; }

if (( DEBUG )); then
  echo "--- ENV DEBUG DUMP ---" >&2
  echo "PWD=$(pwd)" >&2
  echo "STEP=$STEP CONFIG_FILE=$CONFIG_FILE OUTPUT_DIR=$OUTPUT_DIR" >&2
  echo "BASH_VERSION=$BASH_VERSION" >&2
  command -v helm >/dev/null 2>&1 && echo "helm version: $(helm version 2>/dev/null || true)" >&2
  command -v $YQ_CMD >/dev/null 2>&1 && echo "yq version: $($YQ_CMD --version 2>/dev/null || true)" >&2
  command -v trivy >/dev/null 2>&1 && echo "trivy version: $(trivy --version 2>/dev/null | head -1 || true)" >&2
  command -v checkov >/dev/null 2>&1 && echo "checkov version: $(checkov --version 2>/dev/null || true)" >&2
  ls -1 charts 2>/dev/null | sed 's/^/chart-dir: /' >&2 || echo 'no charts dir' >&2
  echo "-----------------------" >&2
fi

# ---------------------------------------------
usage() {
  cat <<EOF
Usage: $0 <lint|trivy|checkov> [--all]
Env Options:
  CONCURRENCY            Parallel image scan workers (default: 4)
  TRIVY_SEVERITY         Severity list (default: CRITICAL)
  TRIVY_IGNORE_UNFIXED   true|false (default: false)
  KEEP_RENDERED          1 to keep rendered manifests (default: 0)
  CONFIG_FILE            Path to config (default: scan-config.yaml)
  YQ_CMD                 yq executable name (default: yq)
EOF
}

# ---------------------------------------------
# Arg Parsing
# ---------------------------------------------
for arg in "$@"; do
  case "$arg" in
    --all) ALL_CHARTS=true ; shift ;;
  esac
done

if [[ -z "${STEP}" ]]; then
  usage; exit 2
fi
if ! [[ " ${STEP} " =~ ^[[:space:]]*(lint|trivy|checkov)[[:space:]]*$ ]]; then
  echo "[ERR] Invalid STEP: ${STEP}" >&2; usage; exit 2
fi

# ---------------------------------------------
# Prerequisite Checks
# ---------------------------------------------
need_bin() { command -v "$1" >/dev/null 2>&1 || { echo "[ERR] Missing required binary: $1" >&2; exit 127; }; }
need_bin git; need_bin helm; need_bin "$YQ_CMD"; need_bin grep; need_bin sort; need_bin cut; need_bin find; need_bin awk
[[ "$STEP" == "trivy" ]] && need_bin trivy
[[ "$STEP" == "checkov" ]] && need_bin checkov
command -v xmlstarlet >/dev/null 2>&1 || echo "[WARN] xmlstarlet not found; XML post-processing skipped"

mkdir -p "$TEST_RESULTS_DIR"

EXIT_CODE=0
failed_charts=()
charts_processed=0
values_processed=0
images_scanned=0
images_skipped=0
images_failed=0

# ---------------------------------------------
log() { printf '[%s] %s\n' "$(date -u +'%Y-%m-%dT%H:%M:%SZ')" "$*"; }

# ---------------------------------------------
# Determine Changed Charts (enhanced base ref logic)
# ---------------------------------------------
collect_all_charts() { find charts -maxdepth 1 -mindepth 1 -type d -print | sort; }

if $ALL_CHARTS; then
  mapfile -t charts_changed < <(collect_all_charts)
else
  if [[ -n "${CI_GIT_COMMIT_RANGE:-}" ]]; then
    base_range="$CI_GIT_COMMIT_RANGE"
  else
    git fetch --quiet origin || true
    # Allow override via BASE_REF or MAIN_REF; prefer origin/main when present
    if [[ -z "${BASE_REF:-}" ]]; then
      if git show-ref --verify --quiet refs/remotes/origin/main; then
        DEFAULT_BASE=origin/main
      else
        DEFAULT_BASE=origin/master
      fi
      BASE_REF=$DEFAULT_BASE
    fi
    MAIN_REF=${MAIN_REF:-$BASE_REF}
    base=$(git merge-base HEAD "$MAIN_REF" || echo HEAD^) || true
    base_range="$base...HEAD"
  fi
  log "Diff range: $base_range"
  mapfile -t charts_changed < <(git diff --name-only $base_range -- charts 2>/dev/null | cut -d/ -f1-2 | sort -u)
fi

if [[ ${#charts_changed[@]} -eq 0 ]]; then
  log "No changed charts detected."; echo "No changes" > "$SUMMARY_FILE"; exit 0
fi

# ---------------------------------------------
# Load Config
# ---------------------------------------------
if [[ ! -f $CONFIG_FILE ]]; then
  echo "[WARN] Config file $CONFIG_FILE not found; proceeding with empty skips" >&2
  trivy_skip_charts=(); trivy_skip_images=(); checkov_skip_charts=()
else
  mapfile -t trivy_skip_charts < <($YQ_CMD e '.trivy.skipcharts[]' "$CONFIG_FILE" 2>/dev/null || true)
  mapfile -t trivy_skip_images < <($YQ_CMD e '.trivy.skipimages[]' "$CONFIG_FILE" 2>/dev/null || true)
  mapfile -t checkov_skip_charts < <($YQ_CMD e '.checkov.skipcharts[]' "$CONFIG_FILE" 2>/dev/null || true)
fi

in_array() { local needle="$1"; shift; for e in "$@"; do [[ "$e" == "$needle" ]] && return 0; done; return 1; }

# ---------------------------------------------
# Image aggregation structures
# ---------------------------------------------
declare -A IMAGE_OCCURRENCES   # image -> comma separated chart:values entries

# Image scanning cache (kept for potential future reuse)
declare -A IMAGE_DONE

# Single Trivy DB update (if needed)
if [[ "$STEP" == "trivy" ]]; then
  log "Updating Trivy DB (once)"
  RETRIES=20
  for attempt in $(seq 0 $RETRIES); do
    if trivy image --download-db-only >/dev/null 2>&1; then
      log "Trivy DB updated"
      break
    elif [[ $attempt -eq $RETRIES ]]; then
      echo "[ERR] Failed to update Trivy DB after $RETRIES attempts" >&2; exit 1
    else
      sleep 5
    fi
  done
fi

# ---------------------------------------------
# Functions
# ---------------------------------------------
render_chart() {
  local chart=$1 values=$2 outdir=$3 chart_name=$4
  debug "Rendering chart=$chart values=$values outdir=$outdir"
  helm template "$chart" -f "$values" $HELM_TEMPLATE_EXTRA_ARGS >"$outdir/${chart_name}.yaml"
}

detect_double_doc() {
  local file=$1
  # Portable detection of consecutive '---' document separators with no content between (2)
  if awk 'BEGIN{last=0} /^---[[:space:]]*$/ { if (last){ exit 1 } last=1; next } { last=0 } END{ exit 0 }' "$file"; then
    return 0
  else
    return 1
  fi
}

# (7) Merge Checkov config only once per chart
declare -A CHECKOV_MERGED
run_checkov() {
  local chart=$1 values=$2 chart_name=$3 values_name=$4
  if in_array "$chart_name" "${checkov_skip_charts[@]:-}"; then return 0; fi
  if [[ -z "${CHECKOV_MERGED[$chart]:-}" ]]; then
    if [[ -f "$chart/.checkov.yaml" ]]; then
      $YQ_CMD -i eval-all '... comments="" | . as $item ireduce ({}; . *+n $item)' "$chart/.checkov.yaml" .globalcheckov.yaml 2>"$TEST_RESULTS_DIR/${chart_name}_checkov_merge.log" || true
      $YQ_CMD -i '.skip-check[] as $skip | del(.check[] | select(. == $skip))' "$chart/.checkov.yaml" 2>>"$TEST_RESULTS_DIR/${chart_name}_checkov_merge.log" || true
    else
      [[ -f .globalcheckov.yaml ]] && cp .globalcheckov.yaml "$chart/.checkov.yaml"
    fi
    CHECKOV_MERGED[$chart]=1
  fi
  log "Checkov scanning: $chart ($values_name)"
  local base="$TEST_RESULTS_DIR/${chart_name}_${values_name}_checkov"
  local results_file="${base}.xml"
  local log_file="${base}.log"
  if ! checkov -d "$chart" --var-file "$values" --framework helm -o junitxml >"$results_file" 2>"$log_file"; then
    failed_charts+=("Checkov:$chart_name:$values_name")
    EXIT_CODE=1
  fi
  if [[ -s $results_file && -x $(command -v xmlstarlet || echo /bin/false) ]]; then
    xmlstarlet edit --inplace --update /testsuites/testsuite/@name --value "Checkov scan $chart_name $values_name" "$results_file" || true
  else
    [[ ! -s $results_file ]] && rm -f "$results_file"
  fi
}

# ---------------------------------------------
# Main Loop (render + aggregate or per-step actions)
# ---------------------------------------------
for chart in "${charts_changed[@]}"; do
  [[ ! -d "$chart" ]] && continue
  chart_name=$(basename "$chart")
  debug "Begin chart=$chart_name path=$chart"
  (( ++charts_processed ))
  if [[ ! -f "$chart/Chart.yaml" ]]; then
    echo "[WARN] Missing Chart.yaml in $chart (skipping)" >&2
    failed_charts+=("NoChart:$chart_name")
    EXIT_CODE=1
    continue
  fi
  mapfile -t value_files < <(find "$chart" -maxdepth 1 -type f -name 'values.*.yaml' -print | sort || true)
  if [[ ${#value_files[@]} -eq 0 && -f "$chart/values.yaml" ]]; then
    value_files+=("$chart/values.yaml")
  fi
  debug "Value files count=${#value_files[@]}"
  deps=$($YQ_CMD e '.dependencies' "$chart/Chart.yaml" 2>/dev/null || echo '') || true
  if [[ -n "$deps" && "$deps" != "null" ]]; then
    log "Building dependencies for $chart_name"
    debug "Dependencies raw: $deps"
    # Skips build if lock exists & all tgz present (minor optimization)
    if [[ -f "$chart/Chart.lock" ]]; then
      missing_pkg=false
      while IFS= read -r dep; do
        pkg=$(echo "$dep" | awk '{print $1}')
        ver=$(echo "$dep" | awk '{print $2}')
        [[ -n "$pkg" && -n "$ver" && ! -f "$chart/charts/${pkg}-${ver}.tgz" ]] && missing_pkg=true
      done < <($YQ_CMD e '.dependencies[] | .name + " " + .version' "$chart/Chart.yaml" 2>/dev/null || true)
      if ! $missing_pkg; then
        debug "Dependencies already present; skipping helm dependency build"
      else
        if ! helm dependency build "$chart" >/dev/null 2>"$TEST_RESULTS_DIR/${chart_name}_deps.log"; then
          echo "[WARN] helm dependency build failed for $chart_name (continuing)" >&2
          failed_charts+=("Deps:$chart_name")
          EXIT_CODE=1
        fi
      fi
    else
      if ! helm dependency build "$chart" >/dev/null 2>"$TEST_RESULTS_DIR/${chart_name}_deps.log"; then
        echo "[WARN] helm dependency build failed for $chart_name (continuing)" >&2
        failed_charts+=("Deps:$chart_name")
        EXIT_CODE=1
      fi
    fi
  fi
  for values in "${value_files[@]}"; do
    values_name=$(basename "$values")
    debug "Processing values file $values_name for $chart_name"
    (( ++values_processed ))
    render_dir=$(mktemp -d)
    manifest="$render_dir/${chart_name}.yaml"
    if [[ "$STEP" == "lint" || "$STEP" == "trivy" ]]; then
      if ! render_chart "$chart" "$values" "$render_dir" "$chart_name"; then
        failed_charts+=("Render:$chart_name:$values_name")
        EXIT_CODE=1
        rm -rf "$render_dir"
        continue
      fi
      if ! detect_double_doc "$manifest"; then
        echo "Double doc start detected in $chart_name ($values_name)" >&2
        failed_charts+=("DoubleDoc:$chart_name:$values_name")
        EXIT_CODE=1
        rm -rf "$render_dir"
        continue
      fi
      # (8) Aggregate images instead of scanning per chart/values when STEP=trivy
      if [[ "$STEP" == "trivy" ]] && ! in_array "$chart_name" "${trivy_skip_charts[@]:-}"; then
        mapfile -t imgs < <($YQ_CMD -N e '..|.image? | select(tag == "!!str")' "$manifest" 2>/dev/null | sort -u || true)
        for image in "${imgs[@]}"; do
          # Skiplist filtering applied later; record occurrence now
            IMAGE_OCCURRENCES[$image]+="${chart_name}:${values_name},"
        done
      fi
    fi
    case "$STEP" in
      checkov) run_checkov "$chart" "$values" "$chart_name" "$values_name" ;;
      trivy)   ;; # scanning deferred
      lint)    ;; # nothing additional
    esac
    if [[ $KEEP_RENDERED -eq 1 ]]; then
      debug "Keeping rendered manifest for $chart_name $values_name"
      cp "$manifest" "$chart/${chart_name}.${values_name}.rendered.yaml"
    fi
    rm -rf "$render_dir"
  done
done

# ---------------------------------------------
# Trivy aggregated scanning
# ---------------------------------------------
if [[ "$STEP" == "trivy" ]]; then
  log "Preparing aggregated Trivy image scan list"
  statuses_file=$(mktemp)
  # Build unique list, apply skip charts already handled, apply skip images here
  unique_images=()
  for image in "${!IMAGE_OCCURRENCES[@]}"; do
    if in_array "$image" "${trivy_skip_images[@]:-}"; then
      echo "$image SKIPPED" >> "$TRIVY_IMAGE_REPORT"
      (( ++images_skipped ))
      continue
    fi
    unique_images+=("$image")
  done
  log "Total unique images to scan: ${#unique_images[@]} (skipped: $images_skipped)"

  scan_one_image() {
    local image="$1" occurrences="$2"
    local sanitized="${image//[^A-Za-z0-9._-]/_}"
    local results_file="$TEST_RESULTS_DIR/${sanitized}_trivy.xml"
    local log_file="$TEST_RESULTS_DIR/${sanitized}_trivy.log"
    local trivy_opts=(image --exit-code 1 --severity "$TRIVY_SEVERITY" --format template --template "@./scripts/junit.tpl")
    [[ "$TRIVY_IGNORE_UNFIXED" == "true" ]] && trivy_opts+=(--ignore-unfixed)
    local status=OK
    if ! trivy "${trivy_opts[@]}" -o "$results_file" "$image" 2>"$log_file"; then
      status=FAIL
    fi
    if [[ -s $results_file && -x $(command -v xmlstarlet || echo /bin/false) ]]; then
      xmlstarlet edit --inplace --delete /testsuites/testsuite[@tests=0] "$results_file" 2>>"$log_file" || true
      xmlstarlet edit --inplace --update /testsuites/testsuite/@name --value "Trivy scan $image" "$results_file" 2>>"$log_file" || true
    else
      [[ ! -s $results_file ]] && rm -f "$results_file"
    fi
    echo "$image $status OCCURS=${occurrences%,}" >> "$TRIVY_IMAGE_REPORT"
    echo "$status $image" >> "$statuses_file"
  }

  active=0
  for image in "${unique_images[@]}"; do
    occurrences="${IMAGE_OCCURRENCES[$image]}"
    if (( CONCURRENCY > 1 )); then
      scan_one_image "$image" "$occurrences" &
      (( ++active ))
      if (( active >= CONCURRENCY )); then
        wait -n || true
        (( --active )) || true
      fi
    else
      scan_one_image "$image" "$occurrences"
    fi
  done
  wait || true

  # Post-process statuses to update global counters & failures
  while read -r status img; do
    (( ++images_scanned ))
    if [[ "$status" == "FAIL" ]]; then
      (( ++images_failed ))
      failed_charts+=("Trivy:$img")
      EXIT_CODE=1
    fi
  done < "$statuses_file"
  rm -f "$statuses_file"
fi

# ---------------------------------------------
# Reporting
# ---------------------------------------------
if compgen -G "$TEST_RESULTS_DIR"/*.xml >/dev/null; then
  if command -v xunit-viewer >/dev/null 2>&1; then
    log "Generating aggregated HTML report"
    xunit-viewer -r "$TEST_RESULTS_DIR" -t "${STEP}-test-results" -o "$OUTPUT_DIR/${STEP}-test-results.html" || true
  fi
fi

if (( EXIT_CODE != 0 )); then
  echo "[ERR] Failures:" >&2
  for f in "${failed_charts[@]}"; do echo "  - $f" >&2; done
fi

failed_total=${#failed_charts[@]}
{
  echo "Charts processed: $charts_processed"
  echo "Values files processed: $values_processed"
  echo "Images scanned: $images_scanned"
  echo "Images skipped (cache/skiplist): $images_skipped"
  echo "Images failed: $images_failed"
  echo "Failed items: $failed_total"
  (( failed_total > 0 )) && printf 'Failed list: %s\n' "${failed_charts[*]}"
  [[ "$STEP" == "trivy" && -f "$TRIVY_IMAGE_REPORT" ]] && echo "Trivy image report: $TRIVY_IMAGE_REPORT"
  echo "Step: $STEP"
  echo "Exit code: $EXIT_CODE"
} | tee "$SUMMARY_FILE"

log "Finished"
exit $EXIT_CODE
