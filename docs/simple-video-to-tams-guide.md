# Simple Video-to-TAMS Guide 🎬➡️💾

**Transform any video file into a rich TAMS database with AI metadata in minutes!**

## 📋 Quick Checklist

### ✅ **Prerequisites** (5 minutes)
- [ ] AWS account with credentials configured
- [ ] VAST storage accessible 
- [ ] TAMS API running
- [ ] Video file ready to process

### ✅ **One-Time Setup** (10 minutes)
- [ ] Deploy AWS pipeline: `./setup-aws-video-pipeline.sh`
- [ ] Verify services are running
- [ ] Test with small video

### ✅ **Process Any Video** (2-15 minutes depending on length)
- [ ] Choose your processing method
- [ ] Upload/process video
- [ ] Monitor progress
- [ ] Query TAMS for results

---

## 🚀 Three Simple Paths

### Path 1: Short Videos (< 30 minutes) - EASIEST
```bash
# 1. Upload video (auto-triggers processing)
aws s3 cp your-video.mp4 s3://tams-storage/nvidia-ai/ \
  --endpoint-url http://10.0.11.161:9090 --no-verify-ssl

# 2. Wait 2-5 minutes for AWS to process

# 3. Check results in TAMS
curl http://34.216.9.25:8000/api/v1/flows | jq .
```

### Path 2: Long Videos (30+ minutes) - SMARTEST  
```bash
# 1. Intelligent chunking (handles everything)
./scripts/chunk-and-process.sh your-long-video.mp4

# 2. Watch parallel processing magic
# 3. Get unified timeline automatically
```

### Path 3: Demo Mode - FASTEST TO SEE RESULTS
```bash
# 1. Run complete demo (creates test video)
./scripts/chunk-and-process.sh --demo

# 2. See the entire pipeline in action
# 3. Perfect for presentations!
```

---

## 📖 Detailed Step-by-Step

### Step 1: One-Time AWS Setup
```bash
# Deploy the AWS infrastructure (only needed once)
./scripts/setup-aws-video-pipeline.sh

# This creates:
# ✅ Lambda function for video processing
# ✅ S3 event triggers
# ✅ CloudWatch monitoring
# ✅ All necessary permissions
```

**Expected result:** AWS pipeline ready, TAMS connected

### Step 2: Choose Your Video Processing Method

#### For Regular Videos (< 30 min):
```bash
# Just upload - processing happens automatically
aws s3 cp race-highlights.mp4 s3://tams-storage/nvidia-ai/ \
  --endpoint-url http://10.0.11.161:9090 --no-verify-ssl
```

#### For Long Videos (30+ min):
```bash
# Use intelligent chunking for optimal processing
./scripts/chunk-and-process.sh full-race-broadcast.mp4 monaco_gp_2024
```

#### For Testing/Demo:
```bash
# Auto-creates and processes demo video
./scripts/chunk-and-process.sh --demo
```

### Step 3: Monitor Processing

#### Watch AWS Processing:
```bash
# Monitor Lambda logs in real-time
aws logs tail /aws/lambda/vast-tams-video-processor --follow
```

#### Check TAMS Database:
```bash
# See flows being created
watch -n 5 'curl -s http://34.216.9.25:8000/api/v1/flows | jq ".flows | length"'
```

#### For Chunked Videos:
```bash
# The chunk-and-process.sh script shows progress automatically
# 🔄 Creating chunks... ✅ Uploading... 🤖 Processing... 📊 Results ready!
```

### Step 4: Query Your Rich Metadata

#### Get All Processed Videos:
```bash
curl http://34.216.9.25:8000/api/v1/flows | jq '.flows[] | {name, id, sponsors: .metadata.sponsors_detected}'
```

#### Get Segments with Sponsors:
```bash
# Replace {flow_id} with actual flow ID from above
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
  jq '.segments[] | select(.metadata.sponsors_detected | length > 0)'
```

#### Get Racing Content:
```bash
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
  jq '.segments[] | select(.metadata.tags[] | contains("racing"))'
```

#### Get Timeline Summary:
```bash
curl http://34.216.9.25:8000/api/v1/flows/{flow_id} | \
  jq '.metadata'
```

---

## 🎯 What You Get in TAMS

### Video Sources
```json
{
  "id": "source_123",
  "name": "AWS-Processed: race-video.mp4", 
  "type": "video",
  "location": "vast://tams-storage/nvidia-ai/race-video.mp4"
}
```

### Flows with AI Analysis
```json
{
  "id": "flow_456",
  "name": "AWS Analysis: race-video.mp4",
  "metadata": {
    "total_segments": 18,
    "worthy_segments": 12,
    "sponsors_detected": ["shell", "ferrari", "redbull"],
    "processing_timestamp": "2025-01-20T15:30:45Z"
  }
}
```

### Rich Segments with Timestamps
```json
{
  "segment_number": 3,
  "start_time": 20.0,
  "end_time": 30.0,
  "metadata": {
    "labels_detected": [
      {"name": "race car", "confidence": 94.2},
      {"name": "driver", "confidence": 87.1}
    ],
    "sponsors_detected": ["shell", "ferrari"],
    "is_worthy": true,
    "tags": ["racing-content", "sponsor-content", "sponsor:shell"]
  }
}
```

---

## ⚡ Quick Commands Reference

### Essential Commands
```bash
# Setup (run once)
./scripts/setup-aws-video-pipeline.sh

# Process any video
./scripts/chunk-and-process.sh video.mp4

# Or upload directly for short videos
aws s3 cp video.mp4 s3://tams-storage/nvidia-ai/ --endpoint-url http://10.0.11.161:9090 --no-verify-ssl

# Check results
curl http://34.216.9.25:8000/api/v1/flows
```

### Monitoring Commands
```bash
# Watch AWS processing
aws logs tail /aws/lambda/vast-tams-video-processor --follow

# Monitor TAMS
curl http://34.216.9.25:8000/health

# Check processing progress
curl http://34.216.9.25:8000/api/v1/flows | jq '.flows | length'
```

### Query Commands
```bash
# Get all flows
curl http://34.216.9.25:8000/api/v1/flows | jq .

# Get specific flow
curl http://34.216.9.25:8000/api/v1/flows/{flow_id} | jq .

# Get segments
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | jq .

# Find sponsor content
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | jq '.segments[] | select(.metadata.sponsors_detected | length > 0)'
```

---

## 🚨 Troubleshooting

### Video Not Processing?
```bash
# Check AWS Lambda function
aws lambda get-function --function-name vast-tams-video-processor

# Check S3 upload succeeded
aws s3 ls s3://tams-storage/nvidia-ai/ --endpoint-url http://10.0.11.161:9090 --no-verify-ssl

# Check Lambda logs for errors
aws logs filter-log-events --log-group-name "/aws/lambda/vast-tams-video-processor" --filter-pattern "ERROR"
```

### TAMS Not Responding?
```bash
# Check TAMS health
curl http://34.216.9.25:8000/health

# Restart TAMS if needed (depends on your setup)
# Check with your infrastructure team
```

### Processing Too Slow?
```bash
# For long videos, use chunking
./chunk-and-process.sh long-video.mp4

# Check AWS Lambda concurrency limits
aws lambda get-account-settings
```

---

## 🎉 Success! You Now Have:

✅ **Video uploaded** to VAST storage  
✅ **AI analysis complete** with AWS Rekognition  
✅ **Rich metadata** stored in TAMS database  
✅ **Time-addressable segments** with sponsor detection  
✅ **Racing content** automatically tagged  
✅ **Queryable timeline** for precise media access  

### Next Steps:
- Query specific timestamps: `start_time=45.2&end_time=67.8`
- Filter by sponsors: `sponsors_detected=["shell"]`
- Find racing moments: `tags=["racing-content"]`
- Build dashboards with the rich metadata
- Create highlight reels from worthy segments

**You've successfully transformed a simple video file into a powerful, searchable, time-addressable media database! 🚀**