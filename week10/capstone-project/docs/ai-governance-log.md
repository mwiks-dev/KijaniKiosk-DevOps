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
