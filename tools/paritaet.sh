#!/bin/bash
# Paritaetsbeweis: spielt dieselben Autopilot-Runs im C#-Kern und im
# GDScript-Kern (godot-next) und vergleicht die Spuren Zeile fuer Zeile.
#
#   tools/paritaet.sh            # Standardmatrix
#   tools/paritaet.sh quick      # nur ein paar Seeds
#   GODOT_PROJEKT=pfad tools/paritaet.sh
#
# Braucht: dotnet 8, godot 4.7 im PATH, python3.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJ="${GODOT_PROJEKT:-$ROOT/godot-next}"
OUT="${PARITAET_OUT:-$(mktemp -d)}"
JOBS="${JOBS:-4}"
mkdir -p "$OUT"

dotnet build "$ROOT/src/Tartot.Sim" -c Release -v q -nologo >/dev/null || { echo "C#-Build fehlgeschlagen"; exit 2; }
SIM="$ROOT/src/Tartot.Sim/bin/Release/net8.0/Tartot.Sim.dll"
timeout 300 godot --headless --path "$PROJ" --editor --quit >/dev/null 2>&1

# Jede Zeile: Name und Argumente (beide Kerne verstehen dieselben).
faelle() {
  if [ "${1:-}" = quick ]; then
    for s in 1 2 3; do echo "seed$s --trace=$s"; done
    return
  fi
  for s in $(seq 1 40); do echo "seed$s --trace=$s"; done
  for d in wahrsagerin aderleser buchhalter eremit; do
    for s in 101 102 103 104 105; do echo "${d}_$s --trace=$s --deuter=$d"; done
  done
  for v in 1 2 3 4 5 6 7 8; do
    for s in 201 202 203; do echo "schleier${v}_$s --trace=$s --veil=$v"; done
  done
  for s in 301 302 303 304 305 306; do echo "spirale_$s --trace=$s --spiral=1 --fights=40"; done
  for s in 20261008 20261009; do echo "tageskarte_$s --trace=$s --veil=2 --daily=1 --deuter=eremit"; done
  # Laufbahn: Meta-Fortschritt, Prophezeiungen, Grab, Geschichten ueber Runs.
  for s in 400 500; do echo "laufbahn_$s --trace=$s --laufbahn=25"; done
  # Speichern und Laden nach jedem Zug und jedem Schritt.
  for s in 601 602 603 604; do echo "roundtrip_$s --trace=$s --roundtrip=1"; done
  echo "roundtrip_spirale_605 --trace=605 --roundtrip=1 --spiral=1 --fights=40"
}

lauf() {
  name="$1"; shift
  timeout 300 dotnet "$SIM" "$@" > "$OUT/$name.cs.txt" 2>&1
  timeout 600 godot --headless --path "$PROJ" --script res://tools/trace.gd -- "$@" > "$OUT/$name.gd.txt" 2>&1
  if python3 -I "$ROOT/tools/paritaet_vergleich.py" "$OUT/$name.cs.txt" "$OUT/$name.gd.txt" > "$OUT/$name.diff" 2>&1; then
    echo "OK    $name ($(grep -c '^T ' "$OUT/$name.cs.txt") Zuege)"
  else
    echo "ABWEICHUNG $name"; sed 's/^/      /' "$OUT/$name.diff" | head -8
  fi
}
export -f lauf
export SIM PROJ OUT ROOT

faelle "${1:-}" | xargs -P "$JOBS" -L 1 bash -c 'lauf "$@"' _ | tee "$OUT/ergebnis.txt"
ok=$(grep -c '^OK' "$OUT/ergebnis.txt"); bad=$(grep -c '^ABWEICHUNG' "$OUT/ergebnis.txt")
echo "== $ok identisch, $bad abweichend (Spuren in $OUT)"
[ "$bad" = 0 ]
