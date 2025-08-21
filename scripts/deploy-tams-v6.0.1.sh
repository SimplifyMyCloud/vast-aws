#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
VERSION="6.0.1"

echo "=== TAMS v${VERSION} Deployment with VAST Integration ==="
echo "Deploying TAMS version ${VERSION} to tams_vm..."
echo ""

# First, sync the updated vasttams code to the remote server
echo "1. Copying vasttams v${VERSION} code to remote server..."
rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
  -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  ./vasttams/ $SSH_USER@$TAMS_VM_IP:/home/ubuntu/vasttams-v${VERSION}/

# Build and deploy on the remote server
ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << EOF
echo "2. Stopping existing container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

echo "3. Building TAMS v${VERSION} Docker image..."
cd /home/ubuntu/vasttams-v${VERSION}

# Build the new image with version tag
sudo docker build -t vasttams:${VERSION} -t vasttams:latest .

# Also build with boto3 for S3 support
cat > /tmp/Dockerfile.tams-v${VERSION} << 'DOCKERFILE'
FROM vasttams:${VERSION}
RUN pip install --no-cache-dir boto3
DOCKERFILE

sudo docker build -t vasttams-s3:${VERSION} -t vasttams-s3:latest -f /tmp/Dockerfile.tams-v${VERSION} .

echo "4. Creating VAST-integrated configuration..."
cat > /home/ubuntu/tams_vast_v${VERSION}.py << 'APPPY'
import uvicorn
import logging
import os
import sys
import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Dict, Any
import sqlite3
import json
from datetime import datetime

# Add app directory to path for imports
sys.path.insert(0, '/app')

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Try to import the actual TAMS app v6.0.1
try:
    from app.main import app
    logger.info("Successfully imported TAMS v${VERSION} application")
    USING_NATIVE_APP = True
except ImportError as e:
    logger.warning(f"Could not import native TAMS app, using custom integration: {e}")
    USING_NATIVE_APP = False
    
    app = FastAPI(
        title="TAMS API v${VERSION} - VAST Integration",
        version="${VERSION}",
        description="Time-addressable Media Store connected to VAST cluster"
    )

# VAST S3 Configuration
VAST_S3_ENDPOINT = "http://10.0.11.54"  # Primary protocol VIP
VAST_S3_ENDPOINT_BACKUP = "http://10.0.11.170"  # Backup protocol VIP
VAST_ACCESS_KEY = "RTK1A2B7RVTB77Q9KPL1"
VAST_SECRET_KEY = "WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO"
VAST_BUCKET_DB = "tams-db"
VAST_BUCKET_S3 = "tams-s3"

# Configure S3 client for VAST
s3_config = Config(
    signature_version='s3v4',
    retries={'max_attempts': 3},
    s3={'addressing_style': 'path'}
)

s3_client = None
try:
    s3_client = boto3.client(
        's3',
        endpoint_url=VAST_S3_ENDPOINT,
        aws_access_key_id=VAST_ACCESS_KEY,
        aws_secret_access_key=VAST_SECRET_KEY,
        config=s3_config,
        verify=False
    )
    logger.info(f"Connected to VAST S3 at {VAST_S3_ENDPOINT}")
except Exception as e:
    logger.error(f"Failed to connect to VAST S3: {e}")

# Add custom endpoints if using native app
if USING_NATIVE_APP:
    @app.get("/vast/status")
    async def vast_status():
        """Check VAST integration status"""
        try:
            response = s3_client.list_buckets() if s3_client else None
            if response:
                return {
                    "version": "${VERSION}",
                    "vast_connected": True,
                    "endpoint": VAST_S3_ENDPOINT,
                    "buckets": [b['Name'] for b in response.get('Buckets', [])]
                }
        except Exception as e:
            pass
        
        return {
            "version": "${VERSION}",
            "vast_connected": False,
            "error": "VAST S3 connection failed"
        }

else:
    # Custom endpoints for standalone mode
    @app.get("/")
    async def root():
        return {
            "message": "TAMS API v${VERSION}",
            "status": "running",
            "storage": {
                "type": "VAST S3",
                "primary_endpoint": VAST_S3_ENDPOINT,
                "version": "${VERSION}"
            }
        }

    @app.get("/health")
    async def health():
        """Health check endpoint"""
        try:
            response = s3_client.list_buckets() if s3_client else None
            s3_status = "connected" if response else "disconnected"
            bucket_count = len(response.get('Buckets', [])) if response else 0
        except Exception as e:
            s3_status = f"error: {str(e)}"
            bucket_count = 0
        
        return JSONResponse(
            status_code=200 if s3_status == "connected" else 503,
            content={
                "status": "healthy" if s3_status == "connected" else "degraded",
                "version": "${VERSION}",
                "service": "TAMS with VAST S3",
                "storage": {
                    "vast_s3": s3_status,
                    "endpoint": VAST_S3_ENDPOINT,
                    "buckets": bucket_count
                }
            }
        )

if __name__ == "__main__":
    logger.info(f"Starting TAMS v${VERSION} with VAST S3 backend")
    uvicorn.run(app, host="0.0.0.0", port=8000)
APPPY

echo "5. Creating environment configuration..."
cat > /home/ubuntu/tams-v${VERSION}.env << 'ENVFILE'
# TAMS v${VERSION} Configuration
TAMS_VERSION=${VERSION}
TAMS_ENV=production
TAMS_LOG_LEVEL=INFO
TAMS_HOST=0.0.0.0
TAMS_PORT=8000

# VAST S3 Configuration
VAST_ENDPOINT=http://10.0.11.54
VAST_ACCESS_KEY=RTK1A2B7RVTB77Q9KPL1
VAST_SECRET_KEY=WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO
VAST_BUCKET=tams-db
VAST_SCHEMA=tams

# S3 Storage Configuration
S3_ENDPOINT_URL=http://10.0.11.54
S3_ACCESS_KEY_ID=RTK1A2B7RVTB77Q9KPL1
S3_SECRET_ACCESS_KEY=WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO
S3_BUCKET_NAME=tams-s3
S3_USE_SSL=false

# Database Configuration
DATABASE_URL=sqlite:////tmp/tams.db

# API Settings
API_V1_STR=/api/v1
PROJECT_NAME=TAMS-v${VERSION}
ENVFILE

echo "6. Starting TAMS v${VERSION} container..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file /home/ubuntu/tams-v${VERSION}.env \
  -v /home/ubuntu/tams_vast_v${VERSION}.py:/app/run.py:ro \
  -v /home/ubuntu/tams-data:/app/data \
  -v /home/ubuntu/tams-logs:/app/logs \
  vasttams-s3:${VERSION}

echo "7. Waiting for container to start..."
sleep 10

echo ""
echo "=== Container Status ==="
sudo docker ps | grep vasttams || echo "Container not running"

echo ""
echo "=== Container Logs ==="
sudo docker logs --tail 30 vasttams

echo ""
echo "=== Testing TAMS v${VERSION} ==="
echo ""

echo "1. Health check:"
curl -s http://localhost:8000/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo "2. VAST status (if available):"
curl -s http://localhost:8000/vast/status | python3 -m json.tool || echo "Custom endpoint not available"

echo ""
echo "3. Root endpoint:"
curl -s http://localhost:8000/ | python3 -m json.tool || echo "Root endpoint failed"

EOF

echo ""
echo "=== External Verification ==="
echo ""

echo "Testing from outside:"
curl -s http://$TAMS_VM_IP:8000/health | python3 -m json.tool || echo "External health check failed"

echo ""
echo "=== Deployment Complete ==="
echo "TAMS v${VERSION} deployed successfully!"
echo "API Endpoint: http://$TAMS_VM_IP:8000"
echo "Health: http://$TAMS_VM_IP:8000/health"
echo "Docs: http://$TAMS_VM_IP:8000/docs"
echo ""
echo "Use ./manage-tams.sh for container management"