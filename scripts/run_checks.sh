#!/usr/bin/env bash
set -euo pipefail

# Environment VAR used:
# INCLUDE_UNREAL_ASSETS_DIRS: comma-separated list of directories (relative to project root) to include in asset name checks
# EXCLUDE_UNREAL_ASSETS_DIRS: comma-separated list of directories (relative to project root) to exclude from asset name checks
# INCLUDE_SOURCE_DIRS: comma-separated list of directories (relative to project root) to include in C/C++/C# formatting checks
# EXCLUDE_SOURCE_DIRS: comma-separated list of directories (relative to project root) to exclude from C/C++/C# formatting checks

ROOT_DIR="/workspace"

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

# 2) C# formatting: use dotnet-format if available
echo ""
echo "Checking C# formatting..."
echo "----------------"
STEP_FAILED=0
if command -v dotnet >/dev/null 2>&1; then
  # Prefer the standalone dotnet-format binary (installed into /usr/share/dotnet/tools and on PATH)
  if command -v dotnet-format >/dev/null 2>&1; then
    # Standalone dotnet-format uses --check; older versions may not support --verify-no-changes
    if dotnet-format --help 2>&1 | grep -q -- '--check'; then
      dotnet-format --check "$ROOT_DIR" || STEP_FAILED=1 || true
    else
      # Try the older flag; if it's not supported this will set STEP_FAILED
      dotnet-format --verify-no-changes "$ROOT_DIR" || STEP_FAILED=1 || true
    fi
    if [ $STEP_FAILED -ne 0 ]; then
      echo "C# formatting issues detected (use dotnet-format or dotnet format)."
      ANY_STEP_FAILED=1
    else
      echo "C# files formatted correctly."
    fi
  elif dotnet tool list -g | grep -q dotnet-format; then
    # Fallback to global tool invocation via 'dotnet format'
    dotnet format "$ROOT_DIR" --verify-no-changes || STEP_FAILED=1 || true
    if [ $STEP_FAILED -ne 0 ]; then
      echo "C# formatting issues detected (use dotnet format)."
      ANY_STEP_FAILED=1
    else
      echo "C# files formatted correctly."
    fi
  else
    echo "dotnet-format not available. Skipping C# auto-check."
  fi
else
  echo "dotnet not available in image. Skipping C# formatting check."
fi
STEP_PASSED_OR_FAILED

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
