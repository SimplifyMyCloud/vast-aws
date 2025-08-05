# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This repository contains Terraform configurations for deploying AWS infrastructure to support Vast Datalayer. It's designed as a proof-of-concept (POC) that prioritizes simplicity for frequent deployment and teardown cycles.

## Common Commands

### Authentication
```bash
# Authenticate with AWS SSO (use 'monks' profile)
./aws-reauth.sh sso monks

# Alternative: source environment variables
source .env
```

### Terraform Operations
```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan

# Apply infrastructure
terraform apply

# Get outputs
terraform output
terraform output > infrastructure-outputs.txt

# Destroy infrastructure
terraform destroy
```

### Operational Scripts
```bash
# Get VPC and subnet information
./get-vpc-info.sh

# Check VPC dependencies before deletion
./check-vpc-dependencies.sh

# Clean up orphaned resources
./cleanup-check.sh

# Force delete VPC (use with caution)
./force-delete-vpc.sh

# Delete RDS instances blocking VPC deletion
./delete-rds-instances.sh
```

## Architecture

The infrastructure creates a VPC (10.0.0.0/16) with:
- 2 public subnets (10.0.1.0/24, 10.0.2.0/24) 
- 2 private subnets (10.0.11.0/24, 10.0.12.0/24)
- Single NAT gateway for cost optimization
- Comprehensive security group with Vast-specific ports (VMS:5551, MLX:6126, NFS:2049, replication ports)
- S3 deployment bucket with encryption
- Auto-generated SSH key pair

## Key Configuration Patterns

### Resource Naming
All resources use the prefix `vast-datalayer-poc-*`

### Security Model
- Tag-based IAM policies restrict actions based on `VoC:component` tags
- MCM policies require `VoC:component = "mcvms"`
- VOC policies require `VoC:component = "voc"`
- Security group allows internal VPC communication (10.0.0.0/16)

### Required Ports
The security group in `security-groups.tf` includes these Vast-specific ports:
- VMS: 5551
- MLX: 6126
- NFS: 2049
- Mount: 20048
- NSM: 20106
- NLM: 20107
- RPC: 111
- NetBIOS/SMB: 445
- Replication Initialization: 49001
- Replication Peer Initialization: 49002

### AWS Profile
The infrastructure uses the AWS profile `monks-poc-admin-chrisl` configured in `provider.tf`

## Testing and Validation

Run `terraform plan` before applying any changes to verify the impact. The project includes no automated tests - validation is done through Terraform's built-in planning and state management.