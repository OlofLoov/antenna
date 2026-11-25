#!/usr/bin/env python3
"""Writes the answers of the App Review demo Xtream Codes server.

Usage: make-review-xtream.py <playlist.m3u> <folder> <base address>

The live channels are the playlist's, with its tvg-ids as guide ids, so
xmltv.php can answer with the playlist's guide. The movies and the series are
made up and reuse names the store screenshots show. Posters and backdrops are
<base address>/art/<movie|series>-<id>-<poster|backdrop>.jpg, drawn by
scripts/make-store-art.py. Infra/modules/site/review.js maps each request to
a file here and each stream id to one of Apple's sample streams. The same
arguments always give the same files.
"""

import json
import pathlib
import re
import sys

ADDED = 1764547200

LIVE_CATEGORY = ("1", "Apple samples")
MOVIE_CATEGORIES = [("11", "Drama"), ("12", "Adventure")]
SERIES_CATEGORIES = [("21", "Crime")]

# (stream id, name, category id, release date, seconds, rating out of 10, plot)
MOVIES = [
    (101, "The Long Harbor", "11", "2024-03-01", 600, 7.4,
     "A harbor pilot has one night to decide who leaves port before the buyers arrive at dawn."),
    (102, "Salt Road", "12", "2023-06-16", 1800, 6.9,
     "Two sisters drive a salt truck across the flats to the coast and find the road ends sooner than the map says."),
    (103, "Paper Cities", "11", "2022-10-07", 600, 7.1,
     "An architect builds a paper model of the town she grew up in, one street for every letter she never sent."),
    (104, "Quiet Engines", "12", "2025-01-24", 600, 6.6,
     "A night train crew keeps the engines running through a snowstorm, with three passengers who will not say where "
     "they are going."),
    (105, "Glass Orchard", "11", "2021-04-30", 1800, 7.8,
     "A glassblower takes over her grandfather's greenhouse and the orchard of glass fruit he left unfinished."),
]

SERIES = (201, "Harbor Watch", "21", "2024-09-12", 8.1,
          "The night shift at a small harbor police station, one case for every tide.")

# (episode id, season, number, title, seconds, plot)
EPISODES = [
    (2011, 1, 1, "Low Tide", 600, "A fishing boat comes in on the tide with no one aboard."),
    (2012, 1, 2, "Fog Bell", 600, "The bell on the outer buoy rings all night, and there is no wind."),
    (2013, 1, 3, "Slack Water", 1800, "The harbormaster's ledger goes missing an hour before the audit."),
]


def channels(playlist):
    found = []
    for line in playlist.splitlines():
        if line.startswith("#EXTINF:"):
            guide_id = re.search(r'tvg-id="([^"]+)"', line)
            found.append((line.rsplit(",", 1)[1].strip(), guide_id.group(1) if guide_id else ""))
    return found


def clock(seconds):
    return f"{seconds // 3600:02d}:{seconds % 3600 // 60:02d}:{seconds % 60:02d}"


def art(base, kind, number, shape):
    return f"{base}/art/{kind}-{number}-{shape}.jpg"


def category_rows(categories):
    return [{"category_id": number, "category_name": name, "parent_id": 0} for number, name in categories]


def answers(playlist, base):
    host = re.sub(r"^https?://", "", base).split("/")[0]
    files = {
        "denied.json": {"user_info": {"auth": 0}},
        "account.json": {
            "user_info": {
                "auth": 1,
                "status": "Active",
                "exp_date": None,
                "is_trial": "0",
                "active_cons": "0",
                "created_at": str(ADDED),
                "max_connections": "1",
                "allowed_output_formats": ["m3u8", "ts"],
            },
            "server_info": {
                "url": host,
                "port": "443",
                "https_port": "443",
                "server_protocol": "https",
                "timezone": "UTC",
            },
        },
    }

    live = [
        {
            "num": number,
            "name": name,
            "stream_type": "live",
            "stream_id": number,
            "stream_icon": "",
            "epg_channel_id": guide_id,
            "added": str(ADDED),
            "category_id": LIVE_CATEGORY[0],
            "tv_archive": 0,
            "tv_archive_duration": 0,
        }
        for number, (name, guide_id) in enumerate(channels(playlist), start=1)
    ]
    files["get_live_categories.json"] = category_rows([LIVE_CATEGORY])
    files["get_live_streams.json"] = live
    files[f"get_live_streams/{LIVE_CATEGORY[0]}.json"] = live

    movies = []
    for order, (stream_id, name, category, released, seconds, rating, plot) in enumerate(MOVIES, start=1):
        poster = art(base, "movie", stream_id, "poster")
        row = {
            "num": order,
            "name": name,
            "stream_type": "movie",
            "stream_id": stream_id,
            "stream_icon": poster,
            "rating": f"{rating:.1f}",
            "rating_5based": round(rating / 2, 2),
            "added": str(ADDED - order * 86400),
            "category_id": category,
            "container_extension": "m3u8",
        }
        movies.append(row)
        files[f"get_vod_info/{stream_id}.json"] = {
            "info": {
                "movie_image": poster,
                "backdrop_path": [art(base, "movie", stream_id, "backdrop")],
                "plot": plot,
                "genre": dict(MOVIE_CATEGORIES)[category],
                "releasedate": released,
                "duration_secs": seconds,
                "duration": clock(seconds),
                "rating": f"{rating:.1f}",
            },
            "movie_data": {
                "stream_id": stream_id,
                "name": name,
                "added": row["added"],
                "category_id": category,
                "container_extension": "m3u8",
            },
        }
    files["get_vod_categories.json"] = category_rows(MOVIE_CATEGORIES)
    files["get_vod_streams.json"] = movies
    for number, _ in MOVIE_CATEGORIES:
        files[f"get_vod_streams/{number}.json"] = [row for row in movies if row["category_id"] == number]

    series_id, name, category, released, rating, plot = SERIES
    poster = art(base, "series", series_id, "poster")
    backdrop = art(base, "series", series_id, "backdrop")
    genre = dict(SERIES_CATEGORIES)[category]
    series = [
        {
            "num": 1,
            "name": name,
            "series_id": series_id,
            "cover": poster,
            "plot": plot,
            "genre": genre,
            "releaseDate": released,
            "last_modified": str(ADDED),
            "rating": f"{rating:.1f}",
            "rating_5based": round(rating / 2, 2),
            "backdrop_path": [backdrop],
            "category_id": category,
        }
    ]
    seasons = sorted({season for _, season, *_ in EPISODES})
    files["get_series_categories.json"] = category_rows(SERIES_CATEGORIES)
    files["get_series.json"] = series
    files[f"get_series/{category}.json"] = series
    files[f"get_series_info/{series_id}.json"] = {
        "seasons": [
            {
                "season_number": season,
                "name": f"Season {season}",
                "episode_count": sum(1 for episode in EPISODES if episode[1] == season),
                "cover": poster,
            }
            for season in seasons
        ],
        "info": {
            "name": name,
            "cover": poster,
            "plot": plot,
            "genre": genre,
            "releaseDate": released,
            "rating": f"{rating:.1f}",
            "backdrop_path": [backdrop],
            "category_id": category,
        },
        "episodes": {
            str(season): [
                {
                    "id": str(episode_id),
                    "episode_num": number,
                    "title": title,
                    "container_extension": "m3u8",
                    "season": season,
                    "info": {
                        "duration_secs": seconds,
                        "duration": clock(seconds),
                        "plot": episode_plot,
                        "movie_image": backdrop,
                    },
                }
                for episode_id, episode_season, number, title, seconds, episode_plot in EPISODES
                if episode_season == season
            ]
            for season in seasons
        },
    }
    return files


def main():
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    playlist = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
    folder = pathlib.Path(sys.argv[2])
    base = sys.argv[3].rstrip("/")
    for path, body in answers(playlist, base).items():
        target = folder / path
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(body, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
