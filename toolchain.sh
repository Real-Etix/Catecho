#!/bin/bash
RADIO_SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RADIO_BUILD_DIR="$RADIO_SOURCE_DIR/.build-local"
mkdir -p "$RADIO_BUILD_DIR/module-cache"
RADIO_SDK="$(xcrun --show-sdk-path)"
RADIO_TOOLCHAIN="$(xcode-select -p)/usr/include/swift"
RADIO_FLAGS=(-module-cache-path "$RADIO_BUILD_DIR/module-cache" -target arm64-apple-macosx14.0 -sdk "$RADIO_SDK")
# Some Command Line Tools installations contain two identical SwiftBridging
# module maps. A local virtual overlay avoids changing the installed toolchain.
if [ -f "$RADIO_TOOLCHAIN/module.modulemap" ] && [ -f "$RADIO_TOOLCHAIN/bridging.modulemap" ] && /usr/bin/grep -q '^module SwiftBridging' "$RADIO_TOOLCHAIN/module.modulemap" && /usr/bin/grep -q '^module SwiftBridging' "$RADIO_TOOLCHAIN/bridging.modulemap"; then
    : > "$RADIO_BUILD_DIR/empty.modulemap"
    /usr/bin/python3 - "$RADIO_TOOLCHAIN/module.modulemap" "$RADIO_BUILD_DIR/empty.modulemap" "$RADIO_BUILD_DIR/overlay.json" <<'PY'
import json, sys
with open(sys.argv[3], 'w') as f:
    json.dump({'version': 0, 'roots': [{'type': 'file', 'name': sys.argv[1], 'external-contents': sys.argv[2]}]}, f)
PY
    RADIO_FLAGS+=(-vfsoverlay "$RADIO_BUILD_DIR/overlay.json")
fi

# Build the vendored decompression-only decoder once per source/configuration hash.
# The object is linked into each executable; no external zstd installation is used.
RADIO_ZSTD_DIR="$RADIO_SOURCE_DIR/Vendor/Zstd"
RADIO_ZSTD_OBJECT="$RADIO_BUILD_DIR/zstd-decoder.o"
RADIO_ZSTD_HASH="$(/usr/bin/shasum -a 256 "$RADIO_ZSTD_DIR/zstddeclib.c" "$RADIO_ZSTD_DIR/include/zstd.h" "$RADIO_ZSTD_DIR/include/zstd_errors.h" "$RADIO_ZSTD_DIR/include/module.modulemap" "$RADIO_SOURCE_DIR/toolchain.sh" | /usr/bin/shasum -a 256)"
if [ ! -f "$RADIO_ZSTD_OBJECT" ] || [ ! -f "$RADIO_BUILD_DIR/zstd-decoder.hash" ] || [ "$(cat "$RADIO_BUILD_DIR/zstd-decoder.hash")" != "$RADIO_ZSTD_HASH" ]; then
    xcrun clang -target arm64-apple-macosx14.0 -isysroot "$RADIO_SDK" -std=c99 -O2 -fvisibility=hidden -c "$RADIO_ZSTD_DIR/zstddeclib.c" -o "$RADIO_ZSTD_OBJECT"
    printf '%s\n' "$RADIO_ZSTD_HASH" > "$RADIO_BUILD_DIR/zstd-decoder.hash"
fi
RADIO_FLAGS+=(-I "$RADIO_ZSTD_DIR/include")
RADIO_LINK_FLAGS=("$RADIO_ZSTD_OBJECT")
