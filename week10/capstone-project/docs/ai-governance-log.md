# AI Governance Log

This document records meaningful use of AI during the KijaniKiosk Track B capstone. AI-generated recommendations are reviewed, tested, corrected,
and approved by the engineer before being incorporated into the project.

## Governance Requirements

Each entry records:

1. Date
2. Tool used
3. Task description
4. What was provided to the AI
5. What the AI produced
6. What it got right
7. What it got wrong
8. What was changed before applying the output

## Entry 1

* **Date:** 2026-08-23
* **Tool used:** ChatGPT (GPT-5.6 Luna)
* **Task description:** Extend the `kk-analytics` design with structured correlation and event identifiers and define an explicit idempotency strategy for duplicate receipt events.
* **What was provided to the AI:** The Track B requirement for `kk-analytics` to process receipt events and produce analytics summaries. The additional requirements were that meaningful logs must carry `eventId`, `correlationId`, `receiptId`, `function`, and `timestamp`, and that the system must explicitly define what happens if the same event, such as `E001`, arrives more than once.
* **What the AI produced:** A structured logging design containing the five required metadata fields and an idempotency strategy using `eventId` as the idempotency key. The proposed behaviour is to process a previously unseen event, record its `eventId`, and prevent the same event from being aggregated again if it is received a second time.
* **What it got right:** The design separates event identity from workflow correlation. `eventId` identifies an individual event, `correlationId` allows the event to be traced across services, and `receiptId` identifies the business receipt. The strategy also directly addresses the main capstone risk of duplicate delivery: a repeated event must not increase `receiptCount` or `totalAmount` twice.
* **What required verification:** The AI proposed the idempotency behaviour but did not establish a persistent distributed idempotency store. This is intentional for the capstone scope. The strategy must be implemented in a way that is testable and appropriate to the actual deployment architecture before it is considered production-ready.
* **What was changed before applying the output:** The README was updated to document the required structured log fields, an example analytics log, the `eventId`-based idempotency strategy, duplicate-event behaviour, and verification requirements. The design explicitly avoids introducing an unnecessarily complex distributed state system at this stage.
* **Verification planned:** Unit tests should verify that a first occurrence of an event is processed and that a duplicate `eventId` is not aggregated twice. Integration testing should later verify duplicate-event behaviour through the deployed serverless workflow.
* **Governance consideration:** The idempotency approach was treated as a design decision requiring human review rather than automatically accepting AI-generated architecture. The implementation must be evaluated against the capstone's scope, testability, deployment environment, and production-readiness requirements before final deployment.

## Entry 2

* **Date:** 2026-08-23
* **Tool used:** ChatGPT (GPT-5.6 Luna)
* **Task description:** Complete the `kk-notifier` serverless function for Phase 4 of the Track B capstone and create unit tests for its validation, notification payload, structured logging, and handler behaviour.
* **What was provided to the AI:** The existing `kk-notifier` skeleton:
* **What the AI produced:** A refactored `kk-notifier` implementation with separate `validateEvent`, `createNotification`, `logNotification`, and `handler` responsibilities. The implementation validates the event identity and receipt fields, creates a structured downstream notification payload, and produces machine-readable JSON logs containing `level`, `function`, `eventType`, `eventId`, `correlationId`, `receiptId`, and `timestamp`.
* **What it got right:** The implementation preserved the existing notification behaviour while separating responsibilities to make the function easier to test and maintain. It also added validation for `receiptId`, `amount`, and `timestamp`, ensuring malformed receipt events are rejected before downstream processing. Structured logging was aligned with the Phase 3 observability requirements.
* **What was changed before applying the output:** The generated implementation was reviewed against the existing capstone architecture and kept deliberately small. Unit tests were added in `tests/unit/kk-notifier.test.js` covering valid events, invalid inputs, notification payload creation, default processing status, structured logging, and successful handler execution.
* **Governance decision:** The AI-generated implementation was accepted only after checking that it preserved the existing function's intended behaviour and did not introduce unnecessary infrastructure. S3 persistence was intentionally not added at this stage because it belongs to the next Phase 4 integration step, where `kk-notifier` will write to the configured output bucket and `kk-analytics` will be triggered by an S3 `ObjectCreated` event.

## Entry 3

- **Date:** 2026-08-23
- **Tool used:** ChatGPT (GPT-5.6 Luna)
- **Task description:** Implement the Kubernetes `kk-payments` integration with the staging S3 receipt bucket so that an actual payment generated through `POST /payments` produces a receipt event and stores the resulting JSON object in the configured staging bucket.
- **What was provided to the AI:** The existing `kk-payments` service structure, the Phase 5 requirements, the `RECEIPTS_BUCKET` configuration requirement, the existing Kubernetes `kk-payments-config` containing `RECEIPTS_BUCKET=kijanikiosk-receipts-staging`, and the requirement that the receipt must be generated by `kk-payments` rather than manually uploaded to S3.
- **What the AI produced:** Guidance and implementation for adding the AWS SDK for JavaScript S3 client, configuring the S3 client, validating payment input, generating `eventId`, `correlationId`, and receipt information, writing the receipt event to the configured S3 bucket using `PutObjectCommand`, and adding structured success and error logs. It also provided verification commands for `/health`, `POST /payments`, and the resulting S3 object.
- **What it got right:** The implementation preserved the required integration seam by making `kk-payments` the source of the receipt event. It used the existing `RECEIPTS_BUCKET` environment variable rather than hard-coding the bucket into the application logic. It also maintained the structured logging convention using fields such as `function`, `eventType`, `eventId`, `correlationId`, `receiptId`, `amount`, `bucket`, `objectKey`, and `timestamp`.
- **What required verification/correction:** The generated implementation was treated as a starting point rather than automatically accepted. The service process was first found to be suspended after `Ctrl+Z`, which caused HTTP requests to connect but not receive responses. The process was restarted correctly and `/health` was used to verify service availability before testing `POST /payments`. AWS credentials, bucket existence, region, and S3 write permissions must also be verified independently before treating the S3 integration as successful.
- **Human decision and validation:** The implementation was reviewed against the Phase 5 requirements before use. The intended flow is `kk-payments → staging receipt bucket`, with the payment endpoint generating the receipt rather than manually placing an S3 object. Successful integration will be demonstrated by submitting a payment through `POST /payments` and verifying that the corresponding `receipts/<receiptId>.json` object appears in the staging bucket.
- **Governance control:** AI-generated code was reviewed and tested before acceptance. No credentials or secret values were placed directly in the source code. Environment-specific configuration remains externalized through Kubernetes configuration and environment variables.