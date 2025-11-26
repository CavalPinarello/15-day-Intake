#!/usr/bin/env python3
"""
Zoé Sleep App Icon Generator

Generates all required icon sizes for iOS and watchOS apps.
Design: Deep indigo/purple gradient with stylized crescent moon and "Z" accent.
"""

import math
from PIL import Image, ImageDraw, ImageFont, ImageFilter

# Color palette - calming sleep-themed colors
COLORS = {
    'gradient_top': (45, 27, 92),      # Deep indigo
    'gradient_bottom': (88, 55, 143),   # Rich purple
    'moon': (255, 255, 255),            # White moon
    'moon_shadow': (200, 190, 230),     # Soft lavender shadow
    'accent': (147, 197, 253),          # Soft blue accent
    'stars': (255, 255, 255),           # White stars
}

def create_gradient(size, color1, color2):
    """Create a vertical gradient background."""
    img = Image.new('RGBA', (size, size), color1)
    draw = ImageDraw.Draw(img)

    for y in range(size):
        ratio = y / size
        r = int(color1[0] * (1 - ratio) + color2[0] * ratio)
        g = int(color1[1] * (1 - ratio) + color2[1] * ratio)
        b = int(color1[2] * (1 - ratio) + color2[2] * ratio)
        draw.line([(0, y), (size, y)], fill=(r, g, b))

    return img


def draw_crescent_moon(draw, size, center_x, center_y, radius):
    """Draw a crescent moon shape."""
    # Main moon circle
    moon_bbox = [
        center_x - radius,
        center_y - radius,
        center_x + radius,
        center_y + radius
    ]
    draw.ellipse(moon_bbox, fill=COLORS['moon'])

    # Shadow circle to create crescent effect (offset to upper-right)
    shadow_offset = radius * 0.35
    shadow_radius = radius * 0.85
    shadow_bbox = [
        center_x - shadow_radius + shadow_offset,
        center_y - shadow_radius - shadow_offset * 0.5,
        center_x + shadow_radius + shadow_offset,
        center_y + shadow_radius - shadow_offset * 0.5
    ]

    return shadow_bbox


def draw_z_accent(draw, size, x, y, z_size):
    """Draw a stylized 'Z' representing Zoé and sleep (zzz)."""
    # Z dimensions
    stroke_width = max(2, int(z_size * 0.15))

    # Top horizontal line
    draw.line(
        [(x, y), (x + z_size, y)],
        fill=COLORS['accent'],
        width=stroke_width
    )

    # Diagonal line
    draw.line(
        [(x + z_size, y), (x, y + z_size)],
        fill=COLORS['accent'],
        width=stroke_width
    )

    # Bottom horizontal line
    draw.line(
        [(x, y + z_size), (x + z_size, y + z_size)],
        fill=COLORS['accent'],
        width=stroke_width
    )


def add_stars(draw, size, num_stars=5):
    """Add small twinkling stars."""
    import random
    random.seed(42)  # Consistent star positions

    star_positions = [
        (0.15, 0.2),
        (0.82, 0.15),
        (0.1, 0.55),
        (0.85, 0.45),
        (0.75, 0.7),
    ]

    for px, py in star_positions[:num_stars]:
        x = int(size * px)
        y = int(size * py)
        star_size = max(1, int(size * 0.015))

        # Draw small star (cross pattern)
        for i in range(-star_size, star_size + 1):
            alpha = int(255 * (1 - abs(i) / (star_size + 1)))
            # Horizontal
            if 0 <= x + i < size:
                draw.point((x + i, y), fill=(*COLORS['stars'], alpha))
            # Vertical
            if 0 <= y + i < size:
                draw.point((x, y + i), fill=(*COLORS['stars'], alpha))


def create_zoe_sleep_icon(size):
    """Create the Zoé Sleep app icon at the specified size."""
    # Start with gradient background
    img = create_gradient(size, COLORS['gradient_top'], COLORS['gradient_bottom'])
    draw = ImageDraw.Draw(img, 'RGBA')

    # Add subtle stars for larger sizes
    if size >= 80:
        add_stars(draw, size, num_stars=5)
    elif size >= 40:
        add_stars(draw, size, num_stars=3)

    # Moon parameters - positioned left-center
    moon_radius = size * 0.32
    moon_center_x = size * 0.42
    moon_center_y = size * 0.48

    # Draw moon
    shadow_bbox = draw_crescent_moon(draw, size, moon_center_x, moon_center_y, moon_radius)

    # Create mask for crescent effect
    mask = Image.new('L', (size, size), 255)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.ellipse(shadow_bbox, fill=0)

    # Apply gradient over shadow area to create crescent
    for y in range(int(shadow_bbox[1]), min(size, int(shadow_bbox[3]) + 1)):
        for x in range(int(shadow_bbox[0]), min(size, int(shadow_bbox[2]) + 1)):
            if x < 0 or y < 0:
                continue
            # Check if point is in shadow ellipse
            cx = (shadow_bbox[0] + shadow_bbox[2]) / 2
            cy = (shadow_bbox[1] + shadow_bbox[3]) / 2
            rx = (shadow_bbox[2] - shadow_bbox[0]) / 2
            ry = (shadow_bbox[3] - shadow_bbox[1]) / 2

            if rx > 0 and ry > 0:
                dist = ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2
                if dist <= 1:
                    # Get gradient color at this position
                    ratio = y / size
                    r = int(COLORS['gradient_top'][0] * (1 - ratio) + COLORS['gradient_bottom'][0] * ratio)
                    g = int(COLORS['gradient_top'][1] * (1 - ratio) + COLORS['gradient_bottom'][1] * ratio)
                    b = int(COLORS['gradient_top'][2] * (1 - ratio) + COLORS['gradient_bottom'][2] * ratio)
                    img.putpixel((x, y), (r, g, b, 255))

    # Draw Z accent - positioned near the moon
    z_size = size * 0.18
    z_x = moon_center_x + moon_radius * 0.5
    z_y = moon_center_y - moon_radius * 0.6

    # Only draw Z for sizes >= 40 for clarity
    if size >= 40:
        draw_z_accent(draw, size, z_x, z_y, z_size)

        # Add smaller zzz trail for larger icons
        if size >= 100:
            # Second smaller z
            z2_size = z_size * 0.65
            z2_x = z_x + z_size * 0.9
            z2_y = z_y - z_size * 0.4
            draw_z_accent(draw, size, z2_x, z2_y, z2_size)

            # Third even smaller z
            if size >= 180:
                z3_size = z_size * 0.4
                z3_x = z2_x + z2_size * 0.8
                z3_y = z2_y - z2_size * 0.4
                draw_z_accent(draw, size, z3_x, z3_y, z3_size)

    return img.convert('RGB')


def generate_ios_icons(base_path):
    """Generate all required iOS app icon sizes."""
    ios_sizes = [
        # (filename, actual_pixel_size)
        ('icon-20x20.png', 20),
        ('icon-20x20@2x.png', 40),
        ('icon-20x20@3x.png', 60),
        ('icon-29x29.png', 29),
        ('icon-29x29@2x.png', 58),
        ('icon-29x29@3x.png', 87),
        ('icon-40x40.png', 40),
        ('icon-40x40@2x.png', 80),
        ('icon-40x40@3x.png', 120),
        ('icon-60x60@2x.png', 120),
        ('icon-60x60@3x.png', 180),
        ('icon-76x76.png', 76),
        ('icon-76x76@2x.png', 152),
        ('icon-83.5x83.5@2x.png', 167),
        ('icon-1024x1024.png', 1024),
    ]

    print("Generating iOS icons...")
    for filename, pixel_size in ios_sizes:
        icon = create_zoe_sleep_icon(pixel_size)
        filepath = f"{base_path}/{filename}"
        icon.save(filepath, 'PNG')
        print(f"  Created: {filename} ({pixel_size}x{pixel_size})")

    print(f"iOS icons saved to: {base_path}")


def generate_watchos_icons(base_path):
    """Generate all required watchOS app icon sizes."""
    watch_sizes = [
        # (filename, actual_pixel_size)
        ('watch-24x24@2x.png', 48),
        ('watch-27.5x27.5@2x.png', 55),
        ('watch-29x29@2x.png', 58),
        ('watch-29x29@3x.png', 87),
        ('watch-33x33@2x.png', 66),
        ('watch-40x40@2x.png', 80),
        ('watch-44x44@2x.png', 88),
        ('watch-46x46@2x.png', 92),
        ('watch-50x50@2x.png', 100),
        ('watch-51x51@2x.png', 102),
        ('watch-54x54@2x.png', 108),
        ('watch-86x86@2x.png', 172),
        ('watch-98x98@2x.png', 196),
        ('watch-108x108@2x.png', 216),
        ('watch-117x117@2x.png', 234),
        ('watch-129x129@2x.png', 258),
        ('watch-1024x1024.png', 1024),
    ]

    print("\nGenerating watchOS icons...")
    for filename, pixel_size in watch_sizes:
        icon = create_zoe_sleep_icon(pixel_size)
        filepath = f"{base_path}/{filename}"
        icon.save(filepath, 'PNG')
        print(f"  Created: {filename} ({pixel_size}x{pixel_size})")

    print(f"watchOS icons saved to: {base_path}")


def main():
    import os

    # Paths to asset catalogs
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)

    ios_icon_path = os.path.join(project_root, 'Sleep360', 'Sleep360', 'Assets.xcassets', 'AppIcon.appiconset')
    watch_icon_path = os.path.join(project_root, 'Sleep360', 'Sleep360 Watch App', 'Assets.xcassets', 'AppIcon.appiconset')

    print("=" * 50)
    print("Zoé Sleep App Icon Generator")
    print("=" * 50)
    print(f"\niOS path: {ios_icon_path}")
    print(f"watchOS path: {watch_icon_path}")
    print()

    # Generate icons
    generate_ios_icons(ios_icon_path)
    generate_watchos_icons(watch_icon_path)

    print("\n" + "=" * 50)
    print("Icon generation complete!")
    print("=" * 50)

    # Also save a preview at 512x512 for easy viewing
    preview_path = os.path.join(project_root, 'docs', 'zoe-sleep-icon-preview.png')
    preview = create_zoe_sleep_icon(512)
    preview.save(preview_path, 'PNG')
    print(f"\nPreview saved to: {preview_path}")


if __name__ == '__main__':
    main()
