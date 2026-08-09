#!/usr/bin/env python3
"""Build deterministic, secret-free architecture evidence from OpenTofu plans."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import struct
import sys
import zlib
from pathlib import Path
from typing import Any, Iterable

REDACTED = "[REDACTED]"
SECRET_KEY = re.compile(r"(?:access[_-]?key|secret|password|token|private[_-]?key)", re.I)
FINDING_ID = re.compile(r"^(?:F|ENC|LOG|P)-\d+$")
AWS_ACCESS_KEY = re.compile(r"\b(?:AKIA|ASIA)[A-Z0-9]{16}\b")
AWS_SECRET_KEY = re.compile(r"\b[A-Za-z0-9/+=]{40}\b")


class ContractError(ValueError):
    """Raised when evidence violates the repository architecture contract."""


def read_json(path: Path) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        raise ContractError(f"cannot parse JSON {path}: {exc}") from exc


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2, sort_keys=True) + "\n", encoding="utf-8")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_pixel_digest(path: Path) -> str:
    """Hash decoded RGBA pixels so harmless PNG compression drift is ignored."""
    data = path.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        raise ContractError(f"not a PNG file: {path}")

    offset = 8
    width = height = 0
    compressed: list[bytes] = []
    while offset < len(data):
        if offset + 12 > len(data):
            raise ContractError(f"truncated PNG chunk in {path}")
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        chunk_type = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        expected_crc = struct.unpack(">I", data[offset + 8 + length:offset + 12 + length])[0]
        actual_crc = zlib.crc32(chunk_type + payload) & 0xFFFFFFFF
        if actual_crc != expected_crc:
            raise ContractError(f"invalid PNG CRC in {path}")
        if chunk_type == b"IHDR":
            width, height, depth, color, compression, filtering, interlace = struct.unpack(
                ">IIBBBBB", payload
            )
            if (depth, color, compression, filtering, interlace) != (8, 6, 0, 0, 0):
                raise ContractError(f"unsupported PNG format in {path}; expected RGBA8")
        elif chunk_type == b"IDAT":
            compressed.append(payload)
        elif chunk_type == b"IEND":
            break
        offset += length + 12
    if width == 0 or height == 0 or not compressed:
        raise ContractError(f"incomplete PNG structure in {path}")

    raw = zlib.decompress(b"".join(compressed))
    stride = width * 4
    if len(raw) != height * (stride + 1):
        raise ContractError(f"unexpected PNG raster size in {path}")
    previous = bytearray(stride)
    pixels = bytearray()
    cursor = 0
    for _ in range(height):
        filter_type = raw[cursor]
        cursor += 1
        scanline = bytearray(raw[cursor:cursor + stride])
        cursor += stride
        for index in range(stride):
            left = scanline[index - 4] if index >= 4 else 0
            up = previous[index]
            upper_left = previous[index - 4] if index >= 4 else 0
            if filter_type == 1:
                scanline[index] = (scanline[index] + left) & 0xFF
            elif filter_type == 2:
                scanline[index] = (scanline[index] + up) & 0xFF
            elif filter_type == 3:
                scanline[index] = (scanline[index] + ((left + up) // 2)) & 0xFF
            elif filter_type == 4:
                estimate = left + up - upper_left
                distances = (abs(estimate - left), abs(estimate - up), abs(estimate - upper_left))
                predictor = (left, up, upper_left)[distances.index(min(distances))]
                scanline[index] = (scanline[index] + predictor) & 0xFF
            elif filter_type != 0:
                raise ContractError(f"unsupported PNG filter {filter_type} in {path}")
        pixels.extend(scanline)
        previous = scanline
    dimensions = struct.pack(">II", width, height)
    return hashlib.sha256(dimensions + pixels).hexdigest()


def unique(values: Iterable[str], label: str) -> None:
    seen: set[str] = set()
    duplicates: set[str] = set()
    for value in values:
        if value in seen:
            duplicates.add(value)
        seen.add(value)
    if duplicates:
        raise ContractError(f"duplicate {label}: {', '.join(sorted(duplicates))}")


def validate_catalog(catalog: dict[str, Any]) -> None:
    if catalog.get("schema_version") != "1.0.0":
        raise ContractError("model-tags schema_version must be 1.0.0")
    required_tags = catalog.get("required_tag_keys", [])
    if len(required_tags) != len(set(required_tags)) or not required_tags:
        raise ContractError("required_tag_keys must be non-empty and unique")

    actors = catalog.get("actors", {})
    actor_ids = set(actors)
    component_ids: list[str] = []
    flow_ids: list[str] = []
    expected_postures = {"current-state", "target-state"}
    if set(catalog.get("postures", {})) != expected_postures:
        raise ContractError("catalog must define exactly current-state and target-state")

    for posture_name, posture in catalog["postures"].items():
        units = posture.get("units", {})
        if not units:
            raise ContractError(f"{posture_name} has no units")
        posture_components = {unit["component_id"] for unit in units.values()}
        component_ids.extend(posture_components)

        for unit_name, unit in units.items():
            missing = {
                "component_id", "family", "trust_zone", "purpose", "owner",
                "data_classification", "findings", "flow_ids", "depends_on",
            } - set(unit)
            if missing:
                raise ContractError(f"{posture_name}/{unit_name} missing {sorted(missing)}")
            unknown_dependencies = set(unit["depends_on"]) - set(units)
            if unknown_dependencies:
                raise ContractError(
                    f"{posture_name}/{unit_name} has unknown dependencies "
                    f"{sorted(unknown_dependencies)}"
                )
            invalid_findings = [item for item in unit["findings"] if not FINDING_ID.match(item)]
            if invalid_findings:
                raise ContractError(
                    f"{posture_name}/{unit_name} has invalid finding IDs {invalid_findings}"
                )

        posture_flows = posture.get("flows", [])
        posture_flow_ids = {flow["id"] for flow in posture_flows}
        flow_ids.extend(posture_flow_ids)
        endpoints = actor_ids | posture_components
        for flow in posture_flows:
            if flow["source"] not in endpoints or flow["target"] not in endpoints:
                raise ContractError(f"{flow['id']} has an unknown endpoint")
        for unit_name, unit in units.items():
            missing_flows = set(unit["flow_ids"]) - posture_flow_ids
            if missing_flows:
                raise ContractError(
                    f"{posture_name}/{unit_name} references unknown flows {sorted(missing_flows)}"
                )
    unique(component_ids, "component IDs")
    unique(flow_ids, "flow IDs")


def apply_mask(value: Any, mask: Any) -> Any:
    if mask is True:
        return REDACTED
    if isinstance(value, dict) and isinstance(mask, dict):
        return {key: apply_mask(item, mask.get(key)) for key, item in value.items()}
    if isinstance(value, list) and isinstance(mask, list):
        return [apply_mask(item, mask[index] if index < len(mask) else None)
                for index, item in enumerate(value)]
    return value


def scrub_secrets(value: Any, key: str = "") -> Any:
    if SECRET_KEY.search(key):
        return REDACTED
    if isinstance(value, dict):
        return {item_key: scrub_secrets(item, item_key) for item_key, item in value.items()}
    if isinstance(value, list):
        return [scrub_secrets(item, key) for item in value]
    if isinstance(value, str) and (AWS_ACCESS_KEY.search(value) or AWS_SECRET_KEY.fullmatch(value)):
        return REDACTED
    return value


def _sanitize_module(module: dict[str, Any]) -> None:
    for resource in module.get("resources", []):
        resource["values"] = apply_mask(
            resource.get("values"), resource.get("sensitive_values")
        )
        resource.pop("sensitive_values", None)
    for child in module.get("child_modules", []):
        _sanitize_module(child)


def sanitize_plan(plan: dict[str, Any]) -> dict[str, Any]:
    result = copy.deepcopy(plan)
    # Run time is transport metadata, not architectural evidence.
    result.pop("timestamp", None)
    planned = result.get("planned_values", {})
    for output in planned.get("outputs", {}).values():
        if output.get("sensitive") is True:
            output["value"] = REDACTED
    if isinstance(planned.get("root_module"), dict):
        _sanitize_module(planned["root_module"])

    for change in result.get("resource_changes", []):
        body = change.get("change", {})
        body["before"] = apply_mask(body.get("before"), body.get("before_sensitive"))
        body["after"] = apply_mask(body.get("after"), body.get("after_sensitive"))
        body.pop("before_sensitive", None)
        body.pop("after_sensitive", None)
    for output in result.get("output_changes", {}).values():
        if output.get("before_sensitive") is True:
            output["before"] = REDACTED
        if output.get("after_sensitive") is True:
            output["after"] = REDACTED
        output.pop("before_sensitive", None)
        output.pop("after_sensitive", None)
    result = scrub_secrets(result)
    encoded = json.dumps(result)
    if AWS_ACCESS_KEY.search(encoded):
        raise ContractError("sanitized plan still contains an AWS access-key pattern")
    return result


def sanitize_log(text: str) -> str:
    text = re.sub(
        r'("[^"\n]*(?:secret|password|token|access[_-]?key)[^"\n]*"\s*:\s*\{.*?'
        r'"value"\s*:\s*)"[^"]*"',
        rf'\1"{REDACTED}"',
        text,
        flags=re.I | re.S,
    )
    text = re.sub(
        r'("[^"\n]*(?:secret|password|token|access[_-]?key)[^"\n]*"\s*:\s*)"[^"]*"',
        rf'\1"{REDACTED}"',
        text,
        flags=re.I,
    )
    text = AWS_ACCESS_KEY.sub(REDACTED, text)
    return text


def walk_resources(module: dict[str, Any]) -> Iterable[dict[str, Any]]:
    yield from module.get("resources", [])
    for child in module.get("child_modules", []):
        yield from walk_resources(child)


def safe_resource(resource: dict[str, Any]) -> dict[str, Any]:
    values = resource.get("values") or {}
    # Native AWS resources expose tags at the top level. Explicit Floci
    # substitutes keep the identical contract under terraform_data.input so
    # unsupported emulator APIs remain visible rather than being fabricated.
    input_value = values.get("input") if isinstance(values.get("input"), dict) else {}
    tags = values.get("tags_all") or values.get("tags") or input_value.get("tags") or {}
    identity = next(
        (values.get(key) for key in ("bucket", "name", "role_name", "alias_name")
         if isinstance(values.get(key), str) and values.get(key)),
        resource.get("name"),
    )
    return {
        "address": resource.get("address"),
        "identity": identity,
        "mode": resource.get("mode"),
        "provider_name": resource.get("provider_name"),
        "tags": tags,
        "type": resource.get("type"),
    }


def awsdac_id(raw: str) -> str:
    words = re.findall(r"[A-Za-z0-9]+", raw)
    return "R" + "".join(word[:1].upper() + word[1:] for word in words)


AWS_TYPES = {
    "compute": "AWS::EC2::Instance",
    "detection": "AWS::Events::Rule",
    "edge": "AWS::CloudFront::Distribution",
    "iam": "AWS::IAM::Role",
    "kms": "AWS::KMS::Key",
    "logging": "AWS::CloudTrail::Trail",
    "s3": "AWS::S3::Bucket",
}


def make_awsdac(blueprint: dict[str, Any], definition_file: str) -> dict[str, Any]:
    resources: dict[str, Any] = {
        "Canvas": {
            "Type": "AWS::Diagram::Canvas",
            "Direction": "horizontal",
            "Children": ["Actors", "AWSCloud"],
        },
        "Actors": {
            "Type": "AWS::Diagram::VerticalStack",
            "Children": [awsdac_id(actor["id"]) for actor in blueprint["actors"]],
        },
        "AWSCloud": {
            "Type": "AWS::Diagram::Cloud",
            "Preset": "AWSCloudNoLogo",
            "Direction": "vertical",
            "Children": [awsdac_id(zone["id"]) for zone in blueprint["trust_zones"]],
        },
    }
    for actor in blueprint["actors"]:
        resources[awsdac_id(actor["id"])] = {
            "Type": "AWS::Diagram::Resource", "Preset": "User", "Title": actor["name"]
        }
    for zone in blueprint["trust_zones"]:
        resources[awsdac_id(zone["id"])] = {
            "Type": "AWS::Diagram::Resource",
            "Direction": "horizontal",
            "Title": zone["id"],
            "Children": [awsdac_id(item) for item in zone["components"]],
        }
    for component in blueprint["components"]:
        resources[awsdac_id(component["id"])] = {
            "Type": AWS_TYPES.get(component["family"], "AWS::Diagram::Resource"),
            "Title": f"{component['unit']} ({component['purpose']})",
        }
    links = [
        {
            "Source": awsdac_id(flow["source"]),
            "SourcePosition": "E",
            "Target": awsdac_id(flow["target"]),
            "TargetPosition": "W",
            "TargetArrowHead": {"Type": "Open"},
            "Type": "orthogonal",
        }
        for flow in blueprint["data_flows"]
    ]
    return {
        "Diagram": {
            "DefinitionFiles": [{"Type": "LocalFile", "LocalFile": definition_file}],
            "Resources": resources,
            "Links": links,
        }
    }


def compile_blueprint(
    catalog_path: Path, posture_name: str, evidence_dir: Path, output_dir: Path,
    definition_file: str,
) -> dict[str, Any]:
    catalog = read_json(catalog_path)
    validate_catalog(catalog)
    posture = catalog["postures"][posture_name]
    plan_root = evidence_dir / "plans"
    found_units = {path.parent.name for path in plan_root.glob("*/tfplan.json")}
    expected_units = set(posture["units"])
    if found_units != expected_units:
        raise ContractError(
            f"plan unit mismatch: missing={sorted(expected_units - found_units)}, "
            f"unexpected={sorted(found_units - expected_units)}"
        )

    components: list[dict[str, Any]] = []
    for unit_name, metadata in sorted(posture["units"].items()):
        plan_path = plan_root / unit_name / "tfplan.json"
        plan = read_json(plan_path)
        module = plan.get("planned_values", {}).get("root_module", {})
        resources = [safe_resource(item) for item in walk_resources(module)]
        expected_tags = {
            "tm:component-id": metadata["component_id"],
            "tm:data-classification": metadata["data_classification"],
            "tm:environment": posture_name,
            "tm:family": metadata["family"],
            "tm:owner": metadata["owner"],
            "tm:purpose": metadata["purpose"],
            "tm:trust-zone": metadata["trust_zone"],
        }
        tagged = [resource for resource in resources if resource["tags"]]
        if not any(all(resource["tags"].get(key) == value for key, value in expected_tags.items())
                   for resource in tagged):
            raise ContractError(f"{posture_name}/{unit_name} has no correctly tagged resource")
        components.append({
            "id": metadata["component_id"],
            "unit": unit_name,
            "source_unit": f"live/{posture_name}/{unit_name}",
            "family": metadata["family"],
            "trust_zone": metadata["trust_zone"],
            "purpose": metadata["purpose"],
            "owner": metadata["owner"],
            "data_classification": metadata["data_classification"],
            "findings": metadata["findings"],
            "flow_ids": metadata["flow_ids"],
            "depends_on_units": metadata["depends_on"],
            "resources": resources,
            "evidence": {"plan": str(plan_path.relative_to(evidence_dir))},
        })

    zones: dict[str, list[str]] = {}
    for component in components:
        zones.setdefault(component["trust_zone"], []).append(component["id"])
    actors = [dict({"id": actor_id}, **actor) for actor_id, actor in sorted(catalog["actors"].items())]
    inventory_path = evidence_dir / "inventory.json"
    inventory = read_json(inventory_path)
    runtime_inventory = {
        "scope_prefix": inventory["scope_prefix"],
        "buckets": inventory["buckets"],
        "roles": [item["name"] for item in inventory["roles"]],
        "users": [item["name"] for item in inventory["users"]],
        "kms_aliases": [item["name"] for item in inventory["kms_aliases"]],
        "trails": [item["name"] for item in inventory["trails"]],
        "event_rules": [item["name"] for item in inventory["event_rules"]],
        "topics": inventory["topics"],
        "instances": [
            {
                "name": next(
                    (tag["Value"] for tag in item.get("tags", []) if tag.get("Key") == "Name"),
                    "unnamed",
                ),
                "metadata_options": item.get("metadata_options", {}),
            }
            for item in inventory["instances"]
        ],
    }
    blueprint = {
        "schema_version": "1.0.0",
        "model_id": f"meridian-s3-{posture_name}",
        "posture": posture_name,
        "display_name": posture["display_name"],
        "generation": {
            "mode": "deterministic-offline",
            "catalog": "Examples/S3/architecture/model-tags.json",
            "catalog_sha256": sha256(catalog_path),
            "evidence_manifest": "manifest.json",
        },
        "actors": actors,
        "trust_zones": [
            {"id": zone, "components": sorted(component_ids)}
            for zone, component_ids in sorted(zones.items())
        ],
        "components": components,
        "data_flows": posture["flows"],
        "floci_gaps": posture["floci_gaps"],
        "runtime_inventory": runtime_inventory,
    }
    validate_blueprint(blueprint)
    write_json(output_dir / "blueprint.json", blueprint)
    # JSON is valid YAML 1.2 and keeps this generated file dependency-free.
    write_json(output_dir / "awsdac.yaml", make_awsdac(blueprint, definition_file))
    return blueprint


def validate_blueprint(blueprint: dict[str, Any]) -> None:
    if blueprint.get("schema_version") != "1.0.0":
        raise ContractError("blueprint schema_version must be 1.0.0")
    actors = [item["id"] for item in blueprint.get("actors", [])]
    components = [item["id"] for item in blueprint.get("components", [])]
    flows = [item["id"] for item in blueprint.get("data_flows", [])]
    unique(actors, "blueprint actors")
    unique(components, "blueprint components")
    unique(flows, "blueprint data flows")
    endpoints = set(actors) | set(components)
    for flow in blueprint.get("data_flows", []):
        if flow["source"] not in endpoints or flow["target"] not in endpoints:
            raise ContractError(f"blueprint flow {flow['id']} has an unknown endpoint")
    zone_components = {item for zone in blueprint.get("trust_zones", []) for item in zone["components"]}
    if zone_components != set(components):
        raise ContractError("trust-zone membership does not cover every component exactly")
    if AWS_ACCESS_KEY.search(json.dumps(blueprint)):
        raise ContractError("blueprint contains an AWS access-key pattern")


def create_manifest(evidence_dir: Path, posture: str, versions_path: Path) -> dict[str, Any]:
    files = []
    for path in sorted(evidence_dir.rglob("*")):
        if path.is_file() and path.name != "manifest.json" and "logs" not in path.parts:
            files.append({
                "path": str(path.relative_to(evidence_dir)),
                "sha256": sha256(path),
                "bytes": path.stat().st_size,
            })
    manifest = {
        "schema_version": "1.0.0",
        "posture": posture,
        "classification": "sanitized-training-evidence",
        "raw_plans_retained": False,
        "versions": read_json(versions_path),
        "files": files,
    }
    write_json(evidence_dir / "manifest.json", manifest)
    return manifest


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    validate_catalog_parser = sub.add_parser("validate-catalog")
    validate_catalog_parser.add_argument("catalog", type=Path)
    sanitize = sub.add_parser("sanitize-plan")
    sanitize.add_argument("source", type=Path)
    sanitize.add_argument("destination", type=Path)
    sanitize_log_parser = sub.add_parser("sanitize-log")
    sanitize_log_parser.add_argument("source", type=Path)
    sanitize_log_parser.add_argument("destination", type=Path)
    compile_parser = sub.add_parser("compile")
    compile_parser.add_argument("--catalog", required=True, type=Path)
    compile_parser.add_argument("--posture", required=True, choices=["current-state", "target-state"])
    compile_parser.add_argument("--evidence-dir", required=True, type=Path)
    compile_parser.add_argument("--output-dir", required=True, type=Path)
    compile_parser.add_argument("--definition-file", required=True)
    manifest_parser = sub.add_parser("manifest")
    manifest_parser.add_argument("--evidence-dir", required=True, type=Path)
    manifest_parser.add_argument("--posture", required=True, choices=["current-state", "target-state"])
    manifest_parser.add_argument("--versions", required=True, type=Path)
    validate_blueprint_parser = sub.add_parser("validate-blueprint")
    validate_blueprint_parser.add_argument("blueprint", type=Path)
    compare_png_parser = sub.add_parser("compare-png")
    compare_png_parser.add_argument("expected", type=Path)
    compare_png_parser.add_argument("actual", type=Path)
    return parser


def main() -> int:
    args = build_parser().parse_args()
    try:
        if args.command == "validate-catalog":
            validate_catalog(read_json(args.catalog))
        elif args.command == "sanitize-plan":
            write_json(args.destination, sanitize_plan(read_json(args.source)))
        elif args.command == "sanitize-log":
            args.destination.write_text(
                sanitize_log(args.source.read_text(encoding="utf-8", errors="replace")),
                encoding="utf-8",
            )
        elif args.command == "compile":
            compile_blueprint(
                args.catalog, args.posture, args.evidence_dir, args.output_dir,
                args.definition_file,
            )
        elif args.command == "manifest":
            create_manifest(args.evidence_dir, args.posture, args.versions)
        elif args.command == "validate-blueprint":
            validate_blueprint(read_json(args.blueprint))
        elif args.command == "compare-png":
            if png_pixel_digest(args.expected) != png_pixel_digest(args.actual):
                raise ContractError(
                    f"PNG pixel drift: expected {args.expected}, actual {args.actual}"
                )
    except ContractError as exc:
        print(f"[error] {exc}", file=sys.stderr)
        return 1
    print(f"[debug] {args.command} passed", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
