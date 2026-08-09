#!/usr/bin/env python3
"""Validate the conversation-to-atomic-facts and formal-system contracts."""

from __future__ import annotations

import argparse
import json
import pathlib
import re


EXPECTED_ENTITIES = {
    "actor-customer",
    "cmp-analytics-job",
    "cmp-app-backend",
    "cmp-cicd-pipeline",
    "cmp-cloudfront",
    "cmp-deploy-role",
    "cmp-s3-bucket",
}
EXPECTED_RELATIONS = {f"rel-current-{number:02d}" for number in range(1, 11)}


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts", type=pathlib.Path, required=True)
    parser.add_argument("--system", type=pathlib.Path, required=True)
    parser.add_argument("--rules", type=pathlib.Path, required=True)
    parser.add_argument("--source", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    facts = json.loads(arguments.facts.read_text(encoding="utf-8"))
    system = json.loads(arguments.system.read_text(encoding="utf-8"))
    rules = json.loads(arguments.rules.read_text(encoding="utf-8"))
    source_text = arguments.source.read_text(encoding="utf-8")
    section_start = source_text.index(rules["section_start"])
    section_end = source_text.index(rules["section_end"], section_start)
    transcript = source_text[section_start:section_end]
    if facts.get("evidence_scope") != {
        "start_marker": rules["section_start"],
        "end_marker": rules["section_end"],
        "offset_basis": "raw Unicode codepoint offsets in the scoped transcript",
    }:
        fail("evidence scope metadata changed")
    source = re.sub(
        r"\s+", " ", arguments.source.read_text(encoding="utf-8")
    ).strip()
    entity_ids = {entity["id"] for entity in facts["entities"]}
    if entity_ids != EXPECTED_ENTITIES:
        fail(f"entity coverage drift: {sorted(entity_ids)}")
    participant_names = {"priya", "diego", "amara", "sam", "jordan"}
    if any(entity["name"].casefold() in participant_names for entity in facts["entities"]):
        fail("workshop participant leaked into the deployed-system graph")
    relation_ids = {relation["id"] for relation in facts["relations"]}
    if relation_ids != EXPECTED_RELATIONS:
        fail(f"relation coverage drift: {sorted(relation_ids)}")
    relation_04 = next(item for item in facts["relations"] if item["id"] == "rel-current-04")
    attribute_01 = next(item for item in facts["attributes"] if item["id"] == "attr-current-01")
    if relation_04["evidence"] != "Customers upload avatars":
        fail("rel-current-04 is not an atomic upload assertion")
    if attribute_01["evidence"] != "same bucket, different prefix.":
        fail("attr-current-01 was not separated from the upload assertion")

    for relation in facts["relations"]:
        if relation["subject"] not in entity_ids or relation["object"] not in entity_ids:
            fail(f"unknown endpoint in {relation['id']}")
        if relation["subject"] == relation["object"]:
            fail(f"self-loop produced by {relation['id']}")
        expected = " | ".join(
            part.casefold().replace(" ", "-")
            for part in (
                relation["subject"],
                relation["predicate"],
                relation["object"],
                relation["data"],
            )
        )
        if relation["embedding_text"] != expected:
            fail(f"non-canonical embedding text in {relation['id']}")

    if any("profile-picture" in entity_id for entity_id in entity_ids):
        fail("a bucket prefix was incorrectly promoted to a component")
    if facts["normalization_contract"] != {
        "participants_are_graph_nodes": False,
        "relations_are_atomic": True,
        "unverified_is_implemented": False,
        "aliases_resolve_before_embeddings": True,
    }:
        fail("normalization contract changed")
    states = {item["state"] for item in facts["uncertainties"]}
    if states != {"unknown", "unverified", "confirmed-absent"}:
        fail(f"uncertainty states changed: {sorted(states)}")

    for item in [
        *facts["entities"],
        *facts["relations"],
        *facts["attributes"],
        *facts["uncertainties"],
    ]:
        evidence = item["evidence"]
        if evidence is None:
            if item["evidence_missing"] is not True:
                fail(f"null evidence was not flagged for {item['id']}")
            continue
        if item["evidence_missing"] is not False:
            fail(f"present evidence was flagged missing for {item['id']}")
        if len(evidence.split()) > system["evidence_contract"]["maximum_words"]:
            fail(f"evidence exceeds 25 words for {item['id']}")
        if re.sub(r"\s+", " ", evidence).strip() not in source:
            fail(f"evidence is not an exact source substring for {item['id']}")
        span = item.get("evidence_span")
        if not isinstance(span, dict) or set(span) != {
            "start",
            "end",
            "text",
            "context",
            "mentions",
        }:
            fail(f"evidence span shape changed for {item['id']}")
        if not isinstance(span["start"], int) or not isinstance(span["end"], int):
            fail(f"evidence span offsets are not integers for {item['id']}")
        if not 0 <= span["start"] < span["end"] <= len(transcript):
            fail(f"evidence span offsets are out of range for {item['id']}")
        if transcript[span["start"] : span["end"]] != span["text"]:
            fail(f"evidence span text does not match offsets for {item['id']}")
        if re.sub(r"\s+", " ", span["text"]).strip() != re.sub(
            r"\s+", " ", evidence
        ).strip():
            fail(f"evidence span text differs from evidence for {item['id']}")
        if re.search(r"(?:Priya|Diego|Amara|Sam|Jordan):", span["context"]):
            fail(f"speaker label leaked into evidence context for {item['id']}")
        if not span["mentions"] or any(
            mention not in entity_ids for mention in span["mentions"]
        ):
            fail(f"evidence span mentions are not resolved for {item['id']}")
    for item in [
        *facts["entities"],
        *facts["relations"],
        *facts["attributes"],
        *facts["uncertainties"],
    ]:
        if item["evidence"] is None and item["evidence_span"] is not None:
            fail(f"missing evidence unexpectedly has a span for {item['id']}")

    if facts["formal_system"] != {
        "id": system["system_id"],
        "schema_version": system["schema_version"],
        "completeness_property": system["completeness_property"],
    }:
        fail("normalized facts do not bind to the validated formal system")
    print(
        "[debug] conversation normalization preserves 7 entities, 10 atomic "
        "relations, exact evidence, simple embedding text, and a complete "
        "fail-closed formal-system binding"
    )


if __name__ == "__main__":
    main()
