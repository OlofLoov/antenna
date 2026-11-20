"""Joins MPEG-TS files into one, as a broadcast splices one feed into
another: each PID's continuity counter carries on across the join, so the
demuxer sees no lost packets, only the timestamps of the next feed.

Usage: splice-ts.py <out.ts> <in.ts> <in.ts> [<in.ts> ...]
"""

import sys

PACKET = 188


def main():
    target, sources = sys.argv[1], sys.argv[2:]
    counters = {}
    out = bytearray()
    for source in sources:
        with open(source, "rb") as handle:
            data = handle.read()
        shift = {}
        for offset in range(0, len(data) - PACKET + 1, PACKET):
            packet = bytearray(data[offset : offset + PACKET])
            pid = ((packet[1] & 0x1F) << 8) | packet[2]
            if pid != 0x1FFF and packet[3] & 0x10:
                counter = packet[3] & 0x0F
                if pid not in shift:
                    shift[pid] = (counters[pid] + 1 - counter) % 16 if pid in counters else 0
                counter = (counter + shift[pid]) % 16
                packet[3] = (packet[3] & 0xF0) | counter
                counters[pid] = counter
            out += packet
    with open(target, "wb") as handle:
        handle.write(out)


main()
