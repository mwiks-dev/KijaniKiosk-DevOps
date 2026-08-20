# KijaniKiosk API Server - Desired State Specification

## Identity
- Name: kijanikiosk-api-staging
- Environment tag: staging
- Owner tag: Maryann

## Compute
- Provider: Multipass (local development environment)
- Region: N/A (local deployment; would use the cloud region closest to Nairobi in production)
- Instance type: 1 vCPU / 1 GB RAM / 5 GB disk
- Operating system: ubuntu-22.04-lts (exact image ID: to be looked up dynamically)

> Note: The operating system image ID will become a Terraform data source in the Terraform implementation.

## Networking
- VPC: N/A (Multipass default NAT network)
- Subnet: Multipass default subnet
- Assign public IP: No (local deployment)

## Access Control
- SSH access: Port 22, source = host machine only (equivalent to restricting access to my IP/32 on a cloud provider)
- HTTP access: Port 80, source = local network only (would be 0.0.0.0/0 in production)
- All other inbound: Deny
- All outbound: Allow

## Storage
- Root volume: 5 GB, standard virtual disk

## Authentication
- SSH key pair name: Multipass auto-generated key

## What must NOT exist on this server after provisioning
- No default password authentication
- No services listening other than sshd
- No world-writable directories outside /tmp

## Open questions (things that will need decisions before Terraform can encode this)
- Which cloud provider will be used for production (AWS, Azure, or GCP)?
- Which production region should be selected?
- What Ubuntu image ID should Terraform retrieve dynamically?
- Should a public IP be assigned in production?
- Should additional tags (e.g., project, cost center, owner email) be applied?
- What storage type should be used on the target cloud provider (e.g., gp3, standard SSD)?
- Will an existing VPC and subnet be used, or should Terraform create them?
- Should HTTP be restricted to a load balancer instead of being open to the internet?