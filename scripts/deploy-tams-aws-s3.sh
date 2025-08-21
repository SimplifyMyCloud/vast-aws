#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
S3_BUCKET="vast-deploy-bucket"
AWS_REGION="us-west-2"

echo "=== TAMS Deployment with AWS S3 Storage ==="
echo "Configuring TAMS to use AWS S3 as storage backend..."

ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << 'EOF'
# Stop existing container
echo "Stopping existing TAMS container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

# Create a modified TAMS app that uses S3 and local SQLite
echo "Creating TAMS application with S3 integration..."
cat > /home/ubuntu/tams_s3_app.py << 'APPPY'
import uvicorn
import logging
import os
import boto3
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Dict, Any
import sqlite3
import json
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="TAMS API - AWS S3 Integration",
    version="1.0.0",
    description="Time-addressable Media Store with AWS S3 backend"
)

# Configuration
S3_BUCKET = os.getenv("S3_BUCKET_NAME", "vast-deploy-bucket")
AWS_REGION = os.getenv("AWS_REGION", "us-west-2")
DB_PATH = "/app/data/tams.db"

# Initialize S3 client (uses instance IAM role)
s3_client = boto3.client('s3', region_name=AWS_REGION)

# Initialize SQLite database
def init_db():
    """Initialize SQLite database for metadata"""
    os.makedirs(os.path.dirname(DB_PATH), exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Create tables
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS sources (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            type TEXT,
            location TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            metadata TEXT
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS flows (
            id TEXT PRIMARY KEY,
            source_id TEXT,
            name TEXT NOT NULL,
            type TEXT,
            s3_key TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            metadata TEXT,
            FOREIGN KEY (source_id) REFERENCES sources (id)
        )
    ''')
    
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS segments (
            id TEXT PRIMARY KEY,
            flow_id TEXT,
            segment_number INTEGER,
            s3_key TEXT,
            start_time REAL,
            end_time REAL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (flow_id) REFERENCES flows (id)
        )
    ''')
    
    conn.commit()
    conn.close()
    logger.info("Database initialized successfully")

# Initialize DB on startup
init_db()

@app.get("/")
async def root():
    return {
        "message": "TAMS API with AWS S3 Storage",
        "status": "running",
        "storage": {
            "type": "AWS S3",
            "bucket": S3_BUCKET,
            "region": AWS_REGION
        }
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    try:
        # Check S3 access
        s3_client.head_bucket(Bucket=S3_BUCKET)
        s3_status = "connected"
    except Exception as e:
        s3_status = f"error: {str(e)}"
    
    # Check database
    try:
        conn = sqlite3.connect(DB_PATH)
        cursor = conn.cursor()
        cursor.execute("SELECT COUNT(*) FROM sources")
        source_count = cursor.fetchone()[0]
        conn.close()
        db_status = "connected"
    except Exception as e:
        db_status = f"error: {str(e)}"
        source_count = 0
    
    return JSONResponse(
        status_code=200 if s3_status == "connected" else 503,
        content={
            "status": "healthy" if s3_status == "connected" else "degraded",
            "service": "TAMS with S3",
            "storage": {
                "s3": s3_status,
                "bucket": S3_BUCKET
            },
            "database": db_status,
            "sources_count": source_count
        }
    )

@app.get("/api/v1/sources")
async def list_sources():
    """List all sources"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, name, type, location, created_at FROM sources")
    sources = []
    for row in cursor.fetchall():
        sources.append({
            "id": row[0],
            "name": row[1],
            "type": row[2],
            "location": row[3],
            "created_at": row[4]
        })
    conn.close()
    return {"sources": sources, "count": len(sources)}

@app.post("/api/v1/sources")
async def create_source(source_data: Dict[str, Any]):
    """Create a new source"""
    import uuid
    source_id = str(uuid.uuid4())
    
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO sources (id, name, type, location, metadata) VALUES (?, ?, ?, ?, ?)",
        (source_id, source_data.get("name"), source_data.get("type", "video"),
         source_data.get("location", ""), json.dumps(source_data.get("metadata", {})))
    )
    conn.commit()
    conn.close()
    
    return {"id": source_id, "message": "Source created successfully"}

@app.get("/api/v1/flows")
async def list_flows():
    """List all flows"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute("SELECT id, source_id, name, type, s3_key, created_at FROM flows")
    flows = []
    for row in cursor.fetchall():
        flows.append({
            "id": row[0],
            "source_id": row[1],
            "name": row[2],
            "type": row[3],
            "s3_key": row[4],
            "created_at": row[5]
        })
    conn.close()
    return {"flows": flows, "count": len(flows)}

@app.post("/api/v1/flows")
async def create_flow(flow_data: Dict[str, Any]):
    """Create a new flow and store in S3"""
    import uuid
    flow_id = str(uuid.uuid4())
    s3_key = f"flows/{flow_id}/metadata.json"
    
    # Store metadata in S3
    try:
        s3_client.put_object(
            Bucket=S3_BUCKET,
            Key=s3_key,
            Body=json.dumps(flow_data),
            ContentType='application/json'
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to store in S3: {str(e)}")
    
    # Store reference in database
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    cursor.execute(
        "INSERT INTO flows (id, source_id, name, type, s3_key, metadata) VALUES (?, ?, ?, ?, ?, ?)",
        (flow_id, flow_data.get("source_id"), flow_data.get("name"),
         flow_data.get("type", "video"), s3_key, json.dumps(flow_data))
    )
    conn.commit()
    conn.close()
    
    return {"id": flow_id, "s3_key": s3_key, "message": "Flow created successfully"}

@app.get("/api/v1/storage/test")
async def test_s3_storage():
    """Test S3 storage access"""
    try:
        # List objects in bucket
        response = s3_client.list_objects_v2(Bucket=S3_BUCKET, MaxKeys=10)
        objects = []
        if 'Contents' in response:
            for obj in response['Contents']:
                objects.append({
                    "key": obj['Key'],
                    "size": obj['Size'],
                    "last_modified": obj['LastModified'].isoformat()
                })
        
        return {
            "bucket": S3_BUCKET,
            "region": AWS_REGION,
            "access": "successful",
            "object_count": len(objects),
            "sample_objects": objects[:5]
        }
    except Exception as e:
        return {
            "bucket": S3_BUCKET,
            "region": AWS_REGION,
            "access": "failed",
            "error": str(e)
        }

if __name__ == "__main__":
    logger.info(f"Starting TAMS API with S3 backend (bucket: {S3_BUCKET})")
    uvicorn.run(app, host="0.0.0.0", port=8000)
APPPY

# Create environment file
cat > /home/ubuntu/tams-s3.env << 'ENVFILE'
# AWS Configuration
AWS_REGION=us-west-2
S3_BUCKET_NAME=vast-deploy-bucket
AWS_DEFAULT_REGION=us-west-2

# TAMS Configuration
TAMS_ENV=production
TAMS_LOG_LEVEL=INFO
TAMS_HOST=0.0.0.0
TAMS_PORT=8000

# API Settings
API_V1_STR=/api/v1
PROJECT_NAME=TAMS-S3-POC
ENVFILE

# Install boto3 in the container if needed
echo "Building enhanced TAMS image with boto3..."
cat > /tmp/Dockerfile.tams-s3 << 'DOCKERFILE'
FROM vasttams:latest
RUN pip install --no-cache-dir boto3
DOCKERFILE

sudo docker build -t vasttams-s3:latest -f /tmp/Dockerfile.tams-s3 .

# Run the container
echo "Starting TAMS container with S3 integration..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file /home/ubuntu/tams-s3.env \
  -v /home/ubuntu/tams_s3_app.py:/app/run.py:ro \
  -v /home/ubuntu/tams-data:/app/data \
  -v /home/ubuntu/tams-logs:/app/logs \
  -v /home/ubuntu/.aws:/root/.aws:ro \
  vasttams-s3:latest

# Wait for startup
echo "Waiting for TAMS to start..."
sleep 10

# Check container status
echo ""
echo "Container status:"
sudo docker ps | grep vasttams

# Check logs
echo ""
echo "Container logs:"
sudo docker logs --tail 20 vasttams

# Test endpoints
echo ""
echo "Testing endpoints..."
echo "1. Health check:"
curl -s http://localhost:8000/health | python3 -m json.tool

echo ""
echo "2. Storage test:"
curl -s http://localhost:8000/api/v1/storage/test | python3 -m json.tool

echo ""
echo "3. List sources:"
curl -s http://localhost:8000/api/v1/sources | python3 -m json.tool

EOF

# Ensure IAM role has S3 access
echo ""
echo "=== Configuring IAM Permissions ==="

# Create and attach a policy for S3 bucket access
cat > /tmp/tams-s3-policy.json << 'POLICY'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:PutObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetBucketLocation"
      ],
      "Resource": [
        "arn:aws:s3:::vast-deploy-bucket",
        "arn:aws:s3:::vast-deploy-bucket/*"
      ]
    }
  ]
}
POLICY

# Create the policy
aws iam create-policy \
  --policy-name vast-tams-s3-access \
  --policy-document file:///tmp/tams-s3-policy.json \
  2>/dev/null || echo "Policy might already exist"

# Attach to the role
aws iam attach-role-policy \
  --role-name vast-datalayer-poc-tams-vm-role \
  --policy-arn arn:aws:iam::$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "730420835736"):policy/vast-tams-s3-access \
  2>/dev/null || echo "Policy attachment might already exist"

echo ""
echo "=== Deployment Complete ==="
echo "TAMS API: http://$TAMS_VM_IP:8000"
echo "Health: http://$TAMS_VM_IP:8000/health"
echo "Storage Test: http://$TAMS_VM_IP:8000/api/v1/storage/test"
echo ""
echo "Storage Backend: AWS S3 bucket 'vast-deploy-bucket'"
echo "Database: SQLite (local) for metadata"
echo ""
echo "Testing external access..."
curl -s http://$TAMS_VM_IP:8000/health | python3 -m json.tool