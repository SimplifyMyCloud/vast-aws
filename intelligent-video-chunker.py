#!/usr/bin/env python3
"""
Intelligent Video Chunking System for VAST-TAMS Pipeline
Breaks long videos into optimal 5-minute chunks with scene-aware splitting
Parallel processing and automatic reassembly of metadata
"""

import os
import cv2
import boto3
import json
import subprocess
import logging
import numpy as np
from typing import List, Dict, Tuple, Optional
from pathlib import Path
import tempfile
import time
from datetime import datetime, timedelta
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import requests

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
CHUNK_DURATION = 300  # 5 minutes in seconds
OVERLAP_DURATION = 10  # 10-second overlap between chunks
MAX_CHUNK_SIZE = 400  # 6 minutes 40 seconds max per chunk
MIN_CHUNK_SIZE = 180  # 3 minutes minimum per chunk

VAST_CONFIG = {
    'endpoint': 'http://10.0.11.161:9090',
    'access_key': 'RTK1A2B7RVTB77Q9KPL1',
    'secret_key': 'WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO',
    'bucket': 'tams-storage'
}

TAMS_CONFIG = {
    'base_url': 'http://34.216.9.25:8000'
}

# AWS Lambda function name for processing chunks
AWS_LAMBDA_FUNCTION = 'vast-tams-video-processor'

class IntelligentVideoChunker:
    """Smart video chunking with scene detection and parallel processing"""
    
    def __init__(self):
        self.s3_client = self._init_s3_client()
        self.lambda_client = boto3.client('lambda')
        self.processing_jobs = {}
        
    def _init_s3_client(self):
        """Initialize S3 client for VAST storage"""
        return boto3.client(
            's3',
            endpoint_url=VAST_CONFIG['endpoint'],
            aws_access_key_id=VAST_CONFIG['access_key'],
            aws_secret_access_key=VAST_CONFIG['secret_key'],
            verify=False
        )
    
    def analyze_video_structure(self, video_path: str) -> Dict:
        """Analyze video to understand its structure and optimal chunking points"""
        logger.info(f"Analyzing video structure: {video_path}")
        
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        duration = frame_count / fps
        
        analysis = {
            'duration': duration,
            'fps': fps,
            'frame_count': frame_count,
            'estimated_chunks': int(np.ceil(duration / CHUNK_DURATION)),
            'scene_changes': [],
            'optimal_split_points': []
        }
        
        logger.info(f"Video: {duration:.1f}s, {frame_count} frames @ {fps:.1f}fps")
        logger.info(f"Estimated chunks needed: {analysis['estimated_chunks']}")
        
        # Detect scene changes for smart splitting
        scene_changes = self._detect_scene_changes(cap, fps)
        analysis['scene_changes'] = scene_changes
        
        # Calculate optimal split points
        split_points = self._calculate_optimal_splits(duration, scene_changes)
        analysis['optimal_split_points'] = split_points
        
        cap.release()
        return analysis
    
    def _detect_scene_changes(self, cap, fps: float, sample_rate: int = 30) -> List[float]:
        """Detect major scene changes for intelligent splitting"""
        logger.info("Detecting scene changes for intelligent splitting...")
        
        scene_changes = [0.0]  # Always start at beginning
        prev_frame = None
        frame_idx = 0
        
        # Sample every 30th frame for speed
        while True:
            cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
            ret, frame = cap.read()
            
            if not ret:
                break
            
            if frame_idx % sample_rate == 0:
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                
                if prev_frame is not None:
                    # Calculate histogram difference
                    hist1 = cv2.calcHist([prev_frame], [0], None, [256], [0, 256])
                    hist2 = cv2.calcHist([gray], [0], None, [256], [0, 256])
                    diff = cv2.compareHist(hist1, hist2, cv2.HISTCMP_CORREL)
                    
                    # Major scene change if correlation is low
                    if diff < 0.7:  # Threshold for scene change
                        timestamp = frame_idx / fps
                        scene_changes.append(timestamp)
                        logger.debug(f"Scene change detected at {timestamp:.1f}s")
                
                prev_frame = gray
            
            frame_idx += sample_rate
        
        logger.info(f"Detected {len(scene_changes)} scene changes")
        return scene_changes
    
    def _calculate_optimal_splits(self, duration: float, scene_changes: List[float]) -> List[Dict]:
        """Calculate optimal split points avoiding cutting during action"""
        splits = []
        current_start = 0.0
        
        while current_start < duration:
            # Target end time
            target_end = current_start + CHUNK_DURATION
            
            if target_end >= duration:
                # Final chunk
                splits.append({
                    'start': current_start,
                    'end': duration,
                    'duration': duration - current_start,
                    'chunk_number': len(splits) + 1
                })
                break
            
            # Find the best scene change near the target end
            best_split = target_end
            min_distance = float('inf')
            
            for scene_time in scene_changes:
                # Look for scene changes within ±30 seconds of target
                if abs(scene_time - target_end) < 30:
                    distance = abs(scene_time - target_end)
                    if distance < min_distance:
                        min_distance = distance
                        best_split = scene_time
            
            # Ensure minimum and maximum chunk sizes
            actual_end = max(current_start + MIN_CHUNK_SIZE, 
                           min(best_split, current_start + MAX_CHUNK_SIZE))
            
            splits.append({
                'start': current_start,
                'end': actual_end,
                'duration': actual_end - current_start,
                'chunk_number': len(splits) + 1,
                'has_overlap': len(splits) > 0  # All chunks except first have overlap
            })
            
            # Next chunk starts with overlap
            current_start = actual_end - OVERLAP_DURATION if actual_end < duration else actual_end
        
        logger.info(f"Calculated {len(splits)} optimal chunks")
        for split in splits:
            logger.info(f"  Chunk {split['chunk_number']}: {split['start']:.1f}s - {split['end']:.1f}s ({split['duration']:.1f}s)")
        
        return splits
    
    def create_chunks(self, video_path: str, splits: List[Dict], output_dir: str) -> List[str]:
        """Create video chunks using ffmpeg with high quality"""
        logger.info(f"Creating {len(splits)} video chunks...")
        
        chunk_paths = []
        video_name = Path(video_path).stem
        
        # Use ThreadPoolExecutor for parallel chunk creation
        with ThreadPoolExecutor(max_workers=4) as executor:
            futures = []
            
            for split in splits:
                chunk_filename = f"{video_name}_chunk_{split['chunk_number']:03d}.mp4"
                chunk_path = os.path.join(output_dir, chunk_filename)
                
                future = executor.submit(self._create_single_chunk, video_path, split, chunk_path)
                futures.append((future, chunk_path, split))
            
            # Collect results
            for future, chunk_path, split in futures:
                try:
                    success = future.result(timeout=300)  # 5-minute timeout per chunk
                    if success:
                        chunk_paths.append(chunk_path)
                        logger.info(f"✓ Created chunk {split['chunk_number']}: {os.path.basename(chunk_path)}")
                    else:
                        logger.error(f"✗ Failed to create chunk {split['chunk_number']}")
                except Exception as e:
                    logger.error(f"✗ Error creating chunk {split['chunk_number']}: {e}")
        
        logger.info(f"Successfully created {len(chunk_paths)} chunks")
        return chunk_paths
    
    def _create_single_chunk(self, video_path: str, split: Dict, output_path: str) -> bool:
        """Create a single video chunk using ffmpeg"""
        try:
            # High-quality ffmpeg command
            cmd = [
                'ffmpeg', '-y',  # Overwrite output
                '-ss', str(split['start']),  # Start time
                '-i', video_path,  # Input file
                '-t', str(split['duration']),  # Duration
                '-c:v', 'libx264',  # Video codec
                '-crf', '18',  # High quality
                '-preset', 'fast',  # Encoding speed
                '-c:a', 'aac',  # Audio codec
                '-b:a', '128k',  # Audio bitrate
                '-movflags', '+faststart',  # Web optimization
                output_path
            ]
            
            # Run ffmpeg
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)
            
            if result.returncode == 0:
                return True
            else:
                logger.error(f"ffmpeg error: {result.stderr}")
                return False
                
        except Exception as e:
            logger.error(f"Error creating chunk: {e}")
            return False
    
    def upload_chunks_parallel(self, chunk_paths: List[str], base_key: str) -> List[Dict]:
        """Upload chunks to VAST S3 in parallel"""
        logger.info(f"Uploading {len(chunk_paths)} chunks to VAST S3...")
        
        uploaded_chunks = []
        
        with ThreadPoolExecutor(max_workers=3) as executor:
            futures = []
            
            for chunk_path in chunk_paths:
                chunk_name = os.path.basename(chunk_path)
                s3_key = f"{base_key}/chunks/{chunk_name}"
                
                future = executor.submit(self._upload_single_chunk, chunk_path, s3_key)
                futures.append((future, chunk_path, s3_key))
            
            # Collect results
            for future, chunk_path, s3_key in futures:
                try:
                    success = future.result(timeout=600)  # 10-minute timeout per upload
                    if success:
                        uploaded_chunks.append({
                            'local_path': chunk_path,
                            's3_key': s3_key,
                            'filename': os.path.basename(chunk_path)
                        })
                        logger.info(f"✓ Uploaded: {os.path.basename(chunk_path)}")
                    else:
                        logger.error(f"✗ Failed to upload: {os.path.basename(chunk_path)}")
                except Exception as e:
                    logger.error(f"✗ Upload error for {os.path.basename(chunk_path)}: {e}")
        
        logger.info(f"Successfully uploaded {len(uploaded_chunks)} chunks")
        return uploaded_chunks
    
    def _upload_single_chunk(self, chunk_path: str, s3_key: str) -> bool:
        """Upload a single chunk to S3"""
        try:
            self.s3_client.upload_file(chunk_path, VAST_CONFIG['bucket'], s3_key)
            return True
        except Exception as e:
            logger.error(f"S3 upload error: {e}")
            return False
    
    def trigger_parallel_processing(self, uploaded_chunks: List[Dict]) -> List[str]:
        """Trigger AWS Lambda processing for all chunks in parallel"""
        logger.info(f"Triggering parallel processing for {len(uploaded_chunks)} chunks...")
        
        job_ids = []
        
        for chunk in uploaded_chunks:
            try:
                # Create S3 event payload
                event_payload = {
                    "Records": [{
                        "eventVersion": "2.1",
                        "eventSource": "aws:s3",
                        "eventName": "ObjectCreated:Put",
                        "s3": {
                            "bucket": {"name": VAST_CONFIG['bucket']},
                            "object": {"key": chunk['s3_key']}
                        }
                    }]
                }
                
                # Invoke Lambda asynchronously
                response = self.lambda_client.invoke(
                    FunctionName=AWS_LAMBDA_FUNCTION,
                    InvocationType='Event',  # Asynchronous
                    Payload=json.dumps(event_payload)
                )
                
                job_id = f"chunk_{chunk['filename']}_{int(time.time())}"
                job_ids.append(job_id)
                
                logger.info(f"✓ Triggered processing: {chunk['filename']}")
                
            except Exception as e:
                logger.error(f"✗ Failed to trigger processing for {chunk['filename']}: {e}")
        
        logger.info(f"Triggered processing for {len(job_ids)} chunks")
        return job_ids
    
    def monitor_processing_progress(self, job_ids: List[str], timeout: int = 3600) -> Dict:
        """Monitor the progress of chunk processing"""
        logger.info(f"Monitoring processing progress for {len(job_ids)} jobs...")
        
        start_time = time.time()
        completed_jobs = set()
        
        while time.time() - start_time < timeout:
            # Check TAMS for new flows (simplified check)
            try:
                response = requests.get(f"{TAMS_CONFIG['base_url']}/api/v1/flows", timeout=10)
                if response.status_code == 200:
                    flows = response.json().get('flows', [])
                    chunk_flows = [f for f in flows if 'chunk_' in f.get('name', '')]
                    
                    logger.info(f"Progress: {len(chunk_flows)} chunks processed")
                    
                    if len(chunk_flows) >= len(job_ids):
                        logger.info("All chunks appear to be processed!")
                        break
                
            except Exception as e:
                logger.warning(f"Error checking progress: {e}")
            
            time.sleep(30)  # Check every 30 seconds
        
        return {
            'completed': len(completed_jobs),
            'total': len(job_ids),
            'processing_time': time.time() - start_time
        }
    
    def reassemble_metadata(self, original_video_name: str, splits: List[Dict]) -> Dict:
        """Reassemble metadata from all chunks into a unified timeline"""
        logger.info("Reassembling metadata from processed chunks...")
        
        try:
            # Get all flows from TAMS
            response = requests.get(f"{TAMS_CONFIG['base_url']}/api/v1/flows", timeout=30)
            if response.status_code != 200:
                raise Exception(f"Failed to get flows: {response.status_code}")
            
            flows = response.json().get('flows', [])
            chunk_flows = [f for f in flows if original_video_name in f.get('name', '') and 'chunk_' in f.get('name', '')]
            
            logger.info(f"Found {len(chunk_flows)} chunk flows to reassemble")
            
            # Collect all segments with timeline adjustment
            unified_segments = []
            sponsor_timeline = {}
            total_detections = 0
            
            for flow in chunk_flows:
                # Extract chunk number from flow name
                chunk_num = self._extract_chunk_number(flow['name'])
                if chunk_num is None:
                    continue
                
                # Get the corresponding split info
                split_info = next((s for s in splits if s['chunk_number'] == chunk_num), None)
                if not split_info:
                    continue
                
                # Get segments for this flow
                segments_response = requests.get(
                    f"{TAMS_CONFIG['base_url']}/api/v1/flows/{flow['id']}/segments",
                    timeout=30
                )
                
                if segments_response.status_code == 200:
                    segments = segments_response.json().get('segments', [])
                    
                    # Adjust timestamps for global timeline
                    for segment in segments:
                        adjusted_segment = segment.copy()
                        adjusted_segment['start_time'] += split_info['start']
                        adjusted_segment['end_time'] += split_info['start']
                        adjusted_segment['original_chunk'] = chunk_num
                        
                        # Track sponsors
                        sponsors = segment.get('metadata', {}).get('sponsors_detected', [])
                        for sponsor in sponsors:
                            if sponsor not in sponsor_timeline:
                                sponsor_timeline[sponsor] = []
                            sponsor_timeline[sponsor].append({
                                'start': adjusted_segment['start_time'],
                                'end': adjusted_segment['end_time'],
                                'chunk': chunk_num
                            })
                        
                        unified_segments.append(adjusted_segment)
                        total_detections += len(sponsors)
            
            # Sort segments by timeline
            unified_segments.sort(key=lambda x: x['start_time'])
            
            # Create unified metadata
            unified_metadata = {
                'original_video': original_video_name,
                'total_chunks_processed': len(chunk_flows),
                'total_segments': len(unified_segments),
                'total_sponsor_detections': total_detections,
                'unique_sponsors': list(sponsor_timeline.keys()),
                'processing_timestamp': datetime.now().isoformat(),
                'sponsor_timeline': self._calculate_sponsor_analytics(sponsor_timeline),
                'segments': unified_segments[:10]  # Sample of segments
            }
            
            logger.info(f"Reassembled timeline: {len(unified_segments)} segments, {len(sponsor_timeline)} unique sponsors")
            return unified_metadata
            
        except Exception as e:
            logger.error(f"Error reassembling metadata: {e}")
            return {'error': str(e)}
    
    def _extract_chunk_number(self, flow_name: str) -> Optional[int]:
        """Extract chunk number from flow name"""
        import re
        match = re.search(r'chunk_(\d+)', flow_name)
        return int(match.group(1)) if match else None
    
    def _calculate_sponsor_analytics(self, sponsor_timeline: Dict) -> Dict:
        """Calculate comprehensive sponsor analytics"""
        analytics = {}
        
        for sponsor, appearances in sponsor_timeline.items():
            total_time = sum(app['end'] - app['start'] for app in appearances)
            chunks_appeared = len(set(app['chunk'] for app in appearances))
            
            analytics[sponsor] = {
                'total_screen_time': round(total_time, 2),
                'appearance_count': len(appearances),
                'chunks_appeared_in': chunks_appeared,
                'average_appearance_duration': round(total_time / len(appearances), 2) if appearances else 0,
                'first_appearance': min(app['start'] for app in appearances),
                'last_appearance': max(app['end'] for app in appearances)
            }
        
        return analytics


def process_long_video(video_path: str, output_name: str = None) -> Dict:
    """Main function to process a long video end-to-end"""
    
    logger.info("="*60)
    logger.info("🎬 INTELLIGENT VIDEO CHUNKING PIPELINE")
    logger.info("="*60)
    
    start_time = time.time()
    
    if not output_name:
        output_name = Path(video_path).stem
    
    chunker = IntelligentVideoChunker()
    
    # Create temporary directory for chunks
    with tempfile.TemporaryDirectory() as temp_dir:
        try:
            # Step 1: Analyze video structure
            logger.info("\n1️⃣  ANALYZING VIDEO STRUCTURE")
            logger.info("="*40)
            analysis = chunker.analyze_video_structure(video_path)
            
            if analysis['duration'] < CHUNK_DURATION:
                logger.info("Video is shorter than chunk duration, processing as single file...")
                # Process normally without chunking
                return {'status': 'processed_single', 'duration': analysis['duration']}
            
            # Step 2: Create intelligent chunks
            logger.info("\n2️⃣  CREATING INTELLIGENT CHUNKS")
            logger.info("="*40)
            chunk_paths = chunker.create_chunks(video_path, analysis['optimal_split_points'], temp_dir)
            
            if not chunk_paths:
                raise Exception("Failed to create any chunks")
            
            # Step 3: Upload chunks in parallel
            logger.info("\n3️⃣  UPLOADING CHUNKS TO VAST")
            logger.info("="*40)
            uploaded_chunks = chunker.upload_chunks_parallel(chunk_paths, f"nvidia-ai/{output_name}")
            
            # Step 4: Trigger parallel AI processing
            logger.info("\n4️⃣  TRIGGERING PARALLEL AI PROCESSING")
            logger.info("="*40)
            job_ids = chunker.trigger_parallel_processing(uploaded_chunks)
            
            # Step 5: Monitor processing
            logger.info("\n5️⃣  MONITORING PROCESSING PROGRESS")
            logger.info("="*40)
            progress = chunker.monitor_processing_progress(job_ids, timeout=1800)  # 30 minutes
            
            # Step 6: Reassemble metadata
            logger.info("\n6️⃣  REASSEMBLING UNIFIED TIMELINE")
            logger.info("="*40)
            unified_metadata = chunker.reassemble_metadata(output_name, analysis['optimal_split_points'])
            
            # Generate summary report
            total_time = time.time() - start_time
            
            summary = {
                'status': 'success',
                'original_video': video_path,
                'processing_time': round(total_time, 2),
                'video_duration': analysis['duration'],
                'chunks_created': len(chunk_paths),
                'chunks_uploaded': len(uploaded_chunks),
                'chunks_processed': progress['completed'],
                'unified_metadata': unified_metadata
            }
            
            # Save detailed report
            report_path = f"chunking_report_{output_name}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
            with open(report_path, 'w') as f:
                json.dump(summary, f, indent=2, default=str)
            
            logger.info("\n" + "="*60)
            logger.info("🎉 CHUNKING PIPELINE COMPLETE!")
            logger.info("="*60)
            logger.info(f"📊 Original video: {analysis['duration']:.1f} seconds")
            logger.info(f"🔧 Chunks created: {len(chunk_paths)}")
            logger.info(f"⚡ Processing time: {total_time:.1f} seconds")
            logger.info(f"🏆 Sponsors detected: {len(unified_metadata.get('unique_sponsors', []))}")
            logger.info(f"📋 Report saved: {report_path}")
            
            if unified_metadata.get('unique_sponsors'):
                logger.info(f"🎯 Top sponsors: {', '.join(unified_metadata['unique_sponsors'][:5])}")
            
            return summary
            
        except Exception as e:
            logger.error(f"Pipeline failed: {e}")
            return {'status': 'failed', 'error': str(e), 'processing_time': time.time() - start_time}


def main():
    """Command-line interface for video chunking"""
    import argparse
    
    parser = argparse.ArgumentParser(description='Intelligent Video Chunking for AI Processing')
    parser.add_argument('video_path', help='Path to the long video file')
    parser.add_argument('--output-name', help='Output name for chunks (default: video filename)')
    parser.add_argument('--chunk-duration', type=int, default=300, help='Chunk duration in seconds (default: 300)')
    
    args = parser.parse_args()
    
    global CHUNK_DURATION
    CHUNK_DURATION = args.chunk_duration
    
    if not os.path.exists(args.video_path):
        logger.error(f"Video file not found: {args.video_path}")
        return 1
    
    result = process_long_video(args.video_path, args.output_name)
    
    if result['status'] == 'success':
        logger.info("\n🎬 Ready to query TAMS for results:")
        logger.info(f"   curl {TAMS_CONFIG['base_url']}/api/v1/flows")
        return 0
    else:
        logger.error(f"Processing failed: {result.get('error', 'Unknown error')}")
        return 1


if __name__ == "__main__":
    exit(main())