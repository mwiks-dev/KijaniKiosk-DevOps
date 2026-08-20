#!/bin/bash
set -e

echo "== Terraform apply =="
cd terraform
terraform init -reconfigure
terraform apply -auto-approve

echo "== Extracting IPs to inventory =="
API_IP=$(terraform output -json server_ips | jq -r '.api')
PAY_IP=$(terraform output -json server_ips | jq -r '.payments')
LOG_IP=$(terraform output -json server_ips | jq -r '.logs')

cat > ../ansible/inventory.ini <<EOF
[kijanikiosk]
api-staging ansible_host=${API_IP}
payments-staging ansible_host=${PAY_IP}
logs-staging ansible_host=${LOG_IP}
EOF

echo "== Ansible playbook =="
cd ../ansible
ansible-playbook -i inventory.ini kijanikiosk.yml