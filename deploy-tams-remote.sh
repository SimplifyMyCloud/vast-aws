#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
CONTAINER_NAME="vasttams"
IMAGE_NAME="vasttams:latest"
PORT="8000"

echo "=== TAMS Container Remote Deployment Script ==="
echo "Deploying to: $TAMS_VM_IP"

# First, copy the vasttams directory to the remote server
echo "Copying vasttams code to remote server..."
rsync -avz --exclude='.git' --exclude='__pycache__' --exclude='*.pyc' \
  -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
  ./vasttams/ $SSH_USER@$TAMS_VM_IP:/home/ubuntu/vasttams/

# Build and run the container on the remote server
echo "Building and running container on tams_vm..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << 'EOF'
cd /home/ubuntu/vasttams

# Stop and remove existing container if it exists
echo "Cleaning up existing container..."
docker stop vasttams 2>/dev/null || true
docker rm vasttams 2>/dev/null || true

# Build the Docker image
echo "Building Docker image..."
docker build -t vasttams:latest .

# Create a simple .env file with minimal config
echo "Creating environment configuration..."
cat > /home/ubuntu/tams.env << 'ENVFILE'
# Basic TAMS Configuration
TAMS_ENV=development
TAMS_LOG_LEVEL=INFO
TAMS_HOST=0.0.0.0
TAMS_PORT=8000

# S3 Configuration (using instance IAM role)
AWS_REGION=us-west-2
S3_BUCKET_NAME=vast-deploy-bucket

# Database Configuration (SQLite for POC)
DATABASE_URL=sqlite:////app/data/tams.db

# API Settings
API_V1_STR=/api/v1
PROJECT_NAME=TAMS-POC
ENVFILE

# Create data directory
mkdir -p /home/ubuntu/tams-data

# Run the container
echo "Starting TAMS container..."
docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file /home/ubuntu/tams.env \
  -v /home/ubuntu/tams-data:/app/data \
  -v /home/ubuntu/tams-data:/app/vast_data \
  -v /home/ubuntu/tams-logs:/app/logs \
  vasttams:latest

# Wait for container to start
echo "Waiting for container to start..."
sleep 10

# Check container status
echo "Container status:"
docker ps | grep vasttams || echo "Container not running"

# Check logs
echo "Recent container logs:"
docker logs --tail 30 vasttams

echo ""
echo "Deployment complete!"
echo "TAMS API should be accessible at: http://34.216.9.25:8000"
echo "Health check: http://34.216.9.25:8000/health"
EOF

echo ""
echo "=== Deployment Complete ==="
echo "TAMS API endpoint: http://$TAMS_VM_IP:$PORT"
echo "Health check: http://$TAMS_VM_IP:$PORT/health"
echo "API docs: http://$TAMS_VM_IP:$PORT/docs"
echo ""
echo "Useful commands:"
echo "  View logs: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'docker logs vasttams'"
echo "  Restart: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'docker restart vasttams'"
echo "  Shell: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'docker exec -it vasttams /bin/bash'"

# Test the health endpoint
echo ""
echo "Testing health endpoint..."
sleep 2
curl -s http://$TAMS_VM_IP:$PORT/health || echo "Health check not yet available"