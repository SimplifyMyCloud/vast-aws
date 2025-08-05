#!/bin/bash

VPC_ID=${1:-vpc-0efd8172c76e4f4cf}
REGION="us-west-2"

echo "Checking dependencies for VPC: $VPC_ID"
echo "======================================"

echo ""
echo "Network Interfaces and their attachments:"
aws ec2 describe-network-interfaces --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "NetworkInterfaces[*].[NetworkInterfaceId,Status,InterfaceType,Description,Attachment.InstanceId,Attachment.InstanceOwnerId,RequesterId]" \
    --output table

echo ""
echo "VPC Endpoints:"
aws ec2 describe-vpc-endpoints --region $REGION \
    --filters "Name=vpc-id,Values=$VPC_ID" \
    --query "VpcEndpoints[*].[VpcEndpointId,ServiceName,State]" \
    --output table

echo ""
echo "If you see Lambda ENIs (RequesterId contains 'lambda'), they will auto-delete in ~40 minutes"
echo "If you see other attachments, you may need to terminate those resources first"