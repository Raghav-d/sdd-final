# PRD — GENAI BE: API endpoint to capture the user acknowledgement
**Jira:** HRTP-8050

## Summary
As a people leader I want to be able to acknowledge that I have read the all feedback data of the associate so that I can start my interaction with the calibration assist feature. 

## Acceptance Criteria
- AC-1: Build an API endpoint to capture the acknowledgement from the PL
- AC-2: As part of thea API call we will create entries in Chat Session table(will include the initial POV and selected themes- all themes selected by default) and Acknowledgment table
- AC-3: Post endpoint - input parameter- Owner eid, associate eid, competency code, type (strength/opportunity), cycle id
  - output: session record
- AC-4: Chat Session table with below columns-
  - ID (PK) - UUID
  - owner Eid (FK)
  - associate Eid(FK)
  - Owner POV
  - competency Code
  - type (strength/opportunity)
  - cycle Id
  - Status (In Draft, Live)
  - Selected Insights (JSONB)
  - Audit Columns (created/ Last updated TS)
- AC-5: Acknowledgment table
  - Id (PK)
  - owner ID (FK)
  - Associate Eid (FK)
  - Audit Columns (created/ Last updated TS)
- AC-6: Composite key on associate EID, Created by EID, Competency code, Type and the cycle ID


## Affected files
[Your best guess at which files need changing —
archaeology.md will make this more precise]

## Out of scope
[Anything the ticket explicitly excludes]



--- New

# PRD — GENAI BE: API endpoint to capture user acknowledgement
**Jira:** HRTP-8050

## Summary
As a people leader I want to acknowledge that I have read all feedback
data for an associate so that I can start my interaction with the
calibration assist feature.

## Acceptance Criteria

- AC-1: Build a POST API endpoint to capture acknowledgement from the PL.
  Path: POST /v1/acknowledgment
  Auth: SSO required (no additional permissions beyond standard auth)

- AC-2: The endpoint creates two records atomically:
    1. A ChatSession record (with initial POV empty, all themes selected
       by default in selectedInsights)
    2. An Acknowledgment record
       Both must succeed or neither is committed (use a DB transaction).

- AC-3: Request body:
    - ownerEid (string, required)
    - associateEid (string, required)
    - competencyCode (string, required)
    - type (string enum: "strength" | "opportunity", required)
    - cycleId (number, required)

  Response (201):
    - chatSession record (full ChatSession attributes)
    - acknowledgment record (full Acknowledgment attributes)

- AC-4: ChatSession table — `chat_session` (freezeTableName: true)
  | JS field | DB column | Type | Notes |
  |---|---|---|---|
  | chatSessionId | chat_ses_id | UUID | PK, defaultValue: UUIDV4 |
  | ownerEid | ownr_eid | STRING(6) | not null |
  | associateEid | assoc_eid | STRING(6) | not null |
  | ownerPov | ownr_pov | TEXT | nullable |
  | competencyCode | cmptncy_cd | STRING(6) | not null |
  | type | type_cd | STRING(6) | not null |
  | cycleId | pm_cyc_id | INTEGER | not null |
  | status | ses_stat_cd | STRING(6) | not null, default "In Draft" |
  | selectedInsights | sel_insghts | JSONB | not null |
  | createdAt | cretd_ts | DATE | |
  | updatedAt | last_updtd_ts | DATE | |

- AC-5: Acknowledgment table — `acknowledgment` (freezeTableName: true)
  | JS field | DB column | Type | Notes |
  |---|---|---|---|
  | acknowledgmentId | ack_id | INTEGER | PK, autoIncrement |
  | ownerEid | ownr_eid | STRING(6) | not null |
  | associateEid | assoc_eid | STRING(6) | not null |
  | createdAt | cretd_ts | DATE | |
  | updatedAt | last_updtd_ts | DATE | |

- AC-6: Composite unique index on ChatSession:
  (associateEid, ownerEid, competencyCode, type, cycleId)
  Sequelize indexes block with unique: true.
  Return 400 if this combination already exists.

## New files required
- src/routes/acknowledgment/index.ts
- src/schema/acknowledgment/index.ts
- src/database/models/chatSession/index.ts
- src/database/models/acknowledgment/index.ts
- src/services/acknowledgment/index.ts
- src/routes/acknowledgment/index.test.ts

## Modified files
- src/server.ts — wire AcknowledgmentController into DI graph

## Out of scope
- Fetching or listing acknowledgments
- Updating or deleting chat sessions
- Themes reference data — selectedInsights defaults to empty array []
  until a themes source is defined