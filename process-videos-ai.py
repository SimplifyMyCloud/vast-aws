#!/usr/bin/env python3
"""
AI Video Processing Pipeline for TAMS
Processes videos stored in VAST S3, extracts timestamps and worthy scenes,
and hydrates the TAMS API with segments and metadata.
"""

import boto3
import json
import requests
import cv2
import numpy as np
from datetime import datetime, timedelta
import os
import tempfile
import logging
from typing import List, Dict, Tuple, Optional
import subprocess
from concurrent.futures import ThreadPoolExecutor, as_completed
import hashlib
import time
import urllib.request
from pathlib import Path

# Configure logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
VAST_CONFIG = {
    'endpoint': 'http://10.0.11.161:9090',
    'access_key': 'RTK1A2B7RVTB77Q9KPL1',
    'secret_key': 'WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO',
    'bucket': 'tams-storage'
}

TAMS_CONFIG = {
    'base_url': 'http://34.216.9.25:8000',
    'api_version': 'v1'
}

# NVIDIA AI Config (can be replaced with other AI services)
AI_CONFIG = {
    'nvidia_api_key': os.getenv('NVIDIA_API_KEY', ''),
    'nvidia_endpoint': 'https://api.nvcf.nvidia.com/v2/nvcf/pexec/functions/',
    'model': 'nvidia/video-understanding-v1',  # Example model
    'use_local_processing': True  # Fallback to local processing if NVIDIA not available
}

# Logo detection configuration
LOGO_CONFIG = {
    'detect_logos': True,
    'logo_templates_dir': './logo_templates',  # Directory containing logo images to detect
    'confidence_threshold': 0.7,  # Minimum confidence for logo detection
    'use_deep_learning': False,  # Use YOLO/CNN for logo detection if True
    'common_logos': [  # List of common logos to look for
        'nvidia', 'aws', 'vast', 'bbc', 'netflix', 'youtube', 'apple', 'google'
    ]
}

class VideoProcessor:
    """Main video processing class"""
    
    def __init__(self):
        self.s3_client = self._init_s3_client()
        self.tams_client = TAMSClient(TAMS_CONFIG['base_url'])
        self.logo_templates = self._load_logo_templates() if LOGO_CONFIG['detect_logos'] else {}
        
    def _init_s3_client(self):
        """Initialize S3 client for VAST storage"""
        return boto3.client(
            's3',
            endpoint_url=VAST_CONFIG['endpoint'],
            aws_access_key_id=VAST_CONFIG['access_key'],
            aws_secret_access_key=VAST_CONFIG['secret_key'],
            verify=False
        )
    
    def _load_logo_templates(self) -> Dict:
        """Load logo templates for detection"""
        templates = {}
        template_dir = Path(LOGO_CONFIG['logo_templates_dir'])
        
        # Create template directory if it doesn't exist
        template_dir.mkdir(exist_ok=True)
        
        # Download some common logo templates if directory is empty
        if not any(template_dir.iterdir()):
            logger.info("Downloading common logo templates...")
            self._download_default_logos(template_dir)
        
        # Load templates from directory
        for logo_file in template_dir.glob('*.{png,jpg,jpeg}'):
            logo_name = logo_file.stem.lower()
            try:
                template = cv2.imread(str(logo_file))
                if template is not None:
                    templates[logo_name] = template
                    logger.info(f"Loaded logo template: {logo_name}")
            except Exception as e:
                logger.warning(f"Failed to load logo {logo_file}: {e}")
        
        return templates
    
    def _download_default_logos(self, template_dir: Path):
        """Download default logo templates for demo"""
        # These would be URLs to actual logo images in production
        # For demo, we'll create simple placeholder logos
        default_logos = {
            'nvidia': self._create_text_logo('NVIDIA', (0, 118, 0)),  # Green
            'aws': self._create_text_logo('AWS', (255, 153, 0)),  # Orange
            'vast': self._create_text_logo('VAST', (0, 0, 255)),  # Blue
            'bbc': self._create_text_logo('BBC', (0, 0, 0)),  # Black
        }
        
        for name, logo_img in default_logos.items():
            logo_path = template_dir / f"{name}.png"
            cv2.imwrite(str(logo_path), logo_img)
            logger.info(f"Created placeholder logo: {name}")
    
    def _create_text_logo(self, text: str, color: Tuple[int, int, int]) -> np.ndarray:
        """Create a simple text-based logo for demonstration"""
        img = np.ones((100, 200, 3), dtype=np.uint8) * 255
        font = cv2.FONT_HERSHEY_SIMPLEX
        cv2.putText(img, text, (10, 60), font, 1.5, color, 3)
        return img
    
    def download_video(self, s3_key: str, local_path: str) -> bool:
        """Download video from VAST S3 to local storage"""
        try:
            logger.info(f"Downloading {s3_key} from VAST S3...")
            self.s3_client.download_file(VAST_CONFIG['bucket'], s3_key, local_path)
            return True
        except Exception as e:
            logger.error(f"Failed to download {s3_key}: {e}")
            return False
    
    def extract_video_metadata(self, video_path: str) -> Dict:
        """Extract basic video metadata using OpenCV"""
        cap = cv2.VideoCapture(video_path)
        
        metadata = {
            'fps': cap.get(cv2.CAP_PROP_FPS),
            'frame_count': int(cap.get(cv2.CAP_PROP_FRAME_COUNT)),
            'width': int(cap.get(cv2.CAP_PROP_FRAME_WIDTH)),
            'height': int(cap.get(cv2.CAP_PROP_FRAME_HEIGHT)),
            'duration': cap.get(cv2.CAP_PROP_FRAME_COUNT) / cap.get(cv2.CAP_PROP_FPS),
            'codec': int(cap.get(cv2.CAP_PROP_FOURCC))
        }
        
        cap.release()
        return metadata
    
    def detect_scene_changes(self, video_path: str, threshold: float = 30.0) -> List[Dict]:
        """Detect scene changes using frame differencing"""
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        scenes = []
        prev_frame = None
        frame_idx = 0
        scene_start = 0
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            # Convert to grayscale for comparison
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            if prev_frame is not None:
                # Calculate frame difference
                diff = cv2.absdiff(prev_frame, gray)
                mean_diff = np.mean(diff)
                
                # Detect scene change
                if mean_diff > threshold:
                    timestamp = frame_idx / fps
                    scenes.append({
                        'scene_number': len(scenes) + 1,
                        'start_time': scene_start,
                        'end_time': timestamp,
                        'duration': timestamp - scene_start,
                        'start_frame': int(scene_start * fps),
                        'end_frame': frame_idx,
                        'confidence': min(mean_diff / 100, 1.0),
                        'logos_detected': []  # Will be populated by logo detection
                    })
                    scene_start = timestamp
            
            prev_frame = gray
            frame_idx += 1
        
        # Add final scene
        if scene_start < frame_idx / fps:
            scenes.append({
                'scene_number': len(scenes) + 1,
                'start_time': scene_start,
                'end_time': frame_idx / fps,
                'duration': (frame_idx / fps) - scene_start,
                'start_frame': int(scene_start * fps),
                'end_frame': frame_idx,
                'confidence': 1.0,
                'logos_detected': []
            })
        
        cap.release()
        return scenes
    
    def detect_logos_in_frame(self, frame: np.ndarray) -> List[Dict]:
        """Detect logos in a single frame using template matching"""
        detected_logos = []
        
        if not self.logo_templates:
            return detected_logos
        
        # Convert frame to grayscale for template matching
        gray_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
        
        for logo_name, template in self.logo_templates.items():
            # Convert template to grayscale
            template_gray = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
            
            # Perform template matching at multiple scales
            for scale in [0.5, 0.75, 1.0, 1.25, 1.5]:
                # Resize template
                width = int(template_gray.shape[1] * scale)
                height = int(template_gray.shape[0] * scale)
                resized_template = cv2.resize(template_gray, (width, height))
                
                # Skip if template is larger than frame
                if resized_template.shape[0] > gray_frame.shape[0] or \
                   resized_template.shape[1] > gray_frame.shape[1]:
                    continue
                
                # Apply template matching
                result = cv2.matchTemplate(gray_frame, resized_template, cv2.TM_CCOEFF_NORMED)
                min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(result)
                
                # Check if confidence threshold is met
                if max_val >= LOGO_CONFIG['confidence_threshold']:
                    detected_logos.append({
                        'logo_name': logo_name,
                        'confidence': float(max_val),
                        'position': {
                            'x': int(max_loc[0]),
                            'y': int(max_loc[1]),
                            'width': width,
                            'height': height
                        },
                        'scale': scale
                    })
                    break  # Found at this scale, no need to check other scales
        
        return detected_logos
    
    def detect_logos_in_video(self, video_path: str, scenes: List[Dict], sample_rate: int = 30) -> List[Dict]:
        """Detect logos throughout the video and update scenes with logo information"""
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        all_logo_detections = []
        
        for scene in scenes:
            scene_logos = {}
            frames_to_check = range(scene['start_frame'], scene['end_frame'], sample_rate)
            
            for frame_idx in frames_to_check:
                cap.set(cv2.CAP_PROP_POS_FRAMES, frame_idx)
                ret, frame = cap.read()
                
                if not ret:
                    continue
                
                # Detect logos in this frame
                logos = self.detect_logos_in_frame(frame)
                
                # Aggregate logo detections for this scene
                for logo in logos:
                    logo_name = logo['logo_name']
                    if logo_name not in scene_logos:
                        scene_logos[logo_name] = {
                            'logo_name': logo_name,
                            'first_appearance': frame_idx / fps,
                            'last_appearance': frame_idx / fps,
                            'max_confidence': logo['confidence'],
                            'avg_confidence': logo['confidence'],
                            'detection_count': 1,
                            'positions': [logo['position']]
                        }
                    else:
                        scene_logos[logo_name]['last_appearance'] = frame_idx / fps
                        scene_logos[logo_name]['max_confidence'] = max(
                            scene_logos[logo_name]['max_confidence'], 
                            logo['confidence']
                        )
                        scene_logos[logo_name]['avg_confidence'] = (
                            scene_logos[logo_name]['avg_confidence'] + logo['confidence']
                        ) / 2
                        scene_logos[logo_name]['detection_count'] += 1
                        scene_logos[logo_name]['positions'].append(logo['position'])
                
                # Record individual detection
                if logos:
                    all_logo_detections.append({
                        'timestamp': frame_idx / fps,
                        'frame_number': frame_idx,
                        'scene_number': scene['scene_number'],
                        'logos': logos
                    })
            
            # Update scene with detected logos
            scene['logos_detected'] = list(scene_logos.values())
        
        cap.release()
        
        # Log summary
        total_logos = sum(len(scene['logos_detected']) for scene in scenes)
        logger.info(f"Detected {total_logos} logo appearances across {len(scenes)} scenes")
        
        return all_logo_detections
    
    def extract_keyframes(self, video_path: str, scenes: List[Dict]) -> List[Dict]:
        """Extract keyframes from detected scenes"""
        cap = cv2.VideoCapture(video_path)
        keyframes = []
        
        for scene in scenes:
            # Get frame from middle of scene
            middle_frame = (scene['start_frame'] + scene['end_frame']) // 2
            cap.set(cv2.CAP_PROP_POS_FRAMES, middle_frame)
            
            ret, frame = cap.read()
            if ret:
                # Calculate frame metrics for "worthiness"
                gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
                
                # Calculate sharpness (Laplacian variance)
                laplacian = cv2.Laplacian(gray, cv2.CV_64F)
                sharpness = laplacian.var()
                
                # Calculate brightness
                brightness = np.mean(gray)
                
                # Calculate contrast
                contrast = gray.std()
                
                keyframes.append({
                    'scene_number': scene['scene_number'],
                    'frame_number': middle_frame,
                    'timestamp': middle_frame / cap.get(cv2.CAP_PROP_FPS),
                    'sharpness': float(sharpness),
                    'brightness': float(brightness),
                    'contrast': float(contrast),
                    'quality_score': self._calculate_quality_score(sharpness, brightness, contrast)
                })
        
        cap.release()
        return keyframes
    
    def _calculate_quality_score(self, sharpness: float, brightness: float, contrast: float) -> float:
        """Calculate overall quality score for a frame"""
        # Normalize and weight the metrics
        sharpness_score = min(sharpness / 1000, 1.0) * 0.4
        brightness_score = (1 - abs(brightness - 128) / 128) * 0.3
        contrast_score = min(contrast / 50, 1.0) * 0.3
        
        return sharpness_score + brightness_score + contrast_score
    
    def analyze_with_ai(self, video_path: str, scenes: List[Dict]) -> List[Dict]:
        """Analyze video with AI (NVIDIA or fallback)"""
        if AI_CONFIG['nvidia_api_key'] and not AI_CONFIG['use_local_processing']:
            return self._analyze_with_nvidia(video_path, scenes)
        else:
            return self._analyze_locally(video_path, scenes)
    
    def _analyze_locally(self, video_path: str, scenes: List[Dict]) -> List[Dict]:
        """Local AI analysis using computer vision"""
        logger.info("Performing local AI analysis...")
        
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        
        enhanced_scenes = []
        
        for scene in scenes:
            # Sample frames from the scene
            cap.set(cv2.CAP_PROP_POS_FRAMES, scene['start_frame'])
            
            # Analyze motion
            motion_score = self._analyze_motion(cap, scene['start_frame'], scene['end_frame'])
            
            # Detect objects/features
            cap.set(cv2.CAP_PROP_POS_FRAMES, (scene['start_frame'] + scene['end_frame']) // 2)
            ret, frame = cap.read()
            
            if ret:
                features = self._detect_features(frame)
                
                enhanced_scene = {
                    **scene,
                    'motion_score': motion_score,
                    'feature_count': features['feature_count'],
                    'dominant_colors': features['dominant_colors'],
                    'is_worthy': self._determine_worthiness(motion_score, features, scene.get('logos_detected')),
                    'ai_confidence': 0.85,  # Local processing confidence
                    'tags': self._generate_tags(motion_score, features, scene.get('logos_detected'))
                }
                enhanced_scenes.append(enhanced_scene)
        
        cap.release()
        return enhanced_scenes
    
    def _analyze_motion(self, cap, start_frame: int, end_frame: int, sample_rate: int = 10) -> float:
        """Analyze motion between frames"""
        motion_scores = []
        prev_frame = None
        
        for i in range(start_frame, min(end_frame, start_frame + 100), sample_rate):
            cap.set(cv2.CAP_PROP_POS_FRAMES, i)
            ret, frame = cap.read()
            
            if not ret:
                break
            
            gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
            
            if prev_frame is not None:
                flow = cv2.calcOpticalFlowFarneback(
                    prev_frame, gray, None, 0.5, 3, 15, 3, 5, 1.2, 0
                )
                magnitude = np.sqrt(flow[..., 0]**2 + flow[..., 1]**2)
                motion_scores.append(np.mean(magnitude))
            
            prev_frame = gray
        
        return np.mean(motion_scores) if motion_scores else 0.0
    
    def _detect_features(self, frame) -> Dict:
        """Detect visual features in a frame"""
        # Convert to RGB for analysis
        rgb_frame = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        
        # Detect edges (feature count)
        edges = cv2.Canny(cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY), 100, 200)
        feature_count = np.sum(edges > 0)
        
        # Get dominant colors
        pixels = rgb_frame.reshape(-1, 3)
        from sklearn.cluster import KMeans
        kmeans = KMeans(n_clusters=3, random_state=42, n_init=10)
        kmeans.fit(pixels)
        dominant_colors = kmeans.cluster_centers_.astype(int).tolist()
        
        return {
            'feature_count': int(feature_count),
            'dominant_colors': dominant_colors
        }
    
    def _determine_worthiness(self, motion_score: float, features: Dict, logos_detected: List = None) -> bool:
        """Determine if a scene is worthy based on metrics"""
        # Higher motion or many features indicate interesting content
        motion_threshold = 2.0
        feature_threshold = 10000
        
        # Scene is worthy if it has motion, features, or logos
        has_motion = motion_score > motion_threshold
        has_features = features['feature_count'] > feature_threshold
        has_logos = logos_detected and len(logos_detected) > 0
        
        return has_motion or has_features or has_logos
    
    def _generate_tags(self, motion_score: float, features: Dict, logos_detected: List = None) -> List[str]:
        """Generate descriptive tags for a scene"""
        tags = []
        
        if motion_score > 5.0:
            tags.append("high-motion")
        elif motion_score > 2.0:
            tags.append("moderate-motion")
        else:
            tags.append("static")
        
        if features['feature_count'] > 20000:
            tags.append("complex-scene")
        elif features['feature_count'] > 10000:
            tags.append("detailed")
        else:
            tags.append("simple")
        
        # Add logo-related tags
        if logos_detected:
            tags.append("has-logos")
            for logo in logos_detected:
                tags.append(f"logo:{logo.get('logo_name', 'unknown')}")
        
        return tags
    
    def _analyze_with_nvidia(self, video_path: str, scenes: List[Dict]) -> List[Dict]:
        """Analyze video using NVIDIA AI services"""
        logger.info("Analyzing with NVIDIA AI...")
        # This would integrate with NVIDIA's video understanding APIs
        # Placeholder for NVIDIA integration
        pass


class TAMSClient:
    """Client for interacting with TAMS API"""
    
    def __init__(self, base_url: str):
        self.base_url = base_url
        self.session = requests.Session()
    
    def create_source(self, name: str, video_path: str, metadata: Dict) -> str:
        """Create a new source in TAMS"""
        payload = {
            'name': name,
            'type': 'video',
            'location': f'vast://{video_path}',
            'metadata': metadata
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/sources",
            json=payload
        )
        
        if response.status_code == 200:
            return response.json().get('id')
        else:
            logger.error(f"Failed to create source: {response.text}")
            return None
    
    def create_flow(self, source_id: str, name: str, metadata: Dict) -> str:
        """Create a new flow in TAMS"""
        payload = {
            'source_id': source_id,
            'name': name,
            'type': 'video',
            'metadata': metadata
        }
        
        response = self.session.post(
            f"{self.base_url}/api/v1/flows",
            json=payload
        )
        
        if response.status_code == 200:
            return response.json().get('id')
        else:
            logger.error(f"Failed to create flow: {response.text}")
            return None
    
    def create_segments(self, flow_id: str, segments: List[Dict]) -> bool:
        """Create segments for a flow"""
        success_count = 0
        
        for segment in segments:
            # Include logo information in metadata
            logos_info = []
            if segment.get('logos_detected'):
                logos_info = [{
                    'name': logo['logo_name'],
                    'confidence': logo.get('avg_confidence', 0),
                    'first_seen': logo.get('first_appearance', 0),
                    'last_seen': logo.get('last_appearance', 0),
                    'detection_count': logo.get('detection_count', 0)
                } for logo in segment['logos_detected']]
            
            payload = {
                'flow_id': flow_id,
                'segment_number': segment['scene_number'],
                'start_time': segment['start_time'],
                'end_time': segment['end_time'],
                'metadata': {
                    'duration': segment['duration'],
                    'motion_score': segment.get('motion_score', 0),
                    'is_worthy': segment.get('is_worthy', False),
                    'tags': segment.get('tags', []),
                    'quality_score': segment.get('quality_score', 0),
                    'ai_confidence': segment.get('ai_confidence', 0),
                    'logos_detected': logos_info
                }
            }
            
            # In a real implementation, this would use the proper segment creation endpoint
            response = self.session.post(
                f"{self.base_url}/api/v1/flows/{flow_id}/segments",
                json=payload
            )
            
            if response.status_code == 200:
                success_count += 1
                logger.info(f"Created segment {segment['scene_number']} for flow {flow_id}")
            else:
                logger.error(f"Failed to create segment {segment['scene_number']}: {response.text}")
        
        return success_count == len(segments)


def process_video_batch(video_keys: List[str]) -> Dict:
    """Process a batch of videos"""
    processor = VideoProcessor()
    results = {}
    
    with tempfile.TemporaryDirectory() as temp_dir:
        for video_key in video_keys:
            logger.info(f"Processing video: {video_key}")
            
            # Download video
            local_path = os.path.join(temp_dir, os.path.basename(video_key))
            if not processor.download_video(video_key, local_path):
                results[video_key] = {'status': 'download_failed'}
                continue
            
            # Extract metadata
            metadata = processor.extract_video_metadata(local_path)
            logger.info(f"Video metadata: {metadata}")
            
            # Detect scenes
            scenes = processor.detect_scene_changes(local_path)
            logger.info(f"Detected {len(scenes)} scenes")
            
            # Detect logos in video
            if LOGO_CONFIG['detect_logos']:
                logger.info("Detecting logos in video...")
                logo_detections = processor.detect_logos_in_video(local_path, scenes)
                logger.info(f"Found {len(logo_detections)} frames with logos")
            
            # Extract keyframes
            keyframes = processor.extract_keyframes(local_path, scenes)
            
            # Enhance with AI analysis
            enhanced_scenes = processor.analyze_with_ai(local_path, scenes)
            
            # Filter worthy scenes
            worthy_scenes = [s for s in enhanced_scenes if s.get('is_worthy', False)]
            logger.info(f"Found {len(worthy_scenes)} worthy scenes out of {len(enhanced_scenes)}")
            
            # Count total logos detected
            total_logos = sum(len(scene.get('logos_detected', [])) for scene in enhanced_scenes)
            unique_logos = set()
            for scene in enhanced_scenes:
                for logo in scene.get('logos_detected', []):
                    unique_logos.add(logo.get('logo_name'))
            
            # Create TAMS source
            source_id = processor.tams_client.create_source(
                name=os.path.basename(video_key),
                video_path=video_key,
                metadata={**metadata, 'logos_found': list(unique_logos)}
            )
            
            if source_id:
                # Create TAMS flow
                flow_id = processor.tams_client.create_flow(
                    source_id=source_id,
                    name=f"AI-Processed: {os.path.basename(video_key)}",
                    metadata={
                        'total_scenes': len(scenes),
                        'worthy_scenes': len(worthy_scenes),
                        'processing_timestamp': datetime.now().isoformat(),
                        'video_metadata': metadata,
                        'logos_detected': {
                            'total_detections': total_logos,
                            'unique_logos': list(unique_logos),
                            'logo_count': len(unique_logos)
                        }
                    }
                )
                
                if flow_id:
                    # Create segments in TAMS
                    success = processor.tams_client.create_segments(flow_id, enhanced_scenes)
                    
                    results[video_key] = {
                        'status': 'success',
                        'source_id': source_id,
                        'flow_id': flow_id,
                        'total_scenes': len(scenes),
                        'worthy_scenes': len(worthy_scenes),
                        'segments_created': success,
                        'logos_detected': {
                            'total': total_logos,
                            'unique': list(unique_logos)
                        }
                    }
                else:
                    results[video_key] = {'status': 'flow_creation_failed'}
            else:
                results[video_key] = {'status': 'source_creation_failed'}
    
    return results


def main():
    """Main execution function"""
    # List of videos to process
    video_keys = [
        'nvidia-ai/video1.mp4',
        'nvidia-ai/video2.mp4',
        'nvidia-ai/video3.mp4',
        'nvidia-ai/video4.mp4',
        'nvidia-ai/video5.mp4',
        'nvidia-ai/video6.mp4'
    ]
    
    logger.info("Starting AI video processing pipeline...")
    logger.info(f"Processing {len(video_keys)} videos")
    
    # Process videos
    results = process_video_batch(video_keys)
    
    # Print results summary
    logger.info("\n=== Processing Results ===")
    for video_key, result in results.items():
        logger.info(f"{video_key}: {result}")
    
    # Calculate statistics
    successful = sum(1 for r in results.values() if r.get('status') == 'success')
    total_scenes = sum(r.get('total_scenes', 0) for r in results.values())
    worthy_scenes = sum(r.get('worthy_scenes', 0) for r in results.values())
    
    # Logo statistics
    all_logos = set()
    total_logo_detections = 0
    for result in results.values():
        if result.get('logos_detected'):
            all_logos.update(result['logos_detected']['unique'])
            total_logo_detections += result['logos_detected']['total']
    
    logger.info(f"\n=== Summary ===")
    logger.info(f"Videos processed: {successful}/{len(video_keys)}")
    logger.info(f"Total scenes detected: {total_scenes}")
    logger.info(f"Worthy scenes identified: {worthy_scenes}")
    logger.info(f"Average worthy scenes per video: {worthy_scenes/successful if successful > 0 else 0:.1f}")
    logger.info(f"\n=== Logo Detection Results ===")
    logger.info(f"Total logo detections: {total_logo_detections}")
    logger.info(f"Unique logos found: {', '.join(all_logos) if all_logos else 'None'}")


if __name__ == "__main__":
    # Check dependencies
    try:
        import cv2
        import numpy
        import sklearn
    except ImportError as e:
        logger.error(f"Missing dependency: {e}")
        logger.error("Install with: pip install opencv-python numpy scikit-learn boto3 requests")
        exit(1)
    
    main()