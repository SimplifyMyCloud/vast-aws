# TAMS + VAST Demo Guide
## "Monetizing Media Archives at Scale"

### Demo Setup Requirements

#### Pre-Demo Preparation
1. **Sample Media Files** (20-30 minutes total)
   - NASCAR race footage (10 min) - Charlotte Motor Speedway
   - F1 race footage (10 min) - Monaco Grand Prix  
   - NFL highlights (5 min) - Super Bowl commercials + plays
   - Premier League (5 min) - Goal compilations

2. **Pre-Tagged Content Requirements**
   - Visible sponsor logos (Lucas Oil, Red Bull, Coca-Cola, etc.)
   - Exciting moments (crashes, overtakes, goals, touchdowns)
   - Metadata: timestamps, camera angles, weather conditions

### Technical Demo Flow

#### Act 1: The Problem (2 minutes)
*Show traditional tape archive imagery*

```bash
# Display current "tape storage" costs
curl -X GET http://34.216.9.25:8000/service
```

**Talking Points:**
- "10PB on LTO tape = $600K/year in storage"
- "48-72 hour retrieval time"
- "No searchability, no monetization"
- "Your archive is a buried treasure"

#### Act 2: The Ingestion (3 minutes)
*Live ingest of race footage*

```bash
# Create a new source for NASCAR footage
curl -X POST http://34.216.9.25:8000/sources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "NASCAR Charlotte 2024",
    "type": "video",
    "location": "vast://10.0.11.54/tams-s3/nascar/charlotte-2024.mp4",
    "metadata": {
      "event": "Bank of America ROVAL 400",
      "date": "2024-10-13",
      "venue": "Charlotte Motor Speedway",
      "broadcast_rights": "ESPN"
    }
  }'

# Create flow with AI-extracted metadata
curl -X POST http://34.216.9.25:8000/flows \
  -H "Content-Type: application/json" \
  -d '{
    "source_id": "<source-id>",
    "name": "NASCAR AI Analysis",
    "type": "video",
    "metadata": {
      "logos_detected": ["Lucas Oil", "Goodyear", "Coca-Cola"],
      "events": ["crash_turn_3", "pass_outside", "pit_stop"],
      "duration_seconds": 600
    }
  }'
```

**Key Visual:** Show the TAMS ingestion progress bar with "AI Metadata Extraction" running

#### Act 3: The Magic Query - Sponsor Verification (5 minutes)

```bash
# Query 1: Logo appearance tracking
curl -X GET "http://34.216.9.25:8000/flows?query=logo:lucas_oil" \
  | jq '.segments[] | select(.metadata.logo=="Lucas Oil") | .duration'
```

**Demo Script:**
1. "Let's verify Lucas Oil's 30-second sponsorship requirement"
2. Show timeline with highlighted segments
3. "27.3 seconds so far - they need 2.7 more seconds of placement"
4. "This query just saved 3 days of manual review"

#### Act 4: Content Monetization - Highlight Reels (5 minutes)

```bash
# Query 2: Find exciting moments
curl -X GET "http://34.216.9.25:8000/flows?query=event:crash_infield" \
  | jq '.segments[] | {
      timestamp: .start_time,
      duration: .duration,
      description: .metadata.description
    }'

# Query 3: Find specific overtakes
curl -X GET "http://34.216.9.25:8000/flows?query=action:pass_outside_turn_3" \
  | jq '.segments[] | select(.metadata.turn==3)'
```

**Visual Demo:**
- Show instant compilation of crash highlights
- Display "Create Highlight Reel" button
- Export options: Social (vertical), Broadcast (4K), Stadium (8K)

#### Act 5: The Business Case (3 minutes)

```bash
# Show storage costs comparison
curl -X GET http://34.216.9.25:8000/vast/status
```

**Cost Breakdown Display:**
```
CURRENT TAPE STORAGE          |  VAST + TAMS SOLUTION
-----------------------------|---------------------------
Storage: $50K/month          |  Storage: $30K/month
Retrieval: $10K/month        |  Retrieval: $0
Manual Search: 3 FTEs        |  AI Search: Automated
Time to Access: 48-72 hrs    |  Time to Access: <1 second
Revenue Potential: $0        |  Revenue Potential: $2M/year
-----------------------------|---------------------------
TOTAL: -$600K/year          |  TOTAL: +$1.4M/year
```

### Killer Demo Queries

#### For NASCAR Fan:
```bash
"Show me every time Dale Jr. passed on the high side"
"Find all crashes involving more than 3 cars"
"Extract every victory burnout from the last 10 years"
```

#### For Football (NFL) Exec:
```bash
"Show me every Pepsi logo during Super Bowl LVIII"
"Find all touchdowns over 50 yards"
"Compile all controversial referee calls"
```

#### For Soccer/Football (Premier League):
```bash
"Find every goal scored from outside the box"
"Show Budweiser logo exposure during Manchester derbies"
"Extract all red card incidents"
```

### The Close: Live Custom Query

**Ask the prospect:** "What would you search for in your archive?"

Then live-query their request:
```bash
# Custom query based on their request
curl -X POST http://34.216.9.25:8000/flows/search \
  -H "Content-Type: application/json" \
  -d '{
    "query": "<their-specific-request>",
    "timerange": "all",
    "limit": 10
  }'
```

### Post-Demo Follow-Up

1. **Send them a custom highlight reel** created from the demo
2. **Provide cost analysis** specific to their archive size
3. **Schedule POC** with their actual footage

### Demo Environment Commands

```bash
# Start demo mode
./scripts/manage-tams.sh status

# Monitor real-time ingestion
ssh -i ./vast-datalayer-poc-key.pem ubuntu@34.216.9.25 \
  'sudo docker logs -f vasttams'

# Show VAST storage efficiency
curl http://34.216.9.25:8000/vast/status | jq .

# Emergency demo reset
./scripts/manage-tams.sh restart
```

### Success Metrics
- **Wow Factor**: Instant results on 10-year old footage query
- **Pain Relief**: Show monthly savings of $20K+
- **Revenue Vision**: "$2M in new licensing opportunities"
- **Technical Trust**: Live system, no smoke and mirrors

### Common Objections & Responses

**"Our footage is too old/poor quality"**
> "TAMS AI improves with any content. We've processed 1950s footage successfully."

**"We don't have metadata"**
> "That's the point - TAMS creates it automatically during ingestion."

**"Cloud storage is expensive"**
> "VAST on-prem costs less than your current tape storage, with instant access."

**"Our rights are complicated"**
> "TAMS tracks rights metadata too - know exactly what you can monetize."

---

## Remember: You're not selling storage. You're selling treasure maps to buried gold.

*"Every frame of your archive should be making money, not collecting dust."*