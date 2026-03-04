#!/usr/bin/env python3
"""Generate GRUB theme PNG assets for UmaOS.

Creates:
  background.png  — 1920x1080 dark emerald gradient with glows + vignette
  accent_line.png — green-to-pink gradient accent line
  menu_*.png      — 9-patch set for menu panel (24px rounded corners)
  select_*.png    — 9-patch set for selected item (12px rounded corners)

Uses only the Python standard library (struct + zlib for minimal PNG writing).
"""

import math
import os
import struct
import sys
import zlib


def write_png(path, width, height, pixels):
    """Write an RGB PNG from a flat list of (r, g, b) tuples."""
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
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


def write_rgba_png(path, width, height, pixels):
    """Write an RGBA PNG from a flat list of (r, g, b, a) tuples."""
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
        f.write(chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)))
        f.write(chunk(b"IDAT", compressed))
        f.write(chunk(b"IEND", b""))


def lerp(a, b, t):
    return int(a + (b - a) * t)


def hex_to_rgb(h):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def generate_background(path, width=1920, height=1080):
    """1920x1080 dark emerald gradient with green and pink glows.

    Rendered at full HD so GRUB doesn't need to scale it.  This avoids
    blurring and keeps the glow effects crisp.
    """
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


def generate_accent_line(path, width=460, height=3):
    """Green-to-pink gradient accent line (wider for 1080p)."""
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
            edge = min(x, width - 1 - x) / min(30, width // 2)
            a = int(min(1.0, edge) * 200)
            pixels.append((r, g, b, a))
    write_rgba_png(path, width, height, pixels)
    print(f"  Generated {path} ({width}x{height})")


def generate_9patch(prefix, radius, color, alpha,
                    border_color=None, border_alpha=40):
    """Generate a full 9-patch image set for GRUB rounded rectangles.

    Creates: {prefix}_{nw,n,ne,w,c,e,sw,s,se}.png

    Corner tiles are radius×radius with a quarter-circle alpha mask.
    Edge tiles are 2px strips (wider than 1px for better GRUB compat).
    Center is a 2×2 solid fill.
    """
    r, g, b = color
    br, bg_, bb = border_color if border_color else (66, 165, 75)

    def corner_pixel(cx, cy):
        """RGBA for a pixel at (cx, cy) within a corner tile."""
        dist = math.sqrt(cx * cx + cy * cy)
        if dist > radius:
            return (0, 0, 0, 0)
        # Anti-aliased edge (1px soft border)
        edge = radius - dist
        if edge < 1.5:
            t = max(0.0, edge / 1.5)
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

    # ── Edges (2px wide/tall for better GRUB compatibility) ──
    # North: 2px tall strip (border top row + fill bottom row)
    pixels = [
        (br, bg_, bb, border_alpha), (br, bg_, bb, border_alpha),
        (r, g, b, alpha), (r, g, b, alpha),
    ]
    write_rgba_png(prefix + "_n.png", 2, 2, pixels)

    # South: 2px tall strip (fill top row + border bottom row)
    pixels = [
        (r, g, b, alpha), (r, g, b, alpha),
        (br, bg_, bb, border_alpha), (br, bg_, bb, border_alpha),
    ]
    write_rgba_png(prefix + "_s.png", 2, 2, pixels)

    # West: 2px wide strip (border left col + fill right col)
    pixels = [
        (br, bg_, bb, border_alpha), (r, g, b, alpha),
        (br, bg_, bb, border_alpha), (r, g, b, alpha),
    ]
    write_rgba_png(prefix + "_w.png", 2, 2, pixels)

    # East: 2px wide strip (fill left col + border right col)
    pixels = [
        (r, g, b, alpha), (br, bg_, bb, border_alpha),
        (r, g, b, alpha), (br, bg_, bb, border_alpha),
    ]
    write_rgba_png(prefix + "_e.png", 2, 2, pixels)

    # ── Center (2×2 solid fill) ──
    pixels = [(r, g, b, alpha)] * 4
    write_rgba_png(prefix + "_c.png", 2, 2, pixels)

    print(f"  Generated 9-patch set: {os.path.basename(prefix)}_*.png "
          f"({radius}px radius)")


def generate_logo(path, size=64):
    """Fallback green rounded square with white 'U'.  Only used when no
    pre-made logo.png exists (the real URA horse logo takes priority)."""
    bg = hex_to_rgb("#42a54b")
    bg_dark = hex_to_rgb("#2e8838")
    radius = size // 6

    pixels = []
    for y in range(size):
        ny = y / max(size - 1, 1)
        for x in range(size):
            dx = max(0, max(radius - x, x - (size - 1 - radius)))
            dy = max(0, max(radius - y, y - (size - 1 - radius)))
            corner_dist = math.sqrt(dx * dx + dy * dy)
            if corner_dist > radius:
                pixels.append((0, 0, 0, 0))
                continue

            r = lerp(bg[0], bg_dark[0], ny)
            g = lerp(bg[1], bg_dark[1], ny)
            b = lerp(bg[2], bg_dark[2], ny)

            cx, cy = size / 2, size / 2
            u_left = size * 0.30
            u_right = size * 0.70
            u_top = size * 0.22
            stroke_w = size * 0.13
            u_mid_y = size * 0.55

            in_u = False
            if u_left - stroke_w / 2 <= x <= u_left + stroke_w / 2 and u_top <= y <= u_mid_y:
                in_u = True
            if u_right - stroke_w / 2 <= x <= u_right + stroke_w / 2 and u_top <= y <= u_mid_y:
                in_u = True
            if y >= u_mid_y:
                curve_cx = size / 2
                curve_r_outer = (u_right - u_left) / 2 + stroke_w / 2
                curve_r_inner = (u_right - u_left) / 2 - stroke_w / 2
                d = math.sqrt((x - curve_cx) ** 2 + (y - u_mid_y) ** 2)
                if curve_r_inner <= d <= curve_r_outer:
                    in_u = True

            if in_u:
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

    # 9-patch rounded panels — larger radii for visible rounding at 1080p
    #
    # Menu background: 24px corners, dark emerald, semi-transparent
    generate_9patch(
        os.path.join(out_dir, "menu"),
        radius=24,
        color=(14, 31, 20),        # #0e1f14
        alpha=120,
        border_color=(42, 90, 50),  # subtle green border
        border_alpha=50,
    )
    # Selected item: 12px corners, green highlight
    generate_9patch(
        os.path.join(out_dir, "select"),
        radius=12,
        color=(66, 165, 75),       # #42a54b
        alpha=160,
        border_color=(78, 190, 90),
        border_alpha=100,
    )

    # Keep existing URA horse logo; only generate fallback if missing
    logo_path = os.path.join(out_dir, "logo.png")
    if os.path.exists(logo_path):
        print(f"  Keeping existing {logo_path}")
    else:
        generate_logo(logo_path, size=64)

    print("Done.")


if __name__ == "__main__":
    main()
