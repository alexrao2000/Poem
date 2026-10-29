#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT_BIN="${GODOT_BIN:-godot}"
mkdir -p build/web build/native build/logs
touch build/.gdignore
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/import.log" --path "$PWD" --editor --import
GODOT_BIN="$GODOT_BIN" python3 scripts/test_local.py
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/web.log" --path "$PWD" --export-release Web
python3 scripts/pack_web.py
# Export to a new temporary path so Godot never needs to use the system Trash.
BUILD_STAGE="$(mktemp -d "${TMPDIR:-/tmp}/ashen-build.XXXXXX")"
trap 'rm -rf "$BUILD_STAGE"' EXIT
"$GODOT_BIN" --headless --log-file "$PWD/build/logs/native.log" --path "$PWD" --export-release macOS "$BUILD_STAGE/AshenStandard.zip"
mv "$BUILD_STAGE/AshenStandard.zip" build/native/AshenStandard.zip
python3 - <<'PY'
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
with ZipFile('build/AshenStandard-Web.zip','w',ZIP_DEFLATED) as archive:
    for path in Path('build/web').iterdir():
        if path.is_file():archive.write(path,path.name)
    archive.writestr('PLAY.txt','Extract this folder and run: python3 -m http.server 8060\nThen open http://localhost:8060 in a desktop browser.\n')
PY
printf 'Local browser and macOS builds are ready in build/.\n'
