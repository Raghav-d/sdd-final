#!/usr/bin/env bash
# crud-app session scripts — run from inside your crud-app/ directory
#
# Usage:
#   bash sessions.sh setup
#   bash sessions.sh session1
#   bash sessions.sh session2
#   bash sessions.sh session3
#   bash sessions.sh session4
#   bash sessions.sh session5

# ── Adjust these three paths to match your machine ───────────────────────────
AGENCY_AGENTS=~/agency-agents
SPEC_KIT=~/spec-kit
SDD_SKILLS=~/sdd-skills-fixed   # folder extracted from the zip
# ─────────────────────────────────────────────────────────────────────────────

setup() {
  echo ""
  echo "Setting up crud-app..."
  echo ""

  # Verify dependencies
  if [ ! -d "$AGENCY_AGENTS" ]; then
    echo "✗ agency-agents not found at: $AGENCY_AGENTS"
    echo "  Clone it: git clone https://github.com/msitarzewski/agency-agents ~/agency-agents"
    exit 1
  fi
  if [ ! -d "$SPEC_KIT" ]; then
    echo "✗ spec-kit not found at: $SPEC_KIT"
    echo "  Clone it: git clone https://github.com/github/spec-kit ~/spec-kit"
    exit 1
  fi
  if [ ! -d "$SDD_SKILLS" ]; then
    echo "✗ sdd-skills-fixed not found at: $SDD_SKILLS"
    echo "  Extract the zip and set the SDD_SKILLS path at the top of this script"
    exit 1
  fi

  # Directories
  mkdir -p specs
  mkdir -p .claude/skills/sdd-generate
  mkdir -p .claude/skills/sdd-modify
  mkdir -p .claude/skills/sdd-verify
  mkdir -p .claude/skills/sdd-mock
  mkdir -p .claude/commands
  mkdir -p .claude/rules

  # SDD skills
  cp $SDD_SKILLS/.claude/skills/sdd-generate/SKILL.md .claude/skills/sdd-generate/
  cp $SDD_SKILLS/.claude/skills/sdd-modify/SKILL.md   .claude/skills/sdd-modify/
  cp $SDD_SKILLS/.claude/skills/sdd-verify/SKILL.md   .claude/skills/sdd-verify/
  cp $SDD_SKILLS/.claude/skills/sdd-mock/SKILL.md     .claude/skills/sdd-mock/
  cp $SDD_SKILLS/.claude/commands/*.md                .claude/commands/
  echo "✓ SDD skills installed"

  # spec-kit templates — exact filenames confirmed from local clone
  cp $SPEC_KIT/templates/spec-template.md      specs/prd-template.md
  echo "✓ spec-template.md      → specs/prd-template.md"

  cp $SPEC_KIT/templates/plan-template.md      specs/plan-template.md
  echo "✓ plan-template.md      → specs/plan-template.md"

  cp $SPEC_KIT/templates/checklist-template.md specs/qa-checklist-template.md
  echo "✓ checklist-template.md → specs/qa-checklist-template.md"

  cp $SPEC_KIT/templates/tasks-template.md     specs/tasks-template.md
  echo "✓ tasks-template.md     → specs/tasks-template.md"

  # Brief
  if [ ! -f specs/brief.md ]; then
    cat > specs/brief.md << 'BRIEF'
# Brief — Task Manager

A simple task management app. Users can create, read, update, and delete tasks.
Each task has a title, description, status (todo/in-progress/done), and due date.
The frontend is a React SPA. The backend is a Node/Express REST API with
in-memory storage (no database for this prototype). No authentication required.
BRIEF
    echo "✓ specs/brief.md created — edit this before running session1"
  else
    echo "  specs/brief.md already exists — skipping"
  fi

  # Stack rules
  cat > .claude/rules/stack.md << 'STACK'
# Stack Rules

## Frontend
- React 18 + TypeScript strict mode
- Vite
- CSS Modules
- React Query for data fetching
- Vitest + React Testing Library
- MSW 2.x for API mocking in tests
- Playwright for e2e tests

## Backend
- Node.js + Express + TypeScript
- In-memory storage (no database)
- Vitest + Supertest for API tests

## Output paths
- Frontend components: frontend/src/features/
- Backend routes: backend/src/routes/
- MSW handlers: frontend/src/mocks/handlers/
- E2E tests: e2e/

## API
- Base URL: http://localhost:3000
- Frontend env var: VITE_API_URL
- Backend env var: PORT (default 3000)

## Code style
- No `any` types
- Named exports only for types and services
- JSDoc @spec tags linking code to AC numbers
STACK
  echo "✓ .claude/rules/stack.md written"

  echo ""
  echo "────────────────────────────────────────"
  echo "Setup complete."
  echo ""
  echo "Next steps:"
  echo "  1. Edit specs/brief.md with your feature description"
  echo "  2. Run: bash sessions.sh session1"
  echo ""
}


session1() {
  echo ""
  echo "Composing CLAUDE.md for Session 1 — PM Agent..."

  cat $AGENCY_AGENTS/product/product-manager.md > CLAUDE.md

  cat >> CLAUDE.md << 'EOF'

## Your task this session

You are the product manager formalizing a feature brief into a spec.

Read these two files:
- specs/brief.md         — the raw feature brief
- specs/prd-template.md  — the spec-kit spec template you must fill in

Produce specs/prd.md by filling in every section of specs/prd-template.md
using the information in specs/brief.md.

Rules:
- Do not change the template structure or headings
- Populate every section — no placeholders, no "TBD"
- Number every acceptance criterion as AC-1, AC-2, AC-3 etc.
- Each AC must be specific and testable — not vague
- List every API endpoint the feature needs
- Do not generate any code
- Do not create any file other than specs/prd.md
- When finished, print exactly: PRD complete — ready for human review
  then stop
EOF

  echo "✓ CLAUDE.md composed"
  echo ""
  echo "────────────────────────────────────────"
  echo "Now run:  claude"
  echo ""
  echo "Prompt to paste inside Claude Code:"
  echo ""
  echo "  Read specs/brief.md and specs/prd-template.md,"
  echo "  then produce specs/prd.md following your instructions."
  echo ""
  echo "After Claude finishes:"
  echo "  → Review specs/prd.md"
  echo "  → Check every AC is specific and testable"
  echo "  → Edit freely — this is your checkpoint"
  echo "  → When satisfied: bash sessions.sh session2"
  echo ""
}


session2() {
  echo ""
  echo "Composing CLAUDE.md for Session 2 — Architect Agent..."

  cat $AGENCY_AGENTS/engineering/engineering-software-architect.md > CLAUDE.md

  cat >> CLAUDE.md << 'EOF'

## Your task this session

You are the software architect designing the implementation.

Read these files first:
- specs/prd.md
- specs/plan-template.md
- specs/tasks-template.md

Produce three files:

### 1. specs/architecture.md
Fill in specs/plan-template.md with:
- Frontend component tree (name, what it renders, what data it needs)
- Backend route structure (method, path, handler name per endpoint)
- TypeScript interfaces for every data entity
- State management approach
- Error handling strategy

### 2. specs/tasks.md
Fill in specs/tasks-template.md with:
- Backend tasks (one per route)
- Frontend tasks (one per component)
- Testing tasks
Each task references the AC it satisfies.

### 3. specs/openapi.yaml
Complete OpenAPI 3.1 spec:
- Every endpoint from the PRD
- Request/response schemas for all status codes (200/201, 400, 404, 500)
- At least one example per response
- Shared schemas in components/schemas

Rules:
- Do not generate any application code
- Output only the three spec files above
- When finished, print exactly: Architecture complete — ready for human review
  then stop
EOF

  echo "✓ CLAUDE.md composed"
  echo ""
  echo "────────────────────────────────────────"
  echo "Now run:  claude"
  echo ""
  echo "Prompt to paste inside Claude Code:"
  echo ""
  echo "  Read specs/prd.md, specs/plan-template.md, and specs/tasks-template.md,"
  echo "  then produce specs/architecture.md, specs/tasks.md, and specs/openapi.yaml"
  echo "  following your instructions."
  echo ""
  echo "After Claude finishes:"
  echo "  → Check openapi.yaml covers every endpoint in the PRD"
  echo "  → Check architecture.md has TypeScript interfaces"
  echo "  → When satisfied: bash sessions.sh session3"
  echo ""
}


session3() {
  echo ""
  echo "Composing CLAUDE.md for Session 3 — Backend Dev Agent..."

  cat $AGENCY_AGENTS/engineering/engineering-senior-developer.md > CLAUDE.md

  cat >> CLAUDE.md << 'EOF'

## Your task this session

You are building the Node/Express backend.

Read all of these before writing any code:
- specs/prd.md
- specs/architecture.md
- specs/openapi.yaml
- specs/tasks.md
- .claude/rules/stack.md

### Required output structure
backend/
├── package.json
├── tsconfig.json
└── src/
    ├── index.ts            — Express app, PORT from env or 3000
    ├── routes/             — one file per API tag in openapi.yaml
    ├── types/              — interfaces matching openapi.yaml schemas
    ├── middleware/
    │   ├── errorHandler.ts
    │   └── requestLogger.ts
    ├── store/
    │   └── inMemoryStore.ts
    └── tests/              — one test file per route file

Rules:
- Every route in openapi.yaml must be implemented
- Every AC in prd.md that involves the API must have a test
- Tests: Vitest + Supertest, happy path + every error code per endpoint
- JSDoc @spec AC-N on every route handler
- No any types
- Run npm test before finishing — all tests must pass
- When finished, print exactly: Backend complete — ready for human review
  then stop
EOF

  echo "✓ CLAUDE.md composed"
  echo ""
  echo "────────────────────────────────────────"
  echo "Now run:  claude"
  echo ""
  echo "Prompt to paste inside Claude Code:"
  echo ""
  echo "  Read the specs and generate the complete backend"
  echo "  following your instructions."
  echo ""
  echo "After Claude finishes:"
  echo "  → cd backend && npm install && npm test"
  echo "  → All tests must pass before proceeding"
  echo "  → When satisfied: bash sessions.sh session4"
  echo ""
}


session4() {
  echo ""
  echo "Composing CLAUDE.md for Session 4 — Frontend Dev Agent..."

  cat $AGENCY_AGENTS/engineering/engineering-frontend-developer.md > CLAUDE.md

  cat >> CLAUDE.md << 'EOF'

## Your task this session

You are building the React frontend.

Read all of these before writing any code:
- specs/prd.md
- specs/architecture.md
- specs/openapi.yaml
- specs/tasks.md
- .claude/rules/stack.md

Use the SDD skills in this order:

### Step 1 — Generate MSW mock handlers
Run: /sdd-mock specs/openapi.yaml --output frontend/src/mocks/handlers

### Step 2 — Generate each component
For each component in specs/architecture.md, run:
/sdd-generate [ComponentName]

### Step 3 — Wire the app
Create:
- frontend/src/App.tsx
- frontend/src/main.tsx
- frontend/package.json
- frontend/vite.config.ts
- frontend/index.html

Rules:
- Components go in frontend/src/features/
- Every AC touching the UI must have a unit test
- Tests: Vitest + React Testing Library + MSW (never call real API)
- No any types
- Run npm test before finishing — all tests must pass
- When finished, print exactly: Frontend complete — ready for human review
  then stop
EOF

  echo "✓ CLAUDE.md composed"
  echo ""
  echo "────────────────────────────────────────"
  echo "Now run:  claude"
  echo ""
  echo "Inside Claude Code, run this first:"
  echo "  /sdd-mock specs/openapi.yaml --output frontend/src/mocks/handlers"
  echo ""
  echo "Then paste this prompt:"
  echo "  Read the specs and generate the complete frontend"
  echo "  following your instructions."
  echo ""
  echo "After Claude finishes:"
  echo "  → cd frontend && npm install && npm test"
  echo "  → All tests must pass before proceeding"
  echo "  → When satisfied: bash sessions.sh session5"
  echo ""
}


session5() {
  echo ""
  echo "Composing CLAUDE.md for Session 5 — QA Agent..."

  if [ -f "$AGENCY_AGENTS/quality/qa-engineer.md" ]; then
    cat $AGENCY_AGENTS/quality/qa-engineer.md > CLAUDE.md
    echo "  Using: quality/qa-engineer.md"
  else
    cat $AGENCY_AGENTS/engineering/engineering-senior-developer.md > CLAUDE.md
    echo "  Note: quality/qa-engineer.md not found — using engineering-senior-developer.md"
  fi

  cat >> CLAUDE.md << 'EOF'

## Your task this session

You are the QA engineer writing end-to-end tests.

Read these files first:
- specs/prd.md                   — every AC must have an e2e test
- specs/qa-checklist-template.md — use as your coverage checklist
- backend/src/                   — understand the API
- frontend/src/                  — understand the UI

### Required output structure
e2e/
├── playwright.config.ts
├── tasks-crud.spec.ts       — create, read, update, delete
├── tasks-validation.spec.ts — form validation, error states
└── tasks-states.spec.ts     — loading, empty, error UI states

### playwright.config.ts webServer config
- Backend server: command "npm start", cwd "backend", port 3000
- Frontend server: command "npm run dev", cwd "frontend", port 5173
- baseURL: http://localhost:5173

Rules:
- One test per AC minimum — label each: it('AC-1: ...')
- No mocking — test real backend + frontend integration
- After writing all tests, print an AC coverage table:

  | AC   | File                       | Test name                |
  |------|----------------------------|--------------------------|
  | AC-1 | tasks-crud.spec.ts         | creates a new task       |

- When finished, print exactly: QA complete — ready for human review
  then stop
EOF

  echo "✓ CLAUDE.md composed"
  echo ""
  echo "────────────────────────────────────────"
  echo "Now run:  claude"
  echo ""
  echo "Prompt to paste inside Claude Code:"
  echo ""
  echo "  Read the PRD, qa-checklist-template, and generated code,"
  echo "  then write the complete e2e test suite following your instructions."
  echo ""
  echo "After Claude finishes:"
  echo "  → cd backend && npm start  (in one terminal)"
  echo "  → cd frontend && npm run dev  (in another terminal)"
  echo "  → npx playwright test"
  echo "  → Review the AC coverage table Claude printed"
  echo ""
}


# Entry point
case "$1" in
  setup)    setup ;;
  session1) session1 ;;
  session2) session2 ;;
  session3) session3 ;;
  session4) session4 ;;
  session5) session5 ;;
  *)
    echo ""
    echo "Usage: bash sessions.sh <command>"
    echo ""
    echo "  setup     — install skills, copy spec-kit templates, scaffold project"
    echo "  session1  — PM agent     : brief → PRD (spec-kit spec-template)"
    echo "  session2  — Architect    : PRD → architecture + openapi.yaml"
    echo "  session3  — Backend dev  : specs → Express API + tests"
    echo "  session4  — Frontend dev : specs → React app via SDD skills"
    echo "  session5  — QA engineer  : code → Playwright e2e tests"
    echo ""
    echo "Run in order. Review and approve output between every session."
    echo ""
    ;;
esac
