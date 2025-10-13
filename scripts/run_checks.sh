#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="/workspace"
# Read env vars (preferred) then fallback to positional args
INCLUDE_DIRS=""
EXCLUDE_DIRS=""
if [ -n "${1-}" ]; then
  ROOT_DIR="$1"
fi
# Prefer environment variables if set
if [ -n "${INCLUDE_UNREAL_ASSETS_DIRS-}" ]; then
  INCLUDE_DIRS="${INCLUDE_UNREAL_ASSETS_DIRS}"
elif [ -n "${2-}" ]; then
  INCLUDE_DIRS="$2"
fi

if [ -n "${EXCLUDE_UNREAL_ASSETS_DIRS-}" ]; then
  EXCLUDE_DIRS="${EXCLUDE_UNREAL_ASSETS_DIRS}"
elif [ -n "${3-}" ]; then
  EXCLUDE_DIRS="$3"
fi

echo "Running checks against project at: $ROOT_DIR"

# Track if any step failed. If any step fails, we will exit with non-zero at the end
ANY_STEP_FAILED=0

# 1) C++ formatting: find .cpp .h .hpp .inl
echo "Checking C/C++ formatting with clang-format..."
# Use a robust null-delimited find to handle filenames with spaces/newlines
step_failed=0
mapfile -t _files_cc < <(find "$ROOT_DIR" -type f \( -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" -o -name "*.inl" \) -print0 | xargs -0 -n1 echo) || true
if [ ${#_files_cc[@]} -gt 0 ]; then
  for f in "${_files_cc[@]}"; do
    # If diff finds differences it exits non-zero; capture that and mark the step as failed
    clang-format -style=file "$f" | diff -u "$f" - >/dev/null 2>&1 || step_failed=1 || true
  done
  if [ $step_failed -ne 0 ]; then
    echo "C/C++ formatting issues detected (use clang-format -i)."
    ANY_STEP_FAILED=1
  else
    echo "C/C++ files formatted correctly."
  fi
else
  echo "No C/C++ source files found."
fi

# 2) C# formatting: use dotnet-format if available
echo "Checking C# formatting..."
step_failed=0
if command -v dotnet >/dev/null 2>&1; then
  # Prefer the standalone dotnet-format binary (installed into /usr/share/dotnet/tools and on PATH)
  if command -v dotnet-format >/dev/null 2>&1; then
    # Standalone dotnet-format uses --check; older versions may not support --verify-no-changes
    if dotnet-format --help 2>&1 | grep -q -- '--check'; then
      dotnet-format --check "$ROOT_DIR" || step_failed=1 || true
    else
      # Try the older flag; if it's not supported this will set step_failed
      dotnet-format --verify-no-changes "$ROOT_DIR" || step_failed=1 || true
    fi
    if [ $step_failed -ne 0 ]; then
      echo "C# formatting issues detected (use dotnet-format or dotnet format)."
      ANY_STEP_FAILED=1
    else
      echo "C# files formatted correctly."
    fi
  elif dotnet tool list -g | grep -q dotnet-format; then
    # Fallback to global tool invocation via 'dotnet format'
    dotnet format "$ROOT_DIR" --verify-no-changes || step_failed=1 || true
    if [ $step_failed -ne 0 ]; then
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

# 3) Asset naming checks (expects unreal-asset-name.csv in /usr/src/unreal-linter)
echo "Checking Unreal asset names..."
echo "Using include_dirs='$INCLUDE_DIRS' exclude_dirs='$EXCLUDE_DIRS'"
step_failed=0
if [ -n "$INCLUDE_DIRS" ] || [ -n "$EXCLUDE_DIRS" ]; then
  node /usr/src/unreal-linter/scripts/check_asset_names.js "$ROOT_DIR" /usr/src/unreal-linter/unreal-asset-name.csv "$INCLUDE_DIRS" "$EXCLUDE_DIRS" || step_failed=1 || true
else
  node /usr/src/unreal-linter/scripts/check_asset_names.js "$ROOT_DIR" /usr/src/unreal-linter/unreal-asset-name.csv || step_failed=1 || true
fi
if [ $step_failed -ne 0 ]; then
  echo "Unreal asset name checks failed."
  ANY_STEP_FAILED=1
else
  echo "Unreal asset names OK."
fi

echo "Checks complete."

# If any step failed, exit with non-zero so CI (GitHub Actions) fails.
if [ $ANY_STEP_FAILED -ne 0 ]; then
  echo "One or more checks failed. Exiting with non-zero status."
  exit 1
else
  echo "All checks passed."
  exit 0
fi
