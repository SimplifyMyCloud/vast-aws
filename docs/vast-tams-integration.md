# VAST-TAMS Integration Documentation

## Overview
This document describes the successful integration between the TAMS (Time-addressable Media Store) API v6.0.1 and the VAST Data storage cluster deployed in AWS.

**Last Updated**: August 12, 2025  
**TAMS Version**: 6.0.1  
**Status**: ✅ OPERATIONAL

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS VPC (10.0.0.0/16)                     │
├─────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────────────────┐       ┌────────────────────────┐  │
│  │   TAMS VM             │       │   VAST Cluster         │  │
│  │   34.216.9.25:8000    │──────▶│   Protocol VIPs:       │  │
│  │   (Public Subnet)     │       │   - 10.0.11.54        │  │
│  │                       │       │   - 10.0.11.170       │  │
│  │   Docker Container:   │       │   (Private Subnet)     │  │
│  │   - TAMS API v6.0.1   │       │                        │  │
│  │   - VAST DB Client    │       │   S3 Buckets:          │  │
│  │   - Boto3 S3 Client   │       │   - tams-db            │  │
│  └──────────────────────┘       │   - tams-s3            │  │
│                                  └────────────────────────┘  │
│                                                               │
│  ┌──────────────────────┐                                    │
│  │   Bastion Host       │                                    │
│  │   54.68.173.229      │                                    │
│  │   (Jump Box)         │                                    │
│  └──────────────────────┘                                    │
└───────────────────────────────────────────────────────────────┘
```

## Connection Details

### TAMS API Endpoints (v6.0.1)
- **Base URL**: http://34.216.9.25:8000
- **Health Check**: http://34.216.9.25:8000/health (shows version 6.0)
- **API Documentation**: http://34.216.9.25:8000/docs
- **OpenAPI Spec**: http://34.216.9.25:8000/openapi.json
- **VAST Status**: http://34.216.9.25:8000/vast/status
- **Service Info**: http://34.216.9.25:8000/service
- **Sources**: http://34.216.9.25:8000/sources
- **Flows**: http://34.216.9.25:8000/flows
- **Flow Delete Requests**: http://34.216.9.25:8000/flow-delete-requests

### VAST Cluster Configuration
- **Admin UI**: https://10.0.11.161
- **Admin Credentials**: admin / 123456
- **Protocol Pool VIPs** (S3 & NFS traffic):
  - Primary: 10.0.11.54
  - Secondary: 10.0.11.170
- **Replication Pool VIPs**:
  - 10.0.11.173
  - 10.0.11.15

### S3 Configuration
- **S3 Endpoint**: http://10.0.11.54
- **Backup Endpoint**: http://10.0.11.170
- **Access Key ID**: RTK1A2B7RVTB77Q9KPL1
- **Secret Access Key**: WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO
- **Existing Buckets**:
  - `tams-db` (created: 2025-08-08)
  - `tams-s3` (created: 2025-08-08)

## SSH Access

### TAMS VM
```bash
ssh -i ./vast-datalayer-poc-key.pem ubuntu@34.216.9.25
```

### Bastion Host
```bash
ssh -i ./vast-datalayer-poc-key.pem ubuntu@54.68.173.229
```

## Management Commands

### Container Management
```bash
# Check TAMS status
./manage-tams.sh status

# View container logs
./manage-tams.sh logs [number_of_lines]

# Restart TAMS container
./manage-tams.sh restart

# Stop TAMS container
./manage-tams.sh stop

# Start TAMS container
./manage-tams.sh start

# Open shell in container
./manage-tams.sh shell
```

### Direct Docker Commands (on TAMS VM)
```bash
# View container status
sudo docker ps | grep vasttams

# Check container logs
sudo docker logs --tail 50 vasttams

# Restart container
sudo docker restart vasttams

# Execute commands in container
sudo docker exec -it vasttams /bin/bash
```

## Testing the Integration

### 1. Health Check
```bash
curl -s http://34.216.9.25:8000/health | python3 -m json.tool
```

Expected response (v6.0.1):
```json
{
    "status": "healthy",
    "timestamp": "2025-08-12T17:40:11.304953+00:00",
    "version": "6.0",
    "system": {
        "memory_usage_bytes": 1226805248,
        "memory_total_bytes": 16555208704,
        "cpu_percent": 0.5,
        "uptime_seconds": 327919.30497026443
    },
    "telemetry": {
        "tracing_enabled": true,
        "metrics_enabled": true
    }
}
```

### 2. Check VAST Status
```bash
curl -s http://34.216.9.25:8000/vast/status | python3 -m json.tool
```

Expected response:
```json
{
    "version": "6.0.1",
    "vast_connected": true,
    "endpoint": "http://10.0.11.54",
    "buckets": ["tams-db", "tams-s3"]
}
```

### 3. Create a Source
```bash
curl -X POST http://34.216.9.25:8000/api/v1/sources \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Test Video Source",
    "type": "video",
    "location": "vast://10.0.11.54/tams-s3/videos/"
  }'
```

### 4. List Sources
```bash
curl -s http://34.216.9.25:8000/api/v1/sources | python3 -m json.tool
```

## Deployment Scripts

The following scripts are available for deployment and configuration:

1. **`deploy-tams-v6.0.1.sh`** - Deploy TAMS v6.0.1 with VAST integration (CURRENT)
2. **`deploy-tams-minimal.sh`** - Minimal POC deployment without external dependencies
3. **`deploy-tams-aws-s3.sh`** - Deployment with AWS S3 integration
4. **`deploy-tams-vast-integration.sh`** - Full VAST integration deployment
5. **`configure-tams-vast-s3.sh`** - Configure TAMS with VAST S3 credentials
6. **`manage-tams.sh`** - Container management utility
7. **`find-vast-s3-config.sh`** - Helper to find VAST S3 configuration

## Troubleshooting

### Container Won't Start
```bash
# Check logs for errors
sudo docker logs vasttams

# Verify container status
sudo docker ps -a | grep vasttams

# Remove and recreate container
sudo docker stop vasttams
sudo docker rm vasttams
./deploy-tams-vast-integration.sh
```

### VAST Connection Issues
```bash
# Test connectivity from TAMS VM to VAST VIPs
ssh -i ./vast-datalayer-poc-key.pem ubuntu@34.216.9.25
ping 10.0.11.54
curl -I http://10.0.11.54/

# Check S3 credentials
curl -s http://34.216.9.25:8000/api/v1/vast/buckets
```

### Network Connectivity
```bash
# Verify security groups allow port 8000
terraform output tams_vm_instance_id
aws ec2 describe-security-groups --group-ids [security-group-id]

# Test from outside
curl -v http://34.216.9.25:8000/health
```

## Security Considerations

1. **Credentials**: S3 access keys are configured in the container environment
2. **Network**: TAMS VM is in public subnet, VAST cluster in private subnet
3. **Ports**: Only port 8000 is exposed for TAMS API
4. **IAM**: TAMS VM has IAM role for AWS S3 access (if needed)

## Architecture Notes

- **TAMS Version**: v6.0.1 (Git tag: v6.0.1, Commit: 3f1ccb4)
- **TAMS Container**: Running vasttams-s3:6.0.1 Docker image with Python FastAPI
- **Database**: VAST DB for metadata storage (tables: objects, webhooks, deletion_requests)
- **S3 Client**: Boto3 configured for VAST S3-compatible API
- **VAST Tables Created**: Automatically creates required tables on startup
- **Health Checks**: Docker health check configured with 30s intervals
- **Restart Policy**: Container auto-restarts unless explicitly stopped
- **Telemetry**: Tracing and metrics enabled

## Future Enhancements

1. **VAST DB Integration**: Connect to VAST database service when available
2. **SSL/TLS**: Enable HTTPS for TAMS API
3. **Authentication**: Add API key or OAuth authentication
4. **Monitoring**: Integrate with CloudWatch or Prometheus
5. **High Availability**: Deploy multiple TAMS instances with load balancing
6. **Backup**: Automated backup of SQLite database to S3

## Support

For issues or questions:
- Check container logs: `./manage-tams.sh logs`
- SSH to TAMS VM: `ssh -i ./vast-datalayer-poc-key.pem ubuntu@34.216.9.25`
- Review VAST admin UI: https://10.0.11.161 (admin/123456)

---
*Last Updated: August 2025*
*Integration Status: ✅ OPERATIONAL*