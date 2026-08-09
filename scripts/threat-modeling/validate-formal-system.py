#!/usr/bin/env python3
"""Validate the executable threat-modeling vocabulary and completeness rules."""

from __future__ import annotations

import argparse
import json
import pathlib
from typing import Any


REQUIRED_ENTITY_TYPES = {
    "actor",
    "external-entity",
    "process",
    "datastore",
    "container",
    "interface",
    "security-service",
    "block",
    "trust-boundary",
}
REQUIRED_RELATIONSHIPS = {
    "directed-flow",
    "bidirectional-flow",
    "initiates",
    "contains",
    "crosses-trust-boundary",
}
REQUIRED_CERTAINTY_STATES = {
    "confirmed",
    "confirmed-absent",
    "unknown",
    "unverified",
    "contradictory",
    "not-applicable",
}
REQUIRED_COMPLETENESS_RULES = {
    *{f"IC-{number:03d}" for number in range(1, 5)},
    *{f"DF-{number:03d}" for number in range(1, 5)},
    *{f"CF-{number:03d}" for number in range(1, 5)},
    *{f"TB-{number:03d}" for number in range(1, 5)},
    *{f"DS-{number:03d}" for number in range(1, 4)},
    *{f"XV-{number:03d}" for number in range(1, 4)},
    "QG-001",
}
REQUIRED_REVIEW_REASONS = {
    "evidence-missing",
    "classification-nonreproducible",
    "classification-mismatch",
    "slots-nonreproducible",
    "unresolved-entity",
    "direction-contract",
    "slot-mismatch",
    "schema-invalid",
    "reference-invalid",
    "completeness-gap",
}


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def exact_keys(actual: Any, expected: set[str], label: str) -> None:
    if not isinstance(actual, dict) or set(actual) != expected:
        fail(f"{label} vocabulary drift: {sorted(actual) if isinstance(actual, dict) else actual}")
    if any(not isinstance(value, str) or not value.strip() for value in actual.values()):
        fail(f"{label} contains an empty definition")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--system", type=pathlib.Path, required=True)
    parser.add_argument("--rules", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    system: dict[str, Any] = json.loads(arguments.system.read_text(encoding="utf-8"))
    rules: dict[str, Any] = json.loads(arguments.rules.read_text(encoding="utf-8"))
    if rules.get("formal_system") != arguments.system.name:
        fail("normalization rules do not reference the validated formal system")
    if system.get("scope", {}).get("closed_world") is not False:
        fail("the source universe must remain explicitly open-world")
    if not system.get("completeness_property"):
        fail("formal system has no declared completeness property")

    exact_keys(system.get("atomic_fact_classes"), {"relation", "attribute", "uncertainty"}, "atomic fact")
    exact_keys(system.get("entity_types"), REQUIRED_ENTITY_TYPES, "entity type")
    exact_keys(system.get("relationship_types"), REQUIRED_RELATIONSHIPS, "relationship")
    exact_keys(system.get("certainty_states"), REQUIRED_CERTAINTY_STATES, "certainty state")

    evidence = system.get("evidence_contract", {})
    if evidence != {
        "maximum_words": 25,
        "exact_normalized_substring": True,
        "span_offsets": "codepoint offsets into the scoped transcript section",
        "context_required": True,
        "resolved_mentions_required": True,
        "missing_evidence_outcome": "review_queue",
        "speaker_names_are_entities": False,
    }:
        fail("evidence contract is not fail-closed")

    completeness = system.get("completeness_rules", [])
    completeness_ids = [item.get("id") for item in completeness]
    if len(completeness_ids) != len(set(completeness_ids)):
        fail("duplicate completeness rule IDs")
    if set(completeness_ids) != REQUIRED_COMPLETENESS_RULES:
        fail(f"completeness rule coverage drift: {sorted(completeness_ids)}")
    for item in completeness:
        if not all(item.get(key) for key in ("category", "obligation", "failure_state")):
            fail(f"incomplete completeness definition: {item.get('id')}")

    entity_types = set(system["entity_types"])
    predicates = system.get("predicate_contracts", {})
    if not predicates:
        fail("predicate vocabulary is empty")
    for predicate, contract in predicates.items():
        for endpoint in ("subject_kinds", "object_kinds"):
            kinds = contract.get(endpoint)
            if not kinds or not set(kinds) <= entity_types:
                fail(f"invalid {endpoint} for predicate {predicate}")

    aliases = {item["id"]: item for item in rules.get("aliases", [])}
    if len(aliases) != len(rules.get("aliases", [])):
        fail("duplicate alias IDs")
    participant_names = {name.casefold() for name in rules.get("participants", [])}
    for entity in aliases.values():
        if entity["kind"] not in entity_types:
            fail(f"alias uses undefined entity type: {entity['id']}")
        if entity["name"].casefold() in participant_names:
            fail(f"participant leaked into alias registry: {entity['name']}")
    for relation in rules.get("relations", []):
        predicate = relation.get("predicate")
        if predicate not in predicates:
            fail(f"relation uses undefined predicate: {relation.get('id')}")
        if relation.get("subject") not in aliases or relation.get("object") not in aliases:
            fail(f"relation has an unresolved endpoint: {relation.get('id')}")
        contract = predicates[predicate]
        if aliases[relation["subject"]]["kind"] not in contract["subject_kinds"]:
            fail(f"relation violates subject contract: {relation['id']}")
        if aliases[relation["object"]]["kind"] not in contract["object_kinds"]:
            fail(f"relation violates object contract: {relation['id']}")

    admission = system.get("admission", {})
    if admission.get("outcomes") != ["accepted", "review_queue"]:
        fail("admission outcomes are not exhaustive and fail-closed")
    if set(admission.get("review_reasons", [])) != REQUIRED_REVIEW_REASONS:
        fail("review-reason vocabulary drift")
    if admission.get("silent_drop_allowed") is not False:
        fail("formal system permits silent drops")
    if admission.get("automatic_repair_allowed") is not False:
        fail("formal system permits automatic semantic repair")

    print(
        "[debug] formal system defines 9 entity types, 5 relationship types, "
        "23 completeness obligations, and exhaustive fail-closed outcomes"
    )


if __name__ == "__main__":
    main()
