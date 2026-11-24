#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ "${1:-}" == "--help" || "${1:-}" == "-h" ]]; then
    cat <<'HELP'
Usage: scripts/build_local.sh [suite ...]

With no arguments, run every default suite before exporting Web and macOS.
Named suites run focused checks instead. Exported-resource smoke still runs.
Example: GODOT_BIN=/path/to/godot scripts/build_local.sh iris_palette face_blink

A focused build is not evidence that the full suite passed.
HELP
    exit 0
fi
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build/web build/native build/logs
touch build/.gdignore
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/import.log" --path "$PWD" --editor --import
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/model-catalog.log" --path "$PWD" --script scripts/check_combat_models.gd
GODOT_BIN="$GODOT_BIN" python3 scripts/test_local.py "$@"
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/web.log" --path "$PWD" --export-release Web
GODOT_BIN="$GODOT_BIN" python3 scripts/pack_web.py
node tests/test_web_loading.cjs
GODOT_BIN="$GODOT_BIN" python3 scripts/test_local.py export
# Export to a new temporary path so Godot never needs to use the system Trash.
BUILD_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/poem-build.XXXXXX")"
trap 'rm -rf "$BUILD_STAGE"' EXIT
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/native.log" --path "$PWD" --export-release macOS "$BUILD_STAGE/Poem.zip"
mv "$BUILD_STAGE/Poem.zip" build/native/Poem.zip
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
with ZipFile('build/Poem-Web.zip','w',ZIP_DEFLATED) as archive:
    for path in Path('build/web').iterdir():
        if path.is_file():archive.write(path,path.name)
    archive.writestr('PLAY.txt','Extract this folder and run: python3 -m http.server 8060\nThen open http://localhost:8060 in a desktop browser.\n')
PY
printf 'Local browser and macOS builds are ready in build/.\n'
