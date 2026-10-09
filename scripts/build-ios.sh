#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build-ios"
PREFIX="$ROOT/work/ios-deps/prefix"
SHIP_O2R="$ROOT/oracle/build-cmake/mm/2ship.o2r"
TEAM="${SOH_IOS_TEAM:?set your Apple Developer team id (see README)}"
CONSOLE="${SOH_REMOTE_CONSOLE:-ON}"

[[ -d "$ROOT/vendor/2ship2harkinian/.git" ]] || "$ROOT/scripts/bootstrap.sh"
"$ROOT/scripts/apply-overlay.sh"
[[ -f "$PREFIX/lib/libopusfile.a" ]] || "$ROOT/scripts/build-audio-deps-ios.sh"
if [[ ! -f "$SHIP_O2R" ]]; then
    echo "2ship.o2r missing — building host oracle first (produces it)"
    "$ROOT/scripts/build-oracle.sh"
fi
"$ROOT/scripts/check-port-o2r.sh" "$SHIP_O2R"

cmake --no-warn-unused-cli -S "$ROOT/vendor/2ship2harkinian" -B "$BUILD" -GXcode \
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO \
    -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DDEPLOYMENT_TARGET=15.0 \
    -DCMAKE_BUILD_TYPE:STRING=Release \
    -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
    "-DSOH_IOS_DEPS_PREFIX=$PREFIX" \
    "-DSOH_O2R_PATH=$SHIP_O2R" \
    "-DSOH_IOS_SHELL_DIR=$ROOT/app/ios" \
    "-DSOH_REMOTE_CONSOLE=$CONSOLE" \
    -DSOH_IOS_BUNDLE_IDENTIFIER=com.rebelancap.2ship \
    "-DSOH_IOS_DEVELOPMENT_TEAM=$TEAM" \
    "-DPNG_LIBRARY=$PREFIX/lib/libpng16.a" \
    "-DPNG_PNG_INCLUDE_DIR=$PREFIX/include"

rm -rf "$BUILD/mm/Release-iphoneos"
cmake --build "$BUILD" --config Release --target 2ship --parallel 8 -- -allowProvisioningUpdates

APP="$BUILD/mm/Release-iphoneos/2ship.app"
[[ -d "$APP" ]] || { echo "FATAL: expected app at $APP" >&2; exit 1; }
codesign -dv "$APP" 2>&1 | sed -n '1,3p'
echo "built: $APP"
