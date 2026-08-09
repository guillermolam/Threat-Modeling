#!/usr/bin/env python3
"""Convert a workshop transcript into reviewed atomic graph facts."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import re
from typing import Any


SPEAKER_LINE = re.compile(r"^>\s+\*\*(?P<speaker>[^:*]+):\*\*\s*(?P<text>.*)$")


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def section(text: str, start: str, end: str) -> str:
    start_index = text.find(start)
    end_index = text.find(end, start_index + len(start))
    if start_index < 0 or end_index < 0:
        fail(f"could not find transcript boundaries {start!r} and {end!r}")
    return text[start_index:end_index]


def utterances(text: str, participants: set[str]) -> list[dict[str, str]]:
    records: list[dict[str, str]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        match = SPEAKER_LINE.match(line)
        if not match:
            continue
        speaker = match.group("speaker").strip()
        if speaker not in participants:
            fail(f"unreviewed workshop participant: {speaker}")
        content = re.sub(r"\*\([^)]*\)\*", "", match.group("text")).strip()
        records.append({"line": str(line_number), "text": content})
    if not records:
        fail("transcript contains no recognized speaker utterances")
    return records


def normalized(value: str) -> str:
    return re.sub(r"\s+", " ", value.casefold().replace("’", "'")).strip()


def normalized_whitespace(value: str) -> str:
    return re.sub(r"\s+", " ", value).strip()


def evidence_match(fragment: str, transcript: str) -> re.Match[str] | None:
    """Find a fragment while preserving its raw transcript offsets."""
    pattern = re.escape(fragment)
    pattern = re.sub(r"\\ +", r"\\s+", pattern)
    return re.search(pattern, transcript)


def evidence_context(fragment: str, records: list[dict[str, str]]) -> str:
    needle = normalized(fragment)
    record = next(
        (item for item in records if needle in normalized(item["text"])), None
    )
    if record is None:
        fail(f"evidence fragment has no speaker-free context: {fragment!r}")
    return record["text"]


def exact_evidence(
    item_id: str,
    rules: dict[str, Any],
    transcript: str,
    records: list[dict[str, str]],
    maximum_words: int,
) -> tuple[str | None, bool, dict[str, Any] | None]:
    fragments = rules["evidence_fragments"]
    if item_id not in fragments:
        fail(f"missing reviewed evidence fragment for {item_id}")
    fragment = fragments[item_id]
    if fragment is None:
        return None, True, None
    if len(fragment.split()) > maximum_words:
        fail(f"evidence for {item_id} exceeds {maximum_words} words")
    match = evidence_match(fragment, transcript)
    if match is None:
        fail(f"evidence for {item_id} is not an exact transcript substring")
    raw_text = match.group(0)
    return (
        fragment,
        False,
        {
            "start": match.start(),
            "end": match.end(),
            "text": raw_text,
            "context": evidence_context(fragment, records),
        },
    )


def matching_evidence(
    phrases: list[str], records: list[dict[str, str]]
) -> list[dict[str, str]]:
    evidence: list[dict[str, str]] = []
    for phrase in phrases:
        needle = normalized(phrase)
        match = next(
            (record for record in records if needle in normalized(record["text"])), None
        )
        if match is None:
            fail(f"normalization phrase has no transcript evidence: {phrase!r}")
        if match not in evidence:
            evidence.append(match)
    return evidence


def alias_evidence(
    phrases: list[str], records: list[dict[str, str]]
) -> list[dict[str, str]]:
    evidence = [
        record
        for record in records
        if any(normalized(phrase) in normalized(record["text"]) for phrase in phrases)
    ]
    if not evidence:
        fail(f"entity aliases have no transcript evidence: {phrases!r}")
    return evidence


def embedding_text(parts: list[str]) -> str:
    return " | ".join(normalized(part).replace(" ", "-") for part in parts)


def convert(
    rules: dict[str, Any], formal_system: dict[str, Any], source_text: str
) -> dict[str, Any]:
    transcript = section(source_text, rules["section_start"], rules["section_end"])
    records = utterances(transcript, set(rules["participants"]))
    entity_types = set(formal_system["entity_types"])
    predicate_contracts = formal_system["predicate_contracts"]
    certainty_states = set(formal_system["certainty_states"])
    maximum_words = formal_system["evidence_contract"]["maximum_words"]

    entities: list[dict[str, Any]] = []
    entity_ids: set[str] = set()
    entity_kinds: dict[str, str] = {}
    for alias in rules["aliases"]:
        if alias["id"] in entity_ids:
            fail(f"duplicate entity ID: {alias['id']}")
        if alias["kind"] not in entity_types:
            fail(f"unknown entity type for {alias['id']}: {alias['kind']}")
        alias_evidence(alias["phrases"], records)
        evidence, evidence_missing, evidence_span = exact_evidence(
            alias["id"], rules, transcript, records, maximum_words
        )
        if evidence_span is not None:
            evidence_span["mentions"] = [alias["id"]]
        entity_ids.add(alias["id"])
        entity_kinds[alias["id"]] = alias["kind"]
        entities.append(
            {
                "id": alias["id"],
                "name": alias["name"],
                "kind": alias["kind"],
                "aliases": alias["phrases"],
                "embedding_text": embedding_text(
                    [alias["kind"], alias["id"], alias["name"]]
                ),
                "evidence": evidence,
                "evidence_missing": evidence_missing,
                "evidence_span": evidence_span,
            }
        )

    facts: dict[str, list[dict[str, Any]]] = {
        "relations": [],
        "attributes": [],
        "uncertainties": [],
    }
    seen_fact_ids: set[str] = set()
    for collection in facts:
        for rule in rules[collection]:
            if rule["id"] in seen_fact_ids:
                fail(f"duplicate fact ID: {rule['id']}")
            seen_fact_ids.add(rule["id"])
            matching_evidence(rule["contains_all"], records)
            evidence, evidence_missing, evidence_span = exact_evidence(
                rule["id"], rules, transcript, records, maximum_words
            )
            fact = {key: value for key, value in rule.items() if key != "contains_all"}
            for endpoint in ("subject", "object"):
                if endpoint in fact and fact[endpoint] not in entity_ids:
                    fail(f"{rule['id']} references unknown {endpoint}: {fact[endpoint]}")
            if collection == "relations":
                if fact["predicate"] not in predicate_contracts:
                    fail(
                        f"{rule['id']} uses unknown predicate: {fact['predicate']}"
                    )
                contract = predicate_contracts[fact["predicate"]]
                if entity_kinds[fact["subject"]] not in contract["subject_kinds"]:
                    fail(f"{rule['id']} has an invalid subject kind")
                if entity_kinds[fact["object"]] not in contract["object_kinds"]:
                    fail(f"{rule['id']} has an invalid object kind")
                if fact["certainty"] not in certainty_states:
                    fail(f"{rule['id']} uses an unknown certainty state")
                fact["embedding_text"] = embedding_text(
                    [fact["subject"], fact["predicate"], fact["object"], fact["data"]]
                )
            if collection == "uncertainties" and fact["state"] not in certainty_states:
                fail(f"{rule['id']} uses an unknown uncertainty state")
            fact["evidence"] = evidence
            fact["evidence_missing"] = evidence_missing
            fact["evidence_span"] = evidence_span
            if evidence_span is not None:
                evidence_span["mentions"] = [
                    fact[key] for key in ("subject", "object") if key in fact
                ]
            facts[collection].append(fact)

    return {
        "schema_version": rules["schema_version"],
        "formal_system": {
            "id": formal_system["system_id"],
            "schema_version": formal_system["schema_version"],
            "completeness_property": formal_system["completeness_property"],
        },
        "posture": "current-state",
        "source_sha256": hashlib.sha256(source_text.encode()).hexdigest(),
        "evidence_scope": {
            "start_marker": rules["section_start"],
            "end_marker": rules["section_end"],
            "offset_basis": "raw Unicode codepoint offsets in the scoped transcript",
        },
        "normalization_contract": {
            "participants_are_graph_nodes": False,
            "relations_are_atomic": True,
            "unverified_is_implemented": False,
            "aliases_resolve_before_embeddings": True,
        },
        "entities": entities,
        **facts,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--rules", type=pathlib.Path, required=True)
    parser.add_argument("--source", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    rules = json.loads(arguments.rules.read_text(encoding="utf-8"))
    formal_system_path = arguments.rules.parent / rules["formal_system"]
    formal_system = json.loads(formal_system_path.read_text(encoding="utf-8"))
    source_text = arguments.source.read_text(encoding="utf-8")
    output = convert(rules, formal_system, source_text)
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(output, indent=2) + "\n", encoding="utf-8")
    print(
        "[debug] normalized "
        f"{len(output['entities'])} entities, {len(output['relations'])} relations, "
        f"{len(output['attributes'])} attributes, and "
        f"{len(output['uncertainties'])} uncertainties"
    )


if __name__ == "__main__":
    main()
