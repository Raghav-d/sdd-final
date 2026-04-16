---
name: sdd-modify
description: >
  Patch an existing file in the repo using updated specs.
  Invoke when the user says "modify", "patch", "update existing",
  "change an existing component", or runs /sdd-modify.
  Never rewrites the whole file — applies surgical, non-breaking changes.
allowed-tools: Read, Write, Bash(find . -name *), Bash(cat *), Bash(npx tsc *), Bash(npx vitest *)
argument-hint: "<relative/path/to/File.tsx>"
---

# SDD Modify Skill

You are executing the Spec-Driven Development **modify** workflow.
Apply the minimum change that satisfies the updated spec. Break nothing.

## Step 0 — Check argument

If $ARGUMENTS is empty, list existing components and stop:

```
!`find . -name "*.tsx" -not -path "*/node_modules/*" -not -name "*.test.tsx" -not -name "*.stories.tsx" | head -20`
```

Print: "No file specified. Re-run with a path, e.g:
`/sdd-modify src/features/TaskList/TaskList.tsx`"

## Step 1 — Load target file and related files

```
!`cat $ARGUMENTS`
```

If file not found, stop and report the exact path tried.

Find related files:
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

## Step 2 — Load updated specs

```
!`cat specs/prd.md`
```

```
!`cat specs/openapi.yaml`
```

## Step 3 — Change impact analysis

Identify:
1. Affected sections — functions, JSX blocks, types the new spec touches
2. Preserved sections — everything not mentioned in the spec (do not touch)
3. New AC delta — ACs not yet handled
4. API delta — new or changed endpoints/schemas
5. Risk surface — anything that could break existing tests

Print analysis (max 15 lines).
Ask: "Proceed with patch? (yes / adjust)"
Wait for confirmation.

## Step 4 — Apply the patch

Rules:
- Never rewrite code the spec does not mention
- Preserve all existing @spec / @figma / @api JSDoc tags
- Add new @spec tags for every new AC or endpoint implemented
- Update type interfaces only where the API schema changed
- Add tests for new ACs without removing any existing test cases
- If a prop is renamed, update component + tests + story in one pass

After each file write, check types:
```
!`npx tsc --noEmit 2>&1 | head -20`
```

Fix errors before moving to the next file.

## Step 5 — Regression check

```
!`npx vitest run 2>&1 | tail -20`
```

Fix failures caused by your change.
Report pre-existing failures to the user — do not fix them silently.

## Step 6 — Diff summary

Print a plain summary:

```
Modified: src/features/TaskList/TaskList.tsx
  + Handles AC-5: empty state when no tasks exist
  + @api GET /tasks → 200 with empty array

Modified: src/features/TaskList/TaskList.test.tsx
  + describe('AC-5 — empty state') — 2 new test cases
```
