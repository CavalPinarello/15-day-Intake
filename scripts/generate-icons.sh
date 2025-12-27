#!/bin/bash

# Icon Generation Script for Zoe Sleep App
# Generates iOS and watchOS app icons from SVG with NO alpha channel
# Based on the new spiral crescent moon logo (Frame 3.svg)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SVG_SOURCE="/Users/martinkawalski/Downloads/zoe/Frame 3.svg"

# Output directories
IOS_ICONS_DIR="$PROJECT_DIR/ZoeSleep/ZoeSleep/Assets.xcassets/AppIcon.appiconset"
WATCH_ICONS_DIR="$PROJECT_DIR/ZoeSleep/ZoeSleep Watch App/Assets.xcassets/AppIcon.appiconset"

# Temp directory for processing
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

echo "🌙 Zoe Sleep Icon Generator"
echo "=========================="
echo "Source SVG: $SVG_SOURCE"
echo "iOS Icons: $IOS_ICONS_DIR"
echo "Watch Icons: $WATCH_ICONS_DIR"
echo ""

# Check if SVG exists
if [ ! -f "$SVG_SOURCE" ]; then
    echo "❌ Error: SVG source not found at $SVG_SOURCE"
    exit 1
fi

# Check for required tools
if ! command -v magick &> /dev/null; then
    if ! command -v convert &> /dev/null; then
        echo "❌ Error: ImageMagick not found. Install with: brew install imagemagick"
        exit 1
    fi
    MAGICK_CMD="convert"
else
    MAGICK_CMD="magick"
fi

echo "Using: $MAGICK_CMD"

# Create a modified SVG with brand colors on dark background
# The logo will be warm cream on a dark warm background (matching circadian night theme)
COLORED_SVG="$TEMP_DIR/zoe-logo-colored.svg"

# Create SVG with dark background and warm cream logo
cat > "$COLORED_SVG" << 'EOF'
<svg width="1024" height="1024" viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <defs>
    <linearGradient id="bgGradient" x1="0%" y1="0%" x2="100%" y2="100%">
      <stop offset="0%" style="stop-color:#1a1512"/>
      <stop offset="100%" style="stop-color:#0d0a08"/>
    </linearGradient>
  </defs>
  <!-- Background -->
  <rect width="1024" height="1024" fill="url(#bgGradient)"/>
  <!-- Logo centered and scaled -->
  <g transform="translate(80, 80) scale(0.6)">
    <path d="M388.995 722.405C388.995 1011.3 622.747 1245.48 911.054 1245.48C1178.85 1245.48 1399.51 1043.5 1429.6 783.286H1430.55C1399.75 1148.83 1093.84 1435.92 721.014 1435.92C327.709 1435.92 8.89014 1116.45 8.89014 722.405C8.89014 328.358 327.709 8.8902 721.014 8.8902C1114.32 8.8902 1405.4 301.303 1431.33 671.732H1430.68C1405.25 406.611 1182.34 199.327 911.054 199.327C622.747 199.327 388.995 433.509 388.995 722.405Z" fill="#F5E6D3"/>
    <path d="M1422.95 783.297H1428.16C1399.17 960.271 1245.79 1095.34 1060.94 1095.34C855.369 1095.34 688.744 928.361 688.744 722.416C688.744 516.47 855.369 349.493 1060.94 349.493C1249.33 349.493 1405.01 489.756 1429.68 671.743H1426.17C1404.12 593.437 1332.3 536.02 1247.08 536.02C1144.36 536.02 1061.07 619.469 1061.07 722.416C1061.07 825.362 1144.36 908.811 1247.08 908.811C1328.56 908.811 1397.78 856.354 1422.95 783.297Z" fill="#F5E6D3"/>
  </g>
</svg>
EOF

echo "📐 Generating base 1024x1024 icon..."

# Generate high-res master (1024x1024) without alpha channel
# Using -background and -flatten to remove alpha, then convert to JPEG and back to strip alpha completely
$MAGICK_CMD -density 300 -background "#0d0a08" "$COLORED_SVG" -flatten -resize 1024x1024 "$TEMP_DIR/master-1024.png"

# Convert to JPEG and back to strip alpha completely (same fix used before)
$MAGICK_CMD "$TEMP_DIR/master-1024.png" -quality 100 "$TEMP_DIR/master-1024.jpg"
$MAGICK_CMD "$TEMP_DIR/master-1024.jpg" "$TEMP_DIR/master-1024-no-alpha.png"

echo ""
echo "📱 Generating iOS icons..."

# iOS icon sizes: filename -> pixel size
generate_ios_icon() {
    local filename=$1
    local size=$2
    echo "  ✓ $filename (${size}px)"
    $MAGICK_CMD "$TEMP_DIR/master-1024-no-alpha.png" -resize ${size}x${size} "$IOS_ICONS_DIR/$filename"
}

generate_ios_icon "icon-20x20.png" 20
generate_ios_icon "icon-20x20@2x.png" 40
generate_ios_icon "icon-20x20@3x.png" 60
generate_ios_icon "icon-29x29.png" 29
generate_ios_icon "icon-29x29@2x.png" 58
generate_ios_icon "icon-29x29@3x.png" 87
generate_ios_icon "icon-40x40.png" 40
generate_ios_icon "icon-40x40@2x.png" 80
generate_ios_icon "icon-40x40@3x.png" 120
generate_ios_icon "icon-60x60@2x.png" 120
generate_ios_icon "icon-60x60@3x.png" 180
generate_ios_icon "icon-76x76.png" 76
generate_ios_icon "icon-76x76@2x.png" 152
generate_ios_icon "icon-83.5x83.5@2x.png" 167
generate_ios_icon "icon-1024x1024.png" 1024

echo ""
echo "⌚ Generating Watch icons..."

# Watch icon sizes: filename -> pixel size
generate_watch_icon() {
    local filename=$1
    local size=$2
    echo "  ✓ $filename (${size}px)"
    $MAGICK_CMD "$TEMP_DIR/master-1024-no-alpha.png" -resize ${size}x${size} "$WATCH_ICONS_DIR/$filename"
}

generate_watch_icon "watch-24x24@2x.png" 48
generate_watch_icon "watch-27.5x27.5@2x.png" 55
generate_watch_icon "watch-29x29@2x.png" 58
generate_watch_icon "watch-29x29@3x.png" 87
generate_watch_icon "watch-33x33@2x.png" 66
generate_watch_icon "watch-40x40@2x.png" 80
generate_watch_icon "watch-44x44@2x.png" 88
generate_watch_icon "watch-46x46@2x.png" 92
generate_watch_icon "watch-50x50@2x.png" 100
generate_watch_icon "watch-51x51@2x.png" 102
generate_watch_icon "watch-54x54@2x.png" 108
generate_watch_icon "watch-86x86@2x.png" 172
generate_watch_icon "watch-98x98@2x.png" 196
generate_watch_icon "watch-108x108@2x.png" 216
generate_watch_icon "watch-117x117@2x.png" 234
generate_watch_icon "watch-129x129@2x.png" 258
generate_watch_icon "watch-1024x1024.png" 1024

echo ""
echo "🔍 Verifying no alpha channel..."

# Check icons to verify no alpha
check_alpha() {
    local file=$1
    local has_alpha=$(identify -verbose "$file" 2>/dev/null | grep -i "Alpha:" | head -1 || true)
    local channel_stats=$(identify -verbose "$file" 2>/dev/null | grep -i "Channel statistics:" -A 20 | grep -i "Alpha" || true)

    if [ -z "$has_alpha" ] && [ -z "$channel_stats" ]; then
        echo "  ✓ $(basename "$file"): No alpha channel"
        return 0
    else
        echo "  ⚠ $(basename "$file"): Has alpha, stripping..."
        # Strip alpha by converting to JPEG and back
        local temp_jpg=$(mktemp).jpg
        $MAGICK_CMD "$file" -quality 100 "$temp_jpg"
        $MAGICK_CMD "$temp_jpg" "$file"
        rm -f "$temp_jpg"
        echo "  ✓ $(basename "$file"): Alpha stripped"
        return 0
    fi
}

check_alpha "$IOS_ICONS_DIR/icon-1024x1024.png"
check_alpha "$WATCH_ICONS_DIR/watch-1024x1024.png"

echo ""
echo "✅ Icon generation complete!"
echo ""
echo "Generated files:"
echo "  - iOS: $(ls -1 "$IOS_ICONS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ') icons"
echo "  - Watch: $(ls -1 "$WATCH_ICONS_DIR"/*.png 2>/dev/null | wc -l | tr -d ' ') icons"
