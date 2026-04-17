---
name: jira
description: >
  Fetch a Jira ticket from a self-hosted Jira Server/Data Center instance
  using a Bearer PAT and save it to specs/jira-ticket.json.
  Invoke when the user says "fetch ticket", "get story", "read jira",
  "pull ticket", or provides a Jira issue key like PROJ-123 or ABC-456.
  Also automatically extracts any Figma URLs found in the ticket description
  or comments for use by the figma skill.
allowed-tools: Read, Write, Bash(python3 *), Bash(cat *), Bash(ls *)
argument-hint: "<ISSUE-KEY> [--out path/to/output.json]"
---

# Jira Skill — Fetch Ticket

You are executing the **jira fetch** workflow.
Your goal: retrieve a Jira ticket and save it to specs/jira-ticket.json.

## Step 0 — Check argument

If $ARGUMENTS is empty, stop and print:
"No issue key provided. Re-run with a key, e.g:
`/jira PROJ-123`"

## Step 1 — Check environment

Verify .env exists and contains JIRA_PAT:

```
!`ls .env 2>/dev/null || echo "NO_ENV"`
```

```
!`cat .env`
```

If .env is missing or JIRA_PAT is empty, stop and print:
"`.env` not found or JIRA_PAT is not set.
Copy `.env.example` → `.env` and fill in your PAT.
Get a PAT: Jira → Profile → Personal Access Tokens → Create token"

## Step 2 — Check for the fetch script

```
!`ls .claude/skills/jira/get_ticket.py 2>/dev/null || echo "MISSING"`
```

If missing, stop and print:
"Skill script not found: `.claude/skills/jira/get_ticket.py`
Re-run setup to reinstall the skills."

## Step 3 — Fetch the ticket

Parse $ARGUMENTS:
- Issue key = first token (e.g. PROJ-123)
- --out = custom output path if provided, otherwise use specs/jira-ticket.json

Ensure specs/ directory exists:

```
!`mkdir -p specs`
```

Run the fetch:

```
!`python3 .claude/skills/jira/get_ticket.py ISSUE_KEY --out specs/jira-ticket.json`
```

Replace ISSUE_KEY with the actual value from $ARGUMENTS.

If the script exits with an error, print the error message and stop.

## Step 4 — Confirm output

```
!`cat specs/jira-ticket.json`
```

Print a summary:

```
Jira ticket fetched — specs/jira-ticket.json
─────────────────────────────────────────────
Key:      [key]
Summary:  [summary]
Status:   [status]
Priority: [priority]
Assignee: [assignee]
```

If figma_links is non-empty, print:

```
Figma links found: N
  → Run /figma to export design specs
```

If figma_links is empty, print:
"No Figma links found in this ticket."

## Step 5 — Next step guidance

If figma_links were found:
"Ready for Figma export. Run:
  `/figma --from-jira specs/jira-ticket.json`"

If this ticket is being used with sdd-generate:
"To generate a component from this spec:
  `/sdd-generate [ComponentName]`
  (ensure specs/prd.md and specs/openapi.yaml are also present)"
