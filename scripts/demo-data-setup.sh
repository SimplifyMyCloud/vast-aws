#!/bin/bash
set -e

# TAMS + VAST Demo Data Setup Script
# This script creates sample data for the media archive monetization demo

TAMS_API="http://34.216.9.25:8000"

echo "==================================="
echo "   TAMS + VAST Demo Data Setup    "
echo "==================================="
echo ""

# Function to create a source
create_source() {
    local name=$1
    local type=$2
    local location=$3
    local metadata=$4
    
    echo "Creating source: $name"
    response=$(curl -s -X POST $TAMS_API/sources \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"$name\",
            \"type\": \"$type\",
            \"location\": \"$location\",
            \"metadata\": $metadata
        }")
    
    source_id=$(echo $response | jq -r '.id // .source_id // empty')
    if [ -n "$source_id" ]; then
        echo "  ✓ Created source: $source_id"
        echo $source_id
    else
        echo "  ✗ Failed to create source"
        echo $response
        return 1
    fi
}

# Function to create a flow with segments
create_flow() {
    local source_id=$1
    local name=$2
    local metadata=$3
    
    echo "Creating flow: $name"
    response=$(curl -s -X POST $TAMS_API/flows \
        -H "Content-Type: application/json" \
        -d "{
            \"source_id\": \"$source_id\",
            \"name\": \"$name\",
            \"type\": \"video\",
            \"metadata\": $metadata
        }")
    
    flow_id=$(echo $response | jq -r '.id // .flow_id // empty')
    if [ -n "$flow_id" ]; then
        echo "  ✓ Created flow: $flow_id"
        echo $flow_id
    else
        echo "  ✗ Failed to create flow"
        return 1
    fi
}

echo "Step 1: Creating NASCAR Sources"
echo "================================"

# NASCAR Charlotte Motor Speedway
nascar_metadata='{
    "event": "Bank of America ROVAL 400",
    "date": "2024-10-13",
    "venue": "Charlotte Motor Speedway",
    "broadcast_rights": "ESPN",
    "duration_minutes": 10,
    "sponsors": ["Lucas Oil", "Goodyear", "Coca-Cola", "Bank of America"]
}'

nascar_id=$(create_source \
    "NASCAR Charlotte 2024 - Race Footage" \
    "video" \
    "vast://10.0.11.54/tams-s3/nascar/charlotte-2024.mp4" \
    "$nascar_metadata")

# Create NASCAR flow with AI-detected events
nascar_flow_metadata='{
    "logos_detected": [
        {"name": "Lucas Oil", "total_seconds": 27.3, "segments": 15},
        {"name": "Goodyear", "total_seconds": 45.2, "segments": 23},
        {"name": "Coca-Cola", "total_seconds": 18.7, "segments": 9}
    ],
    "events": [
        {"type": "crash", "location": "turn_3", "timestamp": "00:03:45", "cars_involved": 3},
        {"type": "pass", "location": "outside_turn_3", "timestamp": "00:05:12"},
        {"type": "crash", "location": "infield_grass", "timestamp": "00:07:33", "spin": true},
        {"type": "pit_stop", "team": "Hendrick", "duration": 12.3, "timestamp": "00:08:45"}
    ],
    "ai_highlights": ["crash_compilation", "sponsor_verification", "overtake_moments"]
}'

create_flow "$nascar_id" "NASCAR Charlotte AI Analysis" "$nascar_flow_metadata"

echo ""
echo "Step 2: Creating F1 Sources"
echo "============================"

# F1 Monaco Grand Prix
f1_metadata='{
    "event": "Monaco Grand Prix 2024",
    "date": "2024-05-26",
    "venue": "Circuit de Monaco",
    "broadcast_rights": "Sky Sports F1",
    "duration_minutes": 10,
    "weather": "wet",
    "sponsors": ["Red Bull", "Rolex", "Pirelli", "DHL"]
}'

f1_id=$(create_source \
    "F1 Monaco 2024 - Verstappen Highlights" \
    "video" \
    "vast://10.0.11.54/tams-s3/f1/monaco-2024.mp4" \
    "$f1_metadata")

# Create F1 flow
f1_flow_metadata='{
    "logos_detected": [
        {"name": "Red Bull", "total_seconds": 89.4, "segments": 42},
        {"name": "Rolex", "total_seconds": 56.8, "segments": 28},
        {"name": "Pirelli", "total_seconds": 34.2, "segments": 18}
    ],
    "events": [
        {"type": "overtake", "driver": "Verstappen", "location": "tunnel", "conditions": "wet"},
        {"type": "crash", "location": "swimming_pool", "safety_car": true},
        {"type": "fastest_lap", "driver": "Verstappen", "time": "1:12.909"}
    ],
    "ai_highlights": ["wet_weather_mastery", "overtake_compilation", "sponsor_ROI"]
}'

create_flow "$f1_id" "F1 Monaco Wet Weather Analysis" "$f1_flow_metadata"

echo ""
echo "Step 3: Creating NFL Sources"
echo "============================="

# NFL Super Bowl
nfl_metadata='{
    "event": "Super Bowl LVIII",
    "date": "2024-02-11",
    "venue": "Allegiant Stadium",
    "teams": ["Chiefs", "49ers"],
    "broadcast_rights": "CBS",
    "duration_minutes": 5,
    "sponsors": ["Pepsi", "Budweiser", "State Farm", "Toyota"]
}'

nfl_id=$(create_source \
    "Super Bowl LVIII - Highlights & Commercials" \
    "video" \
    "vast://10.0.11.54/tams-s3/nfl/superbowl-2024.mp4" \
    "$nfl_metadata")

# Create NFL flow
nfl_flow_metadata='{
    "logos_detected": [
        {"name": "Pepsi", "total_seconds": 120.5, "segments": 8},
        {"name": "Budweiser", "total_seconds": 90.3, "segments": 6},
        {"name": "State Farm", "total_seconds": 60.2, "segments": 4}
    ],
    "events": [
        {"type": "touchdown", "yards": 65, "player": "Hardman", "quarter": 4},
        {"type": "field_goal", "yards": 57, "successful": true},
        {"type": "controversial_call", "type": "holding", "timestamp": "00:03:22"}
    ],
    "commercials": [
        {"brand": "Pepsi", "duration": 30, "celebrity": true},
        {"brand": "Budweiser", "duration": 60, "horses": true}
    ]
}'

create_flow "$nfl_id" "Super Bowl LVIII Commercial & Play Analysis" "$nfl_flow_metadata"

echo ""
echo "Step 4: Creating Premier League Sources"
echo "========================================"

# Premier League
premier_metadata='{
    "event": "Manchester Derby",
    "date": "2024-03-03",
    "venue": "Etihad Stadium",
    "teams": ["Man City", "Man United"],
    "broadcast_rights": "Sky Sports",
    "duration_minutes": 5,
    "sponsors": ["Budweiser", "EA Sports", "Barclays", "Nike"]
}'

premier_id=$(create_source \
    "Manchester Derby 2024 - Goals & Highlights" \
    "video" \
    "vast://10.0.11.54/tams-s3/premier/manchester-derby-2024.mp4" \
    "$premier_metadata")

# Create Premier League flow
premier_flow_metadata='{
    "logos_detected": [
        {"name": "Budweiser", "total_seconds": 45.6, "segments": 22},
        {"name": "EA Sports", "total_seconds": 38.9, "segments": 19},
        {"name": "Nike", "total_seconds": 67.3, "segments": 31}
    ],
    "events": [
        {"type": "goal", "distance": "outside_box", "player": "Foden", "minute": 23},
        {"type": "red_card", "player": "Casemiro", "minute": 67},
        {"type": "goal", "type": "header", "player": "Haaland", "minute": 89}
    ],
    "ai_highlights": ["goals_outside_box", "red_card_incidents", "derby_intensity"]
}'

create_flow "$premier_id" "Manchester Derby AI Highlights" "$premier_flow_metadata"

echo ""
echo "Step 5: Creating Historical Archive Entry"
echo "=========================================="

# Historical footage
historical_metadata='{
    "event": "NASCAR Daytona 500",
    "date": "1987-02-15",
    "venue": "Daytona International Speedway",
    "format": "Digitized from tape",
    "quality": "SD",
    "restored": false,
    "rights_status": "cleared",
    "historical_value": "high"
}'

historical_id=$(create_source \
    "NASCAR Daytona 500 1987 - Archive Footage" \
    "video" \
    "vast://10.0.11.54/tams-s3/archive/daytona-1987.mp4" \
    "$historical_metadata")

echo ""
echo "================================="
echo "    Demo Data Setup Complete!    "
echo "================================="
echo ""
echo "Created demo sources for:"
echo "  • NASCAR racing footage with sponsor tracking"
echo "  • F1 Monaco Grand Prix with wet weather overtakes"
echo "  • NFL Super Bowl with commercial analysis"
echo "  • Premier League with goal highlights"
echo "  • Historical 1987 archive footage"
echo ""
echo "Ready to demonstrate:"
echo "  1. Sponsor logo verification (Lucas Oil needs 2.7 more seconds)"
echo "  2. Instant highlight reel creation (crashes, goals, touchdowns)"
echo "  3. AI-powered event detection (overtakes, red cards, etc.)"
echo "  4. Historical archive monetization"
echo ""
echo "Test the demo queries:"
echo "  curl $TAMS_API/sources | jq ."
echo "  curl $TAMS_API/flows | jq ."
echo ""
echo "Launch full demo with: ./run-tams-vast-demo.sh"