# Manual Provisioning Decisions - KijaniKiosk API Server
| **Decision**     | **Value I Chose**                           | **Reason**                                                                      |
| ---------------- | ------------------------------------------- | ------------------------------------------------------------------------------- |
| Cloud provider   | Multipass (local, standing in for cloud VM) | No cloud account required; behavior is representative.                          |
| Region           | N/A (local)                                 | Would map to the closest region to Nairobi on a real cloud provider.            |
| Operating system | Ubuntu 22.04 LTS                            | Matches the provisioning constraint.                                            |
| Instance type    | 1 vCPU / 1 GB RAM / 5 GB disk               | Smallest practical size, mirrors a typical free-tier instance.                  |
| VPC              | N/A (Multipass bridged/NAT network)         | Would correspond to the Week 2 VPC on a real cloud provider.                    |
| Subnet           | Multipass default subnet                    | Default local networking configuration.                                         |
| Security group   | Host firewall not configured (local only)   | On a cloud provider: allow SSH from my IP and HTTP from anywhere.               |
| SSH key pair     | Multipass auto-injects key                  | Automatically managed by Multipass.                                             |
| Root volume size | 5 GB                                        | Set at launch.                                                                  |
| Public IP        | No (local only)                             | Would be **Yes** on a cloud provider so the application is reachable over HTTP. |
| Tags/Labels      | `name=kijanikiosk-api`                      | Used to identify the instance.                                                  |
