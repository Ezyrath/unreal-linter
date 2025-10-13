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

# 1) C++ formatting: find .cpp .h .hpp .inl
echo "Checking C/C++ formatting with clang-format..."
FILES_CC=$(find "$ROOT_DIR" -type f \( -name "*.cpp" -o -name "*.cc" -o -name "*.h" -o -name "*.hpp" -o -name "*.inl" \) ) || true
if [ -n "$FILES_CC" ]; then
  STATUS=0
  for f in $FILES_CC; do
    clang-format -style=file "$f" | diff -u "$f" - || STATUS=1 || true
  done
  if [ $STATUS -ne 0 ]; then
    echo "C/C++ formatting issues detected (use clang-format -i)."
  else
    echo "C/C++ files formatted correctly."
  fi
else
  echo "No C/C++ source files found."
fi

# 2) C# formatting: use dotnet-format if available
echo "Checking C# formatting..."
if command -v dotnet >/dev/null 2>&1; then
  if dotnet tool list -g | grep -q dotnet-format; then
    dotnet format "$ROOT_DIR" --verify-no-changes || echo "C# formatting issues detected (use dotnet format)."
  else
    echo "dotnet-format not installed as a global tool. Skipping C# auto-check."
  fi
else
  echo "dotnet not available in image. Skipping C# formatting check."
fi

# 3) Asset naming checks (expects unreal-asset-name.csv in /usr/src/unreal-linter)
echo "Checking Unreal asset names..."
echo "Using include_dirs='$INCLUDE_DIRS' exclude_dirs='$EXCLUDE_DIRS'"
if [ -n "$INCLUDE_DIRS" ] || [ -n "$EXCLUDE_DIRS" ]; then
  node /usr/src/unreal-linter/scripts/check_asset_names.js "$ROOT_DIR" /usr/src/unreal-linter/unreal-asset-name.csv "$INCLUDE_DIRS" "$EXCLUDE_DIRS"
else
  node /usr/src/unreal-linter/scripts/check_asset_names.js "$ROOT_DIR" /usr/src/unreal-linter/unreal-asset-name.csv
fi

echo "Checks complete."
