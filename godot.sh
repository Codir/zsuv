#!/usr/bin/env bash
# One entry point for Khutir Road. Godot 4.7.2 lives in tools/godot/ (not in git); `fetch` puts it
# there, or point GODOT at an existing binary (GODOT=/path/to/Godot_v4.7.2-stable_win64_console.exe).
#   ./godot.sh fetch                 download Godot 4.7.2 (+ export templates) for this OS
#   ./godot.sh run [-- --autodrive]  play (args after -- go to the game)
#   ./godot.sh editor                open the editor
#   ./godot.sh check                 parse every script, compile every shader, headless
#   ./godot.sh test [filter]         tests/run_tests.gd
#   ./godot.sh export [preset|all]   Web | Windows | Linux | macOS -> builds/
#   ./godot.sh web                   export Web and serve it on http://localhost:8060
#   ./godot.sh capture               record the trailer scenes into capture/trailer/ (tools/make_media.py)
#   ./godot.sh soundcheck            record the game's mix on a scripted drive into capture/soundcheck.wav
# Works with the bash 3.2 of a stock Mac as well as Git Bash on Windows.
set -euo pipefail
cd "$(dirname "$0")"
VER=4.7.2
case "$(uname -s)" in
  Linux*)  BIN="tools/godot/Godot_v${VER}-stable_linux.x86_64"; ZIP="Godot_v${VER}-stable_linux.x86_64.zip"; TPL="$HOME/.local/share/godot/export_templates";;
  Darwin*) BIN="tools/godot/Godot.app/Contents/MacOS/Godot"; ZIP="Godot_v${VER}-stable_macos.universal.zip"; TPL="$HOME/Library/Application Support/Godot/export_templates";;
  MINGW*|MSYS*|CYGWIN*) BIN="tools/godot/Godot_v${VER}-stable_win64_console.exe"; ZIP="Godot_v${VER}-stable_win64.exe.zip"; TPL="$APPDATA/Godot/export_templates";;
esac
BIN="${GODOT:-$BIN}"
URL="https://github.com/godotengine/godot/releases/download/${VER}-stable"
# A time limit where the system has one (macOS ships no `timeout`; Homebrew's coreutils call it gtimeout).
LIMIT="$(command -v timeout || command -v gtimeout || true)"

fetch() {
  if [ ! -e "$BIN" ]; then
    mkdir -p tools/godot
    echo "downloading $ZIP"; curl -fL -o "tools/godot/$ZIP" "$URL/$ZIP"; (cd tools/godot && unzip -q -o "$ZIP" && rm "$ZIP")
  fi
  if [ "${1:-}" = "templates" ] && [ ! -d "$TPL/${VER}.stable" ]; then
    echo "downloading export templates (~600 MB)"
    mkdir -p tools/godot
    curl -fL -o tools/godot/tpl.tpz "$URL/Godot_v${VER}-stable_export_templates.tpz"
    mkdir -p "$TPL"; (cd tools/godot && unzip -q -o tpl.tpz && rm tpl.tpz); mv tools/godot/templates "$TPL/${VER}.stable"
  fi
}

# builds/ and capture/ hold PNGs and binaries that Godot must not import as project resources.
# The import runs every time (a second or two): running a scene or a script does not rescan, so a
# new class_name script or asset pulled since the last import would otherwise not be found.
imported() { mkdir -p builds capture && touch builds/.gdignore capture/.gdignore; "$BIN" --headless --path . --import >/dev/null 2>&1 || true; }

out_for() {
  case "$1" in
    Web) echo builds/web/index.html;;
    Windows) echo builds/windows/KhutirRoad.exe;;
    Linux) echo builds/linux/KhutirRoad.x86_64;;
    macOS) echo builds/macos/KhutirRoad.zip;;
  esac
}

export_presets() {
  fetch templates; imported
  local p="${1:-all}" k out hit=0
  for k in Web Windows Linux macOS; do
    if [ "$p" = all ] || [ "$p" = "$k" ]; then
      out="$(out_for "$k")"; mkdir -p "$(dirname "$out")"
      "$BIN" --headless --path . --export-release "$k" "$out"; hit=1
    fi
  done
  [ "$hit" = 1 ] || { echo "unknown preset '$p' (Web | Windows | Linux | macOS | all)" >&2; exit 1; }
}

cmd="${1:-run}"; shift || true
case "$cmd" in
  fetch) fetch templates;;
  run) fetch; imported; [ "${1:-}" = "--" ] && shift; exec "$BIN" --path . -- "$@";;
  editor) fetch; exec "$BIN" --path . -e;;
  check) fetch; imported
    rc=0; out=$("$BIN" --headless --path . -s res://tests/check.gd 2>&1) || rc=$?
    echo "$out" | grep -v "^Godot Engine" || true
    [ "$rc" -eq 0 ] && ! echo "$out" | grep -q "SCRIPT ERROR\|SHADER ERROR\|Parse Error\|Failed to load";;
  test) fetch; imported; exec ${LIMIT:+$LIMIT 900} "$BIN" --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd -- "$@";;
  export) export_presets "${1:-all}";;
  web) export_presets Web; echo "http://localhost:8060"; cd builds/web && exec python3 -m http.server 8060;;
  capture) fetch; imported; what="${1:-trailer}"; out="$(pwd -W 2>/dev/null || pwd)/capture/$what"; rm -rf "$out"; mkdir -p "$out"
    ${LIMIT:+$LIMIT 900} "$BIN" --path . --fixed-fps 30 --disable-vsync -- --capture="$what" --out="$out"
    cat "$out/done.txt";;
  soundcheck) fetch; imported; out="$(pwd -W 2>/dev/null || pwd)/capture/soundcheck.wav"
    ${LIMIT:+$LIMIT 300} "$BIN" --headless --path . -s res://tests/soundcheck.gd -- --out="$out" 2>&1 | grep -v "^Godot Engine\|^autodrive pos";;
  *) sed -n '2,13p' godot.sh; exit 1;;
esac
