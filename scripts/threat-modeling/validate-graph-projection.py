#!/usr/bin/env python3
"""Reject a graph projection that changes reviewed normalized facts."""

from __future__ import annotations

import argparse
import json
import pathlib


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def keyed(items: list[dict[str, object]], name: str) -> dict[str, dict[str, object]]:
    result = {str(item["id"]): item for item in items}
    if len(result) != len(items):
        fail(f"duplicate {name} IDs")
    return result


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts", type=pathlib.Path, required=True)
    parser.add_argument("--graph", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    facts = json.loads(arguments.facts.read_text(encoding="utf-8"))
    graph = json.loads(arguments.graph.read_text(encoding="utf-8"))
    expected_nodes = {
        item["id"]: {
            "id": item["id"],
            "name": item["name"],
            "kind": item["kind"],
            "evidence": item["evidence"],
            "evidence_missing": item["evidence_missing"],
            "evidence_span": item["evidence_span"],
        }
        for item in facts["entities"]
    }
    if keyed(graph["nodes"], "node") != expected_nodes:
        fail("graph changed normalized node identity, kind, evidence, or coverage")

    expected_flows = {
        item["id"]: {
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
    }
    actual_flows = keyed(graph["flows"], "flow")
    if actual_flows != expected_flows:
        for flow_id, expected in expected_flows.items():
            if actual_flows.get(flow_id) != expected:
                fail(
                    f"graph changed normalized relation {flow_id}: "
                    f"expected {expected}, got {actual_flows.get(flow_id)}"
                )
        fail("graph changed normalized relation coverage")

    expected_uncertainties = {
        item["id"]: {
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
    }
    if keyed(graph["uncertainties"], "uncertainty") != expected_uncertainties:
        fail("graph changed normalized uncertainty semantics or coverage")
    print("[debug] graph is an exact deterministic projection of normalized facts")


if __name__ == "__main__":
    main()
