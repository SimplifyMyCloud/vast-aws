"""
AWS Lambda Function: Automatic Video Processing for TAMS
Triggered by S3 uploads to VAST storage, processes with Rekognition, hydrates TAMS
"""

import json
import boto3
import requests
import logging
import os
from datetime import datetime
from typing import Dict, List, Any
import time

# Configure logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# AWS clients
rekognition = boto3.client('rekognition')
s3 = boto3.client('s3')

# Configuration from environment variables
TAMS_API_URL = os.environ.get('TAMS_API_URL', 'http://34.216.9.25:8000')
VAST_ENDPOINT = os.environ.get('VAST_ENDPOINT', 'http://10.0.11.161:9090')
CONFIDENCE_THRESHOLD = float(os.environ.get('CONFIDENCE_THRESHOLD', '70'))

# Racing-specific keywords for worthiness detection
RACING_KEYWORDS = [
    'car', 'race car', 'vehicle', 'automobile', 'racing',
    'track', 'circuit', 'motorsport', 'driver', 'helmet',
    'sponsor', 'logo', 'text', 'brand', 'advertisement'
]

SPONSOR_BRANDS = [
    'shell', 'mobil', 'castrol', 'petronas', 'ferrari', 
    'mercedes', 'red bull', 'redbull', 'pirelli', 'rolex',
    'oracle', 'aws', 'microsoft', 'nvidia', 'intel'
]

def lambda_handler(event, context):
    """Main Lambda handler triggered by S3 events"""
    
    try:
        # Parse S3 event
        for record in event['Records']:
            bucket = record['s3']['bucket']['name']
            key = record['s3']['object']['key']
            
            logger.info(f"Processing video: s3://{bucket}/{key}")
            
            # Only process video files
            if not key.lower().endswith(('.mp4', '.avi', '.mov', '.mkv')):
                logger.info(f"Skipping non-video file: {key}")
                continue
            
            # Process the video
            result = process_video(bucket, key)
            
            if result['success']:
                logger.info(f"Successfully processed {key}")
            else:
                logger.error(f"Failed to process {key}: {result.get('error')}")
        
        return {
            'statusCode': 200,
            'body': json.dumps('Videos processed successfully')
        }
        
    except Exception as e:
        logger.error(f"Error in lambda_handler: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps(f'Error: {str(e)}')
        }

def process_video(bucket: str, key: str) -> Dict:
    """Process a single video with AWS Rekognition"""
    
    try:
        # Start Rekognition jobs
        label_job = start_label_detection(bucket, key)
        text_job = start_text_detection(bucket, key)
        
        # Wait for jobs to complete
        labels = wait_for_job_completion(label_job['JobId'], 'label')
        texts = wait_for_job_completion(text_job['JobId'], 'text')
        
        # Analyze results and create segments
        segments = analyze_and_create_segments(labels, texts, key)
        
        # Create TAMS source and flow
        source_id = create_tams_source(key, bucket)
        if not source_id:
            return {'success': False, 'error': 'Failed to create TAMS source'}
        
        flow_id = create_tams_flow(source_id, key, segments)
        if not flow_id:
            return {'success': False, 'error': 'Failed to create TAMS flow'}
        
        # Create TAMS segments
        success = create_tams_segments(flow_id, segments)
        
        return {
            'success': success,
            'source_id': source_id,
            'flow_id': flow_id,
            'segments_created': len(segments)
        }
        
    except Exception as e:
        logger.error(f"Error processing video {key}: {str(e)}")
        return {'success': False, 'error': str(e)}

def start_label_detection(bucket: str, key: str) -> Dict:
    """Start AWS Rekognition label detection job"""
    
    response = rekognition.start_label_detection(
        Video={
            'S3Object': {
                'Bucket': bucket,
                'Name': key
            }
        },
        MinConfidence=CONFIDENCE_THRESHOLD,
        Features=['GENERAL_LABELS']
    )
    
    logger.info(f"Started label detection job: {response['JobId']}")
    return response

def start_text_detection(bucket: str, key: str) -> Dict:
    """Start AWS Rekognition text detection job"""
    
    response = rekognition.start_text_detection(
        Video={
            'S3Object': {
                'Bucket': bucket,
                'Name': key
            }
        },
        Filters={
            'WordFilter': {
                'MinConfidence': CONFIDENCE_THRESHOLD
            }
        }
    )
    
    logger.info(f"Started text detection job: {response['JobId']}")
    return response

def wait_for_job_completion(job_id: str, job_type: str, max_wait: int = 300) -> List:
    """Wait for Rekognition job to complete and return results"""
    
    start_time = time.time()
    
    while time.time() - start_time < max_wait:
        if job_type == 'label':
            response = rekognition.get_label_detection(JobId=job_id)
        else:  # text
            response = rekognition.get_text_detection(JobId=job_id)
        
        status = response['JobStatus']
        
        if status == 'SUCCEEDED':
            logger.info(f"Job {job_id} completed successfully")
            return response.get('Labels', []) or response.get('TextDetections', [])
        elif status == 'FAILED':
            logger.error(f"Job {job_id} failed")
            return []
        
        # Still in progress, wait
        time.sleep(10)
    
    logger.warning(f"Job {job_id} timed out")
    return []

def analyze_and_create_segments(labels: List, texts: List, video_key: str) -> List[Dict]:
    """Analyze Rekognition results and create time-based segments"""
    
    segments = []
    segment_duration = 10.0  # 10-second segments
    current_time = 0.0
    
    # Get video duration (estimate from last timestamp)
    max_timestamp = 0
    for label in labels:
        max_timestamp = max(max_timestamp, label.get('Timestamp', 0) / 1000.0)
    for text in texts:
        max_timestamp = max(max_timestamp, text.get('Timestamp', 0) / 1000.0)
    
    if max_timestamp == 0:
        max_timestamp = 300  # Default 5 minutes if no timestamps
    
    segment_number = 1
    
    while current_time < max_timestamp:
        segment_end = min(current_time + segment_duration, max_timestamp)
        
        # Find labels and texts in this time segment
        segment_labels = []
        segment_texts = []
        
        for label in labels:
            timestamp = label.get('Timestamp', 0) / 1000.0
            if current_time <= timestamp < segment_end:
                segment_labels.append(label)
        
        for text in texts:
            timestamp = text.get('Timestamp', 0) / 1000.0
            if current_time <= timestamp < segment_end:
                segment_texts.append(text)
        
        # Analyze segment content
        segment_analysis = analyze_segment_content(segment_labels, segment_texts)
        
        # Create segment
        segment = {
            'segment_number': segment_number,
            'start_time': current_time,
            'end_time': segment_end,
            'duration': segment_end - current_time,
            'labels_detected': segment_analysis['labels'],
            'text_detected': segment_analysis['texts'],
            'sponsors_detected': segment_analysis['sponsors'],
            'is_worthy': segment_analysis['is_worthy'],
            'confidence_score': segment_analysis['avg_confidence'],
            'tags': segment_analysis['tags']
        }
        
        segments.append(segment)
        
        current_time = segment_end
        segment_number += 1
    
    logger.info(f"Created {len(segments)} segments for {video_key}")
    return segments

def analyze_segment_content(labels: List, texts: List) -> Dict:
    """Analyze the content of a segment to determine worthiness and tags"""
    
    analysis = {
        'labels': [],
        'texts': [],
        'sponsors': [],
        'is_worthy': False,
        'avg_confidence': 0.0,
        'tags': []
    }
    
    all_confidences = []
    racing_score = 0
    sponsor_score = 0
    
    # Process labels
    for label_data in labels:
        label_name = label_data['Label']['Name'].lower()
        confidence = label_data['Label']['Confidence']
        
        analysis['labels'].append({
            'name': label_name,
            'confidence': confidence
        })
        
        all_confidences.append(confidence)
        
        # Check for racing-related content
        if any(keyword in label_name for keyword in RACING_KEYWORDS):
            racing_score += confidence
            analysis['tags'].append(f'racing:{label_name}')
        
        # Check for sponsor brands
        if any(brand in label_name for brand in SPONSOR_BRANDS):
            sponsor_score += confidence
            analysis['sponsors'].append(label_name)
            analysis['tags'].append(f'sponsor:{label_name}')
    
    # Process text detections
    for text_data in texts:
        detected_text = text_data['TextDetection']['DetectedText'].lower()
        confidence = text_data['TextDetection']['Confidence']
        
        analysis['texts'].append({
            'text': detected_text,
            'confidence': confidence
        })
        
        all_confidences.append(confidence)
        
        # Check for sponsor text
        for brand in SPONSOR_BRANDS:
            if brand in detected_text:
                sponsor_score += confidence
                analysis['sponsors'].append(brand)
                analysis['tags'].append(f'text-sponsor:{brand}')
    
    # Calculate worthiness
    analysis['is_worthy'] = (
        racing_score > 200 or  # Strong racing content
        sponsor_score > 150 or  # Strong sponsor presence
        len(analysis['sponsors']) > 0  # Any sponsors detected
    )
    
    # Calculate average confidence
    if all_confidences:
        analysis['avg_confidence'] = sum(all_confidences) / len(all_confidences)
    
    # Add general tags
    if racing_score > 100:
        analysis['tags'].append('racing-content')
    if sponsor_score > 100:
        analysis['tags'].append('sponsor-content')
    if analysis['is_worthy']:
        analysis['tags'].append('worthy')
    
    return analysis

def create_tams_source(video_key: str, bucket: str) -> str:
    """Create a source in TAMS API"""
    
    try:
        payload = {
            'name': f"AWS-Processed: {video_key}",
            'type': 'video',
            'location': f'vast://{bucket}/{video_key}',
            'metadata': {
                'processor': 'aws-rekognition',
                'bucket': bucket,
                'created_at': datetime.now().isoformat()
            }
        }
        
        response = requests.post(
            f"{TAMS_API_URL}/api/v1/sources",
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            source_id = response.json().get('id')
            logger.info(f"Created TAMS source: {source_id}")
            return source_id
        else:
            logger.error(f"Failed to create TAMS source: {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"Error creating TAMS source: {str(e)}")
        return None

def create_tams_flow(source_id: str, video_key: str, segments: List[Dict]) -> str:
    """Create a flow in TAMS API"""
    
    try:
        # Calculate summary statistics
        worthy_segments = [s for s in segments if s['is_worthy']]
        total_sponsors = set()
        for segment in segments:
            total_sponsors.update(segment['sponsors_detected'])
        
        payload = {
            'source_id': source_id,
            'name': f"AWS Analysis: {video_key}",
            'type': 'video',
            'metadata': {
                'processor': 'aws-rekognition-textract',
                'total_segments': len(segments),
                'worthy_segments': len(worthy_segments),
                'sponsors_detected': list(total_sponsors),
                'processing_timestamp': datetime.now().isoformat()
            }
        }
        
        response = requests.post(
            f"{TAMS_API_URL}/api/v1/flows",
            json=payload,
            timeout=30
        )
        
        if response.status_code == 200:
            flow_id = response.json().get('id')
            logger.info(f"Created TAMS flow: {flow_id}")
            return flow_id
        else:
            logger.error(f"Failed to create TAMS flow: {response.text}")
            return None
            
    except Exception as e:
        logger.error(f"Error creating TAMS flow: {str(e)}")
        return None

def create_tams_segments(flow_id: str, segments: List[Dict]) -> bool:
    """Create segments in TAMS API"""
    
    success_count = 0
    
    for segment in segments:
        try:
            payload = {
                'flow_id': flow_id,
                'segment_number': segment['segment_number'],
                'start_time': segment['start_time'],
                'end_time': segment['end_time'],
                'metadata': {
                    'duration': segment['duration'],
                    'labels_detected': segment['labels_detected'],
                    'text_detected': segment['text_detected'],
                    'sponsors_detected': segment['sponsors_detected'],
                    'is_worthy': segment['is_worthy'],
                    'confidence_score': segment['confidence_score'],
                    'tags': segment['tags'],
                    'processor': 'aws-rekognition'
                }
            }
            
            response = requests.post(
                f"{TAMS_API_URL}/api/v1/flows/{flow_id}/segments",
                json=payload,
                timeout=30
            )
            
            if response.status_code == 200:
                success_count += 1
            else:
                logger.error(f"Failed to create segment {segment['segment_number']}: {response.text}")
                
        except Exception as e:
            logger.error(f"Error creating segment {segment['segment_number']}: {str(e)}")
    
    logger.info(f"Created {success_count}/{len(segments)} segments")
    return success_count == len(segments)