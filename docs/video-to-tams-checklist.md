# Video-to-TAMS Processing Checklist ✅

**Quick checklist to transform any video into rich TAMS metadata**

---

## 📋 Pre-Flight Checklist (5 minutes)

### Prerequisites
- [ ] AWS account configured (`aws configure` or env vars set)
- [ ] VAST storage accessible at `http://10.0.11.161:9090`
- [ ] TAMS API running at `http://34.216.9.25:8000`
- [ ] Video file ready to process (MP4, AVI, MOV supported)
- [ ] Required tools installed:
  - [ ] `ffmpeg` (for video chunking)
  - [ ] `python3` with dependencies
  - [ ] `aws cli`

### Quick Health Check
- [ ] Test VAST access: `aws s3 ls s3://tams-storage/ --endpoint-url http://10.0.11.161:9090 --no-verify-ssl`
- [ ] Test TAMS API: `curl http://34.216.9.25:8000/health`
- [ ] Test AWS credentials: `aws sts get-caller-identity`

---

## ⚙️ One-Time Setup Checklist (10 minutes)

### Deploy AWS Infrastructure
- [ ] Run setup script: `./scripts/setup-aws-video-pipeline.sh`
- [ ] Verify Lambda function created: `aws lambda get-function --function-name vast-tams-video-processor`
- [ ] Confirm S3 event notifications configured
- [ ] Test with small video file
- [ ] Check CloudWatch dashboard is accessible

### Verify Components
- [ ] Lambda function status: **Active**
- [ ] S3 bucket permissions: **Configured**
- [ ] TAMS API connectivity: **Connected**
- [ ] CloudWatch monitoring: **Enabled**

---

## 🎬 Video Processing Checklist

### Choose Your Path:

#### ☐ Path A: Short Videos (< 30 minutes)
```bash
# Upload and auto-process
aws s3 cp your-video.mp4 s3://tams-storage/nvidia-ai/ \
  --endpoint-url http://10.0.11.161:9090 --no-verify-ssl
```
- [ ] Video uploaded successfully
- [ ] Lambda function triggered (check CloudWatch logs)
- [ ] Processing completed (2-5 minutes)
- [ ] Results appear in TAMS

#### ☐ Path B: Long Videos (30+ minutes)
```bash
# Intelligent chunking
./scripts/chunk-and-process.sh your-long-video.mp4 [optional-name]
```
- [ ] Video analysis completed
- [ ] Chunks created successfully
- [ ] Parallel upload to VAST
- [ ] Parallel AWS processing triggered
- [ ] Timeline reassembly completed

#### ☐ Path C: Demo Mode
```bash
# Auto-demo with test video
./scripts/chunk-and-process.sh --demo
```
- [ ] Demo video created (15 minutes with sponsors)
- [ ] Chunking demonstrated
- [ ] Processing completed
- [ ] Results available for presentation

---

## 📊 Results Verification Checklist

### Check TAMS Database
- [ ] **Sources created**: `curl http://34.216.9.25:8000/api/v1/sources | jq '.sources | length'`
- [ ] **Flows generated**: `curl http://34.216.9.25:8000/api/v1/flows | jq '.flows | length'`
- [ ] **Segments populated**: `curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | jq '.segments | length'`

### Verify Rich Metadata
- [ ] **Labels detected**: Check for objects, activities, racing content
- [ ] **Text/sponsors identified**: Look for sponsor names in segments
- [ ] **Timestamps accurate**: Verify start_time/end_time precision
- [ ] **Tags assigned**: Confirm racing-content, sponsor-content tags
- [ ] **Worthiness scoring**: Check is_worthy flags on segments

### Quality Assurance
- [ ] **No missing segments**: All time ranges covered
- [ ] **Sponsor continuity**: Logos tracked across chunks (for long videos)
- [ ] **Timeline accuracy**: No gaps or overlaps in timeline
- [ ] **Confidence scores**: Reasonable detection confidence levels

---

## 🔍 Query Your Data Checklist

### Basic Queries
- [ ] **Get all flows**: 
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows | jq .
  ```

- [ ] **Get flow details**:
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows/{flow_id} | jq .
  ```

- [ ] **Get all segments**:
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | jq .
  ```

### Advanced Queries
- [ ] **Find sponsor content**:
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
    jq '.segments[] | select(.metadata.sponsors_detected | length > 0)'
  ```

- [ ] **Get racing segments**:
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
    jq '.segments[] | select(.metadata.tags[] | contains("racing"))'
  ```

- [ ] **Time range query**:
  ```bash
  curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
    jq '.segments[] | select(.start_time >= 60 and .end_time <= 120)'
  ```

---

## 🚨 Troubleshooting Checklist

### If Video Not Processing
- [ ] Check file format (MP4, AVI, MOV supported)
- [ ] Verify S3 upload: `aws s3 ls s3://tams-storage/nvidia-ai/ --endpoint-url http://10.0.11.161:9090 --no-verify-ssl`
- [ ] Check Lambda logs: `aws logs tail /aws/lambda/vast-tams-video-processor --follow`
- [ ] Verify S3 event notifications configured
- [ ] Confirm video is in correct prefix: `nvidia-ai/`

### If TAMS Database Empty
- [ ] Check TAMS API health: `curl http://34.216.9.25:8000/health`
- [ ] Verify network connectivity from Lambda to TAMS
- [ ] Check Lambda environment variables (TAMS_API_URL)
- [ ] Review Lambda execution logs for API errors

### If Processing Too Slow
- [ ] Use chunking for videos > 30 minutes: `./chunk-and-process.sh`
- [ ] Check AWS Lambda concurrency limits
- [ ] Monitor CloudWatch metrics for bottlenecks
- [ ] Consider adjusting chunk duration: `CHUNK_DURATION=240`

### If Poor Detection Quality
- [ ] Check video quality (resolution, clarity)
- [ ] Adjust confidence thresholds in Lambda configuration
- [ ] Verify lighting conditions in video
- [ ] Test with different video samples

---

## ✅ Success Criteria

### You Know It's Working When:
- [ ] **Upload completes** without errors
- [ ] **Processing finishes** within expected time
- [ ] **TAMS shows new flows** for your video
- [ ] **Segments contain rich metadata** (labels, sponsors, tags)
- [ ] **Queries return meaningful results**
- [ ] **Timeline is complete** with no gaps

### Expected Results:
- [ ] **Sources**: 1 per video file
- [ ] **Flows**: 1+ per video (may have chunks)
- [ ] **Segments**: 6-72 per video (depending on length)
- [ ] **Metadata**: Labels, text, sponsors, confidence scores
- [ ] **Processing time**: 2-15 minutes depending on video length

---

## 🎯 Next Steps Checklist

### Explore Your Data
- [ ] Build queries for specific sponsors
- [ ] Filter by time ranges
- [ ] Search for racing activities
- [ ] Analyze sponsor screen time

### Scale Up
- [ ] Process multiple videos in batch
- [ ] Set up automated processing workflows
- [ ] Create dashboards with metadata
- [ ] Integrate with business intelligence tools

### Optimize
- [ ] Tune confidence thresholds
- [ ] Add custom logo templates
- [ ] Configure chunk sizes for your content
- [ ] Set up monitoring alerts

---

## 📞 Quick Help Commands

```bash
# Check system status
curl http://34.216.9.25:8000/health
aws lambda get-function --function-name vast-tams-video-processor

# Monitor processing
aws logs tail /aws/lambda/vast-tams-video-processor --follow
watch -n 5 'curl -s http://34.216.9.25:8000/api/v1/flows | jq ".flows | length"'

# Basic queries
curl http://34.216.9.25:8000/api/v1/flows
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments

# Reset if needed
aws s3 rm s3://tams-storage/nvidia-ai/ --recursive --endpoint-url http://10.0.11.161:9090
```

---

**🎉 Congratulations! You've successfully transformed a video file into a rich, queryable TAMS database with AI-generated metadata and sponsor analytics!**