# EC2 Key Pair for SSH Access to Vast Datalayer POC

# Generate RSA key pair using TLS provider
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create EC2 Key Pair using the public key
resource "aws_key_pair" "cluster_key" {
  key_name   = "vast-datalayer-poc-key"
  public_key = tls_private_key.ssh_key.public_key_openssh

  tags = {
    Name = "vast-datalayer-poc-key"
  }
}

# Save private key locally (for POC - in production use secrets manager)
resource "local_file" "private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.module}/vast-datalayer-poc-key.pem"
  file_permission = "0600"
}

# Outputs
output "key_pair_name" {
  value       = aws_key_pair.cluster_key.key_name
  description = "Name of the EC2 key pair"
}

output "private_key_path" {
  value       = local_file.private_key.filename
  description = "Path to the private key file"
}

output "ssh_connection_command" {
  value       = "ssh -i ${local_file.private_key.filename} ec2-user@<instance-ip>"
  description = "Example SSH connection command"
}