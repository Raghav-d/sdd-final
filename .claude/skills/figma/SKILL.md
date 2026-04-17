---
name: figma
description: >
  Export a Figma file or specific node/frame to specs/figma-export.json
  using the Figma REST API and a Personal Access Token.
  Can be driven by a raw Figma URL, a file key + node ID, or auto-read
  Figma links from specs/jira-ticket.json produced by the jira skill.
  Invoke when the user says "export figma", "get figma design",
  "generate figma-export", "fetch design", pastes a figma.com URL, or runs /figma.
  Output is consumed by /sdd-generate as optional design token input.
allowed-tools: Read, Write, Bash(python3 *), Bash(cat *), Bash(ls *)
argument-hint: "[<figma-url>] | [--from-jira specs/jira-ticket.json] | [--file-key KEY --node-id ID] [--format png|svg]"
---

# Figma Skill — Export Design

You are executing the **figma export** workflow.
Your goal: fetch Figma component metadata and image export URLs,
then save them to specs/figma-export.json for use by /sdd-generate.

## Step 0 — Parse arguments

Parse $ARGUMENTS before running any bash commands.

Figma URL patterns to recognise:
```
https://www.figma.com/file/{FILE_KEY}/Title
https://www.figma.com/file/{FILE_KEY}/Title?node-id={NODE_ID}
https://www.figma.com/design/{FILE_KEY}/Title
https://www.figma.com/design/{FILE_KEY}/Title?node-id={NODE_ID}
```

Resolution rules (apply in order):

1. **Raw URL** — if $ARGUMENTS starts with `https://www.figma.com` or
   `https://figma.com`, extract:
   - `file_key` = path segment after `/file/` or `/design/`
   - `node_id`  = value of `node-id` query param (omit if absent)
   - Treat as equivalent to `--file-key {file_key} --node-id {node_id}`

2. **`--file-key`** — use provided key + optional `--node-id`

3. **`--from-jira`** — read Figma links from the specified jira-ticket.json

4. **Empty $ARGUMENTS** — default to `--from-jira specs/jira-ticket.json`

Also parse `--format png|svg|pdf|jpg` from $ARGUMENTS (default: png).

## Step 1 — Check environment

```
!`ls .env 2>/dev/null || echo "NO_ENV"`
```

```
!`cat .env`
```

If .env is missing or FIGMA_PAT is empty, stop and print:
"`.env` not found or FIGMA_PAT is not set.
Copy `.env.example` → `.env` and fill in your PAT.
Get a PAT: Figma → Account Settings → Security → Personal access tokens → Create new token"

## Step 2 — Check for the export script

```
!`ls .claude/skills/figma/export_file.py 2>/dev/null || echo "MISSING"`
```

If missing, stop and print:
"Skill script not found: `.claude/skills/figma/export_file.py`
Re-run setup to reinstall the skills."

## Step 3 — Validate input source

If running in --from-jira mode:

```
!`ls specs/jira-ticket.json 2>/dev/null || echo "MISSING"`
```

If missing, stop and print:
"specs/jira-ticket.json not found.
Run `/jira PROJ-123` first to fetch the ticket."

Read the jira ticket to confirm figma_links exist:

```
!`cat specs/jira-ticket.json`
```

If figma_links is empty, stop and print:
"No Figma links found in specs/jira-ticket.json.
Confirm the Jira ticket description or comments contain a Figma URL.
Or paste a URL directly: `/figma https://www.figma.com/design/ABC123/...`"

## Step 4 — Run the export

Ensure specs/ directory exists:

```
!`mkdir -p specs`
```

Build the python3 command from the resolved arguments:

- Raw URL or --file-key mode:
  `python3 .claude/skills/figma/export_file.py --file-key {file_key} [--node-id {node_id}] [--format {fmt}] --out specs/figma-export.json`

- --from-jira mode:
  `python3 .claude/skills/figma/export_file.py --from-jira specs/jira-ticket.json [--format {fmt}] --out specs/figma-export.json`

If the script exits with an error, print the error and stop.

## Step 5 — Confirm output

```
!`cat specs/figma-export.json`
```

Print a summary per exported file:

```
Figma export complete — specs/figma-export.json
────────────────────────────────────────────────
File key:   [file_key]
Node ID:    [node_id or "full file"]
Components: N frames/components exported
Format:     [export_format]
```

List each component name, type, and whether an export_url was returned.

If any export_url is null, warn:
"⚠️  Some nodes have no export URL — the node may be empty or hidden in Figma."

## Step 6 — Next step guidance

"specs/figma-export.json is ready.
/sdd-generate will use it automatically if specs/prd.md and specs/openapi.yaml are also present.

To generate a component:
  `/sdd-generate [ComponentName]`

⚠️  Export URLs are pre-signed and expire in ~30 days.
   Download images now if you need them long-term."
