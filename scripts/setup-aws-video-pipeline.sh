#!/bin/bash
set -e

# Setup AWS Video Processing Pipeline for VAST-TAMS Integration
echo "================================================"
echo "  AWS VIDEO PROCESSING PIPELINE SETUP"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AWS_REGION="${AWS_REGION:-us-west-2}"
TAMS_API_URL="${TAMS_API_URL:-http://34.216.9.25:8000}"
VAST_ENDPOINT="${VAST_ENDPOINT:-http://10.0.11.161:9090}"
VAST_BUCKET="${VAST_BUCKET:-tams-storage}"

echo "Configuration:"
echo "  AWS Region: $AWS_REGION"
echo "  TAMS API: $TAMS_API_URL"
echo "  VAST Endpoint: $VAST_ENDPOINT"
echo "  VAST Bucket: $VAST_BUCKET"
echo ""

# Function to check AWS credentials
check_aws_credentials() {
    echo -n "Checking AWS credentials... "
    if aws sts get-caller-identity >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Valid${NC}"
        aws sts get-caller-identity --query 'Account' --output text
    else
        echo -e "${RED}✗ Invalid or missing${NC}"
        echo "Please configure AWS credentials:"
        echo "  aws configure"
        echo "  # OR #"
        echo "  export AWS_ACCESS_KEY_ID=your-key"
        echo "  export AWS_SECRET_ACCESS_KEY=your-secret"
        exit 1
    fi
}

# Function to install Python dependencies for Lambda
prepare_lambda_package() {
    echo ""
    echo -e "${BLUE}📦 Preparing Lambda deployment package...${NC}"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    
    # Copy Lambda function
    cp lambda-video-processor.py "$TEMP_DIR/"
    
    # Install required packages
    echo "Installing Python dependencies..."
    pip install --target "$TEMP_DIR" \
        requests \
        boto3 \
        botocore
    
    # Create deployment package
    cd "$TEMP_DIR"
    zip -r ../lambda-video-processor.zip .
    cd - >/dev/null
    
    # Move package to current directory
    mv "$TEMP_DIR/../lambda-video-processor.zip" ./
    
    # Cleanup
    rm -rf "$TEMP_DIR"
    
    echo -e "${GREEN}✓ Lambda package ready: lambda-video-processor.zip${NC}"
}

# Function to deploy infrastructure
deploy_infrastructure() {
    echo ""
    echo -e "${BLUE}🚀 Deploying AWS infrastructure...${NC}"
    
    # Initialize Terraform
    if [ ! -d ".terraform" ]; then
        echo "Initializing Terraform..."
        terraform init
    fi
    
    # Plan deployment
    echo "Planning deployment..."
    terraform plan \
        -var="aws_region=$AWS_REGION" \
        -var="tams_api_url=$TAMS_API_URL" \
        -var="vast_endpoint=$VAST_ENDPOINT" \
        -var="vast_bucket=$VAST_BUCKET" \
        -out=pipeline.tfplan
    
    # Apply deployment
    echo ""
    echo -e "${YELLOW}Ready to deploy. Press Enter to continue or Ctrl+C to cancel...${NC}"
    read -r
    
    terraform apply pipeline.tfplan
    
    echo -e "${GREEN}✓ Infrastructure deployed successfully${NC}"
}

# Function to test the pipeline
test_pipeline() {
    echo ""
    echo -e "${BLUE}🧪 Testing the pipeline...${NC}"
    
    # Get Lambda function name
    FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "vast-tams-video-processor")
    
    # Create test event
    cat > test-event.json << EOF
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3",
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {
          "name": "$VAST_BUCKET"
        },
        "object": {
          "key": "nvidia-ai/test-video.mp4"
        }
      }
    }
  ]
}
EOF
    
    # Test Lambda function
    echo "Testing Lambda function with sample event..."
    aws lambda invoke \
        --function-name "$FUNCTION_NAME" \
        --payload file://test-event.json \
        response.json
    
    # Show response
    echo "Lambda response:"
    cat response.json | python3 -m json.tool
    
    # Cleanup test files
    rm -f test-event.json response.json
}

# Function to setup monitoring
setup_monitoring() {
    echo ""
    echo -e "${BLUE}📊 Setting up monitoring...${NC}"
    
    # Get dashboard URL
    DASHBOARD_URL=$(terraform output -raw cloudwatch_dashboard_url 2>/dev/null || echo "")
    
    if [ -n "$DASHBOARD_URL" ]; then
        echo "CloudWatch Dashboard: $DASHBOARD_URL"
    fi
    
    # Create CloudWatch alarms
    FUNCTION_NAME=$(terraform output -raw lambda_function_name 2>/dev/null || echo "vast-tams-video-processor")
    
    echo "Creating CloudWatch alarms..."
    
    # Error rate alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "VideoProcessor-ErrorRate" \
        --alarm-description "High error rate for video processing" \
        --metric-name "Errors" \
        --namespace "AWS/Lambda" \
        --statistic "Sum" \
        --period 300 \
        --threshold 5 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 2 \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME"
    
    # Duration alarm
    aws cloudwatch put-metric-alarm \
        --alarm-name "VideoProcessor-Duration" \
        --alarm-description "Long execution time for video processing" \
        --metric-name "Duration" \
        --namespace "AWS/Lambda" \
        --statistic "Average" \
        --period 300 \
        --threshold 600000 \
        --comparison-operator "GreaterThanThreshold" \
        --evaluation-periods 2 \
        --dimensions Name=FunctionName,Value="$FUNCTION_NAME"
    
    echo -e "${GREEN}✓ Monitoring setup complete${NC}"
}

# Function to create demo script
create_demo_script() {
    echo ""
    echo -e "${BLUE}📝 Creating demo script...${NC}"
    
    cat > demo-aws-pipeline.sh << 'EOF'
#!/bin/bash
# Demo script for AWS Video Processing Pipeline

set -e

echo "================================================"
echo "  AWS VIDEO PROCESSING PIPELINE DEMO"
echo "================================================"
echo ""

# Configuration
VAST_BUCKET="tams-storage"
VAST_ENDPOINT="http://10.0.11.161:9090"
TAMS_API="http://34.216.9.25:8000"

# Function to upload test video
upload_test_video() {
    echo "📤 Uploading test video to trigger pipeline..."
    
    # Create a small test video if it doesn't exist
    if [ ! -f "test-video.mp4" ]; then
        echo "Creating test video..."
        # Use ffmpeg to create a test video with text overlay
        ffmpeg -f lavfi -i testsrc=duration=30:size=1280x720:rate=30 \
               -vf "drawtext=text='DEMO VIDEO - Shell Racing':fontsize=60:fontcolor=white:x=(w-text_w)/2:y=(h-text_h)/2" \
               -c:v libx264 -t 30 test-video.mp4 -y
    fi
    
    # Upload to VAST S3
    aws s3 cp test-video.mp4 "s3://$VAST_BUCKET/nvidia-ai/" \
        --endpoint-url "$VAST_ENDPOINT" \
        --no-verify-ssl
    
    echo "✓ Video uploaded successfully"
}

# Function to monitor processing
monitor_processing() {
    echo ""
    echo "👀 Monitoring AWS processing..."
    
    # Wait for Lambda to process
    echo "Waiting for Lambda processing (30 seconds)..."
    sleep 30
    
    # Check CloudWatch logs
    echo "Recent Lambda logs:"
    aws logs describe-log-streams \
        --log-group-name "/aws/lambda/vast-tams-video-processor" \
        --order-by "LastEventTime" \
        --descending \
        --max-items 1 \
        --query 'logStreams[0].logStreamName' \
        --output text | xargs -I {} \
        aws logs get-log-events \
        --log-group-name "/aws/lambda/vast-tams-video-processor" \
        --log-stream-name {} \
        --query 'events[-10:].message' \
        --output text
}

# Function to check TAMS results
check_tams_results() {
    echo ""
    echo "🔍 Checking TAMS for processed results..."
    
    # Get sources
    echo "Sources in TAMS:"
    curl -s "$TAMS_API/api/v1/sources" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for source in data.get('sources', []):
    print(f\"  - {source['name']} (ID: {source['id']})\")
"
    
    # Get flows
    echo ""
    echo "Flows in TAMS:"
    curl -s "$TAMS_API/api/v1/flows" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for flow in data.get('flows', []):
    print(f\"  - {flow['name']} (ID: {flow['id']})\")
    if 'metadata' in flow and 'sponsors_detected' in flow['metadata']:
        sponsors = flow['metadata']['sponsors_detected']
        print(f\"    Sponsors: {', '.join(sponsors) if sponsors else 'None'}\")
"
}

# Main demo execution
main() {
    upload_test_video
    monitor_processing
    check_tams_results
    
    echo ""
    echo "================================================"
    echo "✓ AWS Pipeline Demo Complete!"
    echo "================================================"
    echo ""
    echo "What happened:"
    echo "1. 📤 Video uploaded to VAST S3 bucket"
    echo "2. 🔔 S3 event triggered AWS Lambda function"
    echo "3. 🤖 AWS Rekognition analyzed video for objects/text"
    echo "4. 📊 Lambda processed results into time-based segments"
    echo "5. 💾 TAMS API hydrated with sponsor/racing data"
    echo ""
    echo "Check the TAMS API for detailed segment analysis:"
    echo "  curl $TAMS_API/api/v1/flows"
    echo ""
}

main "$@"
EOF
    
    chmod +x demo-aws-pipeline.sh
    echo -e "${GREEN}✓ Demo script created: demo-aws-pipeline.sh${NC}"
}

# Main execution
main() {
    echo "Starting AWS Video Processing Pipeline setup..."
    echo ""
    
    # Step 1: Check prerequisites
    echo -e "${BLUE}1️⃣  CHECKING PREREQUISITES${NC}"
    echo "=========================="
    check_aws_credentials
    
    # Check if Terraform is installed
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}Error: Terraform is not installed${NC}"
        echo "Please install Terraform: https://terraform.io/downloads"
        exit 1
    fi
    
    # Step 2: Prepare Lambda package
    echo ""
    echo -e "${BLUE}2️⃣  PREPARING LAMBDA PACKAGE${NC}"
    echo "=========================="
    prepare_lambda_package
    
    # Step 3: Deploy infrastructure
    echo ""
    echo -e "${BLUE}3️⃣  DEPLOYING INFRASTRUCTURE${NC}"
    echo "=========================="
    deploy_infrastructure
    
    # Step 4: Setup monitoring
    echo ""
    echo -e "${BLUE}4️⃣  SETTING UP MONITORING${NC}"
    echo "=========================="
    setup_monitoring
    
    # Step 5: Test pipeline
    echo ""
    echo -e "${BLUE}5️⃣  TESTING PIPELINE${NC}"
    echo "=========================="
    test_pipeline
    
    # Step 6: Create demo script
    echo ""
    echo -e "${BLUE}6️⃣  CREATING DEMO SCRIPT${NC}"
    echo "=========================="
    create_demo_script
    
    # Complete
    echo ""
    echo "================================================"
    echo -e "${GREEN}✅ AWS PIPELINE SETUP COMPLETE!${NC}"
    echo "================================================"
    echo ""
    echo "🎬 To run the demo:"
    echo "   ./demo-aws-pipeline.sh"
    echo ""
    echo "📊 Monitor processing:"
    echo "   aws logs tail /aws/lambda/vast-tams-video-processor --follow"
    echo ""
    echo "🔍 Check TAMS results:"
    echo "   curl $TAMS_API_URL/api/v1/flows"
    echo ""
    echo "📈 View CloudWatch Dashboard:"
    terraform output cloudwatch_dashboard_url 2>/dev/null || echo "   Check AWS Console -> CloudWatch -> Dashboards"
}

# Run main function
main "$@"