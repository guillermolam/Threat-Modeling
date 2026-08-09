#!/usr/bin/env python3
"""Run reproducibility-gated, closed-set Ollama judgments on atomic facts."""

from __future__ import annotations

import argparse
import hashlib
import json
import pathlib
import shutil
import urllib.parse
import urllib.request
from typing import Any


MODEL_OPTIONS = {
    "temperature": 0,
    "seed": 20260809,
    "num_ctx": 4096,
    "top_k": 1,
    "top_p": 1,
    "repeat_penalty": 1,
}
CLASSIFICATIONS = ["relation", "attribute", "uncertainty"]
UNRESOLVED_ENTITY = "__unresolved_entity__"


class InvalidModelOutput(ValueError):
    """The server returned JSON that violates the requested closed schema."""


def fail(message: str) -> None:
    raise SystemExit(f"[error] {message}")


def request_json(url: str, payload: dict[str, Any] | None = None) -> dict[str, Any]:
    data = None if payload is None else json.dumps(payload).encode()
    request = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="GET" if payload is None else "POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=180) as response:
            return json.load(response)
    except Exception as error:  # urllib exposes several transport exceptions
        fail(f"Ollama request failed for {url}: {error}")


def choice_schema(values: list[str]) -> dict[str, Any]:
    return {
        "type": "object",
        "additionalProperties": False,
        "required": ["choice"],
        "properties": {"choice": {"type": "string", "enum": values}},
    }


def model_choice(
    endpoint: str,
    model: str,
    system_prompt: str,
    user_prompt: str,
    schema: dict[str, Any],
    num_predict: int,
) -> dict[str, str]:
    payload = {
        "model": model,
        "stream": False,
        "think": False,
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_prompt},
        ],
        "format": schema,
        "options": {**MODEL_OPTIONS, "num_predict": num_predict},
    }
    response = request_json(f"{endpoint}/api/chat", payload)
    try:
        result = json.loads(response["message"]["content"])
    except (KeyError, TypeError, json.JSONDecodeError) as error:
        fail(f"Ollama returned invalid constrained output: {error}")
    if not isinstance(result, dict):
        raise InvalidModelOutput("output is not an object")
    required = set(schema["required"])
    if set(result) != required:
        raise InvalidModelOutput(
            f"output keys {sorted(result)} do not equal {sorted(required)}"
        )
    for key, property_schema in schema["properties"].items():
        if key not in result or not isinstance(result[key], str):
            raise InvalidModelOutput(f"output field {key} is not a string")
        allowed = property_schema.get("enum")
        if allowed is not None and result[key] not in allowed:
            raise InvalidModelOutput(
                f"output field {key} is outside its enum: {result[key]}"
            )
    return result


def build_slot_prompt(
    fact_id: str,
    evidence: str,
    entities: dict[str, Any],
    predicates: dict[str, Any],
    context: str | None = None,
) -> str:
    """Render the slot-selection prompt from the SET of entities and predicates.

    Prompt content must never depend on the order these appear in the source
    file. A semantically null edit -- reversing the `entities` list in
    current-state.normalized.json -- previously changed the rendered prompt and
    flipped rel-current-05 from accepted to slot-mismatch. Sorting here makes
    admission outcomes invariant under source reordering.
    """
    registry = [
        {
            "id": entities[entity_id]["id"],
            "name": entities[entity_id]["name"],
            "kind": entities[entity_id]["kind"],
            "aliases": sorted(entities[entity_id].get("aliases", [])),
        }
        for entity_id in sorted(entities)
    ]
    context_line = f"Context: {context}\n" if context else ""
    return (
        f"Fact ID: {fact_id}\nFragment: {evidence}\n{context_line}"
        f"Known entities: {json.dumps(registry, separators=(',', ':'))}\n"
        "Predicate contracts: "
        f"{json.dumps(predicates, separators=(',', ':'), sort_keys=True)}"
    )


def exact_twice(
    call: Any,
) -> tuple[dict[str, str] | None, list[dict[str, str]], str | None]:
    results: list[dict[str, str]] = []
    for _attempt in range(2):
        try:
            results.append(call())
        except InvalidModelOutput as error:
            results.append({"__schema_error__": str(error)})
    if any("__schema_error__" in result for result in results):
        return None, results, "schema-invalid"
    if results[0] != results[1]:
        return None, results, "nonreproducible"
    return results[0], results, None


def ensure_local_endpoint(endpoint: str) -> str:
    parsed = urllib.parse.urlparse(endpoint)
    if parsed.scheme != "http" or parsed.hostname not in {"127.0.0.1", "localhost"}:
        fail("Ollama endpoint must use HTTP on 127.0.0.1 or localhost")
    if parsed.path not in {"", "/"}:
        fail("Ollama endpoint must not include a path")
    return endpoint.rstrip("/")


def fact_stream(facts: dict[str, Any]) -> list[tuple[str, dict[str, Any]]]:
    return [
        *[("relation", item) for item in facts["relations"]],
        *[("attribute", item) for item in facts["attributes"]],
        *[("uncertainty", item) for item in facts["uncertainties"]],
    ]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--facts", type=pathlib.Path, required=True)
    parser.add_argument("--rules", type=pathlib.Path, required=True)
    parser.add_argument("--classify-prompt", type=pathlib.Path, required=True)
    parser.add_argument("--slots-prompt", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    parser.add_argument("--model", default="qwen3:1.7b")
    parser.add_argument("--expected-digest", required=True)
    parser.add_argument("--expected-binary-sha256")
    parser.add_argument("--endpoint", default="http://127.0.0.1:11434")
    parser.add_argument("--fact-id", action="append", default=[])
    arguments = parser.parse_args()

    endpoint = ensure_local_endpoint(arguments.endpoint)
    ollama_binary = shutil.which("ollama")
    ollama_binary_sha256 = None
    if ollama_binary is not None:
        ollama_binary_sha256 = hashlib.sha256(
            pathlib.Path(ollama_binary).read_bytes()
        ).hexdigest()
    if arguments.expected_binary_sha256:
        if ollama_binary_sha256 is None:
            fail("cannot enforce Ollama binary pin: ollama executable not found")
        if ollama_binary_sha256 != arguments.expected_binary_sha256:
            fail(
                "Ollama binary hash mismatch: expected "
                f"{arguments.expected_binary_sha256}, got {ollama_binary_sha256}"
            )
    facts = json.loads(arguments.facts.read_text(encoding="utf-8"))
    rules = json.loads(arguments.rules.read_text(encoding="utf-8"))
    formal_system = json.loads(
        (arguments.rules.parent / rules["formal_system"]).read_text(encoding="utf-8")
    )
    expected_system = {
        "id": formal_system["system_id"],
        "schema_version": formal_system["schema_version"],
        "completeness_property": formal_system["completeness_property"],
    }
    if facts.get("formal_system") != expected_system:
        fail("normalized facts do not declare the active formal system")
    classify_prompt = arguments.classify_prompt.read_text(encoding="utf-8")
    slots_prompt = arguments.slots_prompt.read_text(encoding="utf-8")

    version = request_json(f"{endpoint}/api/version").get("version")
    tags = request_json(f"{endpoint}/api/tags").get("models", [])
    model_record = next(
        (item for item in tags if item.get("name") == arguments.model), None
    )
    if model_record is None:
        fail(f"required local model is unavailable: {arguments.model}")
    if model_record.get("digest") != arguments.expected_digest:
        fail(
            f"model digest mismatch: expected {arguments.expected_digest}, "
            f"got {model_record.get('digest')}"
        )

    entities = {item["id"]: item for item in facts["entities"]}
    participant_names = {name.casefold() for name in rules["participants"]}
    for entity in entities.values():
        if entity["name"].casefold() in participant_names:
            fail(f"participant leaked into known entities: {entity['name']}")
    entity_choices = [*sorted(entities), UNRESOLVED_ENTITY]
    predicates = formal_system["predicate_contracts"]
    predicate_choices = sorted(predicates)
    selected_ids = set(arguments.fact_id)
    known_fact_ids = {fact["id"] for _kind, fact in fact_stream(facts)}
    unknown_fact_ids = selected_ids - known_fact_ids
    if unknown_fact_ids:
        fail(f"requested fact IDs are not in the normalized corpus: {sorted(unknown_fact_ids)}")

    accepted: list[dict[str, Any]] = []
    review_queue: list[dict[str, Any]] = []
    unresolved_entities: list[dict[str, Any]] = []
    for expected_class, fact in fact_stream(facts):
        if selected_ids and fact["id"] not in selected_ids:
            continue
        evidence = fact["evidence"]
        if evidence is None or fact["evidence_missing"]:
            review_queue.append(
                {"fact_id": fact["id"], "reason": "evidence-missing", "state": "unknown"}
            )
            continue

        classification_call = lambda: model_choice(
            endpoint,
            arguments.model,
            classify_prompt,
            f"Fact ID: {fact['id']}\nFragment: {evidence}\nChoices: {CLASSIFICATIONS}",
            choice_schema(CLASSIFICATIONS),
            12,
        )
        classification, runs, classification_error = exact_twice(classification_call)
        if classification is None:
            review_queue.append(
                {
                    "fact_id": fact["id"],
                    "reason": (
                        "schema-invalid"
                        if classification_error == "schema-invalid"
                        else "classification-nonreproducible"
                    ),
                    "state": "unknown",
                    "runs": runs,
                }
            )
            continue
        selected_class = classification["choice"]
        if selected_class != expected_class:
            review_queue.append(
                {
                    "fact_id": fact["id"],
                    "reason": "classification-mismatch",
                    "state": "unknown",
                    "expected": expected_class,
                    "selected": selected_class,
                }
            )
            continue
        if selected_class != "relation":
            accepted.append({"fact_id": fact["id"], "classification": selected_class})
            continue

        slot_schema = {
            "type": "object",
            "additionalProperties": False,
            "required": ["subject", "predicate", "object"],
            "properties": {
                "subject": {"type": "string", "enum": entity_choices},
                "predicate": {"type": "string", "enum": predicate_choices},
                "object": {"type": "string", "enum": entity_choices},
            },
        }
        slot_user_prompt = build_slot_prompt(
            fact["id"],
            evidence,
            entities,
            predicates,
            (fact.get("evidence_span") or {}).get("context"),
        )
        slot_call = lambda: model_choice(
            endpoint,
            arguments.model,
            slots_prompt,
            slot_user_prompt,
            slot_schema,
            48,
        )
        slots, slot_runs, slot_error = exact_twice(slot_call)
        if slots is None:
            review_queue.append(
                {
                    "fact_id": fact["id"],
                    "reason": (
                        "schema-invalid"
                        if slot_error == "schema-invalid"
                        else "slots-nonreproducible"
                    ),
                    "state": "unknown",
                    "runs": slot_runs,
                }
            )
            continue
        if UNRESOLVED_ENTITY in {slots["subject"], slots["object"]}:
            proposal = {"fact_id": fact["id"], "literal_mention": evidence}
            unresolved_entities.append(proposal)
            review_queue.append(
                {"fact_id": fact["id"], "reason": "unresolved-entity", "state": "unknown"}
            )
            continue

        contract = predicates[slots["predicate"]]
        subject_kind = entities[slots["subject"]]["kind"]
        object_kind = entities[slots["object"]]["kind"]
        forward = (
            subject_kind in contract["subject_kinds"]
            and object_kind in contract["object_kinds"]
        )
        reverse = (
            object_kind in contract["subject_kinds"]
            and subject_kind in contract["object_kinds"]
        )
        if not forward and reverse:
            slots["subject"], slots["object"] = slots["object"], slots["subject"]
        elif not forward:
            review_queue.append(
                {"fact_id": fact["id"], "reason": "direction-contract", "state": "unknown"}
            )
            continue

        expected_slots = {
            "subject": fact["subject"],
            "predicate": fact["predicate"],
            "object": fact["object"],
        }
        if slots != expected_slots:
            review_queue.append(
                {
                    "fact_id": fact["id"],
                    "reason": "slot-mismatch",
                    "state": "unknown",
                    "expected": expected_slots,
                    "selected": slots,
                }
            )
            continue
        accepted.append(
            {
                "id": fact["id"],
                "source": slots["subject"],
                "target": slots["object"],
                "predicate": slots["predicate"],
                "data": fact["data"],
                "protocol": fact["protocol"],
                "authentication": fact["authentication"],
                "certainty": fact["certainty"],
                "evidence": fact["evidence"],
                "evidence_missing": False,
            }
        )

    report = {
        "metadata": {
            "model": arguments.model,
            "model_digest": arguments.expected_digest,
            "ollama_version": version,
            "ollama_binary_sha256": ollama_binary_sha256,
            "expected_ollama_binary_sha256": arguments.expected_binary_sha256,
            "repeat_count": 2,
            "serial_requests": True,
            "options": MODEL_OPTIONS,
        },
        "accepted": accepted,
        "review_queue": review_queue,
        "unresolved_entities": unresolved_entities,
    }
    arguments.output.parent.mkdir(parents=True, exist_ok=True)
    arguments.output.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(
        f"[debug] closed-set inference accepted {len(accepted)} facts and queued "
        f"{len(review_queue)} for review"
    )
    if review_queue:
        fail("closed-set inference produced review-queue items")


if __name__ == "__main__":
    main()
