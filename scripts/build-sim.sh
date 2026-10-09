#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/spikes/2s2h-sim-build"
PREFIX="$ROOT/work/ios-sim-deps/prefix"
SHIP_O2R="$ROOT/oracle/build-cmake/mm/2ship.o2r"
CONSOLE="${SOH_REMOTE_CONSOLE:-ON}"

[[ -d "$ROOT/vendor/2ship2harkinian/.git" ]] || "$ROOT/scripts/bootstrap.sh"
"$ROOT/scripts/apply-overlay.sh"
[[ -f "$PREFIX/lib/libopusfile.a" ]] || SOH_IOS_SDK=simulator "$ROOT/scripts/build-audio-deps-ios.sh"
[[ -f "$SHIP_O2R" ]] || "$ROOT/scripts/build-oracle.sh"
"$ROOT/scripts/check-port-o2r.sh" "$SHIP_O2R"

cmake --no-warn-unused-cli -S "$ROOT/vendor/2ship2harkinian" -B "$BUILD" -GXcode \
    -DCMAKE_XCODE_ATTRIBUTE_STRIP_INSTALLED_PRODUCT=NO \
    "-DSOH_REMOTE_CONSOLE=$CONSOLE" \
    -DCMAKE_SYSTEM_NAME=iOS -DPLATFORM=SIMULATORARM64 \
    -DCMAKE_DISABLE_PRECOMPILE_HEADERS=ON \
    -DCMAKE_OSX_SYSROOT=iphonesimulator \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 -DCMAKE_BUILD_TYPE:STRING=Release \
    -DDEPLOYMENT_TARGET=15.0 \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
    -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY="" \
    "-DSOH_IOS_DEPS_PREFIX=$PREFIX" \
    "-DSOH_O2R_PATH=$SHIP_O2R" \
    "-DSOH_IOS_SHELL_DIR=$ROOT/app/ios" \
    "-DPNG_LIBRARY=$PREFIX/lib/libpng16.a" \
    "-DPNG_PNG_INCLUDE_DIR=$PREFIX/include"

cmake --build "$BUILD" --config Release --target 2ship --parallel 8

APP="$BUILD/mm/Release-iphonesimulator/2ship.app"
[[ -d "$APP" ]] || { echo "FATAL: expected app at $APP" >&2; exit 1; }
lipo -info "$APP/2ship"
echo "built (simulator): $APP"
