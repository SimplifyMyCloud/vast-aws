#!/bin/bash

# AWS Credential Re-authentication Script
# This script helps refresh AWS credentials that expire every 4 hours

set -e

echo "AWS Credential Re-authentication"
echo "================================"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed. Please install it first."
    exit 1
fi

# Common corporate SSO login
if [[ "$1" == "sso" ]]; then
    PROFILE=${2:-default}
    echo "Starting AWS SSO login for profile: $PROFILE"
    aws sso login --profile $PROFILE
    echo "SSO login complete. Credentials refreshed."
    echo ""
    echo "To use this profile, either:"
    echo "  export AWS_PROFILE=$PROFILE"
    echo "  or add --profile $PROFILE to your AWS commands"
    exit 0
fi

# List available profiles
if [[ "$1" == "list-profiles" ]]; then
    echo "Available AWS profiles:"
    aws configure list-profiles
    exit 0
fi

# If using assume-role pattern
if [[ "$1" == "assume-role" ]]; then
    if [[ -z "$2" ]]; then
        echo "Usage: ./aws-reauth.sh assume-role <role-arn>"
        exit 1
    fi
    
    ROLE_ARN=$2
    SESSION_NAME="terraform-session-$(date +%s)"
    
    echo "Assuming role: $ROLE_ARN"
    
    # Assume the role and capture credentials
    CREDS=$(aws sts assume-role \
        --role-arn "$ROLE_ARN" \
        --role-session-name "$SESSION_NAME" \
        --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' \
        --output text)
    
    # Export credentials
    export AWS_ACCESS_KEY_ID=$(echo $CREDS | awk '{print $1}')
    export AWS_SECRET_ACCESS_KEY=$(echo $CREDS | awk '{print $2}')
    export AWS_SESSION_TOKEN=$(echo $CREDS | awk '{print $3}')
    
    echo "Credentials exported to environment."
    echo "Run: source ./aws-reauth.sh assume-role <role-arn>"
    exit 0
fi

# Default: Show current identity and options
echo "Current AWS identity:"
aws sts get-caller-identity 2>/dev/null || echo "No valid credentials found."

echo ""
echo "Usage:"
echo "  ./aws-reauth.sh sso [profile]         # For AWS SSO login (default: 'default' profile)"
echo "  ./aws-reauth.sh assume-role <role-arn> # For assuming a role"
echo "  ./aws-reauth.sh list-profiles          # List configured AWS profiles"
echo ""
echo "For environment variables, run with 'source':"
echo "  source ./aws-reauth.sh assume-role <role-arn>"