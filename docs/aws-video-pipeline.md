# AWS Video Processing Pipeline for VAST-TAMS Integration

This document describes the automated AWS-powered video processing pipeline that analyzes videos uploaded to VAST storage and hydrates the TAMS API with rich metadata and timestamps.

## Overview

The AWS Video Processing Pipeline provides a serverless, scalable solution for automatically analyzing racing videos and extracting sponsor visibility data. When videos are uploaded to VAST storage, the system automatically triggers AWS Rekognition to analyze the content and populate TAMS with detailed segment information.

## Architecture

```
📤 Video Upload to VAST S3
    ↓
🔔 S3 Event Notification
    ↓
🚀 AWS Lambda Function Triggered
    ↓
🤖 AWS Rekognition Analysis
    ├── Label Detection (objects, activities)
    └── Text Detection (logos, signage)
    ↓
📊 Segment Creation (10-second chunks)
    ↓
💾 TAMS API Hydration
    ├── Sources
    ├── Flows
    └── Segments with Metadata
```

## Components

### Core Infrastructure

1. **AWS Lambda Function** (`lambda-video-processor.py`)
   - Processes S3 upload events
   - Orchestrates Rekognition analysis
   - Creates TAMS segments with timestamps
   - Handles error recovery and logging

2. **Terraform Deployment** (`deploy-aws-video-pipeline.tf`)
   - IAM roles and policies
   - Lambda function configuration
   - S3 event notifications
   - CloudWatch monitoring
   - Dead letter queues

3. **Setup Automation** (`setup-aws-video-pipeline.sh`)
   - One-click deployment script
   - Dependency installation
   - Infrastructure provisioning
   - Testing and validation

## Features

### Automatic Content Detection

The pipeline automatically identifies:

#### Racing Content
- Race cars and vehicles
- Drivers and racing gear
- Racing tracks and circuits
- Motorsport activities
- Racing equipment and infrastructure

#### Sponsor Recognition
- **Primary Sponsors**: Shell, Mobil1, Castrol, Petronas, Ferrari, Mercedes
- **Beverage Brands**: Red Bull, Monster, Coca-Cola
- **Technology**: Oracle, AWS, Microsoft, NVIDIA, Intel
- **Luxury Brands**: Rolex, Tag Heuer, Richard Mille
- **Tire Manufacturers**: Pirelli, Michelin, Bridgestone

#### Text and Signage
- Logo text overlays
- Trackside advertising
- Car number plates
- Sponsor decals
- Digital displays

### Intelligent Segmentation

Videos are automatically divided into 10-second segments with:
- **Timestamp precision** to the millisecond
- **Content analysis** for each segment
- **Worthiness scoring** based on racing and sponsor content
- **Confidence ratings** for all detections

### TAMS Integration

Seamless integration with the TAMS API:
- **Automatic source creation** for each video
- **Flow generation** with processing metadata
- **Segment hydration** with rich analytical data
- **Tag assignment** for easy querying

## Setup Instructions

### Prerequisites

1. **AWS Account** with appropriate permissions:
   - Lambda execution
   - Rekognition access
   - S3 bucket access
   - CloudWatch logging

2. **AWS CLI** configured:
   ```bash
   aws configure
   # OR
   export AWS_ACCESS_KEY_ID=your-key
   export AWS_SECRET_ACCESS_KEY=your-secret
   ```

3. **Terraform** installed:
   ```bash
   # macOS
   brew install terraform
   
   # Linux
   wget https://terraform.io/downloads
   ```

4. **Python 3.9+** with pip installed

### Deployment

#### One-Click Setup

```bash
# Run the complete setup
./setup-aws-video-pipeline.sh
```

This script will:
1. ✅ Validate AWS credentials
2. 📦 Package Lambda function with dependencies
3. 🚀 Deploy infrastructure with Terraform
4. 📊 Configure monitoring and alarms
5. 🧪 Test the pipeline
6. 📝 Create demo script

#### Manual Deployment

If you prefer manual control:

```bash
# 1. Prepare Lambda package
pip install --target ./package requests boto3
cd package && zip -r ../lambda-video-processor.zip .
cd .. && zip -g lambda-video-processor.zip lambda-video-processor.py

# 2. Deploy with Terraform
terraform init
terraform plan -var="aws_region=us-west-2" -out=pipeline.tfplan
terraform apply pipeline.tfplan

# 3. Test deployment
aws lambda invoke --function-name vast-tams-video-processor \
  --payload file://test-event.json response.json
```

### Configuration

#### Environment Variables

The Lambda function uses these environment variables:

```bash
TAMS_API_URL=http://34.216.9.25:8000      # TAMS API endpoint
VAST_ENDPOINT=http://10.0.11.161:9090     # VAST S3 endpoint
CONFIDENCE_THRESHOLD=70                    # Minimum detection confidence
```

#### Terraform Variables

Customize deployment with these variables:

```hcl
variable "aws_region" {
  description = "AWS region for deployment"
  type        = string
  default     = "us-west-2"
}

variable "tams_api_url" {
  description = "TAMS API endpoint URL"
  type        = string
  default     = "http://34.216.9.25:8000"
}

variable "vast_bucket" {
  description = "VAST storage bucket name"
  type        = string
  default     = "tams-storage"
}
```

## Usage

### Automatic Processing

Once deployed, the pipeline runs automatically:

1. **Upload video** to VAST S3 bucket:
   ```bash
   aws s3 cp race-video.mp4 s3://tams-storage/nvidia-ai/ \
     --endpoint-url http://10.0.11.161:9090 --no-verify-ssl
   ```

2. **Processing begins** automatically within seconds
3. **Results appear** in TAMS API within 2-5 minutes

### Demo Execution

Use the generated demo script:

```bash
# Run complete demo
./demo-aws-pipeline.sh
```

This will:
- Create a test video with sponsor overlays
- Upload to VAST storage
- Monitor AWS processing
- Display TAMS results

### Manual Testing

Test specific videos:

```bash
# Create test event
cat > test-event.json << EOF
{
  "Records": [
    {
      "eventVersion": "2.1",
      "eventSource": "aws:s3", 
      "eventName": "ObjectCreated:Put",
      "s3": {
        "bucket": {"name": "tams-storage"},
        "object": {"key": "nvidia-ai/your-video.mp4"}
      }
    }
  ]
}
EOF

# Invoke Lambda
aws lambda invoke --function-name vast-tams-video-processor \
  --payload file://test-event.json response.json

# Check response
cat response.json | python3 -m json.tool
```

## Processing Output

### Segment Metadata Structure

Each processed segment includes comprehensive metadata:

```json
{
  "segment_number": 3,
  "start_time": 20.0,
  "end_time": 30.0,
  "duration": 10.0,
  "labels_detected": [
    {
      "name": "race car",
      "confidence": 94.2
    },
    {
      "name": "driver",
      "confidence": 87.1
    }
  ],
  "text_detected": [
    {
      "text": "shell",
      "confidence": 91.5
    },
    {
      "text": "ferrari",
      "confidence": 88.3
    }
  ],
  "sponsors_detected": ["shell", "ferrari"],
  "is_worthy": true,
  "confidence_score": 90.3,
  "tags": [
    "racing-content",
    "sponsor-content", 
    "racing:race car",
    "sponsor:shell",
    "text-sponsor:ferrari",
    "worthy"
  ]
}
```

### Flow Metadata

Processing summary at the flow level:

```json
{
  "flow_id": "abc123-def456",
  "name": "AWS Analysis: race-video.mp4",
  "metadata": {
    "processor": "aws-rekognition-textract",
    "total_segments": 18,
    "worthy_segments": 12,
    "sponsors_detected": ["shell", "ferrari", "redbull"],
    "processing_timestamp": "2025-01-20T15:30:45Z"
  }
}
```

## Monitoring and Troubleshooting

### CloudWatch Dashboard

Access the monitoring dashboard:
```bash
# Get dashboard URL
terraform output cloudwatch_dashboard_url
```

The dashboard shows:
- Lambda execution metrics
- Error rates and duration
- Rekognition API usage
- Recent processing logs

### CloudWatch Alarms

Automatic alarms are configured for:
- **High error rate** (>5 errors in 10 minutes)
- **Long execution time** (>10 minutes)
- **Failed invocations** 

### Log Monitoring

Monitor processing in real-time:

```bash
# Follow Lambda logs
aws logs tail /aws/lambda/vast-tams-video-processor --follow

# Get recent errors
aws logs filter-log-events \
  --log-group-name "/aws/lambda/vast-tams-video-processor" \
  --filter-pattern "ERROR"
```

### Common Issues

#### Lambda Timeout
**Problem**: Videos too large, processing takes >15 minutes
**Solution**: 
- Split videos into smaller chunks
- Increase Lambda timeout (max 15 minutes)
- Use batch processing for very large files

#### Rekognition Limits
**Problem**: API rate limiting
**Solution**:
- Implement exponential backoff
- Request limit increases from AWS
- Process videos sequentially for high volumes

#### TAMS API Connectivity
**Problem**: Cannot reach TAMS API from Lambda
**Solution**:
- Verify VPC configuration if Lambda is in VPC
- Check security groups and network ACLs
- Ensure TAMS API is publicly accessible

#### Low Detection Accuracy
**Problem**: Missing sponsors or poor confidence scores
**Solution**:
- Lower confidence threshold (e.g., 60%)
- Train custom Rekognition models
- Add video preprocessing for better quality

## Performance and Costs

### Processing Performance

Typical processing times:
- **5-minute video**: 2-3 minutes processing
- **10-minute video**: 4-6 minutes processing
- **30-minute video**: 10-15 minutes processing

### AWS Costs

Estimated costs (us-west-2):
- **Lambda**: $0.20 per 1000 requests + $0.000000167 per 100ms
- **Rekognition**: $0.10 per minute of video processed
- **S3**: $0.023 per GB stored + $0.0004 per 1000 requests
- **CloudWatch**: $0.50 per million log events

Example cost for 100 5-minute videos/month:
- Rekognition: $50 (500 minutes × $0.10)
- Lambda: $5 (execution time)
- S3/CloudWatch: $2
- **Total**: ~$57/month

### Optimization Tips

1. **Batch Processing**: Process multiple videos together
2. **Selective Analysis**: Only analyze specific time ranges
3. **Confidence Tuning**: Adjust thresholds to reduce false positives
4. **Regional Deployment**: Use same region as VAST storage

## API Integration

### Query Processed Videos

```bash
# Get all flows processed by AWS
curl http://34.216.9.25:8000/api/v1/flows | \
  jq '.flows[] | select(.metadata.processor == "aws-rekognition-textract")'

# Get segments with sponsor content
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
  jq '.segments[] | select(.metadata.tags[] | contains("sponsor-content"))'

# Get racing-specific segments
curl http://34.216.9.25:8000/api/v1/flows/{flow_id}/segments | \
  jq '.segments[] | select(.metadata.tags[] | contains("racing-content"))'
```

### Webhook Integration

Set up webhooks to receive processing notifications:

```python
# Example webhook handler
@app.route('/video-processed', methods=['POST'])
def handle_video_processed():
    data = request.json
    flow_id = data['flow_id']
    sponsors = data['sponsors_detected']
    
    # Process notification
    logger.info(f"Video processed: {flow_id}, sponsors: {sponsors}")
    
    return {'status': 'received'}
```

## Advanced Configuration

### Custom Labels

Train custom Rekognition models for specific sponsors:

```python
# Create custom model training
rekognition.create_project(ProjectName='racing-sponsors')

# Add training data
rekognition.create_dataset(
    ProjectArn=project_arn,
    DatasetType='TRAIN',
    DatasetSource={
        'GroundTruthManifest': {
            'S3Object': {
                'Bucket': 'training-data',
                'Name': 'sponsor-labels.manifest'
            }
        }
    }
)
```

### Parallel Processing

Process multiple videos simultaneously:

```python
# Configure Lambda concurrency
aws lambda put-provisioned-concurrency-config \
  --function-name vast-tams-video-processor \
  --provisioned-concurrency 10
```

### Real-time Processing

For live streams, use:
- **Amazon Kinesis Video Streams**
- **Real-time Rekognition analysis**
- **WebSocket connections to TAMS**

## Security Considerations

### IAM Permissions

The Lambda function requires minimal permissions:
- `rekognition:StartLabelDetection`
- `rekognition:GetLabelDetection` 
- `s3:GetObject` (on VAST bucket)
- `logs:CreateLogGroup` (for CloudWatch)

### Network Security

- Lambda can run in VPC for additional security
- Use VPC endpoints for AWS services
- Implement API authentication for TAMS

### Data Privacy

- Videos remain in your VAST storage
- Rekognition results can be encrypted
- Implement data retention policies

## Migration and Backup

### State Management

Terraform state is stored locally by default. For production:

```bash
# Use remote state
terraform {
  backend "s3" {
    bucket = "terraform-state-bucket"
    key    = "vast-tams-pipeline/terraform.tfstate"
    region = "us-west-2"
  }
}
```

### Disaster Recovery

- Lambda functions are automatically replicated
- Store Terraform state in S3 with versioning
- Backup TAMS database regularly
- Document restore procedures

## Future Enhancements

### Planned Features
1. **Real-time processing** for live streams
2. **Custom model training** for specific racing series
3. **Multi-language support** for international sponsors
4. **Enhanced analytics** with trend analysis
5. **Mobile notifications** for processing completion

### Integration Opportunities
- **Grafana dashboards** for sponsor analytics
- **Slack/Teams notifications** for processing events
- **REST API** for external system integration
- **Data export** to business intelligence tools

## Support and Maintenance

### Regular Tasks
- Monitor CloudWatch alarms
- Review processing costs monthly
- Update Lambda runtime as needed
- Refresh Rekognition models quarterly

### Troubleshooting Resources
- CloudWatch Logs: `/aws/lambda/vast-tams-video-processor`
- Terraform State: `terraform.tfstate`
- Configuration: Environment variables in Lambda console
- Metrics: CloudWatch dashboard

### Getting Help
- Check CloudWatch logs for detailed error messages
- Review Terraform plan output for infrastructure issues
- Test with small videos first to isolate problems
- Monitor TAMS API health independently

## License and Compliance

This AWS Video Processing Pipeline is part of the VAST-TAMS integration project and follows the same licensing terms. The system is designed to comply with:
- AWS security best practices
- Data privacy regulations
- Video content licensing requirements
- Motorsport organization guidelines

For production deployments, ensure compliance with your organization's security policies and any applicable data protection regulations.