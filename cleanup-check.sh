#!/bin/bash

# Script to check for resources that might need cleanup

echo "Checking for existing AWS resources..."
echo "====================================="

echo ""
echo "VPCs in us-west-2:"
aws ec2 describe-vpcs --region us-west-2 --query 'Vpcs[?IsDefault==`false`].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0]]' --output table

echo ""
echo "CloudFormation Stacks:"
aws cloudformation list-stacks --region us-west-2 --stack-status-filter CREATE_COMPLETE UPDATE_COMPLETE ROLLBACK_COMPLETE CREATE_FAILED --query 'StackSummaries[*].[StackName,StackStatus,CreationTime]' --output table

echo ""
echo "Load Balancers:"
aws elbv2 describe-load-balancers --region us-west-2 --query 'LoadBalancers[*].[LoadBalancerName,VpcId,State.Code]' --output table

echo ""
echo "To clean up:"
echo "1. Delete any failed CloudFormation stacks"
echo "2. Remove any unused VPCs (check for dependencies first)"
echo "3. Ensure no orphaned resources exist"