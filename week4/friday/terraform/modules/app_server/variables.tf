variable "name" {
  description = "api, payments, logs"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  default     = "t3.micro"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}

variable "ami_id" {
  description = "AMI ID for instance"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID to launch the instance into"
  type        = string
}

variable "vpc_id" {
  type = string
}

variable "my_ip_address" {
  type = string
}

variable "vpc_cidr" {
  type = string
}