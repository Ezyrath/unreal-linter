# unreal-linter (Docker image)

Small Docker-based linter that performs:

- C/C++ formatting checks with `clang-format` (uses local `.clang-format`)
- C# formatting checks with `dotnet format` (requires compatible SDK/runtime)
- Unreal Engine asset file name checks using `unreal-asset-name.csv` rules

> Currently `.clang-format` and `.editorconfig` must be present in the project root. (the files in the repo are examples)

This repository contains a multi-stage `Dockerfile` (Fedora-based) and helper scripts under `scripts/`.

Build the image (from the repo root):

```bash
docker build -t unreal-linter:latest .
```

Run the linter against a local Unreal project (mount project to `/workspace`):

Basic (defaults):

```bash
docker run --rm -v "$(pwd):/workspace" unreal-linter:latest
```

Including/excluding specific asset directories / source directories (recommended via env vars):

```
docker run --rm -v "$(pwd):/workspace" \
  -e INCLUDE_SOURCE_DIRS="Source" \
  -e EXCLUDE_SOURCE_DIRS="" \
  -e INCLUDE_UNREAL_ASSETS_DIRS="Content" \
  -e EXCLUDE_UNREAL_ASSETS_DIRS="Content/_DevImport,Content/__ExternalObjects__,Content/__ExternalActors__" \
  unreal-linter:latest
```
Output example (with some intentional failures):

```txt
Running checks against project at: /workspace

Checking C/C++ formatting...
----------------
Using INCLUDE_DIRS='Source' EXCLUDE_DIRS=''
C/C++ files formatted correctly.
--- [PASSED] ---

Checking C# formatting...
----------------
Using INCLUDE_DIRS='Source' EXCLUDE_DIRS=''
C# files formatted correctly.
--- [PASSED] ---

Checking Unreal asset names...
----------------
Using INCLUDE_DIRS='Content' EXCLUDE_DIRS='Content/_DevImport,Content/__ExternalObjects__,Content/__ExternalActors__'
Asset naming issues found:
 - Content/Levels/Example.uasset ("Example") does not match any naming rule
 - Content/Inputs/NULL_Character.uasset ("NULL_Character") does not match any naming rule
--- [FAILED] ---

CHECKS COMPLETE

--- RESULTS ---
One or more checks failed. Exiting with non-zero status.
```

Notes & behavior
- The asset name checker scans for asset extensions defined in `scripts/check_asset_names.js` (default includes `.uasset`, `.umap`, etc.). You can adjust that list in the script.
- C/C++ formatting: compares files with `clang-format -style=file` and reports differences; does not auto-fix unless you modify the script to run `clang-format -i`.
- C#: `dotnet` is installed in the image but the project's SDK version must be compatible with .NET SDK 7 installed in the container.

Limitations
- This tool checks filenames (`.uasset`/`.umap` etc.) — it does not parse asset internals inside Unreal packages.

Sources
- Unreal asset naming rules are based on [Epic's guidelines](https://dev.epicgames.com/documentation/en-us/unreal-engine/recommended-asset-naming-conventions-in-unreal-engine-projects), [Unreal Directives](https://unrealdirective.com/resources/asset-naming-conventions) and personal experience.
