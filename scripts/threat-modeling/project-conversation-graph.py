#!/usr/bin/env python3
"""Project normalized facts to a graph without generative reinterpretation."""

from __future__ import annotations

import argparse
import json
import pathlib


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    facts = json.loads(arguments.facts.read_text(encoding="utf-8"))
    graph = {
        "posture": facts["posture"],
        "nodes": [
            {
                "id": item["id"],
                "name": item["name"],
                "kind": item["kind"],
                "evidence": item["evidence"],
                "evidence_missing": item["evidence_missing"],
                "evidence_span": item["evidence_span"],
            }
            for item in facts["entities"]
        ],
        "flows": [
            {
                "id": item["id"],
                "source": item["subject"],
                "target": item["object"],
                "predicate": item["predicate"],
                "data": item["data"],
                "protocol": item["protocol"],
                "authentication": item["authentication"],
                "certainty": item["certainty"],
                "evidence": item["evidence"],
                "evidence_missing": item["evidence_missing"],
                "evidence_span": item["evidence_span"],
            }
            for item in facts["relations"]
        ],
        "uncertainties": [
            {
                key: item[key]
                for key in (
                    "id",
                    "subject",
                    "property",
                    "state",
                    "evidence",
                    "evidence_missing",
                    "evidence_span",
                )
            }
            for item in facts["uncertainties"]
        ],
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(graph, indent=2) + "\n", encoding="utf-8")
    print(
        f"[debug] projected {len(graph['nodes'])} nodes and "
        f"{len(graph['flows'])} flows without generative conversion"
    )


if __name__ == "__main__":
    main()
