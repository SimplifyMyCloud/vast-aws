#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
CONTAINER_NAME="vasttams"
IMAGE_NAME="vasttams:latest"
PORT="8000"

echo "=== TAMS Container Deployment (with sudo) ==="
echo "Deploying to: $TAMS_VM_IP"

# Build and run the container on the remote server
ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << 'EOF'
cd /home/ubuntu/vasttams

# Stop and remove existing container if it exists
echo "Cleaning up existing container..."
sudo docker stop vasttams 2>/dev/null || true
sudo docker rm vasttams 2>/dev/null || true

# Remove old image to ensure fresh build
sudo docker rmi vasttams:latest 2>/dev/null || true

# Build the Docker image
echo "Building Docker image..."
sudo docker build -t vasttams:latest .

# Create data directories
sudo mkdir -p /home/ubuntu/tams-data /home/ubuntu/tams-logs
sudo chown ubuntu:ubuntu /home/ubuntu/tams-data /home/ubuntu/tams-logs

# Run the container with minimal config for POC
echo "Starting TAMS container..."
sudo docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  -e TAMS_ENV=development \
  -e TAMS_LOG_LEVEL=INFO \
  -e TAMS_HOST=0.0.0.0 \
  -e TAMS_PORT=8000 \
  -e AWS_REGION=us-west-2 \
  -e S3_BUCKET_NAME=vast-deploy-bucket \
  -e DATABASE_URL=sqlite:////app/data/tams.db \
  -e API_V1_STR=/api/v1 \
  -e PROJECT_NAME=TAMS-POC \
  -v /home/ubuntu/tams-data:/app/data \
  -v /home/ubuntu/tams-logs:/app/logs \
  vasttams:latest

# Wait for container to start
echo "Waiting for container to start..."
sleep 10

# Check container status
echo "Container status:"
sudo docker ps | grep vasttams || echo "Container might not be running"

# Check logs
echo ""
echo "Container logs:"
sudo docker logs --tail 50 vasttams

echo ""
echo "Deployment complete!"
EOF

echo ""
echo "=== Testing Deployment ==="

# Test the health endpoint
echo "Testing health endpoint..."
curl -s http://$TAMS_VM_IP:$PORT/health && echo "" || echo "Health check failed"

# Test the API docs
echo ""
echo "Testing API docs endpoint..."
curl -s -o /dev/null -w "%{http_code}" http://$TAMS_VM_IP:$PORT/docs | grep -q "200" && echo "API docs accessible" || echo "API docs not accessible"

echo ""
echo "=== Deployment Summary ==="
echo "TAMS API endpoint: http://$TAMS_VM_IP:$PORT"
echo "Health check: http://$TAMS_VM_IP:$PORT/health"
echo "API docs: http://$TAMS_VM_IP:$PORT/docs"
echo ""
echo "Useful commands:"
echo "  View logs: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'sudo docker logs vasttams'"
echo "  Restart: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'sudo docker restart vasttams'"
echo "  Shell: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'sudo docker exec -it vasttams /bin/bash'"
echo "  Status: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'sudo docker ps | grep vasttams'"