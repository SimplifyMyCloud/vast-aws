# Security Groups for Vast Datalayer POC
# Defines security groups for private subnet resources

resource "aws_security_group" "private_subnet_sg" {
  name        = "vast-datalayer-poc-private-sg"
  description = "Security group for private subnet resources"
  vpc_id      = aws_vpc.main.id

  # ICMP (ping)
  ingress {
    description = "ICMP"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # SSH
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTP
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # VMS
  ingress {
    description = "VMS"
    from_port   = 5551
    to_port     = 5551
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # HTTPS
  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # RPC
  ingress {
    description = "RPC"
    from_port   = 111
    to_port     = 111
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # NetBIOS/SMB
  ingress {
    description = "NetBIOS/SMB"
    from_port   = 445
    to_port     = 445
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # NFS
  ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # MLX
  ingress {
    description = "MLX"
    from_port   = 6126
    to_port     = 6126
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Replication Peer Initialization
  ingress {
    description = "Replication Peer Initialization"
    from_port   = 49002
    to_port     = 49002
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # NSM
  ingress {
    description = "NSM"
    from_port   = 20106
    to_port     = 20106
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Replication Initialization
  ingress {
    description = "Replication Initialization"
    from_port   = 49001
    to_port     = 49001
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # NLM
  ingress {
    description = "NLM"
    from_port   = 20107
    to_port     = 20107
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Mount
  ingress {
    description = "Mount"
    from_port   = 20048
    to_port     = 20048
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  # Allow all outbound traffic
  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vast-datalayer-poc-private-sg"
  }
}

# Output the security group ID for reference
output "private_subnet_security_group_id" {
  value       = aws_security_group.private_subnet_sg.id
  description = "ID of the private subnet security group"
}