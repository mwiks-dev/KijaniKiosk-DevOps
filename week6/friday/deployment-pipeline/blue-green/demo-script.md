# Board Demonstration Script – Self-Healing Deployment

**Purpose:** Script for Nia to read aloud while the deployment pipeline runs.

---

**[Terminal 1 displays `post-deploy-monitor.sh 90`, showing successful health checks every five seconds. Terminal 2 is prepared with `switch-env.sh green`.]**

Good morning. Over the next two minutes, you will see our payment system update itself, experience a planned failure, and recover automatically without anyone intervening after the fault occurs.

**[Point to the health-check output in Terminal 1.]**

The screen on the left is continuously checking that the service is working properly. Every few seconds it asks whether the system is healthy, and at the moment every response shows that everything is operating normally.

**[Execute the deployment in Terminal 2. The version changes from 1.3 to 1.4.]**

We have now released a new version. Before customers are moved to it, the new version is prepared and verified. Only after those checks pass is customer traffic directed to the updated service, while the previous version remains available in case it is needed.

**[Run `systemctl stop kk-api-green` in Terminal 2. Pause briefly.]**

We are now introducing a deliberate fault to demonstrate how the system responds when something goes wrong.

**[Terminal 1 reports failed health checks, followed by "ROLLBACK TRIGGERED," then healthy responses.]**

The system detects that the new version is no longer operating correctly. It immediately returns customers to the previous stable version without waiting for someone to intervene. Service is restored automatically while the investigation can happen afterwards.

**[Point to the healthy responses showing version 1.3.]**

The complete recovery took **12 seconds**, measured during testing. Previously, recovering from the same type of failure required around four minutes of manual intervention. By reducing recovery time, the system keeps more payment requests successful, minimises disruption for customers, and improves confidence that updates can be deployed safely.
