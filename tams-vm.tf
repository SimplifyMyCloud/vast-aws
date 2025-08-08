# TAMS VM - Ubuntu Desktop with Docker
# 8GB RAM, 4 CPUs, Desktop Environment, Docker Ready

# Data source for Ubuntu 24.04 LTS AMI
data "aws_ami" "ubuntu_tams" {
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

# Security Group for TAMS VM
resource "aws_security_group" "tams_vm" {
  name        = "vast-datalayer-poc-tams-vm-sg"
  description = "Security group for TAMS VM with desktop and Docker"
  vpc_id      = aws_vpc.main.id

  # SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "SSH access"
  }

  # RDP access
  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "RDP access for remote desktop"
  }

  # HTTP access (for Docker apps)
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTP access"
  }

  # HTTPS access (for Docker apps)
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "HTTPS access"
  }

  # Docker port range (common ports)
  ingress {
    from_port   = 8000
    to_port     = 8999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Docker application ports"
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
    Name = "vast-datalayer-poc-tams-vm-sg"
  }
}

# IAM Role for TAMS VM
resource "aws_iam_role" "tams_vm" {
  name = "vast-datalayer-poc-tams-vm-role"

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
    Name = "vast-datalayer-poc-tams-vm-role"
  }
}

# Attach SSM policy for Session Manager access
resource "aws_iam_role_policy_attachment" "tams_vm_ssm" {
  role       = aws_iam_role.tams_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# IAM Instance Profile for TAMS VM
resource "aws_iam_instance_profile" "tams_vm" {
  name = "vast-datalayer-poc-tams-vm-profile"
  role = aws_iam_role.tams_vm.name
}

# User data script to install desktop, Docker, and configure environment
locals {
  tams_vm_user_data = <<-EOT
    #!/bin/bash
    
    # Update system
    apt-get update -y
    
    # Install ubuntu-desktop-minimal for faster installation
    DEBIAN_FRONTEND=noninteractive apt-get install -y ubuntu-desktop-minimal
    
    # Install Docker
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    
    # Install Docker Compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Install xrdp for RDP support
    apt-get install -y xrdp
    systemctl enable xrdp
    systemctl start xrdp
    
    # Install additional tools
    apt-get install -y \
      git \
      vim \
      curl \
      wget \
      htop \
      net-tools \
      dnsutils \
      unzip \
      firefox \
      code \
      terminator
    
    # Create user for desktop access
    useradd -m -s /bin/bash tamsadmin
    echo "tamsadmin:TamsP0c2024!" | chpasswd
    usermod -aG sudo,docker tamsadmin
    
    # Configure sudoers for tamsadmin
    echo "tamsadmin ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/tamsadmin
    
    # Install AWS CLI v2
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    ./aws/install
    rm -rf awscliv2.zip aws/
    
    # Create Docker hello-world setup script
    cat > /home/tamsadmin/docker-test.sh <<EOF
#!/bin/bash
echo "Testing Docker installation..."
sudo docker run hello-world
echo "Docker is working! You can now run Docker containers."
EOF
    chmod +x /home/tamsadmin/docker-test.sh
    chown tamsadmin:tamsadmin /home/tamsadmin/docker-test.sh
    
    # Create connection info file
    cat > /home/tamsadmin/tams-vm-info.txt <<EOF
=====================================
TAMS VM - Ubuntu Desktop + Docker
=====================================

This VM is configured for Docker development with desktop environment.

System Specs:
- 8GB RAM, 4 CPUs
- Ubuntu 24.04 LTS Desktop
- Docker + Docker Compose installed
- VS Code installed

Desktop Access:
- RDP: Connect using any RDP client on port 3389
- Username: tamsadmin
- Password: TamsP0c2024! (change this after first login)

Docker Usage:
- Docker is installed and running
- Run: ./docker-test.sh to test Docker
- Docker Compose is available at /usr/local/bin/docker-compose

Development Tools:
- VS Code: Available in applications
- Firefox: Web browser
- Terminator: Advanced terminal
- Git: Version control

Network Access:
- HTTP/HTTPS ports (80, 443) open
- Docker app ports (8000-8999) open
- SSH access on port 22

Security Notes:
- Change the default password immediately
- User 'tamsadmin' has Docker and sudo access
- AWS CLI is installed for cloud integration
EOF
    
    chown tamsadmin:tamsadmin /home/tamsadmin/tams-vm-info.txt
    
    # Set graphical target
    systemctl set-default graphical.target
    
    # Start Docker service
    systemctl enable docker
    systemctl start docker
    
    # Reboot to ensure desktop environment starts properly
    reboot
  EOT
}

# TAMS VM EC2 Instance - 8GB RAM, 4 CPUs
resource "aws_instance" "tams_vm" {
  ami                    = data.aws_ami.ubuntu_tams.id
  instance_type          = "t3.xlarge" # 4 vCPUs, 16 GiB RAM (exceeds 8GB requirement)
  key_name               = aws_key_pair.cluster_key.key_name
  vpc_security_group_ids = [aws_security_group.tams_vm.id]
  subnet_id              = aws_subnet.public_1.id # Place in public subnet for direct access
  iam_instance_profile   = aws_iam_instance_profile.tams_vm.name

  user_data = base64encode(local.tams_vm_user_data)

  root_block_device {
    volume_type = "gp3"
    volume_size = 50 # 50GB storage for Docker images and development
    encrypted   = true

    tags = {
      Name = "vast-datalayer-poc-tams-vm-root"
    }
  }

  tags = {
    Name    = "vast-datalayer-poc-tams-vm"
    Type    = "development"
    OS      = "Ubuntu 24.04 LTS Desktop"
    Purpose = "Docker Development"
    User    = "TAMS"
  }
}

# Elastic IP for TAMS VM
resource "aws_eip" "tams_vm" {
  instance = aws_instance.tams_vm.id
  domain   = "vpc"

  tags = {
    Name = "vast-datalayer-poc-tams-vm-eip"
  }
}

# Outputs for TAMS VM access
output "tams_vm_public_ip" {
  value       = aws_eip.tams_vm.public_ip
  description = "Public IP address of the TAMS VM"
}

output "tams_vm_public_dns" {
  value       = aws_eip.tams_vm.public_dns
  description = "Public DNS of the TAMS VM"
}

output "tams_vm_instance_id" {
  value       = aws_instance.tams_vm.id
  description = "Instance ID of the TAMS VM"
}

output "tams_vm_rdp_connection" {
  value       = "Connect via RDP to ${aws_eip.tams_vm.public_ip}:3389 with username: tamsadmin"
  description = "RDP connection string for the TAMS VM"
}

output "tams_vm_ssh_connection" {
  value       = "ssh -i ./vast-datalayer-poc-key.pem ubuntu@${aws_eip.tams_vm.public_ip}"
  description = "SSH connection command for the TAMS VM"
}

output "tams_vm_docker_test" {
  value       = "After RDP connection, run: ./docker-test.sh"
  description = "Command to test Docker installation"
}