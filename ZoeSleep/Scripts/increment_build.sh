#!/bin/bash
# increment_build.sh
# Auto-increments build number on each Xcode build
#
# Add this as a "Run Script" Build Phase in Xcode:
# 1. Select your target in Xcode
# 2. Build Phases > + > New Run Script Phase
# 3. Drag it BEFORE "Compile Sources"
# 4. Paste: "${SRCROOT}/Scripts/increment_build.sh"
# 5. Uncheck "Based on dependency analysis"

set -e

# Paths
XCCONFIG_FILE="${SRCROOT}/BuildNumber.xcconfig"
VERSION_SWIFT="${SRCROOT}/Shared/AppVersion.swift"
BUILD_LOG="${SRCROOT}/Scripts/build_history.log"

# Read current build number from xcconfig
if [ -f "$XCCONFIG_FILE" ]; then
    BUILD_NUM=$(grep "CURRENT_PROJECT_VERSION" "$XCCONFIG_FILE" | cut -d'=' -f2 | tr -d ' ')
else
    BUILD_NUM=12
fi

# Increment
NEW_BUILD=$((BUILD_NUM + 1))

# Update xcconfig
echo "// Auto-incremented build number" > "$XCCONFIG_FILE"
echo "// DO NOT EDIT MANUALLY - Updated by increment_build.sh" >> "$XCCONFIG_FILE"
echo "CURRENT_PROJECT_VERSION = $NEW_BUILD" >> "$XCCONFIG_FILE"

# Get current date
BUILD_DATE=$(date +%Y-%m-%d)
BUILD_TIME=$(date +%H:%M:%S)

# Update AppVersion.swift build number
if [ -f "$VERSION_SWIFT" ]; then
    # Update the build number line
    sed -i '' "s/static let build = [0-9]*/static let build = $NEW_BUILD/" "$VERSION_SWIFT"
    # Update the build date line
    sed -i '' "s/static let buildDate = \"[0-9-]*\"/static let buildDate = \"$BUILD_DATE\"/" "$VERSION_SWIFT"
fi

# Log the build
mkdir -p "$(dirname "$BUILD_LOG")"
echo "Build $NEW_BUILD | $BUILD_DATE $BUILD_TIME | ${CONFIGURATION:-Debug}" >> "$BUILD_LOG"

echo "Build number incremented: $BUILD_NUM -> $NEW_BUILD"
