variable "aws_region" {
  description = "The region where the EC2 instance will be provisioned"
  type        = string
  default     = "af-south-1"
}

variable "instance_type" {
  description = "The hardware profile of the provisioned VM"
  type        = string
  default     = "t3.micro"
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  default     = "staging"

  validation {
    condition     = contains(["staging", "production"], var.environment)
    error_message = "Environment must be staging or production."
  }
}

variable "ssh_key_name" {
  description = "My configured ssh key name"
  type        = string
}

variable "subnet_id" {
  description = "Subnet to launch instances into"
  type        = string
}

variable "vpc_id" {
  description = "VPC the security group belongs to"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block of the VPC, for internal app-port access"
  type        = string
}

variable "my_ip_address" {
  description = "Public IP address allowed to SSH"
  type        = string
}