#!/usr/bin/env python3
"""Check exact graph coverage in every generated diagram-as-code format."""

from __future__ import annotations

import argparse
import json
import pathlib
import re


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=pathlib.Path, required=True)
    parser.add_argument("--dfd-dir", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    model = json.loads(arguments.model.read_text(encoding="utf-8"))
    for posture_name in ("current-state", "target-state"):
        mermaid_text = (arguments.dfd_dir / f"{posture_name}.mmd").read_text(
            encoding="utf-8"
        )
        if "flowchart LR" not in mermaid_text:
            fail(f"{posture_name} is not a Mermaid LR flowchart")
        stable_ids = list(model["actors"])
        stable_ids.extend(
            unit["component_id"]
            for unit in model["postures"][posture_name]["units"].values()
        )
        stable_ids.extend(
            flow["id"] for flow in model["postures"][posture_name]["flows"]
        )
        for extension in ("mmd", "d2", "puml"):
            text = (arguments.dfd_dir / f"{posture_name}.{extension}").read_text(
                encoding="utf-8"
            )
            for stable_id in stable_ids:
                token = re.compile(
                    rf"(?<![A-Za-z0-9_-]){re.escape(stable_id)}(?![A-Za-z0-9_-])"
                )
                count = len(token.findall(text))
                if count != 1:
                    fail(
                        f"{posture_name}.{extension} contains {stable_id} {count} times; "
                        "expected exactly once"
                    )
        print(
            f"[debug] {posture_name}: exact coverage for {len(stable_ids)} stable "
            "graph IDs in Mermaid, D2, and PlantUML"
        )


if __name__ == "__main__":
    main()
