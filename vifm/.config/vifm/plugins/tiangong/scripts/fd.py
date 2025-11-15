#!/usr/bin/env python3

import os
from argparse import ArgumentParser
from subprocess import PIPE, Popen


def parse_args():
    par = ArgumentParser()
    par.add_argument("--working-dir", type=str, required=True)
    par.add_argument("--out-file", type=str, required=True)
    return par.parse_args()


def choose_a_dir(working_dir: str) -> bytes:
    """choice=$(fd | fzf)"""
    with Popen(["fd", "--type=d", "--max-depth=10", "--max-results=299"], cwd=working_dir, stdout=PIPE) as fd:
        with Popen(["fzf", "--exit-0"], stdin=fd.stdout, stdout=PIPE) as fzf:
            rc = fzf.wait()
            if rc != 0:
                raise SystemExit(rc)

            assert fzf.stdout
            choice = fzf.stdout.read()
            assert choice.endswith(b"/\n")

            return choice[:-2]


def main():
    assert os.isatty(2)

    args = parse_args()

    choice = choose_a_dir(args.working_dir)

    with open(args.out_file, "wb") as fp:
        fp.write(choice)


if __name__ == "__main__":
    main()
