#!/usr/bin/env python3
"""Writes a picture subtitle stream (.sup, Blu-ray PGS) for the playback
fixtures. ffmpeg cannot turn text into picture subtitles, but it can turn
these pictures into DVB subtitles, which is what make-stream-fixtures.sh does.

Usage: make-pgs-subtitles.py <out.sup> <width>x<height> <start>-<end>[,<start>-<end>...]
Times are in seconds. Each cue is a white bar with a dark band across it,
a fifth of the page wide, near the bottom of the page.
"""
import struct
import sys

CLOCK = 90000


def segment(kind, pts, payload):
    return b"PG" + struct.pack(">IIBH", pts, 0, kind, len(payload)) + payload


def rle(width, height, pixel):
    out = bytearray()
    for row in range(height):
        column = 0
        while column < width:
            color = pixel(column, row)
            run = 1
            while column + run < width and pixel(column + run, row) == color and run < 16383:
                run += 1
            if color == 0:
                out += bytes([0, run]) if run < 64 else bytes([0, 0x40 | (run >> 8), run & 0xFF])
            elif run < 3:
                out += bytes([color]) * run
            else:
                out += bytes([0, 0x80 | run, color]) if run < 64 else bytes([0, 0xC0 | (run >> 8), run & 0xFF, color])
            column += run
        out += b"\x00\x00"
    return bytes(out)


def cue(number, start, end, page_width, page_height):
    width, height = page_width // 5, page_height // 12
    x, y = (page_width - width) // 2, page_height - height * 2
    on, off = int(start * CLOCK), int(end * CLOCK)
    window = struct.pack(">BBHHHH", 1, 0, x, y, width, height)

    def composition(state, objects):
        head = struct.pack(">HHBHBBBB", page_width, page_height, 0x10, number * 2 + (objects == 0), state, 0, 0, objects)
        return head + (struct.pack(">HBBHH", 0, 0, 0, x, y) if objects else b"")

    # Palette entry: id, Y, Cr, Cb, alpha. 1 is opaque white, 2 opaque dark grey.
    palette = struct.pack(">BB", 0, 0) + bytes([1, 235, 128, 128, 255, 2, 40, 128, 128, 255])
    band = range(height // 3, height * 2 // 3)
    data = rle(width, height, lambda column, row: 2 if row in band else 1)
    picture = struct.pack(">HBB", 0, 0, 0xC0) + (len(data) + 4).to_bytes(3, "big") + struct.pack(">HH", width, height) + data
    shown = (
        segment(0x16, on, composition(0x80, 1))
        + segment(0x17, on, window)
        + segment(0x14, on, palette)
        + segment(0x15, on, picture)
        + segment(0x80, on, b"")
    )
    cleared = segment(0x16, off, composition(0x00, 0)) + segment(0x17, off, window) + segment(0x80, off, b"")
    return shown + cleared


def main():
    out, size, cues = sys.argv[1], sys.argv[2], sys.argv[3]
    page_width, page_height = (int(part) for part in size.split("x"))
    stream = b""
    for number, span in enumerate(cues.split(",")):
        start, end = (float(part) for part in span.split("-"))
        stream += cue(number, start, end, page_width, page_height)
    with open(out, "wb") as handle:
        handle.write(stream)


if __name__ == "__main__":
    main()
