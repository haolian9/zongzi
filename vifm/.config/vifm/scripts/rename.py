#!/usr/bin/env python3

# using tmux popup open nvim which contains the file name will be renamed
# on exit rename with the file content.

import logging
import os
import shlex
import subprocess
import tempfile
from argparse import ArgumentParser
from pathlib import Path


def parse_args():
    parser = ArgumentParser()
    parser.add_argument("file", type=str)

    return parser.parse_args()


def main():
    args = parse_args()
    srcfile = Path(args.file).resolve()
    assert srcfile.exists(), srcfile

    if "TMUX" not in os.environ:
        raise SystemExit("requires tmux.")

    _fd, tmpfpath = tempfile.mkstemp()
    os.close(_fd)

    with open(tmpfpath, "wb") as fp:
        fp.write(srcfile.name.encode())

    try:
        subprocess.run(
            ["tmux", "display-popup", "-E", "/usr/bin/vi", shlex.quote(tmpfpath)],
            check=True,
        )
    except subprocess.CalledProcessError as e:
        raise SystemExit(repr(e))
    else:
        with open(tmpfpath, "rb") as fp:
            line: bytes = fp.readline()

        assert line.endswith(b"\n")
        newname = line[:-1].decode()
        if newname == srcfile.name:
            logging.info("no change")
            return

        logging.info(f"renaming to {newname}")
        srcfile.rename(srcfile.parent.joinpath(newname))
    finally:
        os.unlink(tmpfpath)


if __name__ == "__main__":
    logging.basicConfig(
        level="DEBUG",
        style="{",
        datefmt="%H:%M:%S",
        format="{asctime} {message}",
    )

    main()
