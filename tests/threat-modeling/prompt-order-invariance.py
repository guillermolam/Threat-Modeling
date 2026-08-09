#!/usr/bin/env python3
"""Property test: prompt rendering must be invariant under source reordering.

Contract: the slot-selection prompt is a function of the SET of known entities
and the SET of predicate contracts. Reordering `entities` in
current-state.normalized.json, or reordering `predicate_contracts` in
formal-system.json, is semantically null and must not change a single byte of
the prompt -- and therefore must not change an admission outcome.

This is a regression test for an observed violation: with the source order
reversed, the live corpus flipped rel-current-05 from accepted to slot-mismatch.
"""

from __future__ import annotations

import importlib.util
import json
import pathlib
import sys


ROOT = pathlib.Path(__file__).resolve().parents[2]
TM = ROOT / "Examples/S3/threat-modeling"


def load_inference_module():
    path = ROOT / "scripts/threat-modeling/run-closed-set-inference.py"
    spec = importlib.util.spec_from_file_location("closed_set_inference", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def main() -> None:
    inference = load_inference_module()
    facts = json.loads(
        (TM / "conversation/current-state.normalized.json").read_text(encoding="utf-8")
    )
    formal_system = json.loads((TM / "formal-system.json").read_text(encoding="utf-8"))
    predicates = formal_system["predicate_contracts"]
    entity_list = facts["entities"]
    relation = facts["relations"][0]
    context = relation["evidence_span"]["context"]

    def prompt_for(entities_in_order, predicates_in_order):
        entities = {item["id"]: item for item in entities_in_order}
        return inference.build_slot_prompt(
            relation["id"],
            relation["evidence"],
            entities,
            predicates_in_order,
            context,
        )

    baseline = prompt_for(entity_list, predicates)

    reversed_entities = prompt_for(list(reversed(entity_list)), predicates)
    if reversed_entities != baseline:
        fail(
            "prompt changed when the entity list was reversed; admission outcomes "
            "depend on source file ordering"
        )

    rotated_entities = prompt_for(entity_list[3:] + entity_list[:3], predicates)
    if rotated_entities != baseline:
        fail("prompt changed when the entity list was rotated")

    reversed_predicates = prompt_for(
        entity_list, dict(reversed(list(predicates.items())))
    )
    if reversed_predicates != baseline:
        fail(
            "prompt changed when predicate_contracts were reversed; admission "
            "outcomes depend on formal-system.json key ordering"
        )

    # The registry exposes the symbol table, but never reviewed answer fields.
    registry_line = next(
        line for line in baseline.splitlines() if line.startswith("Known entities: ")
    )
    registry = json.loads(registry_line[len("Known entities: ") :])
    if [item["id"] for item in registry] != sorted(item["id"] for item in registry):
        fail("known-entity registry is not emitted in sorted id order")
    for item in registry:
        if set(item) != {"id", "name", "kind", "aliases"}:
            fail(f"registry entry exposes unexpected fields: {sorted(item)}")
        if item["aliases"] != sorted(item["aliases"]):
            fail(f"aliases are not sorted for {item['id']}")
    if f"Context: {context}" not in baseline:
        fail("speaker-free evidence context was not included in the slot prompt")
    for participant in ("Priya:", "Diego:", "Amara:", "Sam:", "Jordan:"):
        if participant in baseline:
            fail(f"speaker label leaked into the slot prompt: {participant}")

    print(
        f"[debug] slot prompt is invariant under entity and predicate reordering "
        f"across {len(registry)} entities and {len(predicates)} predicates"
    )


if __name__ == "__main__":
    main()
