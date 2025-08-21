#!/bin/bash
set -e

# AI Video Processing Demo for VAST-TAMS Integration
# This script orchestrates the complete demo workflow

echo "================================================"
echo "  AI VIDEO PROCESSING DEMO WITH VAST & TAMS"
echo "================================================"
echo ""

# Configuration
VAST_ENDPOINT="http://10.0.11.161:9090"
VAST_BUCKET="tams-storage"
TAMS_API="http://34.216.9.25:8000"
VIDEO_DIR="${1:-./videos}"  # Default to ./videos directory

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check service availability
check_service() {
    local service_name=$1
    local url=$2
    
    echo -n "Checking $service_name... "
    if curl -s -f -o /dev/null "$url"; then
        echo -e "${GREEN}✓ Available${NC}"
        return 0
    else
        echo -e "${RED}✗ Not available${NC}"
        return 1
    fi
}

# Function to upload videos to VAST
upload_videos() {
    echo ""
    echo "📤 Uploading videos to VAST Storage..."
    echo "----------------------------------------"
    
    # Check if video directory exists
    if [ ! -d "$VIDEO_DIR" ]; then
        echo -e "${RED}Error: Video directory $VIDEO_DIR not found${NC}"
        echo "Please create the directory and add your video files"
        exit 1
    fi
    
    # Count video files
    video_count=$(find "$VIDEO_DIR" -name "*.mp4" -o -name "*.avi" -o -name "*.mov" | wc -l)
    
    if [ "$video_count" -eq 0 ]; then
        echo -e "${YELLOW}No video files found in $VIDEO_DIR${NC}"
        echo "Please add video files (*.mp4, *.avi, or *.mov)"
        exit 1
    fi
    
    echo "Found $video_count video file(s)"
    
    # Upload each video
    uploaded=0
    for video in "$VIDEO_DIR"/*.{mp4,avi,mov} 2>/dev/null; do
        if [ -f "$video" ]; then
            filename=$(basename "$video")
            echo -n "  Uploading $filename... "
            
            # Upload using AWS CLI
            if aws s3 cp "$video" "s3://$VAST_BUCKET/nvidia-ai/" \
                --endpoint-url "$VAST_ENDPOINT" \
                --no-verify-ssl 2>/dev/null; then
                echo -e "${GREEN}✓${NC}"
                ((uploaded++))
            else
                echo -e "${RED}✗${NC}"
            fi
        fi
    done
    
    echo ""
    echo "Successfully uploaded $uploaded/$video_count videos"
    return 0
}

# Function to run AI processing
run_ai_processing() {
    echo ""
    echo "🤖 Running AI Video Analysis..."
    echo "----------------------------------------"
    
    # Check if Python script exists
    if [ ! -f "process-videos-ai.py" ]; then
        echo -e "${RED}Error: process-videos-ai.py not found${NC}"
        exit 1
    fi
    
    # Install Python dependencies if needed
    echo "Checking Python dependencies..."
    pip install -q opencv-python numpy scikit-learn boto3 requests 2>/dev/null || {
        echo -e "${YELLOW}Some dependencies may need manual installation${NC}"
    }
    
    # Run the AI processing
    echo "Starting AI analysis (this may take several minutes)..."
    python3 process-videos-ai.py 2>&1 | tee ai-processing.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        echo -e "${GREEN}✓ AI processing completed successfully${NC}"
    else
        echo -e "${RED}✗ AI processing encountered errors${NC}"
        echo "Check ai-processing.log for details"
        return 1
    fi
}

# Function to verify TAMS data
verify_tams_data() {
    echo ""
    echo "🔍 Verifying TAMS Data..."
    echo "----------------------------------------"
    
    # Check sources
    echo -n "Fetching sources... "
    sources=$(curl -s "$TAMS_API/api/v1/sources" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('count', 0))")
    echo -e "${GREEN}$sources sources found${NC}"
    
    # Check flows
    echo -n "Fetching flows... "
    flows=$(curl -s "$TAMS_API/api/v1/flows" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('count', 0))")
    echo -e "${GREEN}$flows flows found${NC}"
    
    # Get detailed flow information
    echo ""
    echo "Flow Details:"
    curl -s "$TAMS_API/api/v1/flows" | python3 -m json.tool | head -50
}

# Function to generate demo report
generate_report() {
    echo ""
    echo "📊 Generating Demo Report..."
    echo "----------------------------------------"
    
    report_file="demo-report-$(date +%Y%m%d-%H%M%S).json"
    
    cat > "$report_file" << EOF
{
    "demo_timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "vast_endpoint": "$VAST_ENDPOINT",
    "tams_api": "$TAMS_API",
    "processing_log": "ai-processing.log",
    "status": "completed"
}
EOF
    
    echo "Report saved to: $report_file"
}

# Main execution
main() {
    echo "Starting demo at $(date)"
    echo ""
    
    # Step 1: Check services
    echo "1️⃣  CHECKING SERVICES"
    echo "====================="
    
    all_services_up=true
    
    check_service "VAST S3" "$VAST_ENDPOINT" || all_services_up=false
    check_service "TAMS API" "$TAMS_API/health" || all_services_up=false
    
    if [ "$all_services_up" = false ]; then
        echo ""
        echo -e "${RED}Error: Not all services are available${NC}"
        echo "Please ensure VAST and TAMS are running"
        exit 1
    fi
    
    # Step 2: Upload videos
    echo ""
    echo "2️⃣  UPLOADING VIDEOS"
    echo "==================="
    upload_videos
    
    # Step 3: Run AI processing
    echo ""
    echo "3️⃣  AI PROCESSING"
    echo "================"
    run_ai_processing
    
    # Step 4: Verify TAMS data
    echo ""
    echo "4️⃣  VERIFICATION"
    echo "==============="
    verify_tams_data
    
    # Step 5: Generate report
    echo ""
    echo "5️⃣  REPORTING"
    echo "============"
    generate_report
    
    # Complete
    echo ""
    echo "================================================"
    echo -e "${GREEN}✓ DEMO COMPLETED SUCCESSFULLY${NC}"
    echo "================================================"
    echo ""
    echo "Next steps:"
    echo "  1. Review the processing log: ai-processing.log"
    echo "  2. Access TAMS API: $TAMS_API"
    echo "  3. Query flows: curl $TAMS_API/api/v1/flows"
    echo "  4. View segments: curl $TAMS_API/api/v1/flows/{flow_id}/segments"
    echo ""
    echo "For NVIDIA GPU acceleration:"
    echo "  - Set NVIDIA_API_KEY environment variable"
    echo "  - Update AI_CONFIG in process-videos-ai.py"
    echo ""
}

# Handle script arguments
case "${2:-}" in
    --upload-only)
        upload_videos
        ;;
    --process-only)
        run_ai_processing
        ;;
    --verify-only)
        verify_tams_data
        ;;
    *)
        main
        ;;
esac