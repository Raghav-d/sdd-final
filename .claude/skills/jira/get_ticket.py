#!/usr/bin/env python3
"""
skills/jira/get_ticket.py
─────────────────────────
Fetch a Jira ticket by issue key and save to jira-ticket.json.

Usage:
    python get_ticket.py PROJ-123
    python get_ticket.py PROJ-123 --out /path/to/output.json

Requirements:
    pip install requests python-dotenv
"""

import argparse
import json
import os
import re
import sys
from pathlib import Path

import requests
from dotenv import load_dotenv

# ── Load .env from repo root (two levels up from this file) ──────────────────
load_dotenv(Path(__file__).resolve().parents[2] / ".env")

JIRA_BASE_URL = os.getenv("JIRA_BASE_URL", "").rstrip("/")
JIRA_PAT = os.getenv("JIRA_PAT", "")

# ── Figma URL patterns ────────────────────────────────────────────────────────
FIGMA_URL_RE = re.compile(
    r"https://(?:www\.)?figma\.com/(?:file|design)/([A-Za-z0-9_-]+)"
    r"(?:/[^?\s]*)?(?:\?node-id=([^\s&\"]+))?"
)


def build_headers() -> dict:
    if not JIRA_PAT:
        sys.exit("❌  JIRA_PAT is not set. Check your .env file.")
    return {
        "Authorization": f"Bearer {JIRA_PAT}",
        "Accept": "application/json",
        "Content-Type": "application/json",
    }


def fetch_ticket(issue_key: str) -> dict:
    url = f"{JIRA_BASE_URL}/rest/api/2/issue/{issue_key}"
    resp = requests.get(url, headers=build_headers(), timeout=15, verify=True)

    if resp.status_code == 401:
        sys.exit("❌  401 Unauthorized — PAT is invalid or expired.")
    if resp.status_code == 404:
        sys.exit(f"❌  404 Not Found — ticket '{issue_key}' does not exist.")
    resp.raise_for_status()

    return resp.json()


def extract_figma_links(text: str) -> list[dict]:
    """Return all Figma URLs found in a block of text."""
    links = []
    for match in FIGMA_URL_RE.finditer(text or ""):
        links.append(
            {
                "url": match.group(0),
                "file_key": match.group(1),
                "node_id": match.group(2),  # None if not present
            }
        )
    return links


def parse_ticket(raw: dict) -> dict:
    fields = raw.get("fields", {})

    # ── Description (Jira Server returns plain ADF or plain text) ────────────
    description = fields.get("description") or ""
    if isinstance(description, dict):
        # Attempt to extract plain text from Atlassian Document Format (ADF)
        description = adf_to_text(description)

    # ── Comments ──────────────────────────────────────────────────────────────
    comments = []
    for c in fields.get("comment", {}).get("comments", []):
        body = c.get("body") or ""
        if isinstance(body, dict):
            body = adf_to_text(body)
        comments.append(
            {
                "author": c.get("author", {}).get("displayName"),
                "created": c.get("created"),
                "body": body,
            }
        )

    # ── Collect all text blobs to scan for Figma links ───────────────────────
    all_text = description + " " + " ".join(c["body"] for c in comments)
    figma_links = extract_figma_links(all_text)

    return {
        "key": raw.get("key"),
        "summary": fields.get("summary"),
        "status": fields.get("status", {}).get("name"),
        "priority": fields.get("priority", {}).get("name"),
        "assignee": (fields.get("assignee") or {}).get("displayName"),
        "reporter": (fields.get("reporter") or {}).get("displayName"),
        "created": fields.get("created"),
        "updated": fields.get("updated"),
        "description": description,
        "comments": comments,
        "figma_links": figma_links,   # ← extracted for use by figma/export.py
    }


def adf_to_text(node: dict, _buf: list | None = None) -> str:
    """Recursively extract plain text from an ADF node."""
    if _buf is None:
        _buf = []
    if isinstance(node, dict):
        if node.get("type") == "text":
            _buf.append(node.get("text", ""))
        for child in node.get("content", []):
            adf_to_text(child, _buf)
    return " ".join(_buf)


def main():
    if not JIRA_BASE_URL:
        sys.exit("❌  JIRA_BASE_URL is not set. Check your .env file.")

    parser = argparse.ArgumentParser(description="Fetch a Jira ticket → jira-ticket.json")
    parser.add_argument("issue_key", help="Jira issue key, e.g. PROJ-123")
    parser.add_argument(
        "--out",
        default="jira-ticket.json",
        help="Output file path (default: jira-ticket.json)",
    )
    args = parser.parse_args()

    print(f"🔍  Fetching {args.issue_key} from {JIRA_BASE_URL} ...")
    raw = fetch_ticket(args.issue_key)
    ticket = parse_ticket(raw)

    out_path = Path(args.out)
    out_path.write_text(json.dumps(ticket, indent=2, ensure_ascii=False))

    print(f"✅  Saved → {out_path}")

    if ticket["figma_links"]:
        print(f"🎨  Found {len(ticket['figma_links'])} Figma link(s):")
        for link in ticket["figma_links"]:
            node_info = f"  node-id: {link['node_id']}" if link["node_id"] else ""
            print(f"     file_key: {link['file_key']}{node_info}")
        print(f"\n💡  Run figma/export_file.py to generate figma-export.json")
    else:
        print("ℹ️   No Figma links found in this ticket.")


if __name__ == "__main__":
    main()
