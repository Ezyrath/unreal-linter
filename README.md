# unreal-linter (Docker image)

Small Docker-based linter that performs:

- C/C++ formatting checks with `clang-format` (uses local `.clang-format`)
- C# formatting checks with `dotnet format` (requires compatible SDK/runtime)
- Unreal Engine asset file name checks using `unreal-asset-name.csv` rules

This repository contains a multi-stage `Dockerfile` (Fedora-based) and helper scripts under `scripts/`.

Build the image (from the repo root):

```bash
docker build -t unreal-linter:fedora .
```

Run the linter against a local Unreal project (mount project to `/workspace`):

Basic (defaults):

```bash
docker run --rm -v "$(pwd)/MyUnrealProject:/workspace" unreal-linter:fedora
```

Including/excluding specific asset directories / source directories (recommended via env vars):

```bash
docker run --rm -v "$(pwd):/workspace" \
  -e INCLUDE_SOURCE_DIRS="Source" \
  -e EXCLUDE_SOURCE_DIRS="" \
  -e INCLUDE_UNREAL_ASSETS_DIRS="Content" \
  -e EXCLUDE_UNREAL_ASSETS_DIRS="Content/_DevImport,Content/__ExternalObjects__,Content/__ExternalActors__" \
  unreal-linter:fedora
```

Notes & behavior
- The asset name checker scans for asset extensions defined in `scripts/check_asset_names.js` (default includes `.uasset`, `.umap`, etc.). You can adjust that list in the script.
- `run_checks.sh` prefers `INCLUDE_UNREAL_ASSETS_DIRS` / `EXCLUDE_UNREAL_ASSETS_DIRS` environment variables when set; otherwise it falls back to positional args 2/3.
- C/C++ formatting: compares files with `clang-format -style=file` and reports differences; does not auto-fix unless you modify the script to run `clang-format -i`.
- C#: `dotnet-format` is installed in the image but the project's SDK version must be compatible with .NET SDK 7 installed in the container.

Limitations
- This tool checks filenames (`.uasset`/`.umap` etc.) — it does not parse asset internals inside Unreal packages. For deeper checks you'd export metadata from Unreal Editor or use editor commandlets.

Extending
- Make the asset extension list configurable (env or config file).
- Add a `--fix` flag to `run_checks.sh` to apply `clang-format -i` automatically.
- Add named CLI flags (`--include`, `--exclude`) if you prefer explicit options over env vars.
