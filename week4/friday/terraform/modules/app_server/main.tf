resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  key_name               = var.key_name
  vpc_security_group_ids = [aws_security_group.kijanikiosk.id]

  tags = {
    Name        = "KijaniKiosk-${var.name}-${var.environment}"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "kijanikiosk" {
  name        = "kijanikiosk-${var.name}-${var.environment}"
  description = "Allow SSH from listed IP only"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from listed IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.my_ip_address}/32"]
  }

  ingress {
    description = "App ports within VPC"
    from_port   = 3000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "apps"
  }
}