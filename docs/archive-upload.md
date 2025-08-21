# Video Archive Upload to VAST Storage

This guide provides instructions for uploading video files to the VAST Storage S3-compatible bucket for AI processing with NVIDIA cloud services.

## VAST S3 Configuration

- **Endpoint**: `http://10.0.11.161:9090`
- **Bucket**: `tams-storage`
- **Access Key**: `RTK1A2B7RVTB77Q9KPL1`
- **Secret Key**: `WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO`

## Upload Methods

### Option 1: AWS CLI with VAST S3 Endpoint

Upload individual videos:
```bash
aws s3 cp video1.mp4 s3://tams-storage/ \
  --endpoint-url http://10.0.11.161:9090 \
  --no-verify-ssl
```

Upload multiple videos from a directory:
```bash
aws s3 cp /path/to/videos/ s3://tams-storage/nvidia-ai/ \
  --recursive \
  --endpoint-url http://10.0.11.161:9090 \
  --no-verify-ssl \
  --include "*.mp4"
```

### Option 2: Python Script with boto3

Create a Python script for programmatic uploads:

```python
import boto3
from botocore.config import Config
import os

# Configure S3 client for VAST
s3 = boto3.client(
    's3',
    endpoint_url='http://10.0.11.161:9090',
    aws_access_key_id='RTK1A2B7RVTB77Q9KPL1',
    aws_secret_access_key='WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO',
    config=Config(signature_version='s3v4'),
    verify=False
)

# Upload videos
video_files = [
    'video1.mp4',
    'video2.mp4',
    'video3.mp4',
    'video4.mp4',
    'video5.mp4',
    'video6.mp4'
]

for video in video_files:
    if os.path.exists(video):
        print(f"Uploading {video}...")
        s3.upload_file(video, 'tams-storage', f'nvidia-ai/{video}')
        print(f"Successfully uploaded {video}")
    else:
        print(f"File {video} not found")
```

### Option 3: Multipart Upload for Large Files

For 5-minute videos (typically >100MB), use multipart uploads for better reliability and resume capability:

```bash
# Configure AWS CLI with VAST credentials
aws configure set aws_access_key_id RTK1A2B7RVTB77Q9KPL1
aws configure set aws_secret_access_key WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO

# Upload with multipart (automatic for files >64MB)
aws s3 cp /path/to/videos/ s3://tams-storage/nvidia-ai/ \
  --recursive \
  --endpoint-url http://10.0.11.161:9090 \
  --no-verify-ssl \
  --storage-class STANDARD
```

### Option 4: Parallel Upload Script

For faster uploads of multiple videos, use parallel processing:

```bash
#!/bin/bash
# parallel-upload.sh

ENDPOINT="http://10.0.11.161:9090"
BUCKET="tams-storage"
PREFIX="nvidia-ai"

# Upload videos in parallel (max 3 at a time)
find . -name "*.mp4" -type f | xargs -P 3 -I {} \
  aws s3 cp {} s3://${BUCKET}/${PREFIX}/ \
  --endpoint-url ${ENDPOINT} \
  --no-verify-ssl
```

## Verifying Uploads

Check if videos were uploaded successfully:

```bash
# List uploaded videos
aws s3 ls s3://tams-storage/nvidia-ai/ \
  --endpoint-url http://10.0.11.161:9090 \
  --no-verify-ssl

# Get file size and metadata
aws s3api head-object \
  --bucket tams-storage \
  --key nvidia-ai/video1.mp4 \
  --endpoint-url http://10.0.11.161:9090 \
  --no-verify-ssl
```

## Best Practices

1. **Network Optimization**: Ensure you're on a fast, stable network connection for uploading large video files
2. **Compression**: Consider compressing videos if quality loss is acceptable to reduce upload time
3. **Naming Convention**: Use descriptive names with timestamps, e.g., `video_2025-01-20_001.mp4`
4. **Chunking**: For very large files, consider splitting them into smaller chunks
5. **Verification**: Always verify uploads completed successfully using the list command

## Troubleshooting

### Connection Issues
If you encounter connection errors:
```bash
# Test connectivity to VAST endpoint
curl -I http://10.0.11.161:9090
```

### SSL Certificate Warnings
The `--no-verify-ssl` flag bypasses SSL verification for self-signed certificates. In production, use proper SSL certificates.

### Upload Failures
For failed uploads, check:
- Network connectivity
- VAST service status
- Available storage space
- Access permissions

## Integration with NVIDIA AI Processing

Once videos are uploaded to the VAST bucket, they can be accessed by NVIDIA cloud services using the S3 API. The typical workflow:

1. Upload videos to `s3://tams-storage/nvidia-ai/`
2. Configure NVIDIA AI service with VAST S3 credentials
3. Process videos using NVIDIA's AI models
4. Store results back to VAST or retrieve for analysis

## Additional Resources

- [VAST S3 API Documentation](https://www.vastdata.com/resources)
- [AWS CLI S3 Commands](https://docs.aws.amazon.com/cli/latest/reference/s3/)
- [boto3 S3 Documentation](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/s3.html)