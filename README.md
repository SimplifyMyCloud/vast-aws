# Vast Datalayer AWS Infrastructure

This repository contains Terraform configurations for deploying the infrastructure required to run Vast Datalayer on AWS. The infrastructure is designed as a proof-of-concept (POC) that prioritizes simplicity for frequent deployment and teardown cycles.

## Architecture Overview

### Infrastructure Components

The Terraform configuration creates the following AWS resources:

#### 1. **Networking (vpc.tf)**
- **VPC**: 10.0.0.0/16 CIDR block with DNS support enabled
- **Availability Zones**: Deployed across 2 AZs (us-west-2a and us-west-2b)
- **Public Subnets**: 
  - 10.0.1.0/24 (us-west-2a)
  - 10.0.2.0/24 (us-west-2b)
- **Private Subnets**:
  - 10.0.11.0/24 (us-west-2a)
  - 10.0.12.0/24 (us-west-2b)
- **Internet Gateway**: For public subnet internet access
- **NAT Gateway**: Single NAT gateway in us-west-2a for private subnet internet access (cost-optimized for POC)
- **Route Tables**: Separate routing for public and private subnets

#### 2. **Security Groups (security-groups.tf)**
- **Private Subnet Security Group**: Comprehensive security group for private subnet resources
  - **Ingress Rules** (all from VPC CIDR 10.0.0.0/16):
    - ICMP (ping)
    - SSH (port 22)
    - HTTP (port 80)
    - HTTPS (port 443)
    - VMS (port 5551)
    - RPC (port 111)
    - NetBIOS/SMB (port 445)
    - NFS (port 2049)
    - MLX (port 6126)
    - Replication Peer Initialization (port 49002)
    - NSM (port 20106)
    - Replication Initialization (port 49001)
    - NLM (port 20107)
    - Mount (port 20048)
  - **Egress Rules**: Allow all outbound traffic

#### 3. **IAM Security Policies (iam-policies.tf)**
- **MCM Security Policy 1**: Permissions for CloudFormation, Lambda, EC2, RDS operations with "mcvms" component tag
- **MCM Security Policy 2**: Permissions for Auto Scaling Groups and Load Balancers with "mcvms" component tag
- **VOC Security Policy**: Permissions for various AWS services with "voc" component tag

#### 4. **SSH Access (keypair.tf)**
- **RSA Key Pair**: 4096-bit RSA key automatically generated
- **EC2 Key Pair**: Registered with AWS for SSH access to instances
- **Local Storage**: Private key saved locally as `vast-datalayer-poc-key.pem`

#### 5. **S3 Deployment Bucket (deploy-bucket.tf)**
- **Bucket Name**: vast-deploy-bucket
- **Security Features**:
  - Public access blocked
  - Versioning enabled
  - AES256 encryption
  - Bucket policy allowing CloudWatch Logs access

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         AWS Region: us-west-2                    │
├─────────────────────────────────────────────────────────────────┤
│                      VPC: 10.0.0.0/16                           │
│                                                                 │
│  ┌─────────────────────┐        ┌─────────────────────┐       │
│  │   Availability       │        │   Availability       │       │
│  │   Zone: us-west-2a   │        │   Zone: us-west-2b   │       │
│  │                      │        │                      │       │
│  │ ┌─────────────────┐ │        │ ┌─────────────────┐ │       │
│  │ │ Public Subnet   │ │        │ │ Public Subnet   │ │       │
│  │ │ 10.0.1.0/24    │ │        │ │ 10.0.2.0/24    │ │       │
│  │ └────────┬────────┘ │        │ └─────────────────┘ │       │
│  │          │          │        │                      │       │
│  │     NAT Gateway     │        │                      │       │
│  │          │          │        │                      │       │
│  │ ┌────────┴────────┐ │        │ ┌─────────────────┐ │       │
│  │ │ Private Subnet  │ │        │ │ Private Subnet  │ │       │
│  │ │ 10.0.11.0/24   │ │        │ │ 10.0.12.0/24   │ │       │
│  │ └─────────────────┘ │        │ └─────────────────┘ │       │
│  └─────────────────────┘        └─────────────────────┘       │
│                                                                 │
│                    Internet Gateway                             │
└─────────────────────────────────────────────────────────────────┘

Additional Resources:
- S3 Bucket: vast-deploy-bucket (encrypted, versioned)
- IAM Policies: MCM and VOC security policies
- SSH Key Pair: vast-datalayer-poc-key
```

## Prerequisites

1. **AWS CLI** configured with appropriate credentials
2. **Terraform** >= 1.0
3. **AWS Account** with permissions to create VPCs, EC2 instances, S3 buckets, and IAM policies
4. **AWS Profile** configured (this setup uses `monks-poc-admin-chrisl`)

## Deployment Instructions

### 1. Clone the Repository

```bash
git clone <repository-url>
cd vast-aws
```

### 2. Configure AWS Credentials

Set up your AWS profile or use the provided authentication script:

```bash
# Option 1: Use the authentication script for SSO
./aws-reauth.sh sso monks

# Option 2: Set environment variables
source .env
```

### 3. Initialize Terraform

```bash
terraform init
```

This will download required providers and initialize the backend.

### 4. Review the Deployment Plan

```bash
terraform plan
```

Review the resources that will be created.

### 5. Deploy the Infrastructure

```bash
terraform apply
```

Type `yes` when prompted to create the resources.

### 6. Save Important Outputs

After deployment, Terraform will output important values:

```bash
# Save outputs to a file
terraform output > infrastructure-outputs.txt
```

Key outputs include:
- VPC ID
- Subnet IDs
- Private subnet security group ID
- S3 bucket name
- IAM policy ARNs
- SSH key pair name

## Using the Infrastructure

### SSH Access

The deployment creates an SSH key pair automatically. To connect to EC2 instances:

```bash
# The private key is saved locally
ssh -i vast-datalayer-poc-key.pem ec2-user@<instance-ip>
```

### Network Architecture

- **Public Subnets**: Use for resources that need direct internet access (load balancers, NAT gateways)
- **Private Subnets**: Use for application servers and databases
- All private subnet traffic routes through the NAT gateway for internet access

### Security Groups

The infrastructure includes a comprehensive security group for private subnet resources:
- **Name**: vast-datalayer-poc-private-sg
- **Ingress**: Allows all required protocols (SSH, HTTP/HTTPS, VMS, NFS, etc.) from within the VPC
- **Egress**: Allows all outbound traffic
- **Usage**: Attach this security group to EC2 instances and other resources in private subnets

### Security Policies

The IAM policies use tag-based access control:
- Resources tagged with `VoC:component = "mcvms"` can be managed by MCM policies
- Resources tagged with `VoC:component = "voc"` can be managed by VOC policies

## Teardown Instructions

To destroy all resources and avoid ongoing charges:

```bash
terraform destroy
```

Type `yes` when prompted. This will remove all resources created by Terraform.

## File Structure

```
vast-aws/
├── README.md                    # This file
├── provider.tf                  # AWS provider configuration
├── vpc.tf                       # VPC and networking resources
├── security-groups.tf           # Security group definitions
├── iam-policies.tf              # IAM policy definitions
├── keypair.tf                   # SSH key pair configuration
├── deploy-bucket.tf             # S3 deployment bucket
├── aws-reauth.sh               # AWS credential refresh script
├── .env                        # Environment variables (git-ignored)
├── .gitignore                  # Git ignore rules
├── mcm-security-policy-1.json  # MCM policy document 1
├── mcm-security-policy-2.json  # MCM policy document 2
├── voc-security-policy.json    # VOC policy document
└── s3-security-policy.json     # S3 bucket policy document
```

## Security Considerations

1. **Private Keys**: The SSH private key is stored locally and excluded from git
2. **Public Access**: All S3 buckets have public access blocked
3. **Encryption**: S3 bucket uses AES256 encryption
4. **Network Isolation**: Private subnets are not directly accessible from the internet
5. **Tag-Based Access**: IAM policies restrict actions based on resource tags

## Cost Optimization

This POC infrastructure is optimized for cost:
- Single NAT gateway (instead of one per AZ)
- Resources can be easily torn down when not in use
- All resources are tagged for cost tracking

## Troubleshooting

### Authentication Issues

If you encounter authentication errors:

```bash
# Check current AWS identity
aws sts get-caller-identity

# Re-authenticate
./aws-reauth.sh sso monks-poc-admin-chrisl

# Verify profile
export AWS_PROFILE=monks-poc-admin-chrisl
```

### Terraform State Issues

If Terraform state gets corrupted:

```bash
# Backup current state
cp terraform.tfstate terraform.tfstate.backup

# Refresh state from AWS
terraform refresh
```

### Resource Cleanup

If `terraform destroy` fails, manually check for:
- EC2 instances in the VPC
- NAT gateways and Elastic IPs
- S3 bucket contents (must be empty before deletion)

## Next Steps

After the infrastructure is deployed:

1. Deploy the Vast Datalayer cluster via AWS Marketplace
2. Configure the cluster to use the created VPC and subnets
3. Apply appropriate security groups for your workload
4. Set up monitoring and logging as needed

## Support

For issues or questions:
1. Check AWS CloudFormation events for deployment errors
2. Review Terraform logs for detailed error messages
3. Ensure your AWS profile has sufficient permissions
