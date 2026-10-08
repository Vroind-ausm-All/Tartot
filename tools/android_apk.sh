#!/bin/bash
# Baut das Android-Debug-APK von godot-next (Godot 4.7.2, arm64-v8a).
#
#   tools/android_apk.sh                 # -> Build/Android/TARTOT-godot-next-debug.apk
#
# Voraussetzungen (einmalig):
#   1. Export-Templates 4.7.2 unter ~/.local/share/godot/export_templates/4.7.2.stable/
#      (aus Godot_v4.7.2-stable_export_templates.tpz: version.txt, android_debug.apk,
#      android_release.apk, android_source.zip)
#   2. Android-SDK. Ein volles SDK (Android Studio / sdkmanager) geht immer.
#      Ohne Zugriff auf dl.google.com reicht fuer den Export ohne Gradle ein
#      Minimal-SDK aus Distributionspaketen:
#        apt-get install apksigner zipalign adb
#        SDK=$HOME/android-sdk-min
#        mkdir -p $SDK/platform-tools $SDK/build-tools/35.0.0
#        ln -s /usr/bin/adb $SDK/platform-tools/adb
#        ln -s /usr/bin/apksigner /usr/bin/zipalign $SDK/build-tools/35.0.0/
#   3. Godot-Editoreinstellungen (~/.config/godot/editor_settings-4.7.tres):
#        export/android/android_sdk_path, export/android/java_sdk_path (JDK 17+),
#        export/android/debug_keystore (Godot legt beim ersten Editorstart eines an).
#      ANDROID_SDK=pfad setzt den SDK-Pfad fuer diesen Lauf.
set -eu
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SETTINGS="$HOME/.config/godot/editor_settings-4.7.tres"
TEMPLATES="$HOME/.local/share/godot/export_templates/4.7.2.stable"
OUT="$ROOT/Build/Android/TARTOT-godot-next-debug.apk"

[ -f "$TEMPLATES/android_debug.apk" ] || { echo "Export-Templates fehlen: $TEMPLATES"; exit 2; }
timeout 300 godot --headless --path "$ROOT/godot-next" --editor --quit >/dev/null 2>&1 || true
if [ -n "${ANDROID_SDK:-}" ]; then
  sed -i "s#^export/android/android_sdk_path = .*#export/android/android_sdk_path = \"$ANDROID_SDK\"#" "$SETTINGS"
fi
SDK=$(sed -n 's#^export/android/android_sdk_path = "\(.*\)"#\1#p' "$SETTINGS")
ls "$SDK"/build-tools/*/apksigner >/dev/null 2>&1 || { echo "apksigner fehlt unter $SDK/build-tools/*/"; exit 2; }

mkdir -p "$(dirname "$OUT")"
rm -f "$OUT" "$OUT.idsig"
timeout 900 godot --headless --path "$ROOT/godot-next" --export-debug "Android Prototype" "$OUT" 2>&1 \
  | grep -E "ERROR|DONE.*export" || true
[ -f "$OUT" ] || { echo "Export fehlgeschlagen."; exit 1; }
"$SDK"/build-tools/*/apksigner verify "$OUT" >/dev/null 2>&1 || { echo "Signatur ungueltig."; exit 1; }
echo "Signatur geprueft (apksigner verify)."
ls -la "$OUT"
