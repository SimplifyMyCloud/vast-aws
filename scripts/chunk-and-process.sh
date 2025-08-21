#!/bin/bash
set -e

# Intelligent Video Chunking and Processing Pipeline
echo "================================================"
echo "🎬 INTELLIGENT VIDEO CHUNKING PIPELINE"
echo "================================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
CHUNK_DURATION="${CHUNK_DURATION:-300}"  # 5 minutes default
MAX_PARALLEL_JOBS="${MAX_PARALLEL_JOBS:-4}"
TAMS_API="${TAMS_API:-http://34.216.9.25:8000}"
VAST_ENDPOINT="${VAST_ENDPOINT:-http://10.0.11.161:9090}"

# Function to print colored status
print_status() {
    local status=$1
    local message=$2
    case $status in
        "info") echo -e "${BLUE}ℹ️  $message${NC}" ;;
        "success") echo -e "${GREEN}✅ $message${NC}" ;;
        "warning") echo -e "${YELLOW}⚠️  $message${NC}" ;;
        "error") echo -e "${RED}❌ $message${NC}" ;;
        "process") echo -e "${PURPLE}🔄 $message${NC}" ;;
        "complete") echo -e "${CYAN}🎉 $message${NC}" ;;
    esac
}

# Function to check prerequisites
check_prerequisites() {
    print_status "info" "Checking prerequisites..."
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        print_status "error" "Python 3 is required"
        exit 1
    fi
    
    # Check ffmpeg
    if ! command -v ffmpeg &> /dev/null; then
        print_status "error" "ffmpeg is required for video chunking"
        echo "Install with: brew install ffmpeg (macOS) or apt install ffmpeg (Ubuntu)"
        exit 1
    fi
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_status "error" "AWS CLI is required"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    
    # Check Python dependencies
    python3 -c "import cv2, boto3, numpy" 2>/dev/null || {
        print_status "warning" "Installing Python dependencies..."
        pip3 install opencv-python boto3 numpy requests
    }
    
    print_status "success" "All prerequisites met"
}

# Function to validate video file
validate_video() {
    local video_path="$1"
    
    if [ ! -f "$video_path" ]; then
        print_status "error" "Video file not found: $video_path"
        exit 1
    fi
    
    # Get video info
    local duration=$(ffprobe -v quiet -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_path" 2>/dev/null)
    local size=$(du -h "$video_path" | cut -f1)
    
    print_status "info" "Video file: $(basename "$video_path")"
    print_status "info" "Duration: ${duration}s ($(echo "$duration/60" | bc -l | xargs printf "%.1f") minutes)"
    print_status "info" "Size: $size"
    
    # Check if chunking is needed
    if (( $(echo "$duration < $CHUNK_DURATION" | bc -l) )); then
        print_status "warning" "Video is shorter than chunk duration ($CHUNK_DURATION seconds)"
        print_status "info" "Will process as single file"
        return 1
    fi
    
    return 0
}

# Function to process long video with chunking
process_with_chunking() {
    local video_path="$1"
    local output_name="$2"
    
    print_status "process" "Starting intelligent chunking pipeline..."
    
    # Run the Python chunking script
    python3 intelligent-video-chunker.py "$video_path" ${output_name:+--output-name "$output_name"}
    
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        print_status "complete" "Chunking pipeline completed successfully!"
        return 0
    else
        print_status "error" "Chunking pipeline failed"
        return 1
    fi
}

# Function to process single video (no chunking needed)
process_single_video() {
    local video_path="$1"
    local output_name="$2"
    
    print_status "process" "Processing single video (no chunking needed)..."
    
    # Upload directly to VAST
    local s3_key="nvidia-ai/${output_name:-$(basename "$video_path")}"
    
    print_status "info" "Uploading to VAST S3: $s3_key"
    aws s3 cp "$video_path" "s3://tams-storage/$s3_key" \
        --endpoint-url "$VAST_ENDPOINT" \
        --no-verify-ssl
    
    if [ $? -eq 0 ]; then
        print_status "success" "Video uploaded successfully"
        print_status "info" "AWS Lambda will process automatically"
        return 0
    else
        print_status "error" "Failed to upload video"
        return 1
    fi
}

# Function to monitor processing
monitor_processing() {
    local video_name="$1"
    
    print_status "process" "Monitoring processing progress..."
    
    local start_time=$(date +%s)
    local timeout=1800  # 30 minutes
    
    while true; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -gt $timeout ]; then
            print_status "warning" "Monitoring timeout reached (30 minutes)"
            break
        fi
        
        # Check TAMS for flows
        local flow_count=$(curl -s "$TAMS_API/api/v1/flows" 2>/dev/null | \
            python3 -c "import sys, json; data=json.load(sys.stdin); print(len([f for f in data.get('flows', []) if '$video_name' in f.get('name', '')]))" 2>/dev/null || echo "0")
        
        if [ "$flow_count" -gt "0" ]; then
            print_status "success" "Found $flow_count processed flow(s) in TAMS"
            break
        fi
        
        printf "\r${PURPLE}🔄 Waiting for processing... (${elapsed}s elapsed)${NC}"
        sleep 10
    done
    
    echo ""  # New line after progress indicator
}

# Function to show results
show_results() {
    local video_name="$1"
    
    print_status "info" "Fetching processing results..."
    
    # Get flows
    local flows_output=$(mktemp)
    curl -s "$TAMS_API/api/v1/flows" > "$flows_output" 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo ""
        echo -e "${CYAN}📊 PROCESSING RESULTS${NC}"
        echo "========================"
        
        python3 << EOF
import json
import sys

try:
    with open('$flows_output', 'r') as f:
        data = json.load(f)
    
    flows = data.get('flows', [])
    relevant_flows = [f for f in flows if '$video_name' in f.get('name', '')]
    
    if not relevant_flows:
        print("No flows found for this video")
        sys.exit(0)
    
    print(f"Found {len(relevant_flows)} flow(s)")
    print()
    
    for flow in relevant_flows:
        print(f"Flow: {flow['name']}")
        print(f"  ID: {flow['id']}")
        
        metadata = flow.get('metadata', {})
        if 'sponsors_detected' in metadata:
            sponsors = metadata['sponsors_detected']
            if sponsors:
                print(f"  Sponsors: {', '.join(sponsors)}")
            else:
                print("  Sponsors: None detected")
        
        if 'total_segments' in metadata:
            print(f"  Segments: {metadata['total_segments']}")
        
        if 'worthy_segments' in metadata:
            print(f"  Worthy segments: {metadata['worthy_segments']}")
        
        print()

except Exception as e:
    print(f"Error parsing results: {e}")
EOF
        
        rm -f "$flows_output"
    else
        print_status "warning" "Could not fetch results from TAMS API"
    fi
}

# Function to create demo videos
create_demo_videos() {
    print_status "info" "Creating demo videos for testing..."
    
    local demo_dir="demo_videos"
    mkdir -p "$demo_dir"
    
    # Create a long demo video with sponsor logos
    local long_video="$demo_dir/long_race_demo.mp4"
    
    if [ ! -f "$long_video" ]; then
        print_status "process" "Creating 15-minute demo racing video..."
        
        ffmpeg -f lavfi -i testsrc=duration=900:size=1280x720:rate=30 \
            -vf "drawtext=text='RACING DEMO - CHUNK TEST':fontsize=40:fontcolor=white:x=(w-text_w)/2:y=50, \
                 drawtext=text='Shell Sponsor at %{pts\:gmtime\:0\:%M\\\:%S}':fontsize=30:fontcolor=yellow:x=50:y=150, \
                 drawtext=text='Ferrari Team':fontsize=25:fontcolor=red:x=50:y=200, \
                 drawtext=text='Red Bull Racing':fontsize=25:fontcolor=blue:x=50:y=250" \
            -c:v libx264 -preset fast -crf 23 \
            "$long_video" -y
        
        print_status "success" "Created demo video: $long_video"
    else
        print_status "info" "Demo video already exists: $long_video"
    fi
    
    echo "$long_video"
}

# Function to run comprehensive demo
run_demo() {
    print_status "complete" "Running comprehensive chunking demo..."
    
    # Create demo video
    local demo_video=$(create_demo_videos)
    local video_name="long_race_demo"
    
    # Process the video
    main_process "$demo_video" "$video_name"
    
    # Show advanced results
    echo ""
    echo -e "${CYAN}🔍 ADVANCED ANALYTICS${NC}"
    echo "========================"
    
    # Get detailed sponsor analytics
    python3 << 'EOF'
import requests
import json

try:
    response = requests.get('http://34.216.9.25:8000/api/v1/flows')
    data = response.json()
    
    for flow in data.get('flows', []):
        if 'long_race_demo' in flow.get('name', ''):
            print(f"\n📈 Flow Analysis: {flow['name']}")
            
            # Get segments
            segments_response = requests.get(f"http://34.216.9.25:8000/api/v1/flows/{flow['id']}/segments")
            if segments_response.status_code == 200:
                segments = segments_response.json().get('segments', [])
                worthy_segments = [s for s in segments if s.get('metadata', {}).get('is_worthy', False)]
                
                print(f"  Total segments: {len(segments)}")
                print(f"  Worthy segments: {len(worthy_segments)}")
                
                # Sponsor analysis
                all_sponsors = set()
                for segment in segments:
                    sponsors = segment.get('metadata', {}).get('sponsors_detected', [])
                    all_sponsors.update(sponsors)
                
                if all_sponsors:
                    print(f"  Unique sponsors detected: {', '.join(all_sponsors)}")
                else:
                    print("  No sponsors detected")

except Exception as e:
    print(f"Error getting analytics: {e}")
EOF
}

# Main processing function
main_process() {
    local video_path="$1"
    local output_name="$2"
    
    if [ -z "$video_path" ]; then
        print_status "error" "Video path is required"
        echo "Usage: $0 <video_path> [output_name]"
        exit 1
    fi
    
    # Extract output name if not provided
    if [ -z "$output_name" ]; then
        output_name=$(basename "$video_path" | sed 's/\.[^.]*$//')
    fi
    
    print_status "info" "Processing video: $video_path"
    print_status "info" "Output name: $output_name"
    
    # Validate video
    if validate_video "$video_path"; then
        # Video needs chunking
        process_with_chunking "$video_path" "$output_name"
    else
        # Video is short enough to process directly
        process_single_video "$video_path" "$output_name"
    fi
    
    # Monitor processing
    monitor_processing "$output_name"
    
    # Show results
    show_results "$output_name"
}

# Parse command line arguments
case "${1:-}" in
    "--demo")
        check_prerequisites
        run_demo
        ;;
    "--help"|"-h")
        echo "Intelligent Video Chunking Pipeline"
        echo ""
        echo "Usage:"
        echo "  $0 <video_path> [output_name]  # Process specific video"
        echo "  $0 --demo                      # Run comprehensive demo"
        echo "  $0 --help                      # Show this help"
        echo ""
        echo "Features:"
        echo "  🎯 Smart scene-aware chunking (avoids cutting mid-action)"
        echo "  ⚡ Parallel processing of chunks"
        echo "  🤖 AWS Rekognition integration"
        echo "  📊 Unified metadata timeline"
        echo "  🏁 Racing sponsor detection"
        echo ""
        echo "Configuration:"
        echo "  CHUNK_DURATION=$CHUNK_DURATION seconds (5 minutes default)"
        echo "  MAX_PARALLEL_JOBS=$MAX_PARALLEL_JOBS (parallel chunk creation)"
        echo "  TAMS_API=$TAMS_API"
        echo ""
        ;;
    "")
        print_status "error" "No video path provided"
        echo "Use --help for usage information"
        exit 1
        ;;
    *)
        check_prerequisites
        main_process "$1" "$2"
        ;;
esac

print_status "complete" "Pipeline execution complete!"