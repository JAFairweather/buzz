#!/usr/bin/env python3
"""Check the review deadline for q-172 cargo-deny exceptions."""

import argparse
import datetime as dt
import pathlib
import re
import tomllib


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--today", type=dt.date.fromisoformat, default=dt.date.today())
    args = parser.parse_args()

    policy = pathlib.Path(__file__).resolve().parent.parent / "deny.toml"
    ignores = tomllib.loads(policy.read_text())["advisories"]["ignore"]
    errors = []
    for entry in ignores:
        reason = entry.get("reason", "")
        if "q-172" not in reason:
            continue
        match = re.search(r"\bexpires=(\d{4}-\d{2}-\d{2})\b", reason)
        if match is None:
            errors.append(f"{entry['id']}: missing q-172 expiry")
            continue
        expires = dt.date.fromisoformat(match.group(1))
        if args.today > expires:
            errors.append(f"{entry['id']}: expired on {expires}")

    if errors:
        for error in errors:
            print(error)
        return 1
    print("q-172 cargo-deny exceptions are within their review window")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
