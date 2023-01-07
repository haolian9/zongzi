#!/usr/bin/env python3

# pylint: disable=raise-missing-from

import argparse
import json
import logging
import pathlib
import shutil
import sys


class Filesystem:
    root = pathlib.Path(__file__).resolve().parent
    output_root = root.joinpath("configs")


def _template():
    return {
        "run_type": "client",
        "local_addr": "127.0.0.1",
        "local_port": 1080,
        "remote_addr": "example.com",
        "remote_port": 443,
        "password": ["password1"],
        "log_level": 1,
        "ssl": {
            "verify": True,
            "verify_hostname": True,
            "cert": "",
            "cipher": "ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-AES256-SHA:ECDHE-ECDSA-AES128-SHA:ECDHE-RSA-AES128-SHA:ECDHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA:AES128-SHA:AES256-SHA:DES-CBC3-SHA",
            "cipher_tls13": "TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256:TLS_AES_256_GCM_SHA384",
            "sni": "",
            "alpn": ["h2", "http/1.1"],
            "reuse_session": True,
            "session_ticket": False,
            "curves": "",
        },
        "tcp": {
            "no_delay": True,
            "keep_alive": True,
            "reuse_port": False,
            "fast_open": False,
            "fast_open_qlen": 20,
        },
    }


def _export_profile(defn: dict):
    def reconstruct(defn):
        """
        :raise: KeyError
        """

        config = _template()
        config.update(
            {
                "remote_addr": defn["server"],
                "remote_port": defn["server_port"],
                "password": [defn["password"]],
            }
        )

        return defn["server"], config

    def filename(origin: str):
        return origin.replace("-", "_")

    try:
        server_name, profile = reconstruct(defn)
    except (KeyError, TypeError) as e:
        raise RuntimeError("malformed profile defn") from e

    outroot = Filesystem.output_root
    outfile = outroot.joinpath(filename(server_name))
    with outfile.open("w") as fp:
        json.dump(profile, fp)
        logging.info("dumped %s", outfile.relative_to(outroot))


def _parse_args():
    par = argparse.ArgumentParser()
    par.add_argument("source", type=str, nargs="?", default="gui-config.json")
    par.add_argument("--keep-olds", action="store_true")

    return par.parse_args()


def main():
    args = _parse_args()

    srcfile = args.source

    try:
        if srcfile == "-":
            fp = sys.stdin
        else:
            fp = open(srcfile, "rb")
    except (FileNotFoundError, PermissionError) as e:
        raise SystemError(repr(e))
    else:
        with fp:
            logging.info("loading source %s", fp.name)
            source = json.load(fp)

    outroot = Filesystem.output_root

    if not args.keep_olds:
        logging.info("removed profiles in %s", outroot)
        try:
            shutil.rmtree(outroot)
        except FileNotFoundError:
            pass

    outroot.mkdir(exist_ok=True)

    try:
        nodes = source["configs"]
    except (KeyError, TypeError) as e:
        raise SystemExit(repr(e))

    assert isinstance(nodes, list)

    for node in nodes:
        try:
            _export_profile(node)
        except RuntimeError:
            logging.exception("failed to export profile")
            continue


if __name__ == "__main__":
    logging.basicConfig(
        level="DEBUG",
        style="{",
        datefmt="%Y-%m-%d %H:%M:%S",
        format="{asctime} {message}",
    )
    main()
