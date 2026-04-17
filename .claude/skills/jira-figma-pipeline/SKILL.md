---
name: jira-figma-pipeline
description: >
  Run the full Jira → Figma → sdd-generate pipeline in one shot.
  Fetches a Jira ticket, extracts and exports any Figma design linked in it,
  then scaffolds a component using /sdd-generate.
  Invoke when the user says "full pipeline", "fetch and generate",
  "run jira to component", or "pipeline PROJ-123 ComponentName".
allowed-tools: Read, Write, Bash(python3 *), Bash(cat *), Bash(ls *), Bash(mkdir *)
argument-hint: "<ISSUE-KEY> <ComponentName>"
---

# Jira → Figma → Generate Pipeline

You are executing the **full design-to-code pipeline**:
Jira ticket → Figma export → component scaffold.

## Step 0 — Check arguments

Parse $ARGUMENTS:
- Token 1 = issue key (e.g. PROJ-123) — required
- Token 2 = component name (e.g. LoginForm) — required

If either is missing, stop and print:
"Two arguments required. Usage:
  `/jira-figma-pipeline PROJ-123 LoginForm`"

## Step 1 — Fetch Jira ticket

Use the jira skill:
"Fetching Jira ticket [ISSUE_KEY]..."

```
!`mkdir -p specs`
```

```
!`python3 .claude/skills/jira/get_ticket.py ISSUE_KEY --out specs/jira-ticket.json`
```

On error, stop and print the error. Do not continue.

Print: "✓ specs/jira-ticket.json written"

## Step 2 — Export Figma (if links found)

```
!`cat specs/jira-ticket.json`
```

If figma_links is non-empty:
  Print: "Figma link(s) found — exporting..."

  ```
  !`python3 .claude/skills/figma/export_file.py --from-jira specs/jira-ticket.json --out specs/figma-export.json`
  ```

  On error, warn but continue:
  "⚠️  Figma export failed — continuing without design tokens.
   /sdd-generate will derive visual structure from the PRD instead."

  On success, print: "✓ specs/figma-export.json written"

If figma_links is empty:
  Print: "No Figma links in ticket — skipping Figma export.
  /sdd-generate will use PRD and OpenAPI spec only."

## Step 3 — Verify sdd-generate prerequisites

Check that required spec files exist:

```
!`ls specs/prd.md 2>/dev/null || echo "MISSING_PRD"`
```

```
!`ls specs/openapi.yaml 2>/dev/null || echo "MISSING_OPENAPI"`
```

If specs/prd.md is missing, stop and print:
"specs/prd.md is required for /sdd-generate.
Run Session 1 (PM agent) first: `bash sessions.sh session1`
Then re-run this pipeline."

If specs/openapi.yaml is missing, stop and print:
"specs/openapi.yaml is required for /sdd-generate.
Run Session 2 (Architect agent) first: `bash sessions.sh session2`
Then re-run this pipeline."

## Step 4 — Run sdd-generate

Print: "Generating component [ComponentName]..."

Use the sdd-generate skill with ComponentName as the argument.

## Step 5 — Pipeline summary

Print a final status table:

```
Pipeline complete
─────────────────────────────────────────────
Jira ticket:    specs/jira-ticket.json  ✓
Figma export:   specs/figma-export.json ✓ / skipped
Component:      src/features/[Name]/    ✓

Files generated:
  [Name].tsx
  [Name].module.css
  [Name].types.ts
  [name].service.ts
  [Name].test.tsx
  [Name].stories.tsx

Next: run `npx vitest run src/features/[Name]` to verify tests pass.
```
