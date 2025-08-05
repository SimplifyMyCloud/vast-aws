#!/bin/bash

# Script to delete RDS instances blocking VPC deletion

export AWS_PROFILE=monks-poc-admin-chrisl
REGION="us-west-2"

echo "Deleting RDS instances in VPC vpc-0efd8172c76e4f4cf"
echo "==================================================="

# RDS instance identifiers
INSTANCES=(
    "monks-vast-tams-poc-006-mcvmsdb-k4z13hpmmdxw"
    "monks-vast-tams-poc-008-mcvmsdb-5fel48znbgck"
)

for INSTANCE in "${INSTANCES[@]}"; do
    echo ""
    echo "Deleting RDS instance: $INSTANCE"
    
    # Delete without final snapshot (for POC - use --final-db-snapshot-identifier for production)
    aws rds delete-db-instance \
        --region $REGION \
        --db-instance-identifier "$INSTANCE" \
        --skip-final-snapshot \
        --delete-automated-backups
done

echo ""
echo "Waiting for RDS instances to be deleted (this may take several minutes)..."
echo "You can check status with: aws rds describe-db-instances --region us-west-2"

# Wait for deletion
for INSTANCE in "${INSTANCES[@]}"; do
    echo "Waiting for $INSTANCE to be deleted..."
    aws rds wait db-instance-deleted \
        --region $REGION \
        --db-instance-identifier "$INSTANCE" 2>/dev/null || echo "Instance $INSTANCE deleted or not found"
done

echo ""
echo "✅ RDS instances deleted. Now you can delete the VPC."