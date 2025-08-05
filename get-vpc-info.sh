#!/bin/bash

# Script to get VPC and subnet information from Terraform outputs

echo "Getting VPC and Subnet information..."
echo "===================================="

# Get VPC ID
echo "VPC ID:"
terraform output -raw vpc_id 2>/dev/null || echo "Run 'terraform apply' first"

echo ""
echo "Private Subnet IDs:"
terraform output -json private_subnet_ids 2>/dev/null | jq -r '.[]' || echo "Run 'terraform apply' first"

echo ""
echo "Public Subnet IDs:"
terraform output -json public_subnet_ids 2>/dev/null | jq -r '.[]' || echo "Run 'terraform apply' first"

echo ""
echo "To use these in CloudFormation:"
echo "1. Copy the VPC ID"
echo "2. Use the subnet IDs that match your requirements"
echo "3. Make sure ALL subnets are from the same VPC"