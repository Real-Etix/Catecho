#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/toolchain.sh"

run_codex_zstd_tests() {
    swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/CodexZstd.swift" "$RADIO_SOURCE_DIR/Tests/CodexZstd/main.swift" -o "$RADIO_BUILD_DIR/codex-zstd-tests"
    "$RADIO_BUILD_DIR/codex-zstd-tests" "$RADIO_SOURCE_DIR/Tests/CodexZstd/Fixtures"
}
if [ "${1:-}" = "--codex-zstd" ]; then
    run_codex_zstd_tests
    exit 0
fi
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/main.swift" -o "$RADIO_BUILD_DIR/core-tests"
"$RADIO_BUILD_DIR/core-tests" "$@"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/RadioModel.swift" "$RADIO_SOURCE_DIR/Sources/App/CodexMonitorModel.swift" "$RADIO_SOURCE_DIR/Tests/Model/main.swift" -o "$RADIO_BUILD_DIR/model-tests" -framework AppKit -framework SwiftUI
"$RADIO_BUILD_DIR/model-tests"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/AntennaPull.swift" "$RADIO_SOURCE_DIR/Sources/Core/RadioTurn.swift" "$RADIO_SOURCE_DIR/Sources/Core/RadioCaseGeometry.swift" "$RADIO_SOURCE_DIR/Tests/Interaction/main.swift" -o "$RADIO_BUILD_DIR/interaction-tests"
"$RADIO_BUILD_DIR/interaction-tests"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/App/RadioPlacement.swift" "$RADIO_SOURCE_DIR/Tests/Placement/main.swift" -o "$RADIO_BUILD_DIR/placement-tests"
"$RADIO_BUILD_DIR/placement-tests"

swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Language/main.swift" -o "$RADIO_BUILD_DIR/language-tests"
"$RADIO_BUILD_DIR/language-tests"

swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Discovery/main.swift" -o "$RADIO_BUILD_DIR/discovery-tests"
"$RADIO_BUILD_DIR/discovery-tests" "$@"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/FeedDiscoveryModel.swift" "$RADIO_SOURCE_DIR/Tests/DiscoveryModel/main.swift" -o "$RADIO_BUILD_DIR/discovery-model-tests" -framework SwiftUI
"$RADIO_BUILD_DIR/discovery-model-tests"

swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Webpage/main.swift" -o "$RADIO_BUILD_DIR/webpage-tests"
"$RADIO_BUILD_DIR/webpage-tests" "$@"

# First-run lifecycle, persisted setup and the operating-system login adapter.
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/RadioModel.swift" "$RADIO_SOURCE_DIR/Sources/App/CodexMonitorModel.swift" "$RADIO_SOURCE_DIR/Tests/Setup/main.swift" -o "$RADIO_BUILD_DIR/setup-tests" -framework AppKit -framework SwiftUI
"$RADIO_BUILD_DIR/setup-tests"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/App/RadioLoginItem.swift" "$RADIO_SOURCE_DIR/Tests/Login/main.swift" -o "$RADIO_BUILD_DIR/login-tests" -framework ServiceManagement
"$RADIO_BUILD_DIR/login-tests"

# Local Codex accounting and rolling display windows.
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/CodexUsage*.swift "$RADIO_SOURCE_DIR/Sources/Core/CodexZstd.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexJSONProjection.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexLifetimeStore.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexSessions.swift" "$RADIO_SOURCE_DIR/Tests/CodexUsage/main.swift" -o "$RADIO_BUILD_DIR/codex-usage-tests"
"$RADIO_BUILD_DIR/codex-usage-tests"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/CodexUsage.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexUsageWindow.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexSessions.swift" "$RADIO_SOURCE_DIR/Tests/CodexWindow/main.swift" -o "$RADIO_BUILD_DIR/codex-window-tests"
"$RADIO_BUILD_DIR/codex-window-tests"
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/RadioModel.swift" "$RADIO_SOURCE_DIR/Sources/App/CodexMonitorModel.swift" "$RADIO_SOURCE_DIR/Tests/CodexMonitor/main.swift" -o "$RADIO_BUILD_DIR/codex-monitor-tests" -framework AppKit -framework SwiftUI
"$RADIO_BUILD_DIR/codex-monitor-tests"

# Portable bounded streaming decompression.
run_codex_zstd_tests

# Bounded numeric projection from local JSON lines.
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/CodexJSONProjection.swift" "$RADIO_SOURCE_DIR/Tests/CodexProjection/main.swift" -o "$RADIO_BUILD_DIR/codex-projection-tests"
"$RADIO_BUILD_DIR/codex-projection-tests"

# Per-chat aggregation and optional local title metadata.
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/CodexUsage.swift" "$RADIO_SOURCE_DIR/Sources/Core/CodexUsageWindow.swift" "$RADIO_SOURCE_DIR"/Sources/Core/CodexSession*.swift "$RADIO_SOURCE_DIR/Tests/CodexSessions/main.swift" -o "$RADIO_BUILD_DIR/codex-sessions-tests"
"$RADIO_BUILD_DIR/codex-sessions-tests"

# Durable per-chat lifetime accounting.
swiftc "${RADIO_FLAGS[@]}" "${RADIO_LINK_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/Codex*.swift "$RADIO_SOURCE_DIR/Tests/CodexLifetime/main.swift" -o "$RADIO_BUILD_DIR/codex-lifetime-tests"
"$RADIO_BUILD_DIR/codex-lifetime-tests"
