#!/usr/bin/env python3

from argparse import ArgumentParser
from pathlib import Path
from string import ascii_lowercase

valid_suffixes = ("mp4", "mkv")
valid_sections = list(ascii_lowercase)


def extract_code(fname: str):
    """
    todo:
    * apak175.mp4
    * fc2-ppv-1864525-123-a.mp4
    """

    def ensure_number_valid(num: str):
        try:
            int(num)
        except ValueError:
            raise ValueError(f"invalid number part of code: {num}")

    def ensure_section_valid(sect: str):
        if sect not in valid_sections:
            raise ValueError(f"invalid section part of code: {sect}")

    def ensure_provider_valid(prov: str):
        if "." not in prov:
            raise ValueError(f"invalid provider part of code: {prov}")

    def prune_provider(string: str):
        """
        * x.com@code
        * [x.com]@code
        """

        remain = string

        if "@" in remain:
            # possible unpack error, lets use `*`
            provider, remain = remain.split("@", maxsplit=1)
            ensure_provider_valid(provider)

        if "]" in remain:
            if remain[0] != "[":
                raise ValueError("invalid provider: lack of begin [")
            provider, remain = remain.split("]", maxsplit=1)
            ensure_provider_valid(provider)

        return remain

    def prune_trailer(string: str):
        # sort by length
        trailers = [
            "_uncensored_leaked_nowatermark",
            "_uncensored_leaked",
            "_uncensored",
            "-uncensored",
        ]

        for trailer in trailers:
            if string.endswith(trailer):
                return string.removesuffix(trailer)

        return string

    def handle_2_parts_code(parts: list[str], suffix: str):
        series, num = parts
        try:
            ensure_number_valid(num)
        except ValueError:
            # hrv-035a
            if num[-1] in valid_sections:
                return handle_3_parts_code([series, num[:-1], num[-1]], suffix)
            raise
        else:
            return "{}-{}.{}".format(series, num, suffix)

    def handle_3_parts_code(parts: list[str], suffix: str):
        series, num, sect = parts
        ensure_number_valid(num)
        ensure_section_valid(sect)

        return "{}-{}-{}.{}".format(series, num, sect, suffix)

    def normalize_fc2ppv(raw: str):
        r"""
        patterns:
        * fc2-ppv-\d+_\d
        """

        if not raw.startswith("fc2-ppv-"):
            return raw

        remain = raw[len("fc2-ppv-") :]

        if remain[-2] != "_":
            return "fc2ppv-{}".format(remain)

        try:
            _sect = int(remain[-1], 10)
        except ValueError:
            raise ValueError(r"expect _\d")
        else:
            assert 0 < _sect < 10

        # 1..9 -> a..?
        sect = chr(_sect - 1 + ord("a"))

        return "fc2ppv-{}-{}".format(sect, remain[:-2])

    remain: str = fname.lower()

    # possible unpack error
    remain, suffix = remain.rsplit(".", maxsplit=1)
    if suffix not in valid_suffixes:
        raise ValueError(f"invalid suffix: {suffix}")

    remain = prune_provider(remain)
    remain = prune_trailer(remain)
    remain = normalize_fc2ppv(remain)

    if "_" in remain:
        raise ValueError(f"not support _ in code: {remain}")

    parts = remain.split("-")

    if len(parts) == 1:
        raise ValueError(f"none dash in code: {remain}")

    if len(parts) == 2:
        return handle_2_parts_code(parts, suffix)

    if len(parts) == 3:
        return handle_3_parts_code(parts, suffix)

    raise ValueError(f"too many parts of code: {remain}")


def recruit(srcpath: Path, destdir: Path, dryrun: bool):
    try:
        code = extract_code(srcpath.name)
    except ValueError as e:
        raise SystemExit(repr(e))

    destpath = destdir.joinpath(code)
    print(f"mv {srcpath.name} {code}")
    if not dryrun:
        srcpath.rename(destpath)


def main():
    parser = ArgumentParser()
    parser.add_argument("src_path", type=str)
    parser.add_argument("dest_dir", type=str)
    parser.add_argument("-n", "--dryrun", action="store_true")
    args = parser.parse_args()

    srcpath = Path(args.src_path).resolve()
    if not srcpath.is_file():
        raise SystemExit("invalid src path")

    destdir = Path(args.dest_dir).resolve()
    if not destdir.is_dir():
        raise SystemExit("invalid dest dir")

    recruit(srcpath, destdir, args.dryrun)


if __name__ == "__main__":
    main()
