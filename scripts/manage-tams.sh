#!/bin/bash

# TAMS Container Management Script
TAMS_VM_IP="34.216.9.25"
SSH_KEY="./vast-datalayer-poc-key.pem"
SSH_USER="ubuntu"

case "$1" in
  status)
    echo "Checking TAMS container status..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker ps | grep vasttams"
    echo ""
    echo "Testing health endpoint..."
    curl -s http://$TAMS_VM_IP:8000/health | python3 -m json.tool
    ;;
    
  logs)
    echo "Showing TAMS container logs..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker logs --tail ${2:-50} vasttams"
    ;;
    
  restart)
    echo "Restarting TAMS container..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker restart vasttams"
    sleep 5
    $0 status
    ;;
    
  stop)
    echo "Stopping TAMS container..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker stop vasttams"
    ;;
    
  start)
    echo "Starting TAMS container..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker start vasttams"
    sleep 5
    $0 status
    ;;
    
  shell)
    echo "Opening shell in TAMS container..."
    ssh -o StrictHostKeyChecking=no -i $SSH_KEY $SSH_USER@$TAMS_VM_IP "sudo docker exec -it vasttams /bin/bash"
    ;;
    
  deploy-full)
    echo "Deploying full TAMS application (with dependencies)..."
    echo "This would deploy the full application with database connections."
    echo "Not implemented in POC mode."
    ;;
    
  *)
    echo "TAMS Container Management"
    echo "========================="
    echo ""
    echo "Usage: $0 {status|logs|restart|stop|start|shell|deploy-full}"
    echo ""
    echo "Commands:"
    echo "  status      - Check container status and health"
    echo "  logs [n]    - Show last n lines of logs (default: 50)"
    echo "  restart     - Restart the container"
    echo "  stop        - Stop the container"
    echo "  start       - Start the container"
    echo "  shell       - Open shell in container"
    echo "  deploy-full - Deploy full application (not POC)"
    echo ""
    echo "Current endpoints:"
    echo "  API:    http://$TAMS_VM_IP:8000/"
    echo "  Health: http://$TAMS_VM_IP:8000/health"
    echo "  Docs:   http://$TAMS_VM_IP:8000/docs (if available)"
    ;;
esac