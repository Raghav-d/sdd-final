cat > .claude/rules/stack.md << 'EOF'
# Stack Rules — HORIZON-pme-calibration-api

## Runtime
- Node.js 22+
- TypeScript 5.4+
- ESM project ("type": "module") — all imports use .js extension

## Framework
- Fastify 5.x
- Zod + fastify-type-provider-zod for schema validation
- Manual dependency injection (no Inversify decorators)
  — services constructed with new in server.ts

## Database
- Sequelize 6.x + PostgreSQL
- freezeTableName: true on all models
- Column naming: abbreviated snake_case (e.g. ownr_eid, cmptncy_cd)
- JS field naming: camelCase full words
- PKs: INTEGER autoIncrement unless UUID explicitly required
- Timestamps: cretd_ts, last_updtd_ts

## Auth
- SSO via @cof/pme-common-backend addAuthPreHandlersToRoutes
- request.user = { userid: string, permissions: string[] }
- auth: false only for /health

## Error handling
- try/catch in every handler
- Error response shape: { error: true, message: string }
- Domain errors mapped to HTTP status codes

## Capital One packages
- @cof/horizon-logger — structured logging
- @cof/pme-common-backend — SSO, ERROR_MESSAGES, TaskResponse
- @cof/pme-crypto — field-level encryption

## Naming conventions
- Controllers: <Domain>Controller
- Services: <Domain>Service / I<Domain>Service
- DAOs: <Domain>Dao
- Routes: src/routes/<domain>/index.ts
- Schemas: src/schema/<domain>/index.ts
- Models: src/database/models/<domain>/index.ts
  EOF