# Fault Injection Log — Final Pipeline

**Week 5 — Friday — Jenkinsfile**

The final KijaniKiosk Payments Pipeline was tested by introducing failures into individual stages and confirming that Jenkins handled each failure according to the pipeline design.

The pipeline uses a Docker-based Jenkins agent to provide a consistent Node.js environment. The main flow is:

**Lint → Build → Verify (Test + Security Audit in parallel) → Archive → Publish**

Each fault was introduced independently. After testing a fault, the change was reverted and the pipeline was run again to confirm that the pipeline returned to a successful/green state before testing the next failure.

| Stage faulted  | Fault introduced                                                                         | Expected behaviour                                                                                               | Observed? | Design rationale                                                                                                                                                                                          |
| -------------- | ---------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------- | --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Lint           | Introduced invalid JavaScript syntax in the application source                           | Lint fails and all downstream stages are skipped                                                                 | Y         | The pipeline should fail as early as possible. Invalid source code should not consume resources running builds, tests, or publishing.                                                                     |
| Build          | Broke the build command/script so that the application could not produce a valid build   | Build fails; Verify, Archive and Publish are skipped                                                             | Y         | There is no valid artifact to test or release if the build cannot complete successfully.                                                                                                                  |
| Test           | Introduced a deliberately failing test assertion                                         | Test branch fails; Security Audit continues independently; Verify fails overall; Archive and Publish are skipped | Y         | Test and Security Audit are independent checks inside the parallel Verify stage. A failure in one branch must not prevent the other branch from completing.                                               |
| Security Audit | Introduced a dependency vulnerability that causes `npm audit --audit-level=high` to fail | Security Audit fails; Test continues independently; Verify fails overall; Archive and Publish are skipped        | Y         | Security validation is a release gate. Code must not be published when the dependency audit detects a vulnerability at or above the configured threshold.                                                 |
| Publish        | Used an invalid Nexus credential/configuration so authentication fails                   | Archive succeeds; Publish fails; `npm publish` does not successfully publish the package to Nexus                | Y         | Creating and retaining a Jenkins artifact is separate from releasing it to Nexus. Authentication failure must stop the release rather than allow an unauthenticated or incorrectly authenticated publish. |

## 1. Lint Fault

**Fault introduced:** A syntax error was deliberately introduced into the application source code.

The source file was modified so that the JavaScript parser could no longer correctly interpret the file.

**Observed pipeline behaviour:**

* Jenkins started the pipeline using the configured Docker agent.
* The Lint stage executed first.
* ESLint detected the syntax/parsing error.
* The Lint stage failed.
* Jenkins marked the pipeline as `FAILURE`.
* Build did not execute.
* Verify did not execute.
* Archive did not execute.
* Publish did not execute.

The downstream stages were reported as being skipped because of the earlier failure.

**Result:** Expected fail-fast behaviour was confirmed.

This demonstrates that the pipeline does not attempt to build, test, archive or publish source code that has already failed basic static validation.

---

## 2. Build Fault

**Fault introduced:** The application build command was deliberately changed so that the required build script could not be executed successfully.

The build stage therefore reached the point where `npm run build` was executed, but the required build process failed.

**Observed pipeline behaviour:**

* Lint completed successfully.
* The Build stage started.
* `npm run build` failed.
* Jenkins marked the Build stage as failed.
* Verify was skipped.
* Archive was skipped.
* Publish was skipped.
* The overall pipeline result was `FAILURE`.

**Result:** Expected behaviour was confirmed.

The pipeline correctly allowed the source to pass linting but stopped the release process when a usable build could not be produced.

The important distinction is that **passing Lint does not mean that the application is releasable**. The build itself must also succeed before testing and publishing can continue.

---

## 3. Test Fault — Verify Stage

**Fault introduced:** A test assertion was deliberately changed so that a valid application result was compared against an incorrect expected value.

The failure was introduced in the payments tests.

**Observed pipeline behaviour:**

* Lint completed successfully.
* Build completed successfully.
* Verify started.
* Verify split into its two independent branches:

  * Test
  * Security Audit
* The Test branch failed because the assertion did not match the actual result.
* The Security Audit branch continued running independently.
* Security Audit completed successfully.
* Verify was ultimately marked as failed because one of its required branches failed.
* Archive was skipped.
* Publish was skipped.
* The pipeline result was `FAILURE`.

This was an important confirmation of the parallel Verify design.

The failure of the Test branch did **not** incorrectly cause the Security Audit branch to be abandoned. Both checks are independent, but the Verify stage as a whole still acts as a gate.

**Result:** Expected behaviour was confirmed.

The design ensures that:

> Both Test and Security Audit must pass before the pipeline can proceed to Archive and Publish.

---

## 4. Security Audit Fault — Verify Stage

**Fault introduced:** A dependency with a known high/critical-severity vulnerability was introduced into the project dependencies.

The Security Audit stage runs:

```bash
npm audit --audit-level=high
```

The vulnerable dependency caused the audit command to return a non-zero exit status.

**Observed pipeline behaviour:**

* Lint completed successfully.
* Build completed successfully.
* Verify started.
* Test and Security Audit ran independently.
* The Test branch completed successfully.
* Security Audit detected the vulnerable dependency.
* `npm audit --audit-level=high` returned a failure.
* Verify was marked as failed.
* Archive was skipped.
* Publish was skipped.
* The overall pipeline result was `FAILURE`.

**Result:** Expected security-gate behaviour was confirmed.

The pipeline therefore treats a failed security audit as a release-blocking failure. A build cannot be published simply because its functional tests pass.

This is important for the production design because a technically correct application can still be unsafe to release if it contains a known high-severity dependency vulnerability.

---

## 5. Publish Fault

**Fault introduced:** The Nexus publishing configuration was deliberately broken by using an invalid Jenkins credential/configuration.

The purpose of this test was to confirm that the pipeline does not treat successful artifact creation as equivalent to successful publication.

**Observed pipeline behaviour:**

* Lint completed successfully.
* Build completed successfully.
* Verify completed successfully.
* Archive completed successfully.
* The generated artifact was retained by Jenkins.
* The artifact was fingerprinted by Jenkins.
* Publish then attempted to use the invalid credential/configuration.
* Jenkins failed during the publishing stage.
* The package was not successfully published to Nexus.
* The pipeline result was `FAILURE`.

**Result:** Expected Publish-stage failure behaviour was confirmed.

This demonstrates the separation between:

**Archive**

and

**Publish**

The pipeline is therefore able to preserve a successfully built artifact in Jenkins even when the external release operation fails.

This is preferable to treating the build and external publication as one operation because a release may fail for infrastructure, authentication, repository, or credential reasons even when the application itself is valid.

---

# Overall Fault-Injection Result

All five major pipeline failure paths were tested independently.

| Test                           | Result    |
| ------------------------------ | --------- |
| Lint failure                   | Confirmed |
| Build failure                  | Confirmed |
| Test failure                   | Confirmed |
| Security Audit failure         | Confirmed |
| Publish/authentication failure | Confirmed |

The pipeline consistently demonstrated the intended fail-fast and release-gating behaviour:

```text
Lint
  ↓
Build
  ↓
Verify
 ┌───────────────┐
 ↓               ↓
Test       Security Audit
 └───────┬───────┘
         ↓
      Archive
         ↓
      Publish
         ↓
       Nexus
```

Failures in **Lint** prevent all downstream stages from running.

Failures in **Build** prevent Verify, Archive and Publish from running.

Failures in either **Test** or **Security Audit** cause the overall Verify stage to fail while allowing the independent Verify branch to complete. Because Verify is a release gate, Archive and Publish are then skipped.

A failure during **Publish** occurs after the artifact has already been successfully archived, demonstrating that artifact retention and external release are intentionally separate concerns.

After each fault was removed, the pipeline was rerun to confirm that the Jenkinsfile returned to its normal successful execution path.

## Final Conclusion

The fault-injection exercises demonstrate that the final KijaniKiosk Jenkins pipeline behaves as a controlled CI/CD release pipeline rather than simply executing commands sequentially.

The pipeline:

* Fails early when source validation fails.
* Does not build invalid or unverified code.
* Requires a successful build before verification.
* Runs functional testing and security auditing independently.
* Treats both testing and security as mandatory release gates.
* Preserves successfully generated artifacts in Jenkins.
* Separates artifact archival from external publication.
* Prevents failed authentication or publishing configuration from resulting in an unintended Nexus release.
* Returns to a successful state after each injected fault is reverted.

This confirms that the final Jenkinsfile provides the intended **fail-fast, parallel verification, artifact retention, credential isolation, and controlled publication** behaviour required for the KijaniKiosk production-grade payments pipeline.
