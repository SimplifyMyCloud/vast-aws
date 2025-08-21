#!/bin/bash

# Script to forcefully delete a VPC and all its dependencies
# Usage: ./force-delete-vpc.sh <vpc-id>

VPC_ID=${1:-vpc-0efd8172c76e4f4cf}
REGION="us-west-2"

echo "Attempting to delete VPC: $VPC_ID"
echo "=================================="

# Function to wait for resource deletion
wait_for_deletion() {
    echo "Waiting for resources to be deleted..."
    sleep 5
}

# 1. Terminate all EC2 instances in the VPC
echo "1. Checking for EC2 instances..."
INSTANCE_IDS=$(aws ec2 describe-instances --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "Reservations[].Instances[?State.Name!='terminated'].InstanceId" --output text)
if [ ! -z "$INSTANCE_IDS" ]; then
    echo "   Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --region $REGION --instance-ids $INSTANCE_IDS
    echo "   Waiting for instances to terminate..."
    aws ec2 wait instance-terminated --region $REGION --instance-ids $INSTANCE_IDS
fi

# 2. Delete Load Balancers
echo "2. Checking for Load Balancers..."
LB_ARNS=$(aws elbv2 describe-load-balancers --region $REGION --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text)
for LB_ARN in $LB_ARNS; do
    echo "   Deleting Load Balancer: $LB_ARN"
    aws elbv2 delete-load-balancer --region $REGION --load-balancer-arn $LB_ARN
done
if [ ! -z "$LB_ARNS" ]; then
    wait_for_deletion
fi

# 3. Delete NAT Gateways
echo "3. Checking for NAT Gateways..."
NAT_IDS=$(aws ec2 describe-nat-gateways --region $REGION --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query "NatGateways[].NatGatewayId" --output text)
for NAT_ID in $NAT_IDS; do
    echo "   Deleting NAT Gateway: $NAT_ID"
    aws ec2 delete-nat-gateway --region $REGION --nat-gateway-id $NAT_ID
done
if [ ! -z "$NAT_IDS" ]; then
    echo "   Waiting for NAT Gateways to delete..."
    sleep 60
fi

# 4. Delete Network Interfaces
echo "4. Checking for Network Interfaces..."
ENI_IDS=$(aws ec2 describe-network-interfaces --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "NetworkInterfaces[].NetworkInterfaceId" --output text)
for ENI_ID in $ENI_IDS; do
    echo "   Checking ENI: $ENI_ID"
    ATTACHMENT_ID=$(aws ec2 describe-network-interfaces --region $REGION --network-interface-ids $ENI_ID --query "NetworkInterfaces[0].Attachment.AttachmentId" --output text 2>/dev/null)
    
    if [ "$ATTACHMENT_ID" != "None" ] && [ ! -z "$ATTACHMENT_ID" ]; then
        echo "   Detaching ENI: $ENI_ID"
        aws ec2 detach-network-interface --region $REGION --attachment-id $ATTACHMENT_ID --force 2>/dev/null
        sleep 5
    fi
    
    echo "   Deleting ENI: $ENI_ID"
    aws ec2 delete-network-interface --region $REGION --network-interface-id $ENI_ID 2>/dev/null
done

# 5. Release Elastic IPs
echo "5. Checking for Elastic IPs..."
EIP_ALLOCS=$(aws ec2 describe-addresses --region $REGION --query "Addresses[?Domain=='vpc'].AllocationId" --output text)
for ALLOC_ID in $EIP_ALLOCS; do
    echo "   Releasing Elastic IP: $ALLOC_ID"
    aws ec2 release-address --region $REGION --allocation-id $ALLOC_ID 2>/dev/null
done

# 6. Delete Security Groups (except default)
echo "6. Checking for Security Groups..."
SG_IDS=$(aws ec2 describe-security-groups --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "SecurityGroups[?GroupName!='default'].GroupId" --output text)
for SG_ID in $SG_IDS; do
    echo "   Deleting Security Group: $SG_ID"
    aws ec2 delete-security-group --region $REGION --group-id $SG_ID 2>/dev/null
done

# 7. Delete Subnets
echo "7. Checking for Subnets..."
SUBNET_IDS=$(aws ec2 describe-subnets --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text)
for SUBNET_ID in $SUBNET_IDS; do
    echo "   Deleting Subnet: $SUBNET_ID"
    aws ec2 delete-subnet --region $REGION --subnet-id $SUBNET_ID
done

# 8. Delete Route Tables (except main)
echo "8. Checking for Route Tables..."
RT_IDS=$(aws ec2 describe-route-tables --region $REGION --filters "Name=vpc-id,Values=$VPC_ID" --query "RouteTables[?Associations[0].Main!=\`true\`].RouteTableId" --output text)
for RT_ID in $RT_IDS; do
    echo "   Deleting Route Table: $RT_ID"
    aws ec2 delete-route-table --region $REGION --route-table-id $RT_ID
done

# 9. Detach and Delete Internet Gateways
echo "9. Checking for Internet Gateways..."
IGW_IDS=$(aws ec2 describe-internet-gateways --region $REGION --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query "InternetGateways[].InternetGatewayId" --output text)
for IGW_ID in $IGW_IDS; do
    echo "   Detaching Internet Gateway: $IGW_ID"
    aws ec2 detach-internet-gateway --region $REGION --internet-gateway-id $IGW_ID --vpc-id $VPC_ID
    echo "   Deleting Internet Gateway: $IGW_ID"
    aws ec2 delete-internet-gateway --region $REGION --internet-gateway-id $IGW_ID
done

# 10. Finally, delete the VPC
echo "10. Deleting VPC..."
aws ec2 delete-vpc --region $REGION --vpc-id $VPC_ID

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ VPC $VPC_ID deleted successfully!"
else
    echo ""
    echo "❌ Failed to delete VPC. Check for remaining dependencies:"
    echo "   - RDS instances"
    echo "   - VPC endpoints"
    echo "   - VPN connections"
    echo "   - Or permission issues with specific resources"
fi