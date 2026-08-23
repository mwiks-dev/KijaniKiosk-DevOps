# Two Ways to Deploy the Payments Service — A Comparison for the Board

**Prepared for:** Nia, Engineering Lead
**Purpose:** Board presentation comparison of the current blue/green deployment model and the newer container-based cluster approach.

## What We Compared

We evaluated two complete deployment approaches for the payments service.

The first is our current **blue/green deployment model**, where two complete versions of the service run side by side on a server. One environment serves customers while the other remains ready as a standby. When a new version is released, it is deployed to the inactive environment, tested, and then customer traffic is switched to it. If the new version fails, traffic can be moved back to the previously stable environment.

The second approach uses **containers managed by a cluster**. Instead of maintaining two complete server environments, the application is packaged into a self-contained image and multiple identical copies run simultaneously. The cluster continuously maintains the required number of copies and automatically creates a replacement when one fails.

Both approaches were deliberately tested under failure conditions. Both demonstrated automated recovery without requiring a person to intervene. The main differences are the speed of recovery, how much automation we have to maintain ourselves, and how easily the system can scale.

## The Numbers That Matter

The blue/green deployment recovered from a deliberately introduced failure in **12 seconds**. The measurement represents the time between detecting the failure and successfully returning customer traffic to the previously proven version. This recovery depends on monitoring and deployment automation that we designed and maintain ourselves.

The container-based approach recovered even faster. During the self-healing test, one of two running application copies was deliberately removed. The cluster automatically created a replacement, which reached a running state in **2 seconds**, while the other copy remained available.

This is an important distinction. With blue/green deployment, recovery depends on automation that we own and operate. With the cluster approach, maintaining the required number of application copies is a built-in capability of the platform.

The containerized application was also reduced from **193 MB to 90 MB** through the production image build. A smaller application package reduces the amount of data that must be transferred and stored and removes unnecessary build-time components from the production environment.

## Side-by-Side Comparison

| Concern                  | Blue/Green on Servers                                                                                                                                                                     | Containers on Kubernetes                                                                                                                                                                                                                                                   |
| ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Deployment mechanism** | A new version is deployed to the inactive environment, verified independently, and customer traffic is then switched to it. The previous environment remains available as a fallback.     | A versioned, immutable application image is stored in the private registry. The cluster creates and replaces application copies while maintaining the required replica count during the rollout.                                                                           |
| **Rollback mechanism**   | Automated monitoring detects repeated health-check failures and switches traffic back to the previously stable environment. The demonstrated fault-to-recovery time was **12 seconds**.   | The application can be returned to a previously published image version. The cluster replaces the running copies using that known-good version, making previous registry versions available as rollback targets.                                                           |
| **Failure recovery**     | Recovery is limited to the failure conditions covered by the monitoring and recovery automation we have implemented. Failures outside those checks may not trigger an automatic response. | The cluster provides built-in self-healing by replacing failed application copies. In testing, a deleted copy was replaced and reached a running state in **2 seconds**. Additional health checks can later provide a more meaningful definition of application readiness. |
| **Scaling**              | Capacity is primarily increased by provisioning and configuring additional server resources. This can require additional infrastructure and deployment work.                              | Capacity can be increased by running additional application copies. The cluster scheduler places new copies automatically, subject to the available cluster resources.                                                                                                     |

## What This Does Not Yet Solve

The container-based approach has demonstrated better recovery performance, but the demonstration should not be mistaken for production readiness. The cluster used for testing currently runs on a single underlying machine, meaning the machine itself remains a single point of failure. We have demonstrated that the service can recover from losing an individual application copy, but we have not demonstrated that the platform can survive losing the entire machine.

There are also configuration and security gaps that must be addressed before production adoption. Application configuration and sensitive values still need to be managed independently from the deployment definition using appropriate secret-management practices. The service is also exposed through a fixed access point rather than a production-grade entry point with proper certificates, routing, and a stable customer-facing address.

Another limitation is health detection. At present, the cluster primarily establishes that an application copy has started successfully. Starting successfully is not necessarily the same as being ready to process real customer payments. Production deployment should use appropriate readiness and health checks so that customer traffic is sent only to instances capable of serving requests correctly.

For these reasons, the current position should remain measured rather than overstated: **blue/green remains the production deployment strategy today, while the container-based cluster approach is a validated candidate for the next stage of the platform.** Its measured 2-second recovery is promising compared with the 12-second blue/green recovery, but additional work is required around machine-level resilience, configuration management, secrets, production traffic entry, and application readiness before it should replace the existing production strategy.
