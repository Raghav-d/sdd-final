# SDD Toolkit — Spec-Driven Development for Claude Code

A set of Claude Code skills that turn a PRD + API contract into a
fully-tested React/Node application — one session per role, with a
human verification checkpoint between each.

Validated on Claude Code v2.1.107 with a Claude Pro subscription.

---

## What it does

```
Brief → PRD → Architecture → Backend → Frontend → E2E Tests
         ↑           ↑            ↑          ↑           ↑
      human       human        human      human       human
      reviews     reviews      reviews    reviews     reviews
```

Each arrow is a Claude Code session with a specific agent persona.
Each checkpoint is you reading and approving the output before proceeding.
No session proceeds without a human approval.

---

## Prerequisites

| Tool | Install |
|---|---|
| Claude Code | `npm install -g @anthropic-ai/claude-code` |
| Claude Pro subscription | Required for Claude Code |
| Node.js 18+ | `node --version` to check |
| agency-agents | `git clone https://github.com/msitarzewski/agency-agents ~/agency-agents` |
| spec-kit | `git clone https://github.com/github/spec-kit ~/spec-kit` |

---

## Install into a project

```bash
mkdir my-project && cd my-project

# Copy the .claude folder from this repo into your project
cp -r /path/to/sdd-final/.claude .

# Run setup (pulls spec-kit templates, creates specs/ scaffold)
bash /path/to/sdd-final/sessions.sh setup
```

---

## The five sessions

### Session 1 — PM Agent writes the PRD

```bash
bash sessions.sh session1
claude
```

Prompt to paste:
```
Read specs/brief.md and specs/prd-template.md,
then produce specs/prd.md following your instructions.
```

Output: `specs/prd.md`
Your job: read every AC, make sure each is specific and testable, edit freely.

---

### Session 2 — Architect designs the system

```bash
bash sessions.sh session2
claude
```

Prompt to paste:
```
Read specs/prd.md, specs/plan-template.md, and specs/tasks-template.md,
then produce specs/architecture.md, specs/tasks.md, and specs/openapi.yaml
following your instructions.
```

Output: `specs/architecture.md`, `specs/tasks.md`, `specs/openapi.yaml`
Your job: check openapi.yaml covers every PRD endpoint. Edit if needed.

---

### Session 3 — Backend dev generates the Express API

```bash
bash sessions.sh session3
claude
```

Prompt to paste:
```
Read the specs and generate the complete backend following your instructions.
```

Output: `backend/` — routes, types, middleware, tests
Your job:
```bash
cd backend && npm install && npm test
```
All tests must pass before session 4.

---

### Session 4 — Frontend dev generates the React app

```bash
bash sessions.sh session4
claude
```

Inside Claude Code, run the mock skill first:
```
/sdd-mock specs/openapi.yaml --output frontend/src/mocks/handlers
```

Then paste this prompt:
```
Read the specs and generate the complete frontend following your instructions.
```

Output: `frontend/` — components, tests, MSW handlers, App.tsx
Your job:
```bash
cd frontend && npm install && npm test
```

**Important:** If `/sdd-mock` fails or if components are not generated,
bypass the skills and ask Claude directly:

```
Read specs/prd.md, specs/architecture.md, and specs/openapi.yaml.
There is no Figma export — generate components from the PRD and API spec only.
Create: frontend/src/features/TaskList/TaskList.tsx, TaskList.test.tsx etc.
Stack: React 18, TypeScript, CSS Modules, React Query, MSW 2.x.
```

---

### Session 5 — QA agent writes Playwright e2e tests

```bash
bash sessions.sh session5
claude
```

Prompt to paste:
```
Read the PRD, qa-checklist-template, and generated code,
then write the complete e2e test suite following your instructions.
```

Output: `e2e/` — Playwright tests, one per AC
Your job:
```bash
# Terminal 1
cd backend && npm start

# Terminal 2
cd frontend && npm run dev

# Terminal 3
npx playwright test
```

---

## SDD Skills reference

The four skills live in `.claude/skills/` and are invoked as slash commands.

### `/sdd-generate [ComponentName]`

Generates a fully-tested component from specs. Figma export is optional —
if `specs/figma-export.json` is absent, the skill continues using the PRD
and OpenAPI spec only.

Generates:
- `ComponentName.tsx` — component with all AC logic
- `ComponentName.module.css` — styles
- `ComponentName.types.ts` — TypeScript interfaces from OpenAPI
- `componentName.service.ts` — typed fetch layer
- `ComponentName.test.tsx` — one describe per AC
- `ComponentName.stories.tsx` — one story per variant

### `/sdd-modify <path/to/File.tsx>`

Patches an existing component to satisfy updated specs.
Never rewrites code the spec does not mention.
Runs type-check and tests after every file write.

Always pass the file path argument:
```
/sdd-modify src/features/TaskList/TaskList.tsx
```

### `/sdd-verify <path/to/File.tsx>`

Audits an existing component against the PRD. Reads only, writes nothing.
Reports: AC coverage, API coverage, accessibility violations.

Always pass the file path argument:
```
/sdd-verify src/features/TaskList/TaskList.tsx
```

### `/sdd-mock [spec/path] [--output path]`

Generates MSW 2.x handlers from an OpenAPI spec.

Always pass the spec path explicitly:
```
/sdd-mock specs/openapi.yaml --output frontend/src/mocks/handlers
```

---

## Known issues and workarounds

### `/sdd-mock` — "cat: specs/openapi.json: No such file"

The old skill tried a hardcoded fallback to `openapi.json`.
The version in this repo is fixed. If you see this error, verify the skill
file is from this repo:

```bash
grep "openapi.json" .claude/skills/sdd-mock/SKILL.md
# should return nothing
```

If it returns a match, overwrite with the correct file from this repo.

### `/sdd-generate` — "cat: specs/figma-export.json: No such file"

This is non-fatal. The skill is supposed to continue without Figma.
If Claude stops instead of continuing, bypass the skill:

```
Read specs/prd.md and specs/openapi.yaml.
There is no Figma export.
Generate [ComponentName] directly without using any skill.
```

### Shell command substitution errors

Claude Code blocks `$()` and backtick command substitution in skill bash blocks.
All skills in this repo use only simple commands (cat, find, ls) to avoid this.
If you edit a skill and add `$()`, it will fail.

### Session limit reached mid-session

Claude Code has a context limit per session. If you hit it:
1. Start a new `claude` session
2. Re-run `bash sessions.sh sessionN` to re-compose CLAUDE.md
3. Ask Claude to continue from where it left off, referencing the files
   already written: "Continue generating the backend — routes/tasks.ts
   is done, now generate routes/users.ts"

---

## Adapting for Capital One (internal teams)

To use this with Capital One tooling:

1. **Replace the PM persona** with the Capital One Agent-Personalities
   frontend or product persona from `cof-sandbox/Agent-Personalities`

2. **Add Omni/Gravity design system** — point `.claude/rules/stack.md`
   at `local-docs/lightframe/` and specify your design system:
   ```
   ## Design system
   - Omni (primary)
   - Component docs: ../local-docs/omni/
   ```

3. **Add LightFrame registration** — add a rule describing the
   `lightframe: { packageType: app }` config your MFE needs in package.json

4. **Compose personas** for cross-functional sessions:
   ```bash
   cat ~/agency-agents/product/product-manager.md \
       ~/agency-agents/quality/qa-engineer.md \
       > CLAUDE.md
   ```

---

## File structure

```
.claude/
├── skills/
│   ├── sdd-generate/SKILL.md   — new component from specs
│   ├── sdd-modify/SKILL.md     — patch existing component
│   ├── sdd-verify/SKILL.md     — audit without generating
│   └── sdd-mock/SKILL.md       — MSW handlers from OpenAPI
├── commands/
│   ├── sdd-generate.md         — /sdd-generate alias
│   ├── sdd-modify.md           — /sdd-modify alias
│   ├── sdd-verify.md           — /sdd-verify alias
│   └── sdd-mock.md             — /sdd-mock alias
└── rules/
    ├── stack.md                — tech stack (edit to match your project)
    └── accessibility.md        — WCAG 2.1 AA requirements

sessions.sh                     — session setup scripts
```

---

## Traceability

Every generated code block carries JSDoc tags linking back to its spec:

```typescript
/** @spec PRD AC-3 — submitting form sends POST /tasks */
/** @api POST /tasks → 201 Created */
```

This lets you grep for any AC number and find every line it produced:

```bash
grep -r "@spec PRD AC-3" frontend/src/
```
