#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
MODULE_PATH = ROOT / "scripts/architecture/model_pipeline.py"
SPEC = importlib.util.spec_from_file_location("model_pipeline", MODULE_PATH)
assert SPEC and SPEC.loader
PIPELINE = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PIPELINE)


class CatalogTests(unittest.TestCase):
    def test_catalog_is_referentially_complete(self) -> None:
        catalog = PIPELINE.read_json(ROOT / "Examples/S3/architecture/model-tags.json")
        PIPELINE.validate_catalog(catalog)
        units = sum(len(item["units"]) for item in catalog["postures"].values())
        self.assertEqual(units, 19)

    def test_unknown_flow_endpoint_fails(self) -> None:
        catalog = PIPELINE.read_json(ROOT / "Examples/S3/architecture/model-tags.json")
        catalog["postures"]["current-state"]["flows"][0]["target"] = "missing"
        with self.assertRaises(PIPELINE.ContractError):
            PIPELINE.validate_catalog(catalog)


class SanitizerTests(unittest.TestCase):
    def test_floci_substitute_exposes_nested_model_tags(self) -> None:
        resource = PIPELINE.safe_resource({
            "address": "terraform_data.floci_distribution[0]",
            "name": "floci_distribution",
            "type": "terraform_data",
            "values": {"input": {"tags": {"tm:component-id": "cmp-edge"}}},
        })
        self.assertEqual(resource["tags"]["tm:component-id"], "cmp-edge")

    def test_sensitive_values_and_key_patterns_are_redacted(self) -> None:
        plan = {
            "timestamp": "never stable",
            "planned_values": {
                "outputs": {
                    "credential": {"sensitive": True, "value": "not-for-output"}
                },
                "root_module": {
                    "resources": [{
                        "address": "aws_iam_access_key.fixture",
                        "values": {
                            "id": "AKIAABCDEFGHIJKLMNOP",
                            "secret": "A" * 40,
                            "safe": "fixture",
                        },
                        "sensitive_values": {"secret": True},
                    }]
                },
            },
        }
        result = PIPELINE.sanitize_plan(plan)
        encoded = json.dumps(result)
        self.assertNotIn("not-for-output", encoded)
        self.assertNotIn("AKIAABCDEFGHIJKLMNOP", encoded)
        self.assertNotIn("A" * 40, encoded)
        self.assertNotIn("timestamp", result)
        self.assertIn(PIPELINE.REDACTED, encoded)

    def test_debug_log_structured_secret_is_redacted(self) -> None:
        log = '"legacy_secret_access_key": {"sensitive": true, "value": "' + "B" * 40 + '"}'
        sanitized = PIPELINE.sanitize_log(log)
        self.assertNotIn("B" * 40, sanitized)
        self.assertIn(PIPELINE.REDACTED, sanitized)


class DiagramTests(unittest.TestCase):
    def test_reviewed_png_has_a_stable_rgba_pixel_digest(self) -> None:
        diagram = ROOT / "Examples/S3/architecture/current-state/architecture.png"
        digest = PIPELINE.png_pixel_digest(diagram)
        self.assertRegex(digest, r"^[0-9a-f]{64}$")
        self.assertEqual(digest, PIPELINE.png_pixel_digest(diagram))


if __name__ == "__main__":
    unittest.main(verbosity=2)
