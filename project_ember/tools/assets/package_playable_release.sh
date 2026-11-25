#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/../.." && pwd)"
VERSION_FILE="$PROJECT_ROOT/VERSION.txt"
ATLAS="$PROJECT_ROOT/assets/combat/tiny_swords/combat_units_atlas.png"
MANIFEST="$PROJECT_ROOT/assets/combat/tiny_swords/atlas_manifest.json"
BATTLE_UNIT="$PROJECT_ROOT/scripts/battle_unit.gd"

if [[ ! -s "$ATLAS" || ! -s "$MANIFEST" ]]; then
  if [[ -v TINY_SWORDS_SOURCE_ZIP && -s "$TINY_SWORDS_SOURCE_ZIP" ]]; then
    python3 "$SCRIPT_DIR/build_tiny_swords_atlas.py" "$TINY_SWORDS_SOURCE_ZIP" --output-dir "$PROJECT_ROOT/assets/combat/tiny_swords"
  else
    echo "ERROR: required Tiny Swords pixel-art atlas or manifest is missing." >&2
    echo "Restore them with tools/assets/build_tiny_swords_atlas.py before packaging." >&2
    exit 2
  fi
fi

if [[ ! -f "$VERSION_FILE" ]]; then
  echo "ERROR: VERSION.txt is missing." >&2
  exit 3
fi
VERSION_ID="$(sed -n 's/^Project Ember \(v[0-9][^ ]*\).*/\1/p' "$VERSION_FILE" | head -n 1)"
if [[ -z "$VERSION_ID" ]]; then
  echo "ERROR: unable to determine Project Ember version." >&2
  exit 4
fi

python3 - "$ATLAS" "$MANIFEST" "$BATTLE_UNIT" <<'PY'
import json
import struct
import sys
from pathlib import Path
atlas_path, manifest_path, battle_unit_path = map(Path, sys.argv[1:])
raw = atlas_path.read_bytes()
if len(raw) < 26 or raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
    raise SystemExit("ERROR: combat pixel atlas is not a valid PNG.")
width, height = struct.unpack(">II", raw[16:24])
if (width, height) != (1152, 2304) or raw[25] != 6:
    raise SystemExit("ERROR: combat atlas must be a 1152x2304 RGBA PNG.")
manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
if manifest.get("cell_size") != 96 or manifest.get("rows_per_team") != 12:
    raise SystemExit("ERROR: manifest does not match the 96x96 / 12-row atlas layout.")
animations = manifest.get("animations", {})
required = ["blue_warrior_idle", "blue_warrior_run", "blue_warrior_attack_a", "blue_archer_idle", "blue_archer_shoot", "blue_lancer_idle", "red_warrior_idle", "red_warrior_run", "red_warrior_attack_a", "red_archer_idle", "red_archer_shoot", "red_lancer_idle"]
missing = [name for name in required if name not in animations]
if missing:
    raise SystemExit("ERROR: sprite manifest is missing animations: " + ", ".join(missing))
unit_script = battle_unit_path.read_text(encoding="utf-8")
if "BattleUnitVisualsScript.build(" in unit_script:
    raise SystemExit("ERROR: procedural low-poly fallback is forbidden for combat units.")
if "CombatSpriteLibraryScript.get_frames(team, role)" not in unit_script:
    raise SystemExit("ERROR: BattleUnit does not use the primary pixel-art sprite library.")
print("Pixel-art release assets OK: %dx%d, %d animations." % (width, height, len(animations)))
PY

if ! command -v zip >/dev/null 2>&1 || ! command -v unzip >/dev/null 2>&1; then
  echo "ERROR: install zip and unzip (Termux: pkg install zip unzip)." >&2
  exit 5
fi

if [[ $# -gt 0 ]]; then OUTPUT="$1"; else OUTPUT="$PROJECT_ROOT/../Project-Ember-$VERSION_ID.zip"; fi
mkdir -p "$(dirname -- "$OUTPUT")"
OUTPUT="$(cd -- "$(dirname -- "$OUTPUT")" && pwd)/$(basename -- "$OUTPUT")"
case "$OUTPUT" in
  "$PROJECT_ROOT"/*)
    echo "ERROR: ZIP output cannot be inside the project directory." >&2
    exit 6
    ;;
esac
TEMP_OUTPUT="$OUTPUT.tmp.$$"
trap 'rm -f "$TEMP_OUTPUT"' EXIT
(
  cd "$PROJECT_ROOT"
  zip -q -r -X "$TEMP_OUTPUT" * .[^.]* -x ".godot/*" ".git/*" ".import/*" "artifacts/*" "*.tmp" "*.bak"
)
unzip -tq "$TEMP_OUTPUT"
ZIP_LIST="$(unzip -Z1 "$TEMP_OUTPUT")"
grep -Fqx "assets/combat/tiny_swords/combat_units_atlas.png" <<<"$ZIP_LIST"
grep -Fqx "assets/combat/tiny_swords/atlas_manifest.json" <<<"$ZIP_LIST"
grep -Fqx "project.godot" <<<"$ZIP_LIST"
mv -f "$TEMP_OUTPUT" "$OUTPUT"
trap - EXIT
echo "READY: $OUTPUT"
echo "Project Ember $VERSION_ID — playable pixel-art archive."
echo "PNG CRC, atlas dimensions, manifest, sprite runtime and ZIP contents: OK."
