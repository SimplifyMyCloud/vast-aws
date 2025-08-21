# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

**Last Updated**: August 12, 2025

## Project Overview

This repository contains Terraform configurations for deploying AWS infrastructure to support Vast Datalayer, plus the TAMS (Time-addressable Media Store) API v6.0.1 integration. It's designed as a proof-of-concept (POC) that prioritizes simplicity for frequent deployment and teardown cycles.

## Common Commands

### Authentication
```bash
# Authenticate with AWS SSO (use 'monks' profile)
./scripts/aws-reauth.sh sso monks

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
./scripts/get-vpc-info.sh

# Check VPC dependencies before deletion
./scripts/check-vpc-dependencies.sh

# Clean up orphaned resources
./scripts/cleanup-check.sh

# Force delete VPC (use with caution)
./scripts/force-delete-vpc.sh

# Delete RDS instances blocking VPC deletion
./scripts/delete-rds-instances.sh
```

### TAMS Deployment and Management
```bash
# Deploy TAMS v6.0.1 with VAST integration (CURRENT VERSION)
./scripts/deploy-tams-v6.0.1.sh

# Manage TAMS container
./scripts/manage-tams.sh status   # Check status
./scripts/manage-tams.sh logs     # View logs
./scripts/manage-tams.sh restart  # Restart container
./scripts/manage-tams.sh shell    # Open shell in container

# Find VAST S3 configuration
./scripts/find-vast-s3-config.sh
```

## Architecture

The infrastructure creates a VPC (10.0.0.0/16) with:
- 2 public subnets (10.0.1.0/24, 10.0.2.0/24) 
- 2 private subnets (10.0.11.0/24, 10.0.12.0/24)
- TAMS VM instance in public subnet (34.216.9.25)
- VAST cluster in private subnet with VIPs (10.0.11.54, 10.0.11.170)
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

## VAST-TAMS Integration

### Current Deployment
- **TAMS Version**: v6.0.1
- **TAMS API**: http://34.216.9.25:8000
- **VAST Protocol VIPs**: 10.0.11.54, 10.0.11.170
- **VAST Admin UI**: https://10.0.11.161 (admin/123456)
- **S3 Buckets**: tams-db, tams-s3

### Key Endpoints
- Health: http://34.216.9.25:8000/health
- VAST Status: http://34.216.9.25:8000/vast/status
- API Docs: http://34.216.9.25:8000/docs
- Sources: http://34.216.9.25:8000/sources
- Flows: http://34.216.9.25:8000/flows

## Testing and Validation

Run `terraform plan` before applying any changes to verify the impact. For TAMS testing:
```bash
# Check TAMS health
curl http://34.216.9.25:8000/health | jq .

# Check VAST connection
curl http://34.216.9.25:8000/vast/status | jq .
```