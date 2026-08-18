#!/bin/bash
#
# Verifikation der Rechenkerne von SunPos – ohne Xcode-Testtarget.
#
#   SolarTests        Sonnenstand gegen veröffentlichte Referenzwerte (läuft auf dem Mac)
#   SkyGeometryTests  Umrechnung Azimut/Höhe → ARKit-Weltachsen (iOS-Simulator)
#   SceneTests        Aufbau des AR-Szenengraphen (iOS-Simulator)
#
# Aufruf:  ./Tests/run-tests.sh
#
set -uo pipefail

cd "$(dirname "$0")/.." || exit 1
SOURCES_MODEL="SunPos/Model/Solar.swift SunPos/Model/SolarDay.swift"
SOURCES_AR="SunPos/AR/SunSceneController.swift SunPos/AR/SkyGeometry.swift"
BUILD=".build/tests"
mkdir -p "$BUILD"

FAILED=0
run_section() { printf '\n\033[1m── %s \033[0m\n' "$1"; }

# ---------------------------------------------------------------- 1) Sonnenstand (macOS)
run_section "SolarTests (macOS)"
if swiftc -O -o "$BUILD/SolarTests" Tests/SolarTests/main.swift $SOURCES_MODEL 2>&1 | grep -E "error:"; then
    echo "Kompilierung fehlgeschlagen"; FAILED=1
else
    "$BUILD/SolarTests" || FAILED=1
fi

# ------------------------------------------------- 2)+3) Geometrie und Szene (Simulator)
SDK=$(xcrun --sdk iphonesimulator --show-sdk-path 2>/dev/null)
if [ -z "$SDK" ]; then
    echo; echo "iOS-Simulator-SDK nicht gefunden – Geometrie- und Szenentests übersprungen."
    exit $FAILED
fi

# Einen gebooteten Simulator finden, sonst den ersten verfügbaren iPhone-Simulator starten.
SIM=$(xcrun simctl list devices booted -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
for runtime in d:
    for dev in d[runtime]:
        if 'iOS' in runtime:
            print(dev['udid']); raise SystemExit
" 2>/dev/null)

if [ -z "$SIM" ]; then
    SIM=$(xcrun simctl list devices available -j | python3 -c "
import json,sys
d=json.load(sys.stdin)['devices']
best=None
for runtime in sorted(d):
    if 'iOS' not in runtime: continue
    for dev in d[runtime]:
        if dev['name'].startswith('iPhone'): best=dev['udid']
if best: print(best)
" 2>/dev/null)
    if [ -z "$SIM" ]; then
        echo; echo "Kein iPhone-Simulator verfügbar – Geometrie- und Szenentests übersprungen."
        exit $FAILED
    fi
    echo "Starte Simulator $SIM …"
    xcrun simctl boot "$SIM" >/dev/null 2>&1
    xcrun simctl bootstatus "$SIM" -b >/dev/null 2>&1
fi

build_and_run_sim() {
    local name="$1"; shift
    run_section "$name (iOS-Simulator)"
    if swiftc -O -sdk "$SDK" -target arm64-apple-ios17.0-simulator \
        -o "$BUILD/$name" "Tests/$name/main.swift" "$@" 2>&1 | grep -E "error:"; then
        echo "Kompilierung fehlgeschlagen"; FAILED=1; return
    fi
    xcrun simctl spawn "$SIM" "$BUILD/$name" || FAILED=1
}

build_and_run_sim SkyGeometryTests SunPos/AR/SkyGeometry.swift $SOURCES_MODEL
build_and_run_sim SceneTests $SOURCES_AR $SOURCES_MODEL

printf '\n'
if [ $FAILED -eq 0 ]; then
    printf '\033[32mAlle Testgruppen bestanden.\033[0m\n'
else
    printf '\033[31mMindestens eine Testgruppe ist fehlgeschlagen.\033[0m\n'
fi
exit $FAILED
