# KijaniKiosk Payments Pipeline — Board Document for Nia

## What happens when a developer pushes code

When a developer makes a change and pushes it, the pipeline automatically checks whether that change is safe and ready to be shared with the rest of the team.

The process starts with a basic quality check. The system looks for mistakes in the code before spending time building or testing it. If the code passes, the application is built to make sure it can actually be packaged successfully.

Next, the application goes through two independent checks. The first checks whether the application behaves as expected. The second checks its dependencies for known security vulnerabilities. Both checks need to pass before the process can continue.

Once everything has passed, the resulting package is saved as an identifiable build. It is then sent to the team's package repository, where it can be retrieved and used later.

The goal is simple: **only code that has passed the agreed checks should become an official package for the team to consume.**

### Pipeline at a glance

| Stage                       | What it confirms                                                                                     |
| --------------------------- | ---------------------------------------------------------------------------------------------------- |
| **Lint**                    | The source code follows the expected rules and can be understood correctly.                          |
| **Build**                   | The application can be successfully built into a usable package.                                     |
| **Verify — Test**           | The application behaves according to its expected functionality.                                     |
| **Verify — Security Audit** | The application's dependencies do not contain vulnerabilities above the accepted security threshold. |
| **Archive**                 | A successful package has been saved and can be identified and retrieved from the build system.       |
| **Publish**                 | The approved package has been sent to the team's package repository for wider use.                   |

The flow is therefore:

**Developer pushes code → Lint → Build → Verify (Test + Security Audit) → Archive → Publish**

The verification checks run independently, but both must succeed before the package can move forward.

## What Happens When Something Goes Wrong

The pipeline is designed to stop rather than allow a problem to move further down the process.

If the code fails the initial quality check, the build does not continue. If the build fails, there is no package to test or publish, so the remaining release steps are stopped.

If a functional test fails, the security check can still finish so the team gets a complete picture of the change. However, the overall verification step is considered unsuccessful. The same applies if the security check finds a serious dependency vulnerability.

In either case, **nothing is published**.

The team can then see that the change needs attention and fix the problem before trying again. This prevents a known-bad change from becoming an official package that other parts of the system could depend on.

A failure during the final publishing step is handled differently. The package may already have been successfully saved by the build system, but it is not considered released until the publishing step succeeds. For example, an authentication or repository problem can prevent publication even when all code checks have passed.

This separation gives the team two useful guarantees: a successful build can be retained for investigation or reference, while an unsuccessful release cannot quietly appear in the package repository.

The process has been deliberately tested by introducing failures at different stages. These tests confirmed that failures in code quality, building, testing, security checks, and publishing stop the appropriate part of the process and prevent an unsuccessful change from being published.

## What this gives the team

For the team, the main benefit is consistency. Every change goes through the same checks instead of relying on someone to remember each step manually.

It also creates a clear definition of "ready." A change is not ready simply because it works on a developer's machine. It must pass code-quality checks, build successfully, pass its tests, meet the security threshold, and successfully complete the release process.

This reduces the chance of distributing broken code or code with known serious dependency vulnerabilities. It also gives the team a repeatable record of what happened to each change.

## Honest scope

This pipeline currently focuses on **continuous integration and controlled package publishing**, not the complete deployment lifecycle. It does not automatically deploy the application to production, provide an automated rollback mechanism, or perform performance and load testing. The current setup also uses a single staging environment rather than validating changes across multiple environments. Finally, publishing does not currently require a separate manual approval before it happens.

These are deliberate boundaries for the current stage of the project. Automated deployment, rollback, and broader environment validation can be added as the delivery process develops further.
