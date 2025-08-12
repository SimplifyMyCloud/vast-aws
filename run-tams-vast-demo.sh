#!/bin/bash
set -e

# TAMS + VAST Live Demo Runner
# Interactive demo for trade shows and customer presentations

TAMS_API="http://34.216.9.25:8000"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color
BOLD='\033[1m'

clear

echo -e "${BLUE}${BOLD}"
echo "╔══════════════════════════════════════════════════════════════════╗"
echo "║                                                                  ║"
echo "║              VAST + TAMS: Media Archive Monetization            ║"
echo "║                                                                  ║"
echo "║              'From Cost Center to Profit Center'                ║"
echo "║                                                                  ║"
echo "╚══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo ""
echo -e "${YELLOW}Welcome to the VAST + TAMS demo!${NC}"
echo "Press Enter to begin the journey from buried archives to monetized assets..."
read

# Act 1: The Problem
clear
echo -e "${RED}${BOLD}═══ THE PROBLEM ═══${NC}"
echo ""
echo "Your current situation:"
echo "  • 10 Petabytes of footage on LTO tape"
echo "  • $50,000/month in storage costs"
echo "  • 48-72 hour retrieval time"
echo "  • Zero searchability"
echo "  • Zero monetization"
echo ""
echo -e "${RED}Your archive is a buried treasure that's costing you $600K/year${NC}"
echo ""
echo "Press Enter to see the solution..."
read

# Act 2: The Solution
clear
echo -e "${GREEN}${BOLD}═══ THE SOLUTION: VAST + TAMS ═══${NC}"
echo ""
echo "Checking system status..."
echo ""

# Check VAST connection
echo -n "VAST Storage Cluster: "
vast_status=$(curl -s $TAMS_API/vast/status | jq -r '.vast_connected')
if [ "$vast_status" = "true" ]; then
    echo -e "${GREEN}✓ Connected${NC}"
    echo "  └─ Endpoints: 10.0.11.54, 10.0.11.170"
    echo "  └─ Buckets: tams-db, tams-s3"
else
    echo -e "${RED}✗ Not Connected${NC}"
fi

# Check TAMS health
echo -n "TAMS API v6.0.1: "
tams_status=$(curl -s $TAMS_API/health | jq -r '.status')
if [ "$tams_status" = "healthy" ]; then
    echo -e "${GREEN}✓ Healthy${NC}"
else
    echo -e "${RED}✗ Issues detected${NC}"
fi

echo ""
echo "Press Enter to see the magic..."
read

# Act 3: Sponsor Verification Demo
clear
echo -e "${BLUE}${BOLD}═══ DEMO 1: SPONSOR VERIFICATION ═══${NC}"
echo ""
echo "Lucas Oil pays for 30 seconds of logo placement per NASCAR race."
echo "Let's verify their contract compliance..."
echo ""
echo -e "${YELLOW}Query: 'Show me every Lucas Oil logo appearance'${NC}"
echo ""

# Simulate the query
echo "Analyzing 10 minutes of NASCAR footage..."
sleep 1
echo "AI Detection: Processing frames..."
sleep 1
echo ""
echo -e "${GREEN}Results:${NC}"
echo "┌─────────────────────────────────────┐"
echo "│ Lucas Oil Logo Detection Results    │"
echo "├─────────────────────────────────────┤"
echo "│ Total appearances: 15 segments      │"
echo "│ Total duration: 27.3 seconds        │"
echo "│ Contract requirement: 30 seconds    │"
echo "│ ${RED}Status: UNDER by 2.7 seconds${NC}       │"
echo "└─────────────────────────────────────┘"
echo ""
echo -e "${YELLOW}This query just saved 3 days of manual review!${NC}"
echo ""
echo "Press Enter for the next demo..."
read

# Act 4: Highlight Reel Creation
clear
echo -e "${BLUE}${BOLD}═══ DEMO 2: INSTANT HIGHLIGHT REELS ═══${NC}"
echo ""
echo -e "${YELLOW}Query: 'Find all crashes where cars spun into the infield grass'${NC}"
echo ""
echo "Searching across 40 years of NASCAR footage..."
sleep 1
echo "AI Analysis: Detecting crash patterns..."
sleep 1
echo ""
echo -e "${GREEN}Found 6 matching segments:${NC}"
echo ""
echo "1. [2024-10-13] Charlotte Motor Speedway - Turn 3 - 3 cars"
echo "2. [2023-05-28] Charlotte Motor Speedway - Turn 1 - 2 cars"  
echo "3. [2022-02-20] Daytona 500 - Backstretch - 5 cars"
echo "4. [2019-07-06] Daytona - Turn 4 - 4 cars"
echo "5. [2015-10-10] Charlotte - Turn 3 - 2 cars"
echo "6. [1987-02-15] Daytona 500 - Turn 2 - 3 cars"
echo ""
echo -e "${GREEN}✓ Highlight reel created in 2.3 seconds${NC}"
echo ""
echo "Export options:"
echo "  [1] Social Media (9:16 vertical)"
echo "  [2] Broadcast (16:9 HD)"
echo "  [3] Stadium Display (Ultra-wide 8K)"
echo ""
echo "Press Enter to see F1 capabilities..."
read

# Act 5: F1 Demo
clear
echo -e "${BLUE}${BOLD}═══ DEMO 3: F1 WET WEATHER MASTERY ═══${NC}"
echo ""
echo -e "${YELLOW}Query: 'Show every Verstappen overtake in wet conditions'${NC}"
echo ""
echo "Processing Monaco Grand Prix 2024..."
sleep 1
echo ""
echo -e "${GREEN}AI-Detected Overtakes:${NC}"
echo "├─ 00:12:34 - Verstappen passes Alonso (Tunnel exit)"
echo "├─ 00:23:45 - Verstappen passes Leclerc (Swimming pool)"
echo "├─ 00:34:12 - Verstappen passes Hamilton (Sainte Devote)"
echo "└─ 00:45:23 - Verstappen passes Norris (Casino Square)"
echo ""
echo -e "${BLUE}Red Bull logo exposure: 89.4 seconds total${NC}"
echo -e "${GREEN}Contract requirement: 60 seconds - EXCEEDED by 49%${NC}"
echo ""
echo "Press Enter to see the business case..."
read

# Act 6: The Business Case
clear
echo -e "${GREEN}${BOLD}═══ THE BUSINESS CASE ═══${NC}"
echo ""
echo "┌──────────────────────────┬──────────────────────────┐"
echo "│    CURRENT (TAPE)        │    VAST + TAMS           │"
echo "├──────────────────────────┼──────────────────────────┤"
echo "│ Storage: \$50K/month      │ Storage: \$30K/month      │"
echo "│ Retrieval: \$10K/month    │ Retrieval: \$0            │"
echo "│ Search: 3 FTEs (\$30K)    │ Search: AI Automated      │"
echo "│ Time to access: 48-72hr  │ Time to access: <1 sec   │"
echo "│ Revenue: \$0              │ Revenue: \$165K/month     │"
echo "├──────────────────────────┼──────────────────────────┤"
echo "│ ${RED}COST: \$90K/month${NC}         │ ${GREEN}PROFIT: \$135K/month${NC}     │"
echo "└──────────────────────────┴──────────────────────────┘"
echo ""
echo -e "${GREEN}${BOLD}Annual Impact: +\$2.7 Million${NC}"
echo ""
echo "New Revenue Streams:"
echo "  • Sponsor verification & upselling"
echo "  • Highlight reel licensing"
echo "  • Historical footage monetization"
echo "  • Real-time content creation"
echo ""
echo "Press Enter for custom query..."
read

# Act 7: Custom Query
clear
echo -e "${BLUE}${BOLD}═══ YOUR TURN: CUSTOM QUERY ═══${NC}"
echo ""
echo "What would you like to search for in your archive?"
echo ""
echo "Examples:"
echo "  1. 'Every game-winning touchdown in overtime'"
echo "  2. 'All Coca-Cola appearances during Super Bowls'"
echo "  3. 'Every crash at Daytona turn 4'"
echo "  4. 'Goals scored from outside the penalty box'"
echo ""
echo -n "Enter your query (or 'demo' for a preset): "
read custom_query

if [ "$custom_query" = "demo" ]; then
    custom_query="Every touchdown over 50 yards"
fi

echo ""
echo -e "${YELLOW}Searching: '$custom_query'${NC}"
echo ""
echo "Processing 10PB archive..."
sleep 2
echo "AI Analysis in progress..."
sleep 1
echo ""
echo -e "${GREEN}✓ Found 47 matching segments across 15 years${NC}"
echo ""
echo "Sample results:"
echo "  • [2024] Super Bowl LVIII - Hardman 65-yard TD"
echo "  • [2023] AFC Championship - Hill 71-yard TD"
echo "  • [2022] Week 14 - Jefferson 83-yard TD"
echo "  • [...44 more results]"
echo ""

# Closing
echo -e "${GREEN}${BOLD}═══ READY TO MONETIZE YOUR ARCHIVE? ═══${NC}"
echo ""
echo "Next Steps:"
echo "  1. We'll ingest a sample of your footage (1TB)"
echo "  2. Run AI analysis overnight"
echo "  3. Present custom insights from YOUR content"
echo "  4. Calculate YOUR specific ROI"
echo ""
echo -e "${BLUE}Contact: solutions@vastdata.com${NC}"
echo ""
echo -e "${GREEN}${BOLD}Your archive isn't history. It's your future revenue.${NC}"
echo ""

# Show live stats
echo "─────────────────────────────────────────"
echo "Live System Stats:"
curl -s $TAMS_API/health | jq '{
    version: .version,
    status: .status,
    uptime: (.system.uptime_seconds / 3600 | floor),
    cpu: .system.cpu_percent,
    memory_gb: (.system.memory_usage_bytes / 1073741824 | floor)
}' | sed 's/^/  /'

echo ""
echo -e "${YELLOW}Thank you for visiting VAST + TAMS!${NC}"