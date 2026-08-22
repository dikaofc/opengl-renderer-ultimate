#!/usr/bin/env python3
"""
Generate banner.png for KernelSU module
Pure Python — no external libraries needed
"""

import struct
import zlib
import os

# Banner dimensions (KernelSU recommended)
WIDTH = 500
HEIGHT = 120

# Colors (Neo-Brutalism theme)
BG_COLOR = (245, 240, 232)       # #f5f0e8 cream
ACCENT_COLOR = (255, 225, 86)    # #ffe156 yellow
TEXT_COLOR = (26, 26, 26)        # #1a1a1a black
BORDER_COLOR = (26, 26, 26)     # #1a1a1a black
TEAL = (45, 212, 191)            # #2dd4bf
PINK = (244, 114, 182)           # #f472b6
PURPLE = (192, 132, 252)         # #c084fc

def create_png(width, height, pixels):
    """Create PNG from pixel data (list of rows, each row is list of RGB tuples)"""
    
    # PNG signature
    signature = b'\x89PNG\r\n\x1a\n'
    
    # IHDR chunk
    ihdr_data = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)  # 8-bit RGB
    ihdr_crc = zlib.crc32(b'IHDR' + ihdr_data) & 0xffffffff
    ihdr_chunk = struct.pack('>I', 13) + b'IHDR' + ihdr_data + struct.pack('>I', ihdr_crc)
    
    # IDAT chunk (image data)
    raw_data = b''
    for row in pixels:
        raw_data += b'\x00'  # filter byte (None)
        for r, g, b in row:
            raw_data += struct.pack('BBB', r, g, b)
    
    compressed = zlib.compress(raw_data)
    idat_crc = zlib.crc32(b'IDAT' + compressed) & 0xffffffff
    idat_chunk = struct.pack('>I', len(compressed)) + b'IDAT' + compressed + struct.pack('>I', idat_crc)
    
    # IEND chunk
    iend_crc = zlib.crc32(b'IEND') & 0xffffffff
    iend_chunk = struct.pack('>I', 0) + b'IEND' + struct.pack('>I', iend_crc)
    
    return signature + ihdr_chunk + idat_chunk + iend_chunk

def draw_rect(pixels, x1, y1, x2, y2, color):
    """Draw filled rectangle"""
    for y in range(max(0, y1), min(HEIGHT, y2)):
        for x in range(max(0, x1), min(WIDTH, x2)):
            pixels[y][x] = color

def draw_border(pixels, x1, y1, x2, y2, color, width=3):
    """Draw rectangle border"""
    for w in range(width):
        # Top
        for x in range(x1, x2):
            if y1 + w < HEIGHT:
                pixels[y1 + w][x] = color
        # Bottom
        for x in range(x1, x2):
            if y2 - 1 - w >= 0:
                pixels[y2 - 1 - w][x] = color
        # Left
        for y in range(y1, y2):
            if x1 + w < WIDTH:
                pixels[y][x1 + w] = color
        # Right
        for y in range(y1, y2):
            if x2 - 1 - w >= 0:
                pixels[y][x2 - 1 - w] = color

def draw_text_simple(pixels, text, x, y, color, scale=1):
    """
    Draw simple blocky text (5x7 font, scaled)
    Only supports A-Z, 0-1, and some symbols
    """
    FONT = {
        'O': ['01110','10001','10001','10001','10001','10001','01110'],
        'P': ['11110','10001','10001','11110','10000','10000','10000'],
        'E': ['11111','10000','10000','11110','10000','10000','11111'],
        'N': ['10001','11001','10101','10011','10001','10001','10001'],
        'G': ['01110','10001','10000','10111','10001','10001','01110'],
        'L': ['10000','10000','10000','10000','10000','10000','11111'],
        'R': ['11110','10001','10001','11110','10100','10010','10001'],
        'A': ['01110','10001','10001','11111','10001','10001','10001'],
        ' ': ['00000','00000','00000','00000','00000','00000','00000'],
        'R': ['11110','10001','10001','11110','10100','10010','10001'],
        'D': ['11100','10010','10001','10001','10001','10010','11100'],
        'E': ['11111','10000','10000','11110','10000','10000','11111'],
        'V': ['10001','10001','10001','10001','10001','01010','01010'],
        'U': ['10001','10001','10001','10001','10001','10001','01110'],
        'I': ['11111','00100','00100','00100','00100','00100','11111'],
        'T': ['11111','00100','00100','00100','00100','00100','00100'],
        'M': ['10001','11011','10101','10001','10001','10001','10001'],
        'S': ['01110','10001','10000','01110','00001','10001','01110'],
        'W': ['10001','10001','10001','10101','10101','10101','01010'],
        'H': ['10001','10001','10001','11111','10001','10001','10001'],
        'C': ['01110','10001','10000','10000','10000','10001','01110'],
        'B': ['11110','10001','10001','11110','10001','10001','11110'],
        'F': ['11111','10000','10000','11110','10000','10000','10000'],
        'X': ['10001','10001','01010','00100','01010','10001','10001'],
        '3': ['01110','10001','00001','00110','00001','10001','01110'],
        '.': ['00000','00000','00000','00000','00000','00000','00100'],
        ':': ['00000','00000','00100','00000','00000','00100','00000'],
    }
    
    cx = x
    for ch in text.upper():
        glyph = FONT.get(ch, FONT[' '])
        for row_idx, row in enumerate(glyph):
            for col_idx, pixel in enumerate(row):
                if pixel == '1':
                    for sy in range(scale):
                        for sx in range(scale):
                            px = cx + col_idx * scale + sx
                            py = y + row_idx * scale + sy
                            if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                                pixels[py][px] = color
        cx += 6 * scale

def draw_lightning(pixels, x, y, color, scale=2):
    """Draw a lightning bolt icon"""
    bolt = [
        [0,0,1,0,0],
        [0,1,1,0,0],
        [1,1,0,0,0],
        [0,1,1,0,0],
        [0,0,1,1,0],
        [0,0,0,1,0],
    ]
    for row_idx, row in enumerate(bolt):
        for col_idx, pixel in enumerate(row):
            if pixel == 1:
                for sy in range(scale):
                    for sx in range(scale):
                        px = x + col_idx * scale + sx
                        py = y + row_idx * scale + sy
                        if 0 <= px < WIDTH and 0 <= py < HEIGHT:
                            pixels[py][px] = color

# Initialize pixels
pixels = [[BG_COLOR for _ in range(WIDTH)] for _ in range(HEIGHT)]

# Draw accent bar at top
draw_rect(pixels, 0, 0, WIDTH, 8, ACCENT_COLOR)

# Draw accent bar at bottom
draw_rect(pixels, 0, HEIGHT - 8, WIDTH, HEIGHT, ACCENT_COLOR)

# Draw left accent stripe
draw_rect(pixels, 0, 8, 12, HEIGHT - 8, TEAL)

# Draw main border
draw_border(pixels, 14, 10, WIDTH - 2, HEIGHT - 10, BORDER_COLOR, 3)

# Draw inner fill
draw_rect(pixels, 17, 13, WIDTH - 5, HEIGHT - 13, BG_COLOR)

# Draw lightning bolt icon
draw_lightning(pixels, 28, 30, ACCENT_COLOR, 3)
draw_border(pixels, 28, 30, 28 + 15, 30 + 14 * 3, BORDER_COLOR, 2)

# Draw title text "OPENGL RENDERER"
draw_text_simple(pixels, "OPENGL", 60, 25, TEXT_COLOR, 2)
draw_text_simple(pixels, "RENDERER", 60, 50, TEXT_COLOR, 2)

# Draw subtitle "ULTIMATE"
draw_text_simple(pixels, "ULTIMATE", 60, 80, TEAL, 2)

# Draw version badge
draw_rect(pixels, 250, 80, 340, 100, ACCENT_COLOR)
draw_border(pixels, 250, 80, 340, 100, BORDER_COLOR, 2)
draw_text_simple(pixels, "V3.2.0", 256, 83, TEXT_COLOR, 1)

# Draw decorative dots
for i in range(5):
    draw_rect(pixels, 360 + i * 14, 30, 370 + i * 14, 40, TEAL if i % 2 == 0 else PINK)

# Draw decorative line
draw_rect(pixels, 360, 60, 480, 62, BORDER_COLOR)

# Draw kernelSU compatible text
draw_text_simple(pixels, "KSU", 380, 70, PURPLE, 1)

# Draw pixel-art decorations on right
for i in range(3):
    draw_rect(pixels, 420 + i * 20, 85, 435 + i * 20, 100, [TEAL, PINK, ACCENT_COLOR][i])

# Save
output_path = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'system', 'banner.png')
os.makedirs(os.path.dirname(output_path), exist_ok=True)

png_data = create_png(WIDTH, HEIGHT, pixels)
with open(output_path, 'wb') as f:
    f.write(png_data)

print(f"Banner created: {output_path}")
print(f"Size: {len(png_data)} bytes ({len(png_data) / 1024:.1f} KB)")
print(f"Dimensions: {WIDTH}x{HEIGHT}")
