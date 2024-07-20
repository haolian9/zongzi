#!/usr/bin/env python3


import argparse
import logging
import pathlib
import re
import subprocess
import time
import typing as T
from collections import namedtuple

Unit = namedtuple("Unit", "unit load active sub description")


class Facts:
    home = pathlib.Path.home()
    trojan_xdg = home.joinpath(".config", "trojan")
    profile_root = trojan_xdg.joinpath("configs")
    trojan_unit_source = trojan_xdg.joinpath("trojan@.service")
    trojan_unit_target = home.joinpath(".config", "systemd", "user", "trojan@.service")

    @classmethod
    def profiles(cls):
        root = cls.profile_root
        if not root.exists():
            raise SystemExit("directory that stores trojan profiles did not exist; {}".format(root))

        return [file.name for file in root.iterdir()]

    @classmethod
    def active_trojan_service(cls) -> T.Optional[Unit]:
        units = cls.list_units("--user", "--state=active", "trojan@*")

        if len(units) == 0:
            return None

        assert len(units) == 1, units
        return units[0]

    @staticmethod
    def list_units(*extra_args) -> T.List[Unit]:
        """base on `systemctl list-units --all`

        :return: [(unit, load, active, sub, description)]
        """

        def _units(raw: bytes):
            lines = raw.decode().strip().splitlines(keepends=False)

            assert lines[-2].endswith("loaded units listed.")

            if lines[-2] == "0 loaded units listed.":
                return

            assert lines[0].startswith("UNIT")

            for _line in lines[1:]:
                if _line == "":
                    break
                yield _line.strip()

        def _columns(line: str) -> Unit:
            """
            :return: (unit, load, active, sub, description)
            """

            dirty = "●\r\n\t "

            return Unit(*re.split(r"\s+", line.strip(dirty), maxsplit=5 - 1))

        command = ["systemctl", "list-units", "--all"]
        command.extend(extra_args)

        cp = subprocess.run(command, check=True, stdout=subprocess.PIPE)

        return [_columns(unit) for unit in _units(cp.stdout)]


def make_choice(choices: T.Iterable):
    command = ["fzf", "--no-multi"]
    input = "\n".join(choices).encode()

    try:
        cp = subprocess.run(command, input=input, stdout=subprocess.PIPE, check=True)
    except subprocess.CalledProcessError as e:
        raise SystemExit(repr(e))
    else:
        return cp.stdout.strip().decode()


class Ops:
    @staticmethod
    def status():
        units = Facts.list_units("--user", "trojan@*")
        for unit in units:
            print(" ".join(unit[:-1]))

    @staticmethod
    def ping():
        command = ["curl", "--show-error", "--head", "--connect-timeout", "10", "https://google.com"]
        env = {
            "http_proxy": "http://127.0.0.1:8118",
            "https_proxy": "http://127.0.0.1:8118",
        }

        logging.info("gonna ping google")
        subprocess.run(command, check=True, env=env)

    @classmethod
    def start(cls):
        unit = Facts.active_trojan_service()
        if unit:
            return

        profiles = Facts.profiles()
        if not profiles:
            raise SystemExit("no profile found")

        try:
            Facts.trojan_unit_source.symlink_to(Facts.trojan_unit_target)
        except FileExistsError:
            pass

        profile = make_choice(profiles)
        logging.info("chose profile: %s", profile)

        unit = "trojan@{}".format(profile)

        command = ["systemctl", "--user", "start", unit]
        subprocess.run(command, check=True)

    @classmethod
    def stop(cls, unit: T.Optional[Unit] = None):
        if unit is None:
            unit = Facts.active_trojan_service()
        if not unit:
            return

        command = ["systemctl", "--user", "stop", unit.unit]
        subprocess.run(command, check=True)


class Cmds:
    @staticmethod
    def start(force):
        if force:
            Ops.stop()
        Ops.start()
        time.sleep(1)  # service starting takes time
        Ops.ping()

    @staticmethod
    def status():
        Ops.status()
        Ops.ping()


def _parse_args(args=None):
    par = argparse.ArgumentParser()
    subpar = par.add_subparsers(dest="op")
    subpar.add_parser("status")
    subpar.add_parser("stop")

    start = subpar.add_parser("start")
    start.add_argument("-f", "--force", action="store_true", help="start forcely, close the running one")

    subpar.add_parser("s", help="alias of start -f")

    return par.parse_args(args)


def main():
    args = _parse_args()

    ophandlers = {
        "start": lambda: Cmds.start(args.force),
        "stop": Ops.stop,
        "status": Cmds.status,
        # shortcuts
        "s": lambda: Cmds.start(True),
    }

    op = args.op
    if op is None:
        op = "status"

    ophandlers[op]()


if __name__ == "__main__":
    logging.basicConfig(
        level="INFO",
        style="{",
        datefmt="\x1b[34m%H:%M:%S\x1b[39m",
        format="{asctime} {message}",
    )

    main()

# vim: ft=python :
