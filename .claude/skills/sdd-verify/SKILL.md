---
name: sdd-verify
description: >
  Audit an existing component file against the PRD and API contract.
  No code is generated or modified. Reports gaps, missing tests, and drift.
  Invoke when the user says "verify", "audit", "check against spec",
  or runs /sdd-verify.
allowed-tools: Read, Bash(find . -name *), Bash(cat *), Bash(ls *)
argument-hint: "<relative/path/to/File.tsx>"
---

# SDD Verify Skill

Read everything. Write nothing. Report gaps.

## Step 0 — Check argument

If $ARGUMENTS is empty, list available components and stop:

```
!`find . -name "*.tsx" -not -path "*/node_modules/*" -not -name "*.test.tsx" -not -name "*.stories.tsx" | head -30`
```

Print: "No file specified. Re-run with a path, e.g:
`/sdd-verify src/features/TaskList/TaskList.tsx`"

## Step 1 — Load target file

```
!`cat $ARGUMENTS`
```

If file not found, print:
"File not found: $ARGUMENTS"
Then stop.

## Step 2 — Load spec files

```
!`cat specs/prd.md`
```

```
!`cat specs/openapi.yaml`
```

Only read figma-export.json if it exists:
```
!`ls specs/figma-export.json 2>/dev/null && cat specs/figma-export.json || echo "NO_FIGMA"`
```

Note any missing spec files in the report but continue with what is available.

## Step 3 — Load test and service files

```
!`find . -name "*.test.tsx" -not -path "*/node_modules/*"`
```

```
!`find . -name "*.service.ts" -not -path "*/node_modules/*"`
```

```
!`find . -name "*.types.ts" -not -path "*/node_modules/*"`
```

Read the ones related to the target component.

## Step 4 — Acceptance criteria coverage

For every AC in the PRD:
- Find the code path in the component
- Find the test case in the test file
- Mark:
  - ✅ implemented + tested
  - ⚠️ implemented, not tested
  - ❌ not implemented

## Step 5 — API coverage

For every endpoint in the OpenAPI spec used by this component:
- Called in the service file? ✅ / ❌
- Request types correct against schema? ✅ / ⚠️ / ❌
- All non-2xx response codes handled? ✅ / ⚠️ / ❌
- All non-2xx codes tested with MSW overrides? ✅ / ⚠️ / ❌

## Step 6 — Accessibility audit

Check for:
- All interactive elements have accessible name
- Form fields have associated labels
- Error messages use role="alert"
- Loading states use aria-busy
- No tabIndex > 0
- Focus not lost after async actions

## Step 7 — Report

```
SDD Verify Report — [filename]
==============================

ACCEPTANCE CRITERIA
✅ AC-1 ...
⚠️ AC-2 ... — implemented, no test
❌ AC-3 ... — not implemented

API COVERAGE
✅ POST /tasks — typed, errors handled, tested
⚠️ DELETE /tasks/:id — called but 404 not handled

ACCESSIBILITY
✅ Form fields labelled
❌ Error state missing role="alert"

SUMMARY
ACs:  X/Y fully covered | Z untested | W missing
APIs: X/Y fully covered | Z partial
A11y: X violations found

Recommended next step:
  /sdd-modify $ARGUMENTS
```
