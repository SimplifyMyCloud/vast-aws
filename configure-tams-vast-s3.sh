#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"

# VAST S3 Configuration
VAST_S3_ENDPOINT="http://10.0.11.161:9090"
VAST_ACCESS_KEY="RTK1A2B7RVTB77Q9KPL1"
VAST_SECRET_KEY="WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO"
VAST_BUCKET="tams-storage"  # Default bucket name

echo "=== Configuring TAMS with VAST S3 Storage ==="
echo "VAST S3 Endpoint: $VAST_S3_ENDPOINT"
echo "Access Key: $VAST_ACCESS_KEY"
echo ""

ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << EOF
# Stop existing container
echo "Stopping existing TAMS container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

# Create updated TAMS app with VAST S3 configuration
echo "Creating TAMS app with VAST S3 integration..."
cat > /home/ubuntu/tams_vast_s3.py << 'APPPY'
import uvicorn
import logging
import os
import boto3
from botocore.config import Config
from fastapi import FastAPI, HTTPException
from fastapi.responses import JSONResponse
from typing import List, Dict, Any
import sqlite3
import json
from datetime import datetime

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="TAMS API - VAST S3 Integration",
    version="1.0.0",
    description="Time-addressable Media Store with VAST S3 backend"
)

# VAST Configuration
VAST_S3_ENDPOINT = "$VAST_S3_ENDPOINT"
VAST_ACCESS_KEY = "$VAST_ACCESS_KEY"
VAST_SECRET_KEY = "$VAST_SECRET_KEY"
VAST_BUCKET = "$VAST_BUCKET"
DB_PATH = "/tmp/tams.db"

# Initialize S3 client for VAST cluster
s3_config = Config(
    signature_version='s3v4',
    retries={'max_attempts': 3}
)

s3_client = boto3.client(
    's3',
    endpoint_url=VAST_S3_ENDPOINT,
    aws_access_key_id=VAST_ACCESS_KEY,
    aws_secret_access_key=VAST_SECRET_KEY,
    config=s3_config,
    verify=False  # For self-signed certificates
)

def init_db():
    """Initialize SQLite database for metadata"""
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
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

# Initialize DB and bucket on startup
def startup_init():
    init_db()
    
    # Try to create bucket if it doesn't exist
    try:
        s3_client.create_bucket(Bucket=VAST_BUCKET)
        logger.info(f"Created bucket: {VAST_BUCKET}")
    except Exception as e:
        logger.info(f"Bucket might already exist or creation failed: {e}")

startup_init()

@app.get("/")
async def root():
    return {
        "message": "TAMS API with VAST S3 Storage",
        "status": "running",
        "storage": {
            "type": "VAST S3",
            "endpoint": VAST_S3_ENDPOINT,
            "bucket": VAST_BUCKET
        }
    }

@app.get("/health")
async def health():
    """Health check endpoint"""
    try:
        # Test VAST S3 connection
        response = s3_client.head_bucket(Bucket=VAST_BUCKET)
        s3_status = "connected"
        vast_info = f"Connected to VAST cluster"
    except Exception as e:
        s3_status = f"error: {str(e)}"
        vast_info = "VAST connection failed"
    
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
            "service": "TAMS with VAST S3",
            "storage": {
                "vast_s3": s3_status,
                "endpoint": VAST_S3_ENDPOINT,
                "bucket": VAST_BUCKET,
                "info": vast_info
            },
            "database": db_status,
            "sources_count": source_count
        }
    )

@app.get("/api/v1/vast/test")
async def test_vast_connection():
    """Test VAST S3 connectivity and list some objects"""
    try:
        # Test bucket access
        s3_client.head_bucket(Bucket=VAST_BUCKET)
        
        # List some objects
        response = s3_client.list_objects_v2(Bucket=VAST_BUCKET, MaxKeys=10)
        objects = []
        if 'Contents' in response:
            for obj in response['Contents']:
                objects.append({
                    "key": obj['Key'],
                    "size": obj['Size'],
                    "last_modified": obj['LastModified'].isoformat()
                })
        
        return {
            "vast_cluster": "10.0.11.161",
            "s3_endpoint": VAST_S3_ENDPOINT,
            "bucket": VAST_BUCKET,
            "connection": "successful",
            "object_count": len(objects),
            "sample_objects": objects[:5]
        }
    except Exception as e:
        return {
            "vast_cluster": "10.0.11.161", 
            "s3_endpoint": VAST_S3_ENDPOINT,
            "bucket": VAST_BUCKET,
            "connection": "failed",
            "error": str(e),
            "suggestion": "Check VAST S3 service is running and credentials are correct"
        }

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

@app.post("/api/v1/flows")
async def create_flow(flow_data: Dict[str, Any]):
    """Create a new flow and store in VAST S3"""
    import uuid
    flow_id = str(uuid.uuid4())
    s3_key = f"flows/{flow_id}/metadata.json"
    
    # Store metadata in VAST S3
    try:
        s3_client.put_object(
            Bucket=VAST_BUCKET,
            Key=s3_key,
            Body=json.dumps(flow_data),
            ContentType='application/json'
        )
        logger.info(f"Stored flow metadata in VAST: {s3_key}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to store in VAST S3: {str(e)}")
    
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
    
    return {"id": flow_id, "s3_key": s3_key, "message": "Flow stored in VAST S3 successfully"}

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

if __name__ == "__main__":
    logger.info(f"Starting TAMS API with VAST S3 backend")
    logger.info(f"VAST S3 Endpoint: {VAST_S3_ENDPOINT}")
    logger.info(f"VAST S3 Bucket: {VAST_BUCKET}")
    uvicorn.run(app, host="0.0.0.0", port=8000)
APPPY

# Run the container with VAST S3 configuration
echo "Starting TAMS container with VAST S3..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  -v /home/ubuntu/tams_vast_s3.py:/app/run.py:ro \
  vasttams-s3:latest

# Wait for startup
echo "Waiting for TAMS to start..."
sleep 10

# Test the integration
echo ""
echo "=== Testing TAMS with VAST S3 ==="
echo ""

echo "1. Health check:"
curl -s http://localhost:8000/health | python3 -m json.tool

echo ""
echo "2. VAST connection test:"
curl -s http://localhost:8000/api/v1/vast/test | python3 -m json.tool

echo ""
echo "3. Create a test source:"
curl -s -X POST http://localhost:8000/api/v1/sources \
  -H "Content-Type: application/json" \
  -d '{"name": "VAST Media Source", "type": "video", "location": "vast://10.0.11.161/stream1"}' \
  | python3 -m json.tool

echo ""
echo "4. Create a test flow (will store in VAST S3):"
curl -s -X POST http://localhost:8000/api/v1/flows \
  -H "Content-Type: application/json" \
  -d '{"name": "VAST Test Flow", "type": "video", "source_id": "test", "metadata": {"fps": 30, "bitrate": "5mbps"}}' \
  | python3 -m json.tool

EOF

echo ""
echo "=== VAST S3 Integration Complete ==="
echo "TAMS API: http://$TAMS_VM_IP:8000"
echo "VAST Test: http://$TAMS_VM_IP:8000/api/v1/vast/test"
echo "Health: http://$TAMS_VM_IP:8000/health"
echo ""
echo "Testing external access..."
curl -s http://$TAMS_VM_IP:8000/health | python3 -m json.tool