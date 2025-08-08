# Bastion Host with Desktop Environment
# Provides access to internal Vast control server

# Data source for Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "state"
    values = ["available"]
  }
}

# Security Group for Bastion Host
resource "aws_security_group" "bastion" {
  name        = "vast-datalayer-poc-bastion-sg"
  description = "Security group for bastion host with desktop access"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # RDP access (for xrdp remote desktop)
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RDP access for remote desktop"
  }

  # VNC access (alternative remote desktop)
  ingress {
    from_port   = 5901
    to_port     = 5910
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "VNC access for remote desktop"
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = {
    Name = "vast-datalayer-poc-bastion-sg"
  }
}

# IAM Role for Bastion Host
resource "aws_iam_role" "bastion" {
  name = "vast-datalayer-poc-bastion-role"

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

  tags = {
    Name = "vast-datalayer-poc-bastion-role"
  }
}

# Attach SSM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "bastion_ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for Bastion
resource "aws_iam_instance_profile" "bastion" {
  name = "vast-datalayer-poc-bastion-profile"
  role = aws_iam_role.bastion.name
}

# Lightweight user data script - just install ubuntu-desktop and xrdp
locals {
  bastion_user_data = <<-EOT
    #!/bin/bash
    
    # Update system
    apt-get update -y
    
    # Install ubuntu-desktop (lighter than ubuntu-desktop-minimal paradoxically)
    DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop
    
    # Install xrdp
    apt-get install -y xrdp
    systemctl enable xrdp
    systemctl start xrdp
    
    # Create a user for desktop access
    useradd -m -s /bin/bash vastadmin
    echo "vastadmin:VastP0c2024!" | chpasswd
    usermod -aG sudo vastadmin
    
    # Configure sudoers for vastadmin
    echo "vastadmin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vastadmin
    
    # Set graphical target
    systemctl set-default graphical.target
  EOT
}

# Bastion EC2 Instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.large" # Sufficient for desktop environment
  key_name               = aws_key_pair.cluster_key.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = aws_subnet.public_1.id # Place in public subnet for direct access
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  user_data = base64encode(local.bastion_user_data)

  root_block_device {
    volume_type = "gp3"
    volume_size = 30
    encrypted   = true

    tags = {
      Name = "vast-datalayer-poc-bastion-root"
    }
  }

  tags = {
    Name    = "vast-datalayer-poc-bastion"
    Type    = "bastion"
    OS      = "Ubuntu 24.04 LTS"
    Desktop = "GNOME + xrdp"
  }
}

# Elastic IP for Bastion
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "vast-datalayer-poc-bastion-eip"
  }
}

# Outputs for bastion access
output "bastion_public_ip" {
  value       = aws_eip.bastion.public_ip
  description = "Public IP address of the bastion host"
}

output "bastion_public_dns" {
  value       = aws_eip.bastion.public_dns
  description = "Public DNS of the bastion host"
}

output "bastion_instance_id" {
  value       = aws_instance.bastion.id
  description = "Instance ID of the bastion host"
}

output "bastion_rdp_connection" {
  value       = "Connect via RDP to ${aws_eip.bastion.public_ip}:3389 with username: vastadmin"
  description = "RDP connection string for the bastion host"
}

output "bastion_ssh_connection" {
  value       = "ssh -i ./vast-datalayer-poc-key.pem ubuntu@${aws_eip.bastion.public_ip}"
  description = "SSH connection command for the bastion host"
}