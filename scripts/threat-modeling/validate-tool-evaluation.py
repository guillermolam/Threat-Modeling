#!/usr/bin/env python3
"""Validate the offline AI/tool adapter decision record."""

from __future__ import annotations

import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
EVALUATION = ROOT / "Examples/S3/threat-modeling/tool-evaluation.json"
VERSIONS = ROOT / "config/tool-versions.env"
ALLOWED_DISPOSITIONS = {"candidate", "accepted", "blocked", "rejected", "prohibited"}


def fail(message: str) -> None:
    print(f"[error] {message}", file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    data = json.loads(EVALUATION.read_text(encoding="utf-8"))
    if data.get("schema_version") != "1.0.0":
        fail("unsupported tool-evaluation schema")
    if data.get("promotion_policy", {}).get("automatic_promotion") is not False:
        fail("AI output must never be promoted automatically")

    candidates = data.get("candidates")
    if not isinstance(candidates, list) or not candidates:
        fail("candidate list is empty")

    identifiers: set[str] = set()
    for candidate in candidates:
        missing = {
            key
            for key in ("id", "kind", "source", "revision", "roles", "disposition", "rationale")
            if key not in candidate
        }
        if missing:
            fail(f"candidate missing fields: {sorted(missing)}")
        identifier = candidate["id"]
        if identifier in identifiers:
            fail(f"duplicate candidate id: {identifier}")
        identifiers.add(identifier)
        if candidate["disposition"] not in ALLOWED_DISPOSITIONS:
            fail(f"invalid disposition for {identifier}: {candidate['disposition']}")
        if not candidate["source"].startswith("https://"):
            fail(f"non-HTTPS source for {identifier}")
        if len(candidate["rationale"].strip()) < 20:
            fail(f"insufficient rationale for {identifier}")

    by_id = {entry["id"]: entry for entry in candidates}
    if by_id.get("zeroclaw-openagen-fork", {}).get("disposition") != "prohibited":
        fail("the impersonating ZeroClaw fork must remain prohibited")
    for model_id in ("ollama-qwen3-0.6b", "ollama-qwen3-1.7b"):
        if by_id.get(model_id, {}).get("disposition") != "rejected":
            fail(f"failed model trial cannot be promoted: {model_id}")

    versions = VERSIONS.read_text(encoding="utf-8")
    for variable in (
        "OLLAMA_QWEN3_06_DIGEST",
        "OLLAMA_QWEN3_17_DIGEST",
        "ZEROCLAW_COMMIT",
        "ZEROSTACK_COMMIT",
    ):
        if f"{variable}=" not in versions:
            fail(f"missing tool pin: {variable}")

    print(f"[debug] validated {len(candidates)} adapter decisions with no automatic promotion")


if __name__ == "__main__":
    main()
