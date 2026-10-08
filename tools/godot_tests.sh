#!/bin/bash
# Alle Godot-Tests von godot-next (Godot 4.7.x im PATH). Exit 1 bei einem Fehler.
#   tools/godot_tests.sh
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
P="$ROOT/godot-next"
timeout 300 godot --headless --path "$P" --editor --quit >/dev/null 2>&1
fail=0
for t in "--script res://tests/smoke.gd" "res://tests/ui_walk.tscn" "res://tests/turm_slice.tscn" \
         "res://tests/mond_slice.tscn" "res://tests/tod_slice.tscn"; do
  log=$(timeout 900 godot --headless --path "$P" $t 2>&1); code=$?
  zeile=$(echo "$log" | grep -E 'smoke:|UI-Durchlauf|BOSS-SLICE.*fehler' | tail -1)
  if [ $code -eq 0 ] && ! echo "$log" | grep -q "SCRIPT ERROR"; then
    echo "OK    $t  $zeile"
  else
    echo "FEHLER $t (exit $code)"; echo "$log" | grep -E "SCRIPT ERROR|FEHL|fehler" | head -5; fail=1
  fi
done
exit $fail
