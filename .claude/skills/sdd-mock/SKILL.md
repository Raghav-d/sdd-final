---
name: sdd-mock
description: >
  Generate MSW 2.x mock handlers and fixtures from an OpenAPI spec.
  Invoke when the user says "generate mocks", "create fixtures",
  "mock the API", or runs /sdd-mock.
allowed-tools: Read, Write, Bash(cat *), Bash(ls *), Bash(find . -name *)
argument-hint: "[specs/openapi.yaml] [--output src/mocks/handlers]"
---

# SDD Mock Skill

Generate MSW 2.x handlers from an OpenAPI spec.

## Step 0 — Locate the spec and output path

Parse $ARGUMENTS BEFORE running any bash commands:
- Spec file = first token in $ARGUMENTS that does NOT start with --
- Output path = value after --output flag if present
- If no spec path given, default to: specs/openapi.yaml
- If no --output given, default to: src/mocks/handlers

Examples:
- "" → spec=specs/openapi.yaml, output=src/mocks/handlers
- "specs/openapi.yaml" → spec=specs/openapi.yaml, output=src/mocks/handlers
- "specs/openapi.yaml --output frontend/src/mocks/handlers" → as shown
- "/abs/path/specs/openapi.yaml --output /abs/path/frontend/src/mocks/handlers" → as shown

Once SPEC_PATH is resolved, read only that file.
Do NOT try any fallback paths (no openapi.json, no alternative locations).
If the resolved file does not exist, print:
"Spec file not found: [SPEC_PATH] — check the path and try again."
Then stop.

## Step 1 — Check existing mock setup

```
!`find . -name "browser.ts" -not -path "*/node_modules/*"`
```

```
!`find . -name "server.ts" -not -path "*/node_modules/*"`
```

Note what already exists. Do not overwrite existing files.

## Step 2 — Parse endpoints

For each path + method in the OpenAPI spec extract:
- Method, path, operationId
- Request body schema (if any)
- All response schemas and status codes
- Any examples blocks

Group by OpenAPI tag. One output file per tag.

## Step 3 — Generate handler files

One file per tag in the resolved output directory.

```typescript
import { http, HttpResponse } from 'msw'

/**
 * @api {METHOD} {path}
 * @operationId {operationId}
 */
export const handlers = [
  http.{method}('http://localhost:3000{path}', () => {
    return HttpResponse.json(
      { /* minimal valid response matching OpenAPI example */ },
      { status: 200 }
    )
  }),
]

// Error handlers — use these in tests with server.use(...)
export const {operationId}NotFound = http.{method}('http://localhost:3000{path}', () =>
  HttpResponse.json({ message: 'Not found' }, { status: 404 })
)

export const {operationId}ServerError = http.{method}('http://localhost:3000{path}', () =>
  HttpResponse.json({ message: 'Internal server error' }, { status: 500 })
)
```

## Step 4 — Generate browser.ts and server.ts if missing

If browser.ts is missing, generate at frontend/src/mocks/browser.ts:
```typescript
import { setupWorker } from 'msw/browser'
import { handlers } from './handlers/tasks'
export const worker = setupWorker(...handlers)
```

If server.ts is missing, generate at frontend/src/mocks/server.ts:
```typescript
import { setupServer } from 'msw/node'
import { handlers } from './handlers/tasks'
export const server = setupServer(...handlers)
```

If they already exist, print the imports to add manually — do not overwrite.

## Step 5 — Summary

Print:
- Spec file used
- Output directory
- Number of endpoints mocked
- Number of error handler exports created
- All file paths written
