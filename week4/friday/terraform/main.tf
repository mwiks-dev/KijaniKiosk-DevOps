terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical's AWS Id

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  servers = {
    api = {
      instance_type = "t3.micro"
      port          = 3000
    }
    payments = {
      instance_type = "t3.micro"
      port          = 3001
    }
    logs = {
      instance_type = "t3.micro"
      port          = 5000
    }
  }
}

module "app_servers" {
  source        = "./modules/app_server"
  for_each      = local.servers
  name          = each.key
  instance_type = each.value.instance_type
  environment   = var.environment
  key_name      = var.ssh_key_name
  ami_id        = data.aws_ami.ubuntu.id
  subnet_id     = var.subnet_id
  vpc_id        = var.vpc_id
  vpc_cidr      = var.vpc_cidr
  my_ip_address = var.my_ip_address
}