# Monday - Reflection and Engineering Thinking

## Question 1: The Idempotency Gap

Terraform achieves idempotency by maintaining a **state file (`terraform.tfstate`)** that records the infrastructure it has created and manages. The state file stores information such as resource IDs, configuration values, attributes, and the mapping between the Terraform configuration and the actual infrastructure. During a `terraform plan` or `terraform apply`, Terraform compares three things: the desired configuration, the current state file, and the actual infrastructure (by querying the provider). Based on this comparison, it decides whether to create a new resource, update an existing one, destroy a resource, or leave it unchanged.

Unlike the Week 3 bash script, Terraform does not require explicit guard conditions such as `id kk-api >/dev/null || useradd kk-api`. Instead, the state file allows Terraform to understand what resources already exist and whether they match the desired configuration.

A situation where the state file tells Terraform to do nothing even though the infrastructure has changed is when the infrastructure is modified outside Terraform and Terraform has not yet refreshed its state. For example, an administrator could manually delete a firewall rule or stop a virtual machine through the cloud provider's console. If Terraform relies on an outdated state file without refreshing, it may incorrectly assume everything matches the desired state. The correct response is to refresh the state (or run `terraform plan`, which refreshes by default in normal workflows) so Terraform detects the drift and generates a plan to restore the infrastructure to the desired state. Manual changes outside Terraform should generally be avoided because they cause configuration drift.

---

## Question 2: Declarative Specification Quality

My desired-state specification is structured, but another engineer would still need clarification before reproducing the same infrastructure on a different cloud provider.

The first under-specified item is the **cloud provider and region**. My specification states that Multipass is used locally and that production would use the region closest to Nairobi, but it does not identify the actual provider or region. If Terraform had to make this decision automatically, it might select a different provider or default region, resulting in different networking, pricing, and available services.

The second under-specified item is the **Ubuntu image ID**. The specification states that Ubuntu 22.04 LTS should be used but leaves the exact image ID unspecified. Different cloud providers publish different image IDs, and using the wrong image could result in a different kernel version, security configuration, or package set. Terraform would either fail or use an unintended image if the configuration were incomplete.

Another gap is the **network configuration**. Since Multipass uses its own default network, there is no specific VPC or subnet defined. On a cloud provider, Terraform would require these values or create new ones using defaults, which might not meet the intended security or connectivity requirements.

These gaps demonstrate that automation is only as reliable as the specification it follows. A complete, precise specification removes ambiguity and ensures Terraform produces predictable and repeatable infrastructure. Missing details force assumptions, which can lead to inconsistent or incorrect deployments.

---

## Question 3: Tool Boundary

### 1. Creating a firewall rule that allows port 80 from anywhere

**Best tool:** Terraform.

Firewall rules are infrastructure resources that belong to the cloud networking layer. Terraform should create and manage them because they are part of the desired infrastructure state. Using Ansible or bash would configure the rule after the VM already exists and would not manage the cloud resource itself. This could result in inconsistent firewall rules across environments.

### 2. Installing nginx 1.24.0 on a running VM

**Best tool:** Ansible.

Installing software is part of configuring the operating system rather than provisioning infrastructure. Ansible is designed to install packages, manage configuration files, and ensure services are running. Terraform can execute remote commands, but this is not its intended purpose and makes infrastructure management harder to maintain. Bash could install nginx, but it lacks Ansible's built-in idempotency and package management features.

### 3. Verifying that nginx is responding to HTTP requests after installation

**Best tool:** Bash (or a testing tool).

Verification is a validation step rather than infrastructure provisioning or configuration management. A simple bash command such as `curl http://localhost` is sufficient to confirm that nginx is responding. Using Terraform for testing is inappropriate because it is designed to manage infrastructure, not validate application behavior. Ansible can perform checks, but using it solely for runtime verification is less appropriate than a lightweight test script.

Choosing the correct tool ensures each tool performs the task it was designed for. Terraform manages infrastructure resources, Ansible manages system configuration, and bash performs simple operational checks and automation tasks.

---

## Question 4: From Script to Spec

The infrastructure-related phases from the Week 3 provisioning script translated cleanly into declarative terms. Decisions such as the operating system, instance size, storage size, networking configuration, firewall rules, SSH access, and authentication could all be expressed as the desired final state. These describe *what* the infrastructure should look like rather than *how* to build it.

The configuration phases were more difficult to express declaratively. Tasks such as installing packages, creating users, enabling services, updating software, and verifying that applications were working required procedural steps. These actions describe a sequence of operations rather than a final infrastructure resource. Although configuration management tools like Ansible can describe these tasks declaratively, they still operate on an existing machine rather than creating infrastructure.

This difference highlights the distinction between infrastructure provisioning and configuration management. Infrastructure provisioning focuses on creating and managing resources such as virtual machines, networks, storage, and firewall rules. Configuration management focuses on bringing those resources into the desired operational state by installing software, modifying system settings, and ensuring services are configured correctly. Terraform is optimized for provisioning infrastructure, while tools like Ansible are better suited for configuring and maintaining the software running on that infrastructure.
