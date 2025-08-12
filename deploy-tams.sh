#!/bin/bash
set -e

# Configuration
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"
CONTAINER_NAME="vasttams"
IMAGE_NAME="vasttams:latest"
PORT="8000"

echo "=== TAMS Container Deployment Script ==="
echo "Deploying to: $TAMS_VM_IP"

# Build the Docker image locally
echo "Building Docker image..."
cd vasttams
docker build -t $IMAGE_NAME .
cd ..

# Save the Docker image to a tar file
echo "Saving Docker image to tar..."
docker save $IMAGE_NAME -o /tmp/vasttams.tar

# Copy the tar file to the remote server
echo "Copying image to tams_vm..."
scp -o StrictHostKeyChecking=no -i $SSH_KEY /tmp/vasttams.tar $SSH_USER@$TAMS_VM_IP:/tmp/

# Load and run the container on the remote server
echo "Loading and running container on tams_vm..."
ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP << 'EOF'
# Load the Docker image
echo "Loading Docker image..."
docker load -i /tmp/vasttams.tar

# Stop and remove existing container if it exists
echo "Cleaning up existing container..."
docker stop vasttams 2>/dev/null || true
docker rm vasttams 2>/dev/null || true

# Create a simple .env file with minimal config
echo "Creating environment configuration..."
cat > /tmp/tams.env << 'ENVFILE'
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
ENVFILE

# Run the container
echo "Starting TAMS container..."
docker run -d \
  --name vasttams \
  --restart unless-stopped \
  -p 8000:8000 \
  --env-file /tmp/tams.env \
  -v /home/ubuntu/tams-data:/app/data \
  vasttams:latest

# Wait for container to start
sleep 5

# Check container status
echo "Checking container status..."
docker ps | grep vasttams

# Check logs
echo "Recent container logs:"
docker logs --tail 20 vasttams

# Clean up tar file
rm /tmp/vasttams.tar

echo "Deployment complete!"
echo "TAMS API should be accessible at: http://$TAMS_VM_IP:8000"
echo "Health check: http://$TAMS_VM_IP:8000/health"
EOF

# Clean up local tar file
rm /tmp/vasttams.tar

echo ""
echo "=== Deployment Complete ==="
echo "TAMS API endpoint: http://$TAMS_VM_IP:$PORT"
echo "Health check: http://$TAMS_VM_IP:$PORT/health"
echo "View logs: ssh -i $SSH_KEY $SSH_USER@$TAMS_VM_IP 'docker logs vasttams'"