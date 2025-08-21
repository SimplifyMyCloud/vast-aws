# VAST-TAMS Integration Documentation

This documentation library provides comprehensive guides for the VAST Data Platform integration with Time-Addressable Media Store (TAMS) using AI-powered video analysis.

## 📚 Documentation Index

### Core Integration Guides

- **[Video-to-TAMS Checklist](video-to-tams-checklist.md)** - ✅ **TODO LIST** - Step-by-step checklist for video processing
- **[Simple Video-to-TAMS Guide](simple-video-to-tams-guide.md)** - 📋 **QUICK START** - Simple guide from video file to rich TAMS metadata
- **[TAMS-VAST Demo Guide](tams-vast-demo-guide.md)** - Complete demo walkthrough and booth presentation
- **[VAST-TAMS Integration](vast-tams-integration.md)** - Technical integration details and architecture
- **[Bastion Connection Guide](bastion-connection-guide.md)** - Remote access and SSH tunneling setup

### Video Processing & AI Analysis

- **[AWS Video Pipeline](aws-video-pipeline.md)** - ⭐ **NEW** - Automated AWS-powered video processing with Rekognition
- **[Intelligent Video Chunking](intelligent-video-chunking.md)** - 🔥 **EPIC** - Break long videos into smart 5-minute chunks for parallel AI processing
- **[Logo Detection](logo-detection.md)** - AI-powered logo and sponsor detection in videos
- **[Archive Upload](archive-upload.md)** - Video upload instructions for VAST Storage

### Demo Scripts & Automation

- **[TAMS Booth Screenplay](tams-booth-screenplay.md)** - Presentation script and talking points

## 🚀 Quick Start

### Option 1: Intelligent Chunking (🔥 EPIC for Long Videos)

For massive racing broadcasts and long content:

```bash
# Process any length video with smart chunking
./chunk-and-process.sh your-2-hour-race.mp4

# Or run the amazing demo
./chunk-and-process.sh --demo

# Features:
# - Scene-aware splitting (no mid-action cuts)
# - Parallel processing of 5-minute chunks  
# - AWS Rekognition analysis of all segments
# - Unified timeline reconstruction
# - Complete sponsor analytics across entire video
```

### Option 2: AWS-Powered Processing (Recommended for Single Videos)

For individual videos under 30 minutes:

```bash
# Deploy AWS pipeline (one command)
./setup-aws-video-pipeline.sh

# Upload videos and watch magic happen
aws s3 cp your-video.mp4 s3://tams-storage/nvidia-ai/ \
  --endpoint-url http://10.0.11.161:9090 --no-verify-ssl

# Videos are automatically processed with AWS Rekognition
# Results appear in TAMS within minutes
```

### Option 3: Local AI Processing

For offline or local processing:

```bash
# Setup and run local processing
python3 prepare-logos.py
python3 process-videos-ai.py

# For racing-specific sponsor detection
python3 process-racing-sponsors.py
```

### Option 4: Manual Demo Setup

For hands-on demonstration:

```bash
# Run the complete demo
./run-tams-vast-demo.sh
```

## 🎯 Use Cases Covered

### 1. Automated Video Analysis
- **Intelligent Video Chunking**: Smart segmentation of long videos for parallel processing
- **AWS Rekognition Integration**: Cloud-scale object and text detection
- **Local AI Processing**: OpenCV-based scene analysis and logo detection
- **Racing Sponsor Detection**: Specialized motorsports logo tracking

### 2. Media Storage & Retrieval
- **VAST S3 Integration**: High-performance video storage with automatic chunking
- **Time-Addressable Segments**: Precise timestamp-based media access
- **Metadata Enrichment**: AI-generated tags and classifications
- **Timeline Reconstruction**: Unified metadata from parallel chunk processing

### 3. Real-World Applications
- **Broadcast Processing**: Handle full-length racing broadcasts (2+ hours)
- **Motorsports Analytics**: Sponsor visibility measurement and ROI tracking
- **Content Compliance**: Automated brand monitoring and verification
- **Media Asset Management**: Intelligent cataloging and search

## 🏗️ Architecture Overview

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Video Upload  │    │   AI Processing  │    │  TAMS Storage   │
│                 │    │                  │    │                 │
│ • VAST S3 API   │───▶│ • AWS Rekognition│───▶│ • Time Segments │
│ • Direct Upload │    │ • Local OpenCV   │    │ • Rich Metadata │
│ • Auto-trigger │    │ • Logo Detection │    │ • API Access    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🔧 Technical Components

### Infrastructure
- **Terraform**: Infrastructure as Code for AWS resources
- **Docker**: Containerized TAMS deployment
- **AWS Lambda**: Serverless video processing
- **CloudWatch**: Monitoring and logging

### AI & Machine Learning
- **AWS Rekognition**: Enterprise-grade video analysis
- **OpenCV**: Computer vision for local processing
- **Template Matching**: Logo detection algorithms
- **Scene Analysis**: Automated content classification

### Storage & APIs
- **VAST Data Platform**: High-performance S3-compatible storage
- **TAMS API**: RESTful media store interface
- **Time-based Indexing**: Precise temporal media access

## 📊 Demo Scenarios

### Racing Sponsor Analytics
Perfect for motorsports demonstrations:
- Detect sponsor logos on race cars in motion
- Track sponsor visibility throughout races
- Generate ROI reports for sponsorship teams
- Handle motion blur and multi-angle detection

### Content Monitoring
Ideal for media compliance:
- Automated brand detection in video content
- Compliance verification for required logos
- Unauthorized usage detection
- Content classification and tagging

### Media Asset Management
Powerful for broadcast workflows:
- Intelligent video segmentation
- Metadata-driven search and discovery
- Time-addressable media access
- Automated content cataloging

## 🎬 Demo Flow Examples

### 1. Upload & Automatic Processing
```bash
# 1. Upload racing video
aws s3 cp monaco-gp.mp4 s3://tams-storage/nvidia-ai/

# 2. AWS automatically processes (2-5 minutes)
# 3. Check results in TAMS
curl http://34.216.9.25:8000/api/v1/flows
```

### 2. Query Sponsor Visibility
```bash
# Find segments with specific sponsors
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
  jq '.segments[] | select(.metadata.sponsors_detected[] == "shell")'

# Get sponsor screen time analytics
curl http://34.216.9.25:8000/api/v1/flows/{flow_id} | \
  jq '.metadata.logos_detected'
```

### 3. Real-time Monitoring
```bash
# Watch processing logs
aws logs tail /aws/lambda/vast-tams-video-processor --follow

# Monitor TAMS API
watch -n 5 'curl -s http://34.216.9.25:8000/health | jq .'
```

## 📈 Performance Metrics

### AWS Processing Performance
- **5-minute video**: 2-3 minutes processing time
- **Accuracy**: 85-95% sponsor detection rate
- **Scalability**: Concurrent processing of multiple videos
- **Cost**: ~$0.50 per 5-minute video

### Local Processing Performance  
- **Processing Speed**: ~2-5 minutes per 5-minute video
- **Resource Usage**: 2-4 GB RAM, moderate CPU
- **Accuracy**: 70-85% depending on video quality
- **Cost**: Infrastructure only

## 🔍 Troubleshooting

### Common Issues

1. **AWS Pipeline Not Triggering**
   - Check S3 event notifications are configured
   - Verify Lambda permissions for S3 bucket access
   - Ensure videos are uploaded to correct prefix (`nvidia-ai/`)

2. **Low Detection Accuracy**
   - Reduce confidence threshold in configuration
   - Add more logo templates for better matching
   - Ensure video quality is sufficient for analysis

3. **TAMS API Connection Issues**
   - Verify TAMS service is running and accessible
   - Check network connectivity from processing environment
   - Validate API endpoints and authentication

### Debug Commands

```bash
# Check AWS Lambda logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/vast"

# Test TAMS connectivity
curl -v http://34.216.9.25:8000/health

# Verify VAST S3 access
aws s3 ls s3://tams-storage/ --endpoint-url http://10.0.11.161:9090 --no-verify-ssl
```

## 🚀 Getting Started

1. **Choose your approach**:
   - AWS Pipeline (recommended for demos)
   - Local processing (for development)
   - Manual setup (for learning)

2. **Follow the appropriate guide**:
   - [AWS Video Pipeline](aws-video-pipeline.md) for cloud processing
   - [Logo Detection](logo-detection.md) for local analysis
   - [Demo Guide](tams-vast-demo-guide.md) for presentations

3. **Upload test videos** and watch the system automatically analyze and categorize content

4. **Query results** through TAMS API to see rich metadata and sponsor analytics

## 📞 Support

For technical support or questions:
- Review the specific documentation for your use case
- Check CloudWatch logs for AWS pipeline issues
- Verify TAMS API connectivity and health
- Ensure video formats are supported (MP4, AVI, MOV)

## 🔄 Updates and Maintenance

This documentation is actively maintained. Key areas for regular updates:
- AWS service changes and new features
- TAMS API enhancements and new endpoints
- Performance optimizations and cost improvements
- New AI models and detection capabilities

---

*This integration showcases the power of combining VAST's high-performance storage with TAMS's time-addressable media capabilities, enhanced by modern AI processing for intelligent content analysis.*