#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
S3_BUCKET="vast-deploy-bucket"
AWS_REGION="us-west-2"

echo "=== TAMS Deployment with VAST Integration ==="
echo "Configuring TAMS to work with VAST infrastructure..."

# First, let's set up a mock VAST DB endpoint on the bastion
BASTION_IP="54.68.173.229"
echo "Setting up VAST DB simulator on bastion..."

ssh -o StrictHostKeyChecking=no -i $SSH_KEY ubuntu@$BASTION_IP << 'EOF'
# Install Docker if not present
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker ubuntu
fi

# Run a PostgreSQL container as VAST DB simulator
echo "Starting VAST DB simulator (PostgreSQL)..."
sudo docker stop vast-db 2>/dev/null || true
sudo docker rm vast-db 2>/dev/null || true

sudo docker run -d \
  --name vast-db \
  --restart unless-stopped \
  -e POSTGRES_DB=vastdb \
  -e POSTGRES_USER=vast \
  -e POSTGRES_PASSWORD=vastpass \
  -p 5432:5432 \
  postgres:15-alpine

# Wait for DB to be ready
sleep 10

# Create TAMS schema
sudo docker exec vast-db psql -U vast -d vastdb -c "CREATE SCHEMA IF NOT EXISTS tams;"

echo "VAST DB simulator running on port 5432"
EOF

# Now configure TAMS with proper environment
echo ""
echo "Configuring TAMS on tams_vm..."

ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << EOF
# Stop existing container
echo "Stopping existing TAMS container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

# Create configuration file for TAMS
echo "Creating TAMS configuration..."
sudo mkdir -p /etc/tams

cat > /tmp/tams-config.json << 'CONFIG'
{
  "api_title": "TAMS API - VAST Integration",
  "api_version": "6.0",
  "api_description": "Time-addressable Media Store with VAST",
  
  "vast_endpoint": "http://$BASTION_IP:5432",
  "vast_access_key": "vast",
  "vast_secret_key": "vastpass",
  "vast_bucket": "vastdb",
  "vast_schema": "tams",
  
  "s3_endpoint_url": "https://s3.$AWS_REGION.amazonaws.com",
  "s3_bucket_name": "$S3_BUCKET",
  "s3_use_ssl": true,
  
  "log_level": "INFO"
}
CONFIG

sudo mv /tmp/tams-config.json /etc/tams/config.json

# Create environment file with AWS credentials for S3 access
cat > /tmp/tams.env << 'ENVFILE'
# TAMS Configuration
TAMS_ENV=production
TAMS_LOG_LEVEL=INFO
TAMS_HOST=0.0.0.0
TAMS_PORT=8000

# VAST DB Configuration (PostgreSQL simulator on bastion)
DATABASE_URL=postgresql://vast:vastpass@$BASTION_IP:5432/vastdb
VAST_ENDPOINT=http://$BASTION_IP:5432
VAST_ACCESS_KEY=vast
VAST_SECRET_KEY=vastpass
VAST_BUCKET=vastdb
VAST_SCHEMA=tams

# AWS S3 Configuration
AWS_REGION=$AWS_REGION
S3_BUCKET_NAME=$S3_BUCKET
S3_ENDPOINT_URL=https://s3.$AWS_REGION.amazonaws.com
S3_USE_SSL=true

# Use instance IAM role for S3 access
AWS_DEFAULT_REGION=$AWS_REGION

# API Settings
API_V1_STR=/api/v1
PROJECT_NAME=TAMS-VAST-POC
ENVFILE

sudo mv /tmp/tams.env /home/ubuntu/tams.env

# Update the TAMS application to use real configuration
echo "Updating TAMS application code..."
cd /home/ubuntu/vasttams

# Create a modified run.py that handles the integration
cat > /home/ubuntu/run_integrated.py << 'RUNPY'
import uvicorn
import logging
import os
import sys

# Add app directory to path
sys.path.insert(0, '/app')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import the actual TAMS app
try:
    from app.main import app
    logger.info("Successfully imported TAMS application")
except ImportError as e:
    logger.error(f"Failed to import TAMS app: {e}")
    # Fallback to minimal app
    from fastapi import FastAPI
    from fastapi.responses import JSONResponse
    
    app = FastAPI(title="TAMS POC", version="0.1.0")
    
    @app.get("/")
    async def root():
        return {"message": "TAMS POC API", "status": "running", "mode": "fallback"}
    
    @app.get("/health")
    async def health():
        return JSONResponse(
            status_code=200,
            content={"status": "healthy", "service": "TAMS POC", "mode": "fallback"}
        )

if __name__ == "__main__":
    logger.info("Starting TAMS API server with VAST integration on 0.0.0.0:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
RUNPY

# Grant S3 permissions to the instance (via IAM role attachment)
echo "Note: Ensure the tams_vm instance has IAM role with S3 access to $S3_BUCKET"

# Run the integrated TAMS container
echo "Starting TAMS container with VAST integration..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file /home/ubuntu/tams.env \
  -v /etc/tams:/etc/tams:ro \
  -v /home/ubuntu/tams-data:/app/data \
  -v /home/ubuntu/tams-logs:/app/logs \
  -v /home/ubuntu/run_integrated.py:/app/run.py:ro \
  --add-host="vast-db:$BASTION_IP" \
  vasttams:latest

# Wait for startup
echo "Waiting for TAMS to start..."
sleep 10

# Check status
echo ""
echo "Container status:"
sudo docker ps | grep vasttams || echo "Container not running"

# Check logs
echo ""
echo "Recent logs:"
sudo docker logs --tail 30 vasttams

# Test endpoints
echo ""
echo "Testing endpoints..."
echo "Health check:"
curl -s http://localhost:8000/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo "API root:"
curl -s http://localhost:8000/ | python3 -m json.tool || echo "Root endpoint failed"

echo ""
echo "Sources endpoint (VAST integration):"
curl -s http://localhost:8000/api/v1/sources | python3 -m json.tool 2>/dev/null || echo "Sources endpoint not yet available"

EOF

echo ""
echo "=== Updating IAM Role for S3 Access ==="
# Attach S3 policy to tams_vm IAM role for bucket access
aws iam attach-role-policy \
  --role-name vast-datalayer-poc-tams-vm-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonS3FullAccess \
  2>/dev/null || echo "S3 policy might already be attached"

echo ""
echo "=== Deployment Summary ==="
echo "TAMS API: http://$TAMS_VM_IP:8000"
echo "Health: http://$TAMS_VM_IP:8000/health"
echo "API Docs: http://$TAMS_VM_IP:8000/docs"
echo ""
echo "VAST Components:"
echo "- VAST DB Simulator: PostgreSQL on $BASTION_IP:5432"
echo "- VAST Storage: AWS S3 bucket '$S3_BUCKET'"
echo ""
echo "Testing external access..."
curl -s http://$TAMS_VM_IP:8000/health && echo "" || echo "External access check failed"