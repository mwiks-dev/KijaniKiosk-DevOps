output "instance_public_ips" {
  description = "Public IP addresses of the KijaniKiosk servers"

  value = {
    for name, server in module.app_servers :
    name => server.public_ip
  }
}

output "ssh_commands" {
  description = "SSH commands for each KijaniKiosk server"

  value = {
    for name, server in module.app_servers :
    name => "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${server.public_ip}"
  }
}

output "api_server_ip" {
  description = "SSH command for API server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.app_servers["api"].public_ip}"
}

output "payments_server_ip" {
  description = "SSH command for payments server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.app_servers["payments"].public_ip}"
}

output "logs_server_ip" {
  description = "SSH command for logs server"
  value       = "ssh -i ~/.ssh/${var.ssh_key_name}.pem ubuntu@${module.app_servers["logs"].public_ip}"
}

output "server_ips" {
  description = "Public IP addresses of KijaniKiosk servers"

  value = {
    for name, server in module.app_servers :
    name => server.public_ip
  }
}