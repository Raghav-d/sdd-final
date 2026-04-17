#!/usr/bin/env python3
"""
skills/figma/export_file.py
────────────────────────────
Fetch Figma file/node metadata and image export URLs → figma-export.json.

Can be driven two ways:
  1. Directly via CLI args (file_key + optional node_id)
  2. Auto-read from a jira-ticket.json produced by skills/jira/get_ticket.py

Usage:
    # Raw Figma URL (file or design link, node-id optional)
    python export_file.py --url "https://www.figma.com/design/ABC123/Title?node-id=12:34"

    # Direct file key + optional node
    python export_file.py --file-key ABC123XYZ
    python export_file.py --file-key ABC123XYZ --node-id 12:34
    python export_file.py --file-key ABC123XYZ --node-id 12:34 --format svg

    # Auto-read Figma links from a jira-ticket.json
    python export_file.py --from-jira jira-ticket.json

Requirements:
    pip install requests python-dotenv
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import quote

import requests
from dotenv import load_dotenv

# ── Load .env from repo root ──────────────────────────────────────────────────
load_dotenv(Path(__file__).resolve().parents[2] / ".env")

FIGMA_PAT = os.getenv("FIGMA_PAT", "")
FIGMA_URL_RE = re.compile(
    r"https://(?:www\.)?figma\.com/(?:file|design)/([A-Za-z0-9_-]+)"
    r"(?:/[^?\s]*)?(?:\?node-id=([^\s&\"]+))?"
)


def parse_figma_url(url: str) -> tuple[str, str | None]:
    """Extract (file_key, node_id) from any Figma file/design URL.
    node_id is None when no node-id query param is present.
    Exits with an error message if the URL doesn't match.
    """
    match = FIGMA_URL_RE.search(url)
    if not match:
        sys.exit(
            f"❌  Could not parse Figma URL: {url}\n"
            "    Expected format: https://www.figma.com/design/{{FILE_KEY}}/..."
        )
    return match.group(1), match.group(2)  # file_key, node_id (or None)


FIGMA_BASE = "https://api.figma.com/v1"


def build_headers() -> dict:
    if not FIGMA_PAT:
        sys.exit("❌  FIGMA_PAT is not set. Check your .env file.")
    return {
        "X-Figma-Token": FIGMA_PAT,
        "Content-Type": "application/json",
    }


# ── API helpers ───────────────────────────────────────────────────────────────

def get_file_meta(file_key: str) -> dict:
    """Fetch top-level file metadata (name, last modified, pages)."""
    url = f"{FIGMA_BASE}/files/{file_key}?depth=2"
    resp = requests.get(url, headers=build_headers(), timeout=30)
    _check_response(resp, "file metadata")
    return resp.json()


def get_node_meta(file_key: str, node_id: str) -> dict:
    """Fetch metadata for a specific node (frame / component)."""
    encoded = quote(node_id, safe="")
    url = f"{FIGMA_BASE}/files/{file_key}/nodes?ids={encoded}"
    resp = requests.get(url, headers=build_headers(), timeout=30)
    _check_response(resp, f"node {node_id}")
    return resp.json()


def get_image_urls(file_key: str, node_ids: list[str], fmt: str = "png") -> dict:
    """
    Request image export URLs for one or more node IDs.
    Returns dict: { node_id: image_url }
    """
    ids_param = ",".join(quote(n, safe="") for n in node_ids)
    url = f"{FIGMA_BASE}/images/{file_key}?ids={ids_param}&format={fmt}&scale=2"
    resp = requests.get(url, headers=build_headers(), timeout=30)
    _check_response(resp, "image export")
    return resp.json().get("images", {})


def _check_response(resp: requests.Response, context: str):
    if resp.status_code == 401:
        sys.exit("❌  401 Unauthorized — FIGMA_PAT is invalid or expired.")
    if resp.status_code == 403:
        sys.exit(f"❌  403 Forbidden — you don't have access to this Figma file ({context}).")
    if resp.status_code == 404:
        sys.exit(f"❌  404 Not Found — {context} does not exist.")
    resp.raise_for_status()


# ── Node tree helpers ─────────────────────────────────────────────────────────

def collect_frames(node: dict, results: list | None = None) -> list[dict]:
    """Recursively collect all FRAME and COMPONENT nodes from a node tree."""
    if results is None:
        results = []
    node_type = node.get("type", "")
    if node_type in ("FRAME", "COMPONENT", "COMPONENT_SET", "INSTANCE"):
        results.append(
            {
                "id": node.get("id"),
                "name": node.get("name"),
                "type": node_type,
            }
        )
    for child in node.get("children", []):
        collect_frames(child, results)
    return results


def build_export(file_key: str, node_id: str | None, fmt: str) -> dict:
    print(f"📐  Fetching Figma file: {file_key}")

    if node_id:
        # ── Specific node ─────────────────────────────────────────────────────
        print(f"🔎  Targeting node: {node_id}")
        node_data = get_node_meta(file_key, node_id)
        nodes_map = node_data.get("nodes", {})

        frames = []
        for nid, content in nodes_map.items():
            doc = content.get("document", {})
            frames.append(
                {
                    "id": doc.get("id", nid),
                    "name": doc.get("name"),
                    "type": doc.get("type"),
                    "children_count": len(doc.get("children", [])),
                }
            )
            # Also collect nested frames
            frames += collect_frames(doc)

        target_node_ids = [node_id]

    else:
        # ── Full file (top-level frames across all pages) ─────────────────────
        file_data = get_file_meta(file_key)
        document = file_data.get("document", {})

        frames = []
        for page in document.get("children", []):
            for child in page.get("children", []):
                frames.append(
                    {
                        "id": child.get("id"),
                        "name": child.get("name"),
                        "type": child.get("type"),
                        "page": page.get("name"),
                    }
                )

        target_node_ids = [f["id"] for f in frames if f.get("id")][:50]  # Figma limit

    # ── Fetch image export URLs ───────────────────────────────────────────────
    image_urls = {}
    if target_node_ids:
        print(f"🖼   Requesting {fmt.upper()} export URLs for {len(target_node_ids)} node(s) ...")
        image_urls = get_image_urls(file_key, target_node_ids, fmt)

    # ── Attach image URLs to frames ───────────────────────────────────────────
    for frame in frames:
        fid = frame.get("id")
        frame["export_url"] = image_urls.get(fid)
        frame["export_format"] = fmt

    # ── Build final output ────────────────────────────────────────────────────
    file_info = {}
    if not node_id:
        file_info = {
            "name": file_data.get("name"),
            "last_modified": file_data.get("lastModified"),
            "version": file_data.get("version"),
            "thumbnail_url": file_data.get("thumbnailUrl"),
        }

    return {
        "file_key": file_key,
        "node_id": node_id,
        "file_info": file_info,
        "components": frames,
    }


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    parser = argparse.ArgumentParser(description="Export Figma file/node → figma-export.json")
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--url", help="Full Figma URL (file_key + node-id extracted automatically)")
    group.add_argument("--file-key", help="Figma file key (from URL)")
    group.add_argument(
        "--from-jira",
        metavar="JIRA_JSON",
        help="Path to jira-ticket.json — auto-extracts Figma links",
    )
    parser.add_argument("--node-id", help="Specific node/frame ID (optional with --file-key)")
    parser.add_argument(
        "--format",
        choices=["png", "svg", "pdf", "jpg"],
        default="png",
        help="Export image format (default: png)",
    )
    parser.add_argument(
        "--out",
        default="figma-export.json",
        help="Output file path (default: figma-export.json)",
    )
    args = parser.parse_args()

    exports = []

    if args.url:
        # ── Raw Figma URL mode ────────────────────────────────────────────────
        file_key, node_id = parse_figma_url(args.url)
        node_info = f"  node-id: {node_id}" if node_id else ""
        print(f"🔗  Parsed URL → file_key: {file_key}{node_info}")
        export = build_export(file_key, node_id, args.format)
        export["source_figma_url"] = args.url
        exports.append(export)

    elif args.from_jira:
        # ── Read Figma links from jira-ticket.json ────────────────────────────
        jira_path = Path(args.from_jira)
        if not jira_path.exists():
            sys.exit(f"❌  File not found: {jira_path}")

        ticket = json.loads(jira_path.read_text())
        figma_links = ticket.get("figma_links", [])

        if not figma_links:
            sys.exit("ℹ️   No Figma links found in the Jira ticket JSON.")

        print(f"📎  Found {len(figma_links)} Figma link(s) in {jira_path.name}")
        for link in figma_links:
            export = build_export(link["file_key"], link.get("node_id"), args.format)
            export["source_jira_ticket"] = ticket.get("key")
            export["source_figma_url"] = link["url"]
            exports.append(export)

    else:
        # ── Direct --file-key mode ────────────────────────────────────────────
        export = build_export(args.file_key, args.node_id, args.format)
        exports.append(export)

    out_path = Path(args.out)
    out_path.write_text(json.dumps(exports, indent=2, ensure_ascii=False))

    total_components = sum(len(e.get("components", [])) for e in exports)
    print(f"✅  Saved → {out_path}")
    print(f"📦  {len(exports)} file export(s) | {total_components} component(s) total")


if __name__ == "__main__":
    main()
