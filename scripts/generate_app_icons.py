#!/usr/bin/env python3
"""
Zoe Sleep App Icon Generator - Circadian Wave Design

Generates all required icon sizes for iOS and watchOS apps.
Design: Elegant circadian wave theme with flowing gradients (NO moon/stars).

Theme: Abstract flowing waves representing the natural rhythm of sleep cycles,
using a sophisticated teal-to-deep-blue gradient palette.
"""

import math
from PIL import Image, ImageDraw, ImageFilter

# Color palette - elegant circadian/longevity theme
COLORS = {
    # Background gradient (deep indigo to rich teal)
    'gradient_top': (15, 23, 42),       # Deep navy #0F172A
    'gradient_mid': (30, 41, 59),       # Slate #1E293B
    'gradient_bottom': (20, 83, 96),    # Deep teal #145360

    # Wave colors (flowing circadian rhythm)
    'wave_primary': (20, 184, 166),     # Teal #14B8A6
    'wave_secondary': (45, 212, 191),   # Light teal #2DD4BF
    'wave_accent': (94, 234, 212),      # Bright teal #5EEAD4
    'wave_glow': (153, 246, 228),       # Glow teal #99F6E4

    # Energy accent (representing vitality/longevity)
    'energy_warm': (251, 191, 36),      # Warm amber #FBBF24
    'energy_soft': (254, 240, 138),     # Soft gold #FEF08A
}


def create_gradient(size):
    """Create a sophisticated three-point vertical gradient background."""
    img = Image.new('RGBA', (size, size))

    for y in range(size):
        ratio = y / size

        if ratio < 0.5:
            # Top to middle
            r = ratio * 2
            c1, c2 = COLORS['gradient_top'], COLORS['gradient_mid']
        else:
            # Middle to bottom
            r = (ratio - 0.5) * 2
            c1, c2 = COLORS['gradient_mid'], COLORS['gradient_bottom']

        red = int(c1[0] * (1 - r) + c2[0] * r)
        green = int(c1[1] * (1 - r) + c2[1] * r)
        blue = int(c1[2] * (1 - r) + c2[2] * r)

        for x in range(size):
            img.putpixel((x, y), (red, green, blue, 255))

    return img


def draw_circadian_wave(draw, size, y_offset, amplitude, wavelength, color, thickness, phase=0):
    """Draw a flowing sine wave representing circadian rhythm."""
    points = []

    for x in range(size + 10):
        # Sine wave with phase offset
        y = y_offset + amplitude * math.sin(2 * math.pi * (x / wavelength) + phase)
        points.append((x, y))

    # Draw thick smooth wave
    if len(points) > 1:
        for i in range(len(points) - 1):
            draw.line([points[i], points[i + 1]], fill=color, width=thickness)


def draw_wave_with_gradient(img, size, y_base, amplitude, wavelength, thickness, phase=0, alpha_start=200, alpha_end=80):
    """Draw a wave with gradient alpha for a glowing effect."""
    draw = ImageDraw.Draw(img, 'RGBA')

    for offset in range(thickness, 0, -1):
        alpha = int(alpha_start - (alpha_start - alpha_end) * (thickness - offset) / thickness)

        # Color interpolation from primary to accent
        ratio = offset / thickness
        r = int(COLORS['wave_primary'][0] * ratio + COLORS['wave_accent'][0] * (1 - ratio))
        g = int(COLORS['wave_primary'][1] * ratio + COLORS['wave_accent'][1] * (1 - ratio))
        b = int(COLORS['wave_primary'][2] * ratio + COLORS['wave_accent'][2] * (1 - ratio))

        color = (r, g, b, alpha)

        for x in range(size):
            y = y_base + amplitude * math.sin(2 * math.pi * (x / wavelength) + phase)

            # Draw vertical gradient line at this x position
            for dy in range(-offset, offset + 1):
                py = int(y + dy)
                if 0 <= py < size:
                    existing = img.getpixel((x, py))
                    # Alpha blend
                    blend_alpha = alpha / 255
                    new_r = int(existing[0] * (1 - blend_alpha) + r * blend_alpha)
                    new_g = int(existing[1] * (1 - blend_alpha) + g * blend_alpha)
                    new_b = int(existing[2] * (1 - blend_alpha) + b * blend_alpha)
                    img.putpixel((x, py), (new_r, new_g, new_b, 255))


def draw_energy_orb(img, size, center_x, center_y, radius):
    """Draw a subtle energy orb representing vitality/longevity."""
    draw = ImageDraw.Draw(img, 'RGBA')

    # Draw concentric circles with decreasing alpha
    for r in range(int(radius), 0, -1):
        alpha = int(60 * (r / radius))

        # Interpolate color from warm to soft
        ratio = r / radius
        red = int(COLORS['energy_warm'][0] * ratio + COLORS['energy_soft'][0] * (1 - ratio))
        green = int(COLORS['energy_warm'][1] * ratio + COLORS['energy_soft'][1] * (1 - ratio))
        blue = int(COLORS['energy_warm'][2] * ratio + COLORS['energy_soft'][2] * (1 - ratio))

        bbox = [center_x - r, center_y - r, center_x + r, center_y + r]
        draw.ellipse(bbox, fill=(red, green, blue, alpha))


def draw_flow_lines(img, size):
    """Draw subtle flowing lines representing sleep cycle transitions."""
    draw = ImageDraw.Draw(img, 'RGBA')

    # Multiple subtle flow lines
    line_configs = [
        {'y': size * 0.25, 'amp': size * 0.03, 'wl': size * 0.8, 'phase': 0, 'alpha': 30},
        {'y': size * 0.45, 'amp': size * 0.05, 'wl': size * 0.6, 'phase': 1.5, 'alpha': 40},
        {'y': size * 0.65, 'amp': size * 0.04, 'wl': size * 0.7, 'phase': 3.0, 'alpha': 35},
        {'y': size * 0.85, 'amp': size * 0.03, 'wl': size * 0.9, 'phase': 4.5, 'alpha': 25},
    ]

    for cfg in line_configs:
        color = (*COLORS['wave_glow'][:3], cfg['alpha'])
        draw_circadian_wave(
            draw, size,
            y_offset=cfg['y'],
            amplitude=cfg['amp'],
            wavelength=cfg['wl'],
            color=color,
            thickness=max(1, int(size * 0.005)),
            phase=cfg['phase']
        )


def create_zoe_sleep_icon(size):
    """Create the Zoe Sleep app icon with circadian wave design."""
    # Start with gradient background
    img = create_gradient(size)

    # Add subtle flow lines for texture (only on larger icons)
    if size >= 60:
        draw_flow_lines(img, size)

    # Main wave parameters - the primary visual element
    wave_y = size * 0.55
    wave_amplitude = size * 0.12
    wave_wavelength = size * 0.5
    wave_thickness = max(3, int(size * 0.06))

    # Draw main glowing wave
    if size >= 40:
        draw_wave_with_gradient(
            img, size,
            y_base=wave_y,
            amplitude=wave_amplitude,
            wavelength=wave_wavelength,
            thickness=wave_thickness,
            phase=0.5,
            alpha_start=220,
            alpha_end=60
        )

    # Draw secondary wave (offset and smaller)
    if size >= 60:
        draw = ImageDraw.Draw(img, 'RGBA')
        secondary_color = (*COLORS['wave_secondary'][:3], 120)
        draw_circadian_wave(
            draw, size,
            y_offset=wave_y - size * 0.08,
            amplitude=wave_amplitude * 0.7,
            wavelength=wave_wavelength * 1.2,
            color=secondary_color,
            thickness=max(2, int(wave_thickness * 0.5)),
            phase=2.0
        )

    # Add subtle energy orb (representing vitality) - only on larger icons
    if size >= 100:
        orb_x = size * 0.75
        orb_y = size * 0.35
        orb_radius = size * 0.12
        draw_energy_orb(img, size, orb_x, orb_y, orb_radius)

    # Add a subtle highlight wave on top
    if size >= 80:
        draw = ImageDraw.Draw(img, 'RGBA')
        highlight_color = (*COLORS['wave_glow'][:3], 100)
        draw_circadian_wave(
            draw, size,
            y_offset=wave_y + size * 0.06,
            amplitude=wave_amplitude * 0.5,
            wavelength=wave_wavelength * 0.8,
            color=highlight_color,
            thickness=max(1, int(size * 0.015)),
            phase=1.0
        )

    # Apply subtle blur for smoothness on larger icons
    if size >= 120:
        img = img.filter(ImageFilter.GaussianBlur(radius=0.5))

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

    print("=" * 60)
    print("Zoe Sleep App Icon Generator - Circadian Wave Design")
    print("=" * 60)
    print("\nDesign: Elegant flowing waves representing circadian rhythms")
    print("Colors: Deep navy to teal gradient with glowing wave accents")
    print("Theme: Sleep cycles, longevity, natural rhythm (NO moon/stars)")
    print()
    print(f"iOS path: {ios_icon_path}")
    print(f"watchOS path: {watch_icon_path}")
    print()

    # Ensure directories exist
    os.makedirs(ios_icon_path, exist_ok=True)
    os.makedirs(watch_icon_path, exist_ok=True)

    # Generate icons
    generate_ios_icons(ios_icon_path)
    generate_watchos_icons(watch_icon_path)

    print("\n" + "=" * 60)
    print("Icon generation complete!")
    print("=" * 60)

    # Also save a preview at 512x512 for easy viewing
    docs_path = os.path.join(project_root, 'docs')
    os.makedirs(docs_path, exist_ok=True)

    preview_path = os.path.join(docs_path, 'zoe-sleep-icon-preview.png')
    preview = create_zoe_sleep_icon(512)
    preview.save(preview_path, 'PNG')
    print(f"\nPreview saved to: {preview_path}")

    # Also save a large version for marketing
    marketing_path = os.path.join(docs_path, 'zoe-sleep-icon-1024.png')
    marketing = create_zoe_sleep_icon(1024)
    marketing.save(marketing_path, 'PNG')
    print(f"Marketing icon saved to: {marketing_path}")

    # Generate Launch Screen Icons
    launch_icon_path = os.path.join(project_root, 'Sleep360', 'Sleep360', 'Assets.xcassets', 'LaunchIcon.imageset')
    os.makedirs(launch_icon_path, exist_ok=True)

    print("\nGenerating Launch Screen icons...")
    launch_sizes = [
        ('LaunchIcon.png', 200),
        ('LaunchIcon@2x.png', 400),
        ('LaunchIcon@3x.png', 600),
    ]

    for filename, pixel_size in launch_sizes:
        icon = create_zoe_sleep_icon(pixel_size)
        filepath = os.path.join(launch_icon_path, filename)
        icon.save(filepath, 'PNG')
        print(f"  Created: {filename} ({pixel_size}x{pixel_size})")

    print(f"Launch icons saved to: {launch_icon_path}")


if __name__ == '__main__':
    main()
