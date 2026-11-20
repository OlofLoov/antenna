"""Copies an MPEG-TS file without some packets of its video stream, as a
stream that lost packets on the way arrives.

Usage: drop-ts-packets.py <in.ts> <out.ts> <first> <count>

Drops <count> packets of the first video PID (stream type 0x1B H.264 or
0x24 HEVC), starting at that PID's packet number <first>.
"""

import sys

PACKET = 188


def video_pid(data):
    pmt_pids = set()
    for offset in range(0, len(data) - PACKET + 1, PACKET):
        packet = data[offset : offset + PACKET]
        pid = ((packet[1] & 0x1F) << 8) | packet[2]
        if not packet[1] & 0x40:
            continue
        start = 5 + packet[4] if packet[3] & 0x20 else 4
        start += packet[start] + 1
        section = packet[start:]
        if pid == 0 and section[0] == 0x00:
            length = ((section[1] & 0x0F) << 8) | section[2]
            for entry in range(8, 3 + length - 4, 4):
                number = (section[entry] << 8) | section[entry + 1]
                if number != 0:
                    pmt_pids.add(((section[entry + 2] & 0x1F) << 8) | section[entry + 3])
        elif pid in pmt_pids and section[0] == 0x02:
            length = ((section[1] & 0x0F) << 8) | section[2]
            info = ((section[10] & 0x0F) << 8) | section[11]
            entry = 12 + info
            while entry < 3 + length - 4:
                kind = section[entry]
                stream = ((section[entry + 1] & 0x1F) << 8) | section[entry + 2]
                if kind in (0x1B, 0x24):
                    return stream
                entry += 5 + (((section[entry + 3] & 0x0F) << 8) | section[entry + 4])
    raise SystemExit("no video stream")


def main():
    source, target, first, count = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    with open(source, "rb") as handle:
        data = handle.read()
    pid = video_pid(data)
    seen = 0
    out = bytearray()
    for offset in range(0, len(data) - PACKET + 1, PACKET):
        packet = data[offset : offset + PACKET]
        if ((packet[1] & 0x1F) << 8) | packet[2] == pid:
            seen += 1
            if first <= seen - 1 < first + count:
                continue
        out += packet
    with open(target, "wb") as handle:
        handle.write(out)


main()
