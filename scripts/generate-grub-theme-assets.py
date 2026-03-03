#!/usr/bin/env python3
"""Generate GRUB theme PNG assets for UmaOS.

Creates:
  background.png  — 640x480 dark emerald gradient with subtle glow
  select_c.png    — 1x32 green bar (center slice for selected-item 9-patch)

Uses only the Python standard library (struct + zlib for minimal PNG writing).
"""

import math
import os
import struct
import sys
import zlib


def write_png(path, width, height, pixels):
    """Write an RGB PNG from a flat list of (r, g, b) tuples per row."""
    raw = bytearray()
    idx = 0
    for _y in range(height):
        raw.append(0)  # filter: none
        for _x in range(width):
            r, g, b = pixels[idx]
            raw += struct.pack("BBB", r, g, b)
            idx += 1
    compressed = zlib.compress(bytes(raw), 9)

    def chunk(ctype, data):
        c = ctype + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack(">I", len(data)) + c + crc

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        # IHDR: width, height, bit_depth=8, color_type=2 (RGB)
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


def write_rgba_png(path, width, height, pixels):
    """Write an RGBA PNG from a flat list of (r, g, b, a) tuples per row."""
    raw = bytearray()
    idx = 0
    for _y in range(height):
        raw.append(0)  # filter: none
        for _x in range(width):
            r, g, b, a = pixels[idx]
            raw += struct.pack("BBBB", r, g, b, a)
            idx += 1
    compressed = zlib.compress(bytes(raw), 9)

    def chunk(ctype, data):
        c = ctype + data
        crc = struct.pack(">I", zlib.crc32(c) & 0xFFFFFFFF)
        return struct.pack(">I", len(data)) + c + crc

    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n")
        # IHDR: width, height, bit_depth=8, color_type=6 (RGBA)
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


def lerp(a, b, t):
    return int(a + (b - a) * t)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def generate_background(path, width=640, height=480):
    """Dark emerald gradient with subtle green and pink glows."""
    top = hex_to_rgb("#0e1f14")
    bottom = hex_to_rgb("#12301a")
    green_glow = hex_to_rgb("#42a54b")
    pink_glow = hex_to_rgb("#ff91c0")

    # Glow centers (normalized)
    green_cx, green_cy = 0.78, 0.15
    pink_cx, pink_cy = 0.18, 0.85

    pixels = []
    for y in range(height):
        ny = y / max(height - 1, 1)
        for x in range(width):
            nx = x / max(width - 1, 1)

            # Base vertical gradient
            r = lerp(top[0], bottom[0], ny)
            g = lerp(top[1], bottom[1], ny)
            b = lerp(top[2], bottom[2], ny)

            # Green glow (top-right)
            gd = math.sqrt((nx - green_cx) ** 2 + (ny - green_cy) ** 2)
            gi = max(0.0, 1.0 - gd / 0.55) ** 2 * 0.12
            r = min(255, int(r + green_glow[0] * gi))
            g = min(255, int(g + green_glow[1] * gi))
            b = min(255, int(b + green_glow[2] * gi))

            # Pink glow (bottom-left)
            pd = math.sqrt((nx - pink_cx) ** 2 + (ny - pink_cy) ** 2)
            pi = max(0.0, 1.0 - pd / 0.50) ** 2 * 0.06
            r = min(255, int(r + pink_glow[0] * pi))
            g = min(255, int(g + pink_glow[1] * pi))
            b = min(255, int(b + pink_glow[2] * pi))

            # Subtle vignette (darken edges)
            vd = math.sqrt((nx - 0.5) ** 2 + (ny - 0.5) ** 2) / 0.707
            vf = max(0.0, vd - 0.4) * 0.3
            r = max(0, int(r * (1 - vf)))
            g = max(0, int(g * (1 - vf)))
            b = max(0, int(b * (1 - vf)))

            pixels.append((r, g, b))

    write_png(path, width, height, pixels)
    print(f"  Generated {path} ({width}x{height})")


def generate_select_center(path, width=1, height=32):
    """Green semi-transparent bar for selected boot menu item."""
    pixels = []
    for y in range(height):
        for x in range(width):
            # Slight vertical gradient for depth
            ny = y / max(height - 1, 1)
            base_a = 160
            # Subtle lighter top edge
            if ny < 0.1:
                a = base_a + 30
            elif ny > 0.9:
                a = base_a - 20
            else:
                a = base_a
            pixels.append((66, 165, 75, min(255, a)))  # #42a54b
    write_rgba_png(path, width, height, pixels)
    print(f"  Generated {path} ({width}x{height})")


def generate_accent_line(path, width=200, height=3):
    """Green-to-pink gradient accent line."""
    green = hex_to_rgb("#42a54b")
    pink = hex_to_rgb("#ff91c0")
    pixels = []
    for y in range(height):
        for x in range(width):
            t = x / max(width - 1, 1)
            r = lerp(green[0], pink[0], t)
            g = lerp(green[1], pink[1], t)
            b = lerp(green[2], pink[2], t)
            # Fade edges to transparent
            edge = min(x, width - 1 - x) / min(20, width // 2)
            a = int(min(1.0, edge) * 200)
            pixels.append((r, g, b, a))
    write_rgba_png(path, width, height, pixels)
    print(f"  Generated {path} ({width}x{height})")


def generate_9patch(prefix, radius=12, color=(14, 31, 20), alpha=120, border_color=None, border_alpha=40):
    """Generate a full 9-patch image set for GRUB theme rounded rectangles.

    Creates: {prefix}_nw.png, _n.png, _ne.png, _w.png, _c.png, _e.png,
             _sw.png, _s.png, _se.png

    The corner images are {radius}x{radius} with a quarter-circle mask.
    Edge images are 1px strips.  Center is 1x1 solid fill.
    An optional 1px border is drawn along the outer edge for subtle definition.
    """
    r, g, b = color
    br, bg_, bb = border_color if border_color else (66, 165, 75)  # #42a54b

    def corner_pixel(cx, cy):
        """Return RGBA for a pixel at (cx, cy) within a radius×radius corner tile.
        Origin is at the actual corner of the rounded rect."""
        dist = math.sqrt(cx * cx + cy * cy)
        if dist > radius:
            return (0, 0, 0, 0)
        # Subtle 1px border glow at the outer edge
        edge = radius - dist
        if edge < 1.2:
            t = max(0.0, edge / 1.2)
            a = int(border_alpha + (alpha - border_alpha) * t)
            cr = int(br + (r - br) * t)
            cg = int(bg_ + (g - bg_) * t)
            cb = int(bb + (b - bb) * t)
            return (cr, cg, cb, a)
        return (r, g, b, alpha)

    # ── Corners ──
    # NW (top-left): origin at bottom-right of tile
    pixels = []
    for y in range(radius):
        for x in range(radius):
            pixels.append(corner_pixel(radius - 1 - x, radius - 1 - y))
    write_rgba_png(prefix + "_nw.png", radius, radius, pixels)

    # NE (top-right): origin at bottom-left
    pixels = []
    for y in range(radius):
        for x in range(radius):
            pixels.append(corner_pixel(x, radius - 1 - y))
    write_rgba_png(prefix + "_ne.png", radius, radius, pixels)

    # SW (bottom-left): origin at top-right
    pixels = []
    for y in range(radius):
        for x in range(radius):
            pixels.append(corner_pixel(radius - 1 - x, y))
    write_rgba_png(prefix + "_sw.png", radius, radius, pixels)

    # SE (bottom-right): origin at top-left
    pixels = []
    for y in range(radius):
        for x in range(radius):
            pixels.append(corner_pixel(x, y))
    write_rgba_png(prefix + "_se.png", radius, radius, pixels)

    # ── Edges ──
    # North (top): 1px tall, with border on top edge
    pixels = [(br, bg_, bb, border_alpha)]  # top border
    write_rgba_png(prefix + "_n.png", 1, 1, pixels)

    # South (bottom): 1px tall, with border on bottom edge
    pixels = [(br, bg_, bb, border_alpha)]
    write_rgba_png(prefix + "_s.png", 1, 1, pixels)

    # West (left): 1px wide, with border on left edge
    pixels = [(br, bg_, bb, border_alpha)]
    write_rgba_png(prefix + "_w.png", 1, 1, pixels)

    # East (right): 1px wide, with border on right edge
    pixels = [(br, bg_, bb, border_alpha)]
    write_rgba_png(prefix + "_e.png", 1, 1, pixels)

    # ── Center ──
    pixels = [(r, g, b, alpha)]
    write_rgba_png(prefix + "_c.png", 1, 1, pixels)

    print(f"  Generated 9-patch set: {os.path.basename(prefix)}_*.png ({radius}px radius)")


def generate_logo(path, size=64):
    """Green rounded square with a white 'U' letterform for the GRUB theme header."""
    # Rounded rectangle background
    bg = hex_to_rgb("#42a54b")
    bg_dark = hex_to_rgb("#2e8838")
    radius = size // 6

    pixels = []
    for y in range(size):
        ny = y / max(size - 1, 1)
        for x in range(size):
            # Rounded rect mask
            dx = max(0, max(radius - x, x - (size - 1 - radius)))
            dy = max(0, max(radius - y, y - (size - 1 - radius)))
            corner_dist = math.sqrt(dx * dx + dy * dy)
            if corner_dist > radius:
                pixels.append((0, 0, 0, 0))
                continue

            # Green gradient background
            r = lerp(bg[0], bg_dark[0], ny)
            g = lerp(bg[1], bg_dark[1], ny)
            b = lerp(bg[2], bg_dark[2], ny)

            # Draw white "U" letterform
            cx, cy = size / 2, size / 2
            # U body: two vertical strokes + curved bottom
            u_left = size * 0.30
            u_right = size * 0.70
            u_top = size * 0.22
            u_bottom = size * 0.72
            stroke_w = size * 0.13
            u_mid_y = size * 0.55

            in_u = False
            # Left stroke
            if u_left - stroke_w / 2 <= x <= u_left + stroke_w / 2 and u_top <= y <= u_mid_y:
                in_u = True
            # Right stroke
            if u_right - stroke_w / 2 <= x <= u_right + stroke_w / 2 and u_top <= y <= u_mid_y:
                in_u = True
            # Bottom curve (semicircle)
            if y >= u_mid_y:
                curve_cx = size / 2
                curve_cy = u_mid_y
                curve_r_outer = (u_right - u_left) / 2 + stroke_w / 2
                curve_r_inner = (u_right - u_left) / 2 - stroke_w / 2
                d = math.sqrt((x - curve_cx) ** 2 + (y - curve_cy) ** 2)
                if curve_r_inner <= d <= curve_r_outer and y >= u_mid_y:
                    in_u = True

            if in_u:
                # Anti-alias the edges slightly
                pixels.append((255, 255, 255, 240))
            else:
                pixels.append((r, g, b, 255))

    write_rgba_png(path, size, size, pixels)
    print(f"  Generated {path} ({size}x{size})")


def main():
    if len(sys.argv) < 2:
        print("Usage: generate-grub-theme-assets.py <output-dir>", file=sys.stderr)
        sys.exit(1)

    out_dir = sys.argv[1]
    os.makedirs(out_dir, exist_ok=True)
    print(f"Generating GRUB theme assets in {out_dir}...")

    generate_background(os.path.join(out_dir, "background.png"))
    generate_accent_line(os.path.join(out_dir, "accent_line.png"))

    # 9-patch rounded panels for menu background and selected item
    generate_9patch(
        os.path.join(out_dir, "menu"),
        radius=12,
        color=(14, 31, 20),       # #0e1f14
        alpha=120,
        border_color=(42, 90, 50), # subtle green border
        border_alpha=50,
    )
    generate_9patch(
        os.path.join(out_dir, "select"),
        radius=6,
        color=(66, 165, 75),      # #42a54b
        alpha=160,
        border_color=(78, 190, 90),
        border_alpha=100,
    )

    # Only generate a fallback logo if no pre-made logo exists (e.g. the
    # resized URA horse logo committed to the theme directory).
    logo_path = os.path.join(out_dir, "logo.png")
    if os.path.exists(logo_path):
        print(f"  Keeping existing {logo_path}")
    else:
        generate_logo(logo_path, size=64)
    print("Done.")


if __name__ == "__main__":
    main()
