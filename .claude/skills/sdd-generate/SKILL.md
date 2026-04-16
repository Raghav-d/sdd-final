---
name: sdd-generate
description: >
  Scaffold a fully-tested component from PRD, optional Figma export, and API
  contract. Invoke when the user says "generate MFE", "create component from
  specs", "scaffold from spec", or runs /sdd-generate.
allowed-tools: Read, Write, Bash(find . -name *), Bash(cat *), Bash(ls *), Bash(npx tsc *), Bash(npx prettier *)
argument-hint: "[ComponentName] [--styles modules|tailwind|styled]"
---

# SDD Generate Skill

You are executing the Spec-Driven Development **generate** workflow.
Your goal: produce a PR-ready, fully-tested component from the spec artifacts.

## Step 0 — Check argument

If no ComponentName was provided ($ARGUMENTS is empty):
- Read specs/prd.md to infer a component name from the first feature or title
- Confirm with the user: "No component name provided. I'll generate
  `[InferredName]` — proceed? (yes / rename to X)"
- Wait for confirmation before generating anything

## Step 1 — Load spec files

```
!`ls specs/`
```

```
!`cat specs/prd.md`
```

```
!`cat specs/openapi.yaml`
```

```
!`cat specs/architecture.md`
```

Only read figma-export.json if it exists — it is optional:
```
!`ls specs/figma-export.json 2>/dev/null && cat specs/figma-export.json || echo "NO_FIGMA — continuing without design tokens"`
```

```
!`cat .claude/rules/stack.md`
```

If specs/prd.md is missing, stop and say:
"specs/prd.md is required. Run Session 1 (PM agent) first."

## Step 2 — Check for existing component

```
!`find . -name "$ARGUMENTS.tsx" -not -path "*/node_modules/*"`
```

If the component already exists, stop and say:
"$ARGUMENTS.tsx already exists. Use /sdd-modify to update it."

## Step 3 — Build spec manifest (internal only, do not output in full)

Parse all loaded inputs and produce a mental manifest:
- Design tokens from figma-export.json if present — skip gracefully if absent
- Acceptance criteria numbered AC-1, AC-2… from prd.md
- API endpoints, request/response shapes, error codes from openapi.yaml
- Component responsibilities from architecture.md

Print a brief summary (max 10 lines) for the user to review.
Ask: "Proceed with generation? (yes / adjust)"
Wait for confirmation.

## Step 4 — Determine output path

If stack.md specifies an output directory, use it.
Otherwise default to: src/features/$ARGUMENTS/

## Step 5 — Generate files in order

Generate each file fully. No placeholders. Real working code.
If Figma is absent, derive visual structure from the PRD and architecture.

### File 1: src/features/{Name}/{Name}.tsx
- Typed props interface derived from OpenAPI response schema
- Every AC from the PRD handled in component logic
- Loading, error, and empty states always present
- Accessible: aria attributes, keyboard navigation, focus management
- JSDoc tags on every logical block:
  `/** @spec PRD AC-1 */`
  `/** @api POST /endpoint */`
  `/** @figma ComponentName/Variant */` (only if Figma was provided)

### File 2: src/features/{Name}/{Name}.module.css
- CSS custom properties for any design tokens (if Figma provided)
- No magic numbers — use variables or explicit named values
- One class per major layout section

### File 3: src/features/{Name}/{Name}.types.ts
- All TypeScript interfaces derived from OpenAPI components/schemas
- Export: {Name}Props, {Name}State, and all API request/response types
- No `any` types anywhere

### File 4: src/features/{Name}/{name}.service.ts
- One typed function per API endpoint
- Error class per non-2xx status code from OpenAPI spec
- JSDoc `@api` tag on every function

### File 5: src/features/{Name}/{Name}.test.tsx
- One describe block per AC (labelled AC-1, AC-2…)
- Happy path test for each AC
- Error state test for each non-2xx API response code
- MSW server.use() overrides inside error tests
- At least one axe accessibility check

### File 6: src/features/{Name}/{Name}.stories.tsx
- One story per Figma variant (or Default/Loading/Error if no Figma)
- Args typed against {Name}Props
- MSW handlers in parameters.msw.handlers

## Step 6 — Post-generation type check

```
!`npx tsc --noEmit 2>&1 | head -30`
```

If TypeScript errors exist, fix them before reporting completion.

## Step 7 — Summary

Print a table:

| File | ACs covered | API endpoints |
|---|---|---|
| {Name}.tsx | AC-1, AC-2… | GET /x, POST /y |
| {Name}.test.tsx | AC-1, AC-2… | all error codes |

Then: "Run `npx vitest run src/features/{Name}` to verify tests pass."
