#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"

echo "=== TAMS Minimal Deployment ==="

# Deploy with minimal configuration
ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << 'EOF'
# Stop and remove existing container
echo "Stopping existing container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

# Create a minimal run.py that doesn't require VAST DB
echo "Creating minimal run configuration..."
cat > /home/ubuntu/run_minimal.py << 'RUNPY'
import uvicorn
from fastapi import FastAPI
from fastapi.responses import JSONResponse
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="TAMS POC", version="0.1.0")

@app.get("/")
async def root():
    return {"message": "TAMS POC API", "status": "running"}

@app.get("/health")
async def health():
    return JSONResponse(
        status_code=200,
        content={"status": "healthy", "service": "TAMS POC"}
    )

@app.get("/api/v1/sources")
async def sources():
    return {"sources": [], "message": "POC mode - no VAST DB connection"}

@app.get("/api/v1/flows")
async def flows():
    return {"flows": [], "message": "POC mode - no VAST DB connection"}

if __name__ == "__main__":
    logger.info("Starting TAMS POC API server on 0.0.0.0:8000")
    uvicorn.run(app, host="0.0.0.0", port=8000)
RUNPY

# Run container with the minimal app
echo "Starting TAMS container with minimal config..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  -v /home/ubuntu/run_minimal.py:/app/run.py:ro \
  vasttams:latest

# Wait for startup
echo "Waiting for container to start..."
sleep 5

# Check status
echo "Container status:"
sudo docker ps | grep vasttams

# Test health endpoint
echo ""
echo "Testing health endpoint locally..."
curl -s http://localhost:8000/health | python3 -m json.tool || echo "Health check failed"

echo ""
echo "Testing API root..."
curl -s http://localhost:8000/ | python3 -m json.tool || echo "Root endpoint failed"

EOF

echo ""
echo "=== Testing from outside ==="
sleep 2

# Check if we need to update security group for port 8000
echo "Checking security group rules..."
INSTANCE_ID=$(terraform output -raw tams_vm_instance_id)
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text --profile monks-poc-admin-chrisl)

echo "Security Group ID: $SG_ID"
echo ""

# Check if port 8000 is open
PORT_OPEN=$(aws ec2 describe-security-groups --group-ids $SG_ID --query "SecurityGroups[0].IpPermissions[?FromPort==\`8000\`]" --output json --profile monks-poc-admin-chrisl | jq '. | length')

if [ "$PORT_OPEN" -eq "0" ]; then
    echo "Port 8000 not open in security group. Adding rule..."
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8000 \
        --cidr 0.0.0.0/0 \
        --profile monks-poc-admin-chrisl || echo "Rule might already exist"
else
    echo "Port 8000 is already open in security group"
fi

echo ""
echo "=== Deployment Complete ==="
echo "TAMS API: http://$TAMS_VM_IP:8000"
echo "Health: http://$TAMS_VM_IP:8000/health"
echo ""
echo "Testing external access..."
curl -s http://$TAMS_VM_IP:8000/health && echo "" || echo "External access not working yet"