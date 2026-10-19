#!/bin/bash
set -euo pipefail
source "$(cd "$(dirname "$0")" && pwd)/toolchain.sh"
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/main.swift" -o "$RADIO_BUILD_DIR/core-tests"
"$RADIO_BUILD_DIR/core-tests" "$@"
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/RadioModel.swift" "$RADIO_SOURCE_DIR/Tests/Model/main.swift" -o "$RADIO_BUILD_DIR/model-tests" -framework AppKit -framework SwiftUI
"$RADIO_BUILD_DIR/model-tests"
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/Core/AntennaPull.swift" "$RADIO_SOURCE_DIR/Sources/Core/RadioTurn.swift" "$RADIO_SOURCE_DIR/Sources/Core/RadioCaseGeometry.swift" "$RADIO_SOURCE_DIR/Tests/Interaction/main.swift" -o "$RADIO_BUILD_DIR/interaction-tests"
"$RADIO_BUILD_DIR/interaction-tests"
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR/Sources/App/RadioPlacement.swift" "$RADIO_SOURCE_DIR/Tests/Placement/main.swift" -o "$RADIO_BUILD_DIR/placement-tests"
"$RADIO_BUILD_DIR/placement-tests"

swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Language/main.swift" -o "$RADIO_BUILD_DIR/language-tests"
"$RADIO_BUILD_DIR/language-tests"

swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Discovery/main.swift" -o "$RADIO_BUILD_DIR/discovery-tests"
"$RADIO_BUILD_DIR/discovery-tests" "$@"
swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Sources/App/FeedDiscoveryModel.swift" "$RADIO_SOURCE_DIR/Tests/DiscoveryModel/main.swift" -o "$RADIO_BUILD_DIR/discovery-model-tests" -framework SwiftUI
"$RADIO_BUILD_DIR/discovery-model-tests"

swiftc "${RADIO_FLAGS[@]}" -parse-as-library "$RADIO_SOURCE_DIR"/Sources/Core/*.swift "$RADIO_SOURCE_DIR/Tests/Webpage/main.swift" -o "$RADIO_BUILD_DIR/webpage-tests"
"$RADIO_BUILD_DIR/webpage-tests" "$@"
