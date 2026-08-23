# KijaniKiosk Track B Capstone

## 1. Project Overview

### Phase 0 — Project Foundation

The capstone repository was initialized with separate directories for serverless handlers, Kubernetes configuration, testing, scripts, documentation, and evidence.

The project uses feature branches, conventional commits, pull requests, and documented AI governance throughout development.

### Phase 1 — Scope and Architecture

Track B was selected because the capstone extends the existing KijaniKiosk serverless receipt architecture into a complete event-driven workflow with downstream analytics.

The central integration seam is the flow from the Kubernetes `kk-payments` service into the serverless receipt chain.

### Phase 2 — Serverless Project and Testing Setup

Phase 2 establishes the local Serverless Framework project and prepares the repository for automated testing.

The project contains separate unit and integration test directories. Jest is used as the test runner, with dedicated npm commands for running unit and integration tests.

The intended test commands are:

```bash
npm test
```

and:

```bash
npm run test:integration
```

### Phase 3 — Build `kk-analytics`

Phase 3 introduces the fourth serverless function required by Track B: `kk-analytics`.

The responsibility of `kk-analytics` is to receive receipt events, validate the required receipt fields, aggregate receipt information, produce a structured analytics summary, and log the resulting summary.

The processing flow is:

```text
Receive receipt event
        ↓
Validate required fields
        ↓
Aggregate
        ↓
Produce structured summary
        ↓
Log summary
```

The required analytics metrics are:

* `receiptCount` — number of valid receipts processed.
* `totalAmount` — sum of the receipt amounts.
* `firstReceiptAt` — timestamp of the earliest receipt.
* `lastReceiptAt` — timestamp of the latest receipt.

The analytics function is implemented in:

```text
src/
└── kk-analytics/
    └── handler.js
```

The unit tests are implemented in:

```text
tests/
└── unit/
    └── kk-analytics.test.js
```

The `kk-analytics` implementation validates the following required receipt fields:

```text
receiptId
amount
timestamp
```

Invalid receipts are rejected rather than being included in the analytics calculation.

For an empty receipt collection, the function produces:

```json
{
  "receiptCount": 0,
  "totalAmount": 0,
  "firstReceiptAt": null,
  "lastReceiptAt": null
}
```

A successful analytics calculation produces a structured summary such as:

```json
{
  "receiptCount": 2,
  "totalAmount": 2500,
  "firstReceiptAt": "2026-08-23T08:00:00.000Z",
  "lastReceiptAt": "2026-08-23T09:00:00.000Z"
}
```

### Phase 3.5 — Correlation and Event IDs

Meaningful `kk-analytics` logs must contain consistent identifiers and metadata so that individual receipt events can be traced through the serverless workflow.

The required log fields are:

```text
eventId
correlationId
receiptId
function
timestamp
```

Example structured log:

```json
{
  "eventId": "E001",
  "correlationId": "C001",
  "receiptId": "RCP-001",
  "function": "kk-analytics",
  "timestamp": "2026-08-23T10:30:00.000Z",
  "message": "Analytics summary generated",
  "summary": {
    "receiptCount": 1,
    "totalAmount": 1500,
    "firstReceiptAt": "2026-08-23T10:30:00.000Z",
    "lastReceiptAt": "2026-08-23T10:30:00.000Z"
  }
}
```

The identifiers have the following purposes:

* `eventId` uniquely identifies the individual event.
* `correlationId` allows the same transaction or workflow to be traced across multiple services.
* `receiptId` identifies the receipt being processed.
* `function` identifies the Lambda function generating the log.
* `timestamp` records when the log entry was generated.

This structure will make the event flow easier to demonstrate and troubleshoot during the capstone presentation.

### Phase 3.6 — Idempotency Strategy

`kk-analytics` must have an explicit strategy for handling duplicate events.

For example, if event `E001` arrives twice:

```text
E001
 ↓
kk-analytics
 ↓
Analytics summary generated

E001
 ↓
kk-analytics
 ↓
Duplicate detected
 ↓
Existing result reused / event ignored
```

The capstone uses the `eventId` as the idempotency key.

The intended rule is:

```text
Same eventId
    ↓
Already processed?
    ├── YES → Do not aggregate again
    └── NO  → Process and record eventId
```

This prevents a duplicated delivery of the same event from incorrectly increasing `receiptCount` or `totalAmount`.

For the capstone implementation, idempotency does not require a large distributed state-management system. The important requirement is that the strategy is explicit, testable, and reflected in the application design.

The expected behaviour is:

```text
First arrival of E001
    → Process event
    → Generate analytics
    → Record E001 as processed

Second arrival of E001
    → Detect duplicate eventId
    → Do not aggregate again
```

An integration test should eventually verify that sending the same event twice does not double-count the receipt.

### Phase 3 Verification

Run the complete unit test suite:

```bash
npm test
```

Run only the `kk-analytics` unit tests:

```bash
npx jest tests/unit/kk-analytics.test.js --verbose
```

The expected processing behaviour is:

```text
Receipt event
     ↓
Required-field validation
     ↓
Duplicate/idempotency check
     ↓
Aggregation
     ↓
receiptCount
totalAmount
firstReceiptAt
lastReceiptAt
     ↓
Structured summary
     ↓
Structured log
```

## 2. Problem Statement

KijaniKiosk currently processes receipt events through an asynchronous serverless workflow but does not provide downstream aggregation of receipt information.

The capstone extends this workflow with a fourth `kk-analytics` function that consumes the output of `kk-notifier`, aggregates receipt information, and produces a structured analytics summary.

## 3. Track

**Track B — Serverless and Event-Driven Analytics**

The project combines Kubernetes, AWS serverless services, event-driven processing, and Jenkins CI/CD automation.

## 4. Objectives

The project objectives are to:

1. Add the `kk-analytics` serverless function.
2. Connect `kk-notifier` output to `kk-analytics`.
3. Deploy the complete serverless stack to staging.
4. Integrate the Kubernetes `kk-payments` service with the serverless workflow.
5. Establish automated unit and integration testing.
6. Use Jenkins to deploy and validate staging.
7. Require human approval before production promotion.

## 5. Architecture

```text
                    +----------------------+
                    |     kk-payments      |
                    |   Kubernetes Service |
                    +----------+-----------+
                               |
                         Receipt Event
                               |
                               v
                     +-------------------+
                     |     S3 Bucket     |
                     +---------+---------+
                               |
                               v
                     +-------------------+
                     |   kk-validator    |
                     +---------+---------+
                               |
                               v
                     +-------------------+
                     |   kk-processor    |
                     +---------+---------+
                               |
                               v
                     +-------------------+
                     |    kk-notifier    |
                     +---------+---------+
                               |
                               v
                     +-------------------+
                     |   kk-analytics    |
                     +---------+---------+
                               |
                               v
                  Structured Analytics Summary
```

Jenkins controls deployment and promotion between staging and production.

## 6. Event Flow

The expected receipt-processing flow is:

```text
kk-payments
    |
    v
S3 receipt event
    |
    v
kk-validator
    |
    v
kk-processor
    |
    v
kk-notifier
    |
    v
kk-analytics
    |
    v
Analytics Summary
```

The analytics summary contains:

* Receipt count
* Total receipt amount
* First receipt timestamp
* Last receipt timestamp

## 7. Technology Stack

* AWS Lambda
* Amazon S3
* Serverless Framework
* Node.js
* npm
* Jest
* Kubernetes
* Jenkins
* Docker
* Git/GitHub

## 8. Repository Structure

The repository is organized into application code, infrastructure, tests, scripts, documentation, and evidence.

```text
kijanikiosk/
├── src/
│   ├── kk-validator/
│   ├── kk-processor/
│   ├── kk-notifier/
│   └── kk-analytics/
│       └── handler.js
├── tests/
│   ├── unit/
│   │   ├── smoke.test.js
│   │   └── kk-analytics.test.js
│   └── integration/
│       └── smoke.test.js
├── scripts/
├── docs/
├── evidence/
├── serverless.yml
├── jest.config.js
├── package.json
├── package-lock.json
└── README.md
```

## 9. Prerequisites

The following software is required for local development:

* Node.js 18+
* npm
* Git
* Serverless Framework
* AWS CLI
* AWS credentials with permission to deploy the required resources

Verify Node.js:

```bash
node --version
```

Verify npm:

```bash
npm --version
```

Verify Git:

```bash
git --version
```

Verify the Serverless Framework:

```bash
serverless --version
```

Verify the AWS CLI:

```bash
aws --version
```

Verify AWS authentication:

```bash
aws sts get-caller-identity
```

Clone the repository:

```bash
git clone <repository-url>
```

Move into the project:

```bash
cd <project-directory>
```

## 10. Environment Configuration

Before deploying, configure the AWS credentials required by the project.

Verify the active AWS identity:

```bash
aws sts get-caller-identity
```

The Serverless Framework should use the configured AWS credentials when deploying the application.

Do not commit credentials, access keys, passwords, tokens, or secrets to Git.

## 11. Local Development

Install project dependencies:

```bash
npm install
```

Inspect the installed dependencies:

```bash
npm list --depth=0
```

Run the Serverless project locally using the project's configured commands.

To inspect available Serverless commands:

```bash
serverless --help
```

To validate the Serverless configuration:

```bash
serverless print --stage staging
```

## 12. Installing Dependencies

Dependencies are installed from `package.json` and `package-lock.json`.

For a fresh checkout:

```bash
npm install
```

For a clean, reproducible installation in CI:

```bash
npm ci
```

If Jest is not already installed:

```bash
npm install --save-dev jest
```

The testing configuration is stored in:

```text
jest.config.js
```

## 13. Running Tests

Run the unit test suite:

```bash
npm test
```

Run the integration test suite:

```bash
npm run test:integration
```

Run Jest directly:

```bash
npx jest
```

Run Jest in verbose mode:

```bash
npx jest --verbose
```

The test directories are:

```text
tests/
├── unit/
└── integration/
```

Unit tests are intended to validate individual functions and components.

Integration tests will validate the receipt-processing workflow across the serverless components.

## 14. Deploying Staging

Deploy the complete Serverless application to staging:

```bash
serverless deploy --stage staging
```

Inspect the generated configuration:

```bash
serverless print --stage staging
```

After deployment, verify the deployed resources using the AWS CLI or Serverless Framework output.

## 15. Staging Integration Test

The staging integration test will verify that a receipt generated by `kk-payments` can travel through the serverless workflow.

The expected flow is:

```text
kk-payments
      ↓
S3
      ↓
kk-validator
      ↓
kk-processor
      ↓
kk-notifier
      ↓
kk-analytics
      ↓
Analytics Summary
```

Run the integration tests with:

```bash
npm run test:integration
```

The expected analytics output contains:

```text
receipt count
total amount
first timestamp
last timestamp
```

## 16. Production Promotion

Production deployment must not occur automatically after code is pushed.

The Jenkins pipeline follows this sequence:

```text
Code Push
    ↓
Build
    ↓
Unit Tests
    ↓
Staging Deployment
    ↓
Integration Tests
    ↓
PASS
    ↓
Human Approval
    ↓
Production Deployment
```

The production deployment command is:

```bash
serverless deploy --stage production
```

Production promotion requires explicit human approval after successful staging validation.

## 17. Failure Handling

If unit tests fail, the Jenkins pipeline must stop before staging deployment.

```text
Unit Test Failure
       ↓
Pipeline Stops
```

If staging deployment fails:

```text
Staging Deployment Failure
       ↓
Production Blocked
```

If staging integration tests fail:

```text
Integration Test Failure
       ↓
Production Blocked
```

Only a successful staging deployment and successful integration test may proceed to the approval stage.

## 18. Security and Governance

The project follows these security practices:

* No credentials are committed to Git.
* AWS credentials are supplied through the appropriate credential mechanism.
* Secrets are not hard-coded into application source code.
* Production deployment requires human approval.
* Changes are reviewed through Git-based version control.
* Deployment environments are explicitly separated into staging and production.

Check the repository for accidentally committed secrets:

```bash
git grep -n -iE "password|secret|token|access_key|private_key"
```

Review tracked files:

```bash
git status
```

Review recent commits:

```bash
git log --oneline --decorate -10
```

## 19. AI Governance

AI tools may be used as development assistance but do not replace engineering verification or human decision-making.

AI-generated code and documentation must be reviewed before being committed.

Sensitive information, credentials, private keys, and production secrets must not be provided to AI tools.

Final deployment and production-promotion decisions remain under human control.

## 20. Verification

Verify the local project structure:

```bash
tree -L 3
```

Verify dependencies:

```bash
npm install
```

Run unit tests:

```bash
npm test
```

Run integration tests:

```bash
npm run test:integration
```

Validate the Serverless configuration:

```bash
serverless print --stage staging
```

Deploy staging:

```bash
serverless deploy --stage staging
```

Verify the Git working tree:

```bash
git status
```

## 21. Known Limitations

The current capstone does not implement:

* Multi-region deployment
* A real third-party payment provider
* An enterprise data warehouse
* A full BI/dashboard platform
* Autonomous AI deployment
* Enterprise-scale disaster recovery

The initial integration tests may use controlled test data before the complete Kubernetes-to-serverless integration is validated.

## 22. Production Readiness

The system will be considered ready for the capstone production-promotion stage when:

1. The complete four-function serverless stack deploys successfully.
2. Unit tests pass.
3. Staging integration tests pass.
4. `kk-payments` successfully initiates the receipt workflow.
5. `kk-analytics` produces the expected analytics summary.
6. Jenkins enforces the staging → test → approval → production sequence.
7. No credentials or secrets are exposed in source code or logs.

## 23. Cleanup

Remove the staging Serverless deployment when it is no longer required:

```bash
serverless remove --stage staging
```

Remove the production deployment only when authorized:

```bash
serverless remove --stage production
```

Verify the deployment has been removed using the AWS console or AWS CLI.

## 24. Change History

### Phase 0

* Initialized the capstone repository.
* Established repository structure.
* Established Git workflow and governance practices.

### Phase 1

* Selected Track B.
* Defined the serverless analytics extension.
* Defined the Kubernetes-to-serverless integration.
* Defined staging and production promotion requirements.

### Phase 2

* Established the Serverless Framework project structure.
* Added project dependencies.
* Added Jest testing configuration.
* Created `tests/unit/`.
* Created `tests/integration/`.
* Added `npm test`.
* Added `npm run test:integration`.
* Added initial smoke tests to verify the testing setup.
* Documented local development and testing commands.

### Phase 3

- Added the `kk-analytics` serverless function responsibility.
- Added receipt validation and analytics aggregation requirements.
- Defined `receiptCount`, `totalAmount`, `firstReceiptAt`, and `lastReceiptAt`.
- Added structured logging requirements for `eventId`, `correlationId`, `receiptId`, `function`, and `timestamp`.
- Defined an `eventId`-based idempotency strategy.
- Documented duplicate-event handling.
- Added verification requirements for analytics and idempotency behaviour.