#!/usr/bin/env python3


import argparse
import pathlib
import re
import subprocess
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

        assert len(units) == 1
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
            bounds = slice(1, -6)
            assert lines[-6] == ""
            assert lines[-5].startswith("LOAD")
            assert lines[-4].startswith("ACTIVE")
            assert lines[-3].startswith("SUB")

            for _line in lines[bounds]:
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


class Commands:
    @staticmethod
    def status():
        units = Facts.list_units("--user", "trojan@*")
        for unit in units:
            print(" ".join(unit[:-1]))

    @staticmethod
    def ping():
        command = ["curl", "-SI", "https://google.com"]
        env = {
            "http_proxy": "http://127.0.0.1:8118",
            "https_proxy": "http://127.0.0.1:8118",
        }

        subprocess.run(command, check=True, env=env)

    @classmethod
    def start(cls, force: bool):
        cls._prestart(force)

        profiles = Facts.profiles()
        if not profiles:
            raise SystemExit("no profile found")

        try:
            Facts.trojan_unit_source.symlink_to(Facts.trojan_unit_target)
        except FileExistsError:
            pass

        profile = cls._make_choice(profiles)
        unit = "trojan@{}".format(profile)

        command = ["systemctl", "--user", "start", unit]
        subprocess.run(command, check=True)

    @staticmethod
    def _make_choice(choices: T.Iterable):
        command = ["fzf", "--no-multi"]
        _input = "\n".join(choices).encode()

        cp = subprocess.run(command, input=_input, stdout=subprocess.PIPE, check=True)

        return cp.stdout.strip().decode()

    @classmethod
    def _prestart(cls, force: bool):
        unit = Facts.active_trojan_service()

        if not unit:
            return

        if force:
            cls._stop(unit.unit)
        else:
            raise SystemExit("there is one active trojan service already; {}".format(unit))

    @staticmethod
    def restart():
        unit = Facts.active_trojan_service()
        if not unit:
            raise SystemExit("there is no active trojan service")

        command = ["systemctl", "--user", "restart", unit.unit]
        subprocess.run(command, check=True)

    @classmethod
    def stop(cls):
        unit = Facts.active_trojan_service()
        if not unit:
            return

        cls._stop(unit.unit)

    @staticmethod
    def _stop(*services: str):
        command = ["systemctl", "--user", "stop"]
        command.extend(services)
        subprocess.run(command, check=True)


def _parse_args(args=None):
    par = argparse.ArgumentParser()
    subpar = par.add_subparsers(dest="op")
    subpar.add_parser("restart")
    subpar.add_parser("status")
    subpar.add_parser("stop")

    start = subpar.add_parser("start")
    start.add_argument("-f", "--force", action="store_true", help="start forcely, close the running one")

    subpar.add_parser("ping")

    subpar.add_parser("s", help="alias of start -f")

    return par.parse_args(args)


def main():
    args = _parse_args()

    ophandlers = {
        "start": lambda: Commands.start(args.force),
        "stop": Commands.stop,
        "status": Commands.status,
        "restart": Commands.restart,
        "ping": Commands.ping,
        # shortcuts
        "s": lambda: Commands.start(True),
    }

    try:
        handler = ophandlers[args.op]
    except KeyError:
        if Facts.active_trojan_service():
            Commands.status()
            Commands.ping()
        else:
            Commands.start(False)
    else:
        handler()


if __name__ == "__main__":
    main()
