#!/usr/bin/env python3
"""Minimal Ollama API double for closed-set inference contracts."""

from __future__ import annotations

import argparse
import http.server
import json


MODEL_DIGEST = "test-digest"
BASE_OPTIONS = {
    "temperature": 0,
    "seed": 20260809,
    "num_ctx": 4096,
    "top_k": 1,
    "top_p": 1,
    "repeat_penalty": 1,
}
CLASSIFICATIONS = {
    "rel-current-01": "relation",
    "rel-current-02": "relation",
    "rel-current-03": "relation",
    "rel-current-04": "relation",
    "rel-current-05": "relation",
    "rel-current-06": "relation",
    "rel-current-07": "relation",
    "rel-current-08": "relation",
    "rel-current-09": "relation",
    "rel-current-10": "relation",
    "attr-current-01": "attribute",
    "unc-current-01": "uncertainty",
    "unc-current-02": "uncertainty",
    "unc-current-03": "uncertainty",
    "unc-current-04": "uncertainty",
}
SLOTS = {
    "rel-current-01": ["actor-customer", "reads", "cmp-s3-bucket"],
    "rel-current-02": ["cmp-app-backend", "accesses", "cmp-s3-bucket"],
    "rel-current-03": ["cmp-cicd-pipeline", "deploys-policy-to", "cmp-s3-bucket"],
    "rel-current-04": ["actor-customer", "uploads", "cmp-s3-bucket"],
    "rel-current-05": ["cmp-s3-bucket", "serves-through", "cmp-cloudfront"],
    "rel-current-06": ["cmp-cloudfront", "serves", "actor-customer"],
    "rel-current-07": ["cmp-cicd-pipeline", "assumes", "cmp-deploy-role"],
    "rel-current-08": ["cmp-deploy-role", "may-modify-policy-on", "cmp-s3-bucket"],
    "rel-current-09": ["cmp-analytics-job", "requests-exports-from", "cmp-s3-bucket"],
    "rel-current-10": ["cmp-s3-bucket", "returns", "cmp-analytics-job"],
}


class Handler(http.server.BaseHTTPRequestHandler):
    slot_calls = 0
    mode = "pass"

    def send_json(self, value: object) -> None:
        body = json.dumps(value).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self) -> None:
        if self.path == "/api/version":
            self.send_json({"version": "test-version"})
        elif self.path == "/api/tags":
            self.send_json(
                {"models": [{"name": "qwen3:1.7b", "digest": MODEL_DIGEST}]}
            )
        else:
            self.send_error(404)

    def do_POST(self) -> None:
        if self.path != "/api/chat":
            self.send_error(404)
            return
        length = int(self.headers["Content-Length"])
        request = json.loads(self.rfile.read(length))
        if request.get("stream") is not False or request.get("think") is not False:
            self.send_error(400, "inference must disable streaming and thinking")
            return
        if request.get("model") != "qwen3:1.7b":
            self.send_error(400, "model pin changed")
            return
        if request.get("format", {}).get("additionalProperties") is not False:
            self.send_error(400, "schema is not closed")
            return
        user_prompt = request.get("messages", [{}, {}])[1].get("content", "")
        if any(label in user_prompt for label in ("Priya:", "Diego:", "Amara:", "Sam:", "Jordan:")):
            self.send_error(400, "speaker label crossed the inference boundary")
            return
        properties = request["format"]["properties"]
        expected_num_predict = 12 if "choice" in properties else 48
        expected_options = {**BASE_OPTIONS, "num_predict": expected_num_predict}
        if request.get("options") != expected_options:
            self.send_error(400, "model options changed")
            return
        if "choice" in properties:
            if properties["choice"].get("enum") != [
                "relation",
                "attribute",
                "uncertainty",
            ]:
                self.send_error(400, "classification enum changed")
                return
            fact_id = user_prompt.split("Fact ID: ", 1)[1].split("\n", 1)[0]
            content = {"choice": CLASSIFICATIONS[fact_id]}
        else:
            Handler.slot_calls += 1
            fact_id = user_prompt.split("Fact ID: ", 1)[1].split("\n", 1)[0]
            subject, predicate, object_id = SLOTS[fact_id]
            content = {
                "subject": subject,
                "predicate": predicate,
                "object": object_id,
            }
            if Handler.mode == "disagree" and Handler.slot_calls % 2 == 0:
                content["object"] = "cmp-cloudfront" if object_id != "cmp-cloudfront" else "cmp-s3-bucket"
        self.send_json({"message": {"content": json.dumps(content)}})

    def log_message(self, _format: str, *_args: object) -> None:
        pass


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    parser.add_argument("--mode", choices=["pass", "disagree"], required=True)
    arguments = parser.parse_args()
    Handler.mode = arguments.mode
    http.server.HTTPServer(("127.0.0.1", arguments.port), Handler).serve_forever()


if __name__ == "__main__":
    main()
