#!/usr/bin/env python3
"""Generate deterministic Mermaid DFDs from the reviewed architecture graph."""

from __future__ import annotations

import argparse
import html
import json
import pathlib
import re


def identifier(value: str, prefix: str) -> str:
    return f"{prefix}_{re.sub(r'[^A-Za-z0-9_]', '_', value)}"


def label(value: object) -> str:
    return html.escape(str(value), quote=True).replace("\n", " ")


def node_line(stable_id: str, name: str, kind: str) -> str:
    node_id = identifier(stable_id, "n")
    text = f"{label(stable_id)}<br/>{label(name)}"
    if kind == "datastore":
        return f'    {node_id}[("{text}")]'
    if kind == "service":
        return f'    {node_id}(["{text}"])'
    return f'    {node_id}["{text}"]'


def render(model: dict[str, object], posture_name: str) -> str:
    actors = model["actors"]
    posture = model["postures"][posture_name]
    units = posture["units"]
    zones: dict[str, list[tuple[str, str, str]]] = {}

    for actor_id, actor in sorted(actors.items()):
        zones.setdefault(actor["trust_zone"], []).append(
            (actor_id, actor["name"], "actor")
        )
    for unit_name, unit in sorted(units.items()):
        family = unit["family"]
        kind = "datastore" if family in {"s3", "logging"} else "service"
        display = f"{unit_name}: {unit['purpose']}"
        zones.setdefault(unit["trust_zone"], []).append(
            (unit["component_id"], display, kind)
        )

    lines = [
        "%% Generated from architecture/model-tags.json; do not edit by hand.",
        "%% Workshop evidence: B-traceability-log.md, Session Q&A #1 and #2.",
        f"%% Posture: {posture_name}",
        "flowchart LR",
    ]
    classes: dict[str, list[str]] = {"actor": [], "datastore": [], "service": []}
    for zone_id in sorted(zones):
        lines.append(f'  subgraph {identifier(zone_id, "z")}["{label(zone_id)}"]')
        lines.append("    direction TB")
        for stable_id, name, kind in zones[zone_id]:
            lines.append(node_line(stable_id, name, kind))
            classes[kind].append(identifier(stable_id, "n"))
        lines.append("  end")

    for flow in posture["flows"]:
        source = identifier(flow["source"], "n")
        target = identifier(flow["target"], "n")
        flow_label = (
            f"{label(flow['id'])}<br/>{label(flow['protocol'])}: "
            f"{label(flow['data'])}<br/>auth: {label(flow['authentication'])}"
        )
        lines.append(f'  {source} -->|"{flow_label}"| {target}')

    lines.extend(
        [
            "  classDef actor fill:#fff7ed,stroke:#c2410c,stroke-width:2px,color:#0f172a;",
            "  classDef service fill:#e0f2fe,stroke:#0369a1,stroke-width:2px,color:#0f172a;",
            "  classDef datastore fill:#ecfdf5,stroke:#047857,stroke-width:2px,color:#0f172a;",
        ]
    )
    for kind, node_ids in classes.items():
        if node_ids:
            lines.append(f"  class {','.join(node_ids)} {kind};")
    return "\n".join(lines) + "\n"


def graph_parts(
    model: dict[str, object], posture_name: str
) -> tuple[dict[str, list[tuple[str, str, str]]], list[dict[str, str]]]:
    zones: dict[str, list[tuple[str, str, str]]] = {}
    for actor_id, actor in sorted(model["actors"].items()):
        zones.setdefault(actor["trust_zone"], []).append(
            (actor_id, actor["name"], "actor")
        )
    posture = model["postures"][posture_name]
    for unit_name, unit in sorted(posture["units"].items()):
        kind = "datastore" if unit["family"] in {"s3", "logging"} else "service"
        zones.setdefault(unit["trust_zone"], []).append(
            (unit["component_id"], f"{unit_name}: {unit['purpose']}", kind)
        )
    return zones, posture["flows"]


def d2_text(value: object) -> str:
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def render_d2(model: dict[str, object], posture_name: str) -> str:
    zones, flows = graph_parts(model, posture_name)
    locations: dict[str, str] = {}
    lines = [
        "# Generated from architecture/model-tags.json; do not edit by hand.",
        "# Workshop evidence: B-traceability-log.md, Session Q&A #1 and #2.",
        "direction: right",
    ]
    for zone_id in sorted(zones):
        zone_key = identifier(zone_id, "z")
        lines.extend(
            [
                f'{zone_key}: "{d2_text(zone_id)}" {{',
                "  style.fill: \"#f8fafc\"",
                "  style.stroke: \"#64748b\"",
                "  direction: down",
            ]
        )
        for stable_id, name, kind in zones[zone_id]:
            node_key = identifier(stable_id, "n")
            locations[stable_id] = f"{zone_key}.{node_key}"
            shape = "cylinder" if kind == "datastore" else "rectangle"
            fill = {"actor": "#fff7ed", "service": "#e0f2fe", "datastore": "#ecfdf5"}[kind]
            stroke = {"actor": "#c2410c", "service": "#0369a1", "datastore": "#047857"}[kind]
            lines.extend(
                [
                    f'  {node_key}: "{d2_text(stable_id)}\\n{d2_text(name)}" {{',
                    f"    shape: {shape}",
                    f'    style.fill: "{fill}"',
                    f'    style.stroke: "{stroke}"',
                    "    style.stroke-width: 2",
                    "  }",
                ]
            )
        lines.append("}")
    for flow in flows:
        flow_label = (
            f"{d2_text(flow['id'])}\\n{d2_text(flow['protocol'])}: "
            f"{d2_text(flow['data'])}\\nauth: {d2_text(flow['authentication'])}"
        )
        lines.append(
            f'{locations[flow["source"]]} -> {locations[flow["target"]]}: '
            f'"{flow_label}"'
        )
    return "\n".join(lines) + "\n"


def plantuml_text(value: object) -> str:
    return str(value).replace("\\", "\\\\").replace('"', '\\"').replace("\n", " ")


def render_plantuml(model: dict[str, object], posture_name: str) -> str:
    zones, flows = graph_parts(model, posture_name)
    lines = [
        "@startuml",
        "' Generated from architecture/model-tags.json; do not edit by hand.",
        "' Workshop evidence: B-traceability-log.md, Session Q&A #1 and #2.",
        "left to right direction",
        "!pragma layout smetana",
        "skinparam shadowing false",
        "skinparam componentStyle rectangle",
        "skinparam ArrowColor #475569",
        "skinparam packageBorderColor #64748b",
        "skinparam packageBackgroundColor #f8fafc",
    ]
    for zone_id in sorted(zones):
        lines.append(f'package "{plantuml_text(zone_id)}" {{')
        for stable_id, name, kind in zones[zone_id]:
            alias = identifier(stable_id, "n")
            text = f"{plantuml_text(stable_id)}\\n{plantuml_text(name)}"
            if kind == "datastore":
                lines.append(f'  database "{text}" as {alias} #ecfdf5')
            elif kind == "service":
                lines.append(f'  component "{text}" as {alias} #e0f2fe')
            else:
                lines.append(f'  rectangle "{text}" as {alias} #fff7ed')
        lines.append("}")
    for flow in flows:
        source = identifier(flow["source"], "n")
        target = identifier(flow["target"], "n")
        flow_label = (
            f"{plantuml_text(flow['id'])}\\n{plantuml_text(flow['protocol'])}: "
            f"{plantuml_text(flow['data'])}\\nauth: {plantuml_text(flow['authentication'])}"
        )
        lines.append(f"{source} --> {target} : {flow_label}")
    lines.append("@enduml")
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", type=pathlib.Path, required=True)
    parser.add_argument("--output", type=pathlib.Path, required=True)
    arguments = parser.parse_args()

    model = json.loads(arguments.model.read_text(encoding="utf-8"))
    arguments.output.mkdir(parents=True, exist_ok=True)
    for posture_name in ("current-state", "target-state"):
        outputs = {
            "mmd": render(model, posture_name),
            "d2": render_d2(model, posture_name),
            "puml": render_plantuml(model, posture_name),
        }
        for extension, content in outputs.items():
            destination = arguments.output / f"{posture_name}.{extension}"
            destination.write_text(content, encoding="utf-8")
            print(f"[debug] generated {destination}")


if __name__ == "__main__":
    main()
