#!/usr/bin/env python3
"""Writes the XMLTV guide for the App Review playlist to stdout.

Usage: make-review-guide.py <playlist.m3u> <start YYYY-MM-DD> <days>

Every channel in the playlist with a tvg-id gets back-to-back programmes from
00:00 UTC on the start day for the given number of days. The same arguments
always give the same file.
"""

import datetime
import re
import sys
from xml.sax.saxutils import escape, quoteattr

SHOWS = [
    ("Test Card", "Color bars and a tone, for checking picture and sound.", 30),
    ("Bip Bop Hour", "Apple's sample stream on a loop.", 60),
    ("Signal Check", "Counting frames against the clock on screen.", 30),
    ("Bitrate Ladder", "The test pattern in every bitrate the stream offers.", 60),
    ("Long Loop", "The sample stream again, start to finish.", 90),
]


def channels(playlist):
    found = []
    for line in playlist.splitlines():
        if not line.startswith("#EXTINF:"):
            continue
        guide_id = re.search(r'tvg-id="([^"]+)"', line)
        if guide_id:
            found.append((guide_id.group(1), line.rsplit(",", 1)[1].strip()))
    return found


def stamp(moment):
    return moment.strftime("%Y%m%d%H%M%S +0000")


def guide(playlist, start, days):
    begin = datetime.datetime.combine(start, datetime.time(), datetime.timezone.utc)
    end = begin + datetime.timedelta(days=days)
    lines = ['<?xml version="1.0" encoding="UTF-8"?>', '<tv generator-info-name="Antenna review guide">']
    listed = channels(playlist)
    for guide_id, name in listed:
        lines.append(f"  <channel id={quoteattr(guide_id)}><display-name>{escape(name)}</display-name></channel>")
    for offset, (guide_id, _) in enumerate(listed):
        moment, index = begin, offset
        while moment < end:
            title, description, minutes = SHOWS[index % len(SHOWS)]
            stop = min(moment + datetime.timedelta(minutes=minutes), end)
            lines.append(
                f'  <programme start="{stamp(moment)}" stop="{stamp(stop)}" channel={quoteattr(guide_id)}>'
                f"<title>{escape(title)}</title><desc>{escape(description)}</desc></programme>"
            )
            moment, index = stop, index + 1
    lines.append("</tv>")
    return "\n".join(lines) + "\n"


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    with open(sys.argv[1], encoding="utf-8") as file:
        playlist = file.read()
    start = datetime.date.fromisoformat(sys.argv[2])
    sys.stdout.write(guide(playlist, start, int(sys.argv[3])))


if __name__ == "__main__":
    main()
