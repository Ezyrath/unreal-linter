#!/usr/bin/env bash
set -euo pipefail

export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_NOLOGO=1

# Environment VAR used:
# INCLUDE_UNREAL_ASSETS_DIRS: comma-separated list of directories (relative to project root) to include in asset name checks
# EXCLUDE_UNREAL_ASSETS_DIRS: comma-separated list of directories (relative to project root) to exclude from asset name checks
# INCLUDE_SOURCE_DIRS: comma-separated list of directories (relative to project root) to include in C/C++/C# formatting checks
# EXCLUDE_SOURCE_DIRS: comma-separated list of directories (relative to project root) to exclude from C/C++/C# formatting checks

ROOT_DIR="$(pwd)"

# check node is available
if ! command -v node >/dev/null 2>&1; then
  echo "node not found in PATH. Cannot run checks."
  exit 1
fi

echo "Running checks against project at: $ROOT_DIR"

# Track if any step failed. If any step fails, we will exit with non-zero at the end
ANY_STEP_FAILED=0
STEP_FAILED=0

function STEP_PASSED_OR_FAILED() {
  if [ $STEP_FAILED -ne 0 ]; then
    echo "--- [FAILED] ---"
    ANY_STEP_FAILED=1
  else
    echo "--- [PASSED] ---"
  fi
}

function LAUNCH_SCRIPT() {
  local SCRIPT_PATH="$1"
  local INCLUDE_DIRS="${2:-}"
  local EXCLUDE_DIRS="${3:-}"

  STEP_FAILED=0
  echo "----------------"
  if [ -n "${INCLUDE_DIRS}" ] || [ -n "${EXCLUDE_DIRS}" ]; then
    echo "Using INCLUDE_DIRS='${INCLUDE_DIRS}' EXCLUDE_DIRS='${EXCLUDE_DIRS}'"
    node "$SCRIPT_PATH" "$ROOT_DIR" "$INCLUDE_DIRS" "$EXCLUDE_DIRS" || STEP_FAILED=1 || true
  else
    node "$SCRIPT_PATH" "$ROOT_DIR" || STEP_FAILED=1 || true
  fi
  STEP_PASSED_OR_FAILED
}

# 1) C++ formatting: use Node script to check clang-format consistency
echo ""
echo "Checking C/C++ formatting..."
LAUNCH_SCRIPT /usr/src/unreal-linter/scripts/check_cc_format.js "$INCLUDE_SOURCE_DIRS" "$EXCLUDE_SOURCE_DIRS"

# 2) C# formatting: use Node script to run `dotnet format whitespace --verify-no-changes --folder --include FILE` per-file
echo ""
echo "Checking C# formatting..."
LAUNCH_SCRIPT /usr/src/unreal-linter/scripts/check_cs_format.js "$INCLUDE_SOURCE_DIRS" "$EXCLUDE_SOURCE_DIRS"

# 3) Asset naming checks (expects unreal-asset-name.csv in /usr/src/unreal-linter)
echo ""
echo "Checking Unreal asset names..."
LAUNCH_SCRIPT /usr/src/unreal-linter/scripts/check_asset_names.js "$INCLUDE_UNREAL_ASSETS_DIRS" "$EXCLUDE_UNREAL_ASSETS_DIRS"

echo ""
echo "CHECKS COMPLETE"
echo ""
echo "--- RESULTS ---"

# If any step failed, exit with non-zero so CI (GitHub Actions) fails.
if [ $ANY_STEP_FAILED -ne 0 ]; then
  echo "One or more checks failed. Exiting with non-zero status."
  exit 1
else
  echo "All checks passed."
  exit 0
fi
