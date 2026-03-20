#!/usr/bin/env python3
"""Tiny localhost collector used to demonstrate fake secret exfiltration."""

from __future__ import annotations

import argparse
import json
import threading
from email.parser import BytesParser
from email.policy import default
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path


def parse_body(content_type: str, body: bytes) -> dict:
    fields: dict[str, object] = {}
    files: dict[str, object] = {}

    if "multipart/form-data" not in content_type:
        return {
            "fields": {"raw_body": body.decode("utf-8", errors="replace")},
            "files": files,
        }

    mime_blob = (
        f"Content-Type: {content_type}\r\nMIME-Version: 1.0\r\n\r\n".encode("utf-8")
        + body
    )
    message = BytesParser(policy=default).parsebytes(mime_blob)

    for part in message.iter_parts():
        name = part.get_param("name", header="content-disposition") or "unknown"
        filename = part.get_filename()
        payload = part.get_payload(decode=True) or b""
        text = payload.decode("utf-8", errors="replace")

        if filename:
            files[name] = {
                "filename": filename,
                "size": len(payload),
                "preview": text[:220],
            }
            continue

        if name == "report_json":
            try:
                fields[name] = json.loads(text)
            except json.JSONDecodeError:
                fields[name] = text
            continue

        fields[name] = text

    return {"fields": fields, "files": files}


def build_handler(output_path: Path, stop_after_request: bool):
    class CollectorHandler(BaseHTTPRequestHandler):
        def do_POST(self) -> None:  # noqa: N802
            body_len = int(self.headers.get("Content-Length", "0"))
            body = self.rfile.read(body_len)
            parsed = parse_body(self.headers.get("Content-Type", ""), body)

            record = {
                "path": self.path,
                "content_type": self.headers.get("Content-Type", ""),
                "fields": parsed["fields"],
                "files": parsed["files"],
            }
            output_path.parent.mkdir(parents=True, exist_ok=True)
            output_path.write_text(json.dumps(record, indent=2) + "\n", encoding="utf-8")

            response = json.dumps({"ok": True, "saved_to": str(output_path)}).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Content-Length", str(len(response)))
            self.end_headers()
            self.wfile.write(response)

            if stop_after_request:
                threading.Thread(target=self.server.shutdown, daemon=True).start()

        def log_message(self, format: str, *args: object) -> None:  # noqa: A003
            return

    return CollectorHandler


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=17777)
    parser.add_argument("--output", required=True)
    parser.add_argument("--one-shot", action="store_true")
    args = parser.parse_args()

    output_path = Path(args.output)
    handler = build_handler(output_path, args.one_shot)
    server = HTTPServer((args.host, args.port), handler)
    server.serve_forever()


if __name__ == "__main__":
    main()
