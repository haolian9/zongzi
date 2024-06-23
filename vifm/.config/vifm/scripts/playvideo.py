#!/usr/bin/env python3

# * detect file's mime
# * fallback to xdg-open
# * treat av specially
# * be aware of 3d (side by side) video file

import logging
import os
from argparse import ArgumentParser
from pathlib import Path

known_series = (
    "vrkm",
    "ipvr",
    "sivr",
    "ppvr",
    "bibivr",
    "mdvr",
    "wavr",
    "kavr",
)

known_suffixes = (
    ".mp4",
    ".mkv",
    ".avi",
    ".mts",
    ".ts",
)


def parse_args():
    parser = ArgumentParser()
    parser.add_argument("file", type=str)

    return parser.parse_args()


def is_3d(file: Path):
    fname = file.name.lower()

    for kw in known_series:
        if kw in fname:
            return True

    if "vr-" in fname:
        return True

    return False


def resolve_cmd(file: Path):
    if file.suffix not in known_suffixes:
        return ["xdg-open", str(file)]

    if is_3d(file):
        bin = Path.home().joinpath(".scripts", "mpv3d")
        if bin.exists():
            return [str(bin), str(file)]
        else:
            logging.debug("%s do not exist, fallback to mpv", bin)

    return ["mpv", str(file)]


def main():
    args = parse_args()
    file = Path(args.file).resolve()
    assert file.exists(), file

    cmd = resolve_cmd(file)
    logging.info("cmd %s", cmd)

    os.execvp(cmd[0], cmd)


if __name__ == "__main__":
    logging.basicConfig(
        level="DEBUG",
        style="{",
        datefmt="%Y-%m-%d %H:%M:%S",
        format="{asctime} {message}",
    )

    main()
