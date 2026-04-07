# =============================================================================
# Rural Care - AWS Terraform Configuration
# =============================================================================
# This Terraform configuration provisions:
# - EC2 instance for the Django application
# - Security groups for networking
# - Automatic deployment from Git repository
# =============================================================================

terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "us-west-2"
}

variable "aws_access_key" {
  description = "AWS Access Key ID"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS Secret Access Key"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "app_secret_key" {
  description = "Django SECRET_KEY"
  type        = string
  sensitive   = true
}

variable "git_repo_url" {
  description = "Git repository URL"
  type        = string
  default     = "https://github.com/ashleyalmeida07/Rural_care.git"
}

variable "git_branch" {
  description = "Git branch to deploy"
  type        = string
  default     = "main"
}

variable "key_pair_name" {
  description = "AWS EC2 Key Pair name for SSH access"
  type        = string
}

# Optional environment variables
variable "database_url" {
  description = "Database URL (external database connection string)"
  type        = string
  sensitive   = true
  default     = ""
}

variable "supabase_url" {
  description = "Supabase URL"
  type        = string
  default     = ""
}

variable "supabase_key" {
  description = "Supabase Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "groq_api_key" {
  description = "Groq API Key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "blockchain_enabled" {
  description = "Enable blockchain features"
  type        = string
  default     = "False"
}

# -----------------------------------------------------------------------------
# Provider Configuration
# -----------------------------------------------------------------------------

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key

  default_tags {
    tags = {
      Project     = "RuralCare"
      Environment = "production"
      ManagedBy   = "Terraform"
    }
  }
}

# -----------------------------------------------------------------------------
# Data Sources
# -----------------------------------------------------------------------------

# Get the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Get default VPC
data "aws_vpc" "default" {
  default = true
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

# Security group for EC2 instance
resource "aws_security_group" "ruralcare_ec2" {
  name        = "ruralcare-ec2-sg"
  description = "Security group for Rural Care EC2 instance"
  vpc_id      = data.aws_vpc.default.id

  # SSH access
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTP access
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # HTTPS access
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Django development server (optional)
  ingress {
    description = "Django Dev Server"
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "ruralcare-ec2-sg"
  }
}

# -----------------------------------------------------------------------------
# IAM Role for EC2
# -----------------------------------------------------------------------------

resource "aws_iam_role" "ruralcare_ec2" {
  name = "ruralcare-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ruralcare_ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "ruralcare" {
  name = "ruralcare-instance-profile"
  role = aws_iam_role.ruralcare_ec2.name
}

# -----------------------------------------------------------------------------
# EC2 Instance
# -----------------------------------------------------------------------------

resource "aws_instance" "ruralcare" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.instance_type
  key_name               = var.key_pair_name
  vpc_security_group_ids = [aws_security_group.ruralcare_ec2.id]
  iam_instance_profile   = aws_iam_instance_profile.ruralcare.name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    secret_key           = var.app_secret_key
    database_url         = var.database_url
    git_repo_url         = var.git_repo_url
    git_branch           = var.git_branch
    supabase_url         = var.supabase_url
    supabase_key         = var.supabase_key
    groq_api_key         = var.groq_api_key
    blockchain_enabled   = var.blockchain_enabled
  }))

  tags = {
    Name = "ruralcare-app-server"
  }
}

# -----------------------------------------------------------------------------
# Elastic IP (Optional - for static IP)
# -----------------------------------------------------------------------------

resource "aws_eip" "ruralcare" {
  instance = aws_instance.ruralcare.id
  domain   = "vpc"

  tags = {
    Name = "ruralcare-eip"
  }
}

# -----------------------------------------------------------------------------
# Outputs
# -----------------------------------------------------------------------------

output "ec2_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = aws_eip.ruralcare.public_ip
}

output "ec2_public_dns" {
  description = "Public DNS of the EC2 instance"
  value       = aws_instance.ruralcare.public_dns
}

output "app_url" {
  description = "Application URL"
  value       = "http://${aws_eip.ruralcare.public_ip}"
}

output "ssh_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i <your-key.pem> ec2-user@${aws_eip.ruralcare.public_ip}"
}
