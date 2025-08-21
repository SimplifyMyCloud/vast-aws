#!/usr/bin/env python3
"""
Racing Sponsor Logo Detection for VAST-TAMS
Specialized AI processing for detecting sponsor logos on race cars
"""

import cv2
import numpy as np
import boto3
import json
import logging
from typing import List, Dict, Tuple, Optional
from pathlib import Path
import tempfile
import os
from datetime import datetime

logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')
logger = logging.getLogger(__name__)

# Configuration
VAST_CONFIG = {
    'endpoint': 'http://10.0.11.161:9090',
    'access_key': 'RTK1A2B7RVTB77Q9KPL1',
    'secret_key': 'WLlmWYK+pIl2ct1mD5l2r3fCw9FfziKBko0SGxwO',
    'bucket': 'tams-storage'
}

# Racing-specific sponsor logos
RACING_SPONSORS = {
    'primary_sponsors': [
        'shell', 'mobil1', 'castrol', 'petronas', 'gulf',  # Oil/Fuel
        'pirelli', 'michelin', 'bridgestone', 'goodyear',  # Tires
        'redbull', 'monster', 'rockstar', 'cocacola',      # Beverages
        'ferrari', 'mercedes', 'mclaren', 'porsche', 'audi', # Manufacturers
        'rolex', 'tag-heuer', 'richard-mille',              # Watches
        'oracle', 'aws', 'microsoft', 'dell', 'hp',         # Tech
        'fedex', 'ups', 'dhl',                              # Logistics
        'visa', 'mastercard', 'amex', 'santander'           # Financial
    ],
    'detection_config': {
        'confidence_threshold': 0.6,  # Lower threshold for motion blur
        'motion_compensation': True,
        'multi_angle_detection': True,
        'track_persistence': True
    }
}

class RacingLogoDetector:
    """Specialized detector for racing sponsor logos"""
    
    def __init__(self):
        self.templates = self._load_racing_templates()
        self.car_tracker = {}  # Track cars across frames
        self.sponsor_timeline = {}  # Track sponsor visibility over time
        
    def _load_racing_templates(self) -> Dict:
        """Load or create racing sponsor logo templates"""
        templates = {}
        template_dir = Path('./racing_logos')
        template_dir.mkdir(exist_ok=True)
        
        # Create basic templates for demo
        for sponsor in RACING_SPONSORS['primary_sponsors'][:10]:  # Top 10 for demo
            template_path = template_dir / f"{sponsor}.png"
            if not template_path.exists():
                # Create placeholder logo
                img = self._create_sponsor_logo(sponsor)
                cv2.imwrite(str(template_path), img)
            
            template = cv2.imread(str(template_path))
            if template is not None:
                templates[sponsor] = template
                logger.info(f"Loaded racing sponsor: {sponsor}")
        
        return templates
    
    def _create_sponsor_logo(self, sponsor_name: str) -> np.ndarray:
        """Create a placeholder sponsor logo"""
        # Create distinctive logos for major sponsors
        logo_styles = {
            'shell': {'color': (0, 255, 255), 'bg': (255, 0, 0)},  # Yellow on red
            'redbull': {'color': (0, 0, 255), 'bg': (0, 255, 255)},  # Red on yellow
            'ferrari': {'color': (0, 255, 255), 'bg': (0, 0, 255)},  # Yellow on red
            'mercedes': {'color': (192, 192, 192), 'bg': (0, 0, 0)},  # Silver on black
            'petronas': {'color': (0, 255, 0), 'bg': (0, 139, 139)},  # Green on teal
            'pirelli': {'color': (255, 255, 0), 'bg': (0, 0, 0)},  # Yellow on black
            'rolex': {'color': (0, 255, 0), 'bg': (255, 255, 255)},  # Green on white
            'aws': {'color': (255, 153, 0), 'bg': (35, 47, 62)},  # Orange on dark
            'oracle': {'color': (255, 0, 0), 'bg': (255, 255, 255)},  # Red on white
            'monster': {'color': (0, 255, 0), 'bg': (0, 0, 0)}  # Green on black
        }
        
        style = logo_styles.get(sponsor_name, {'color': (0, 0, 0), 'bg': (255, 255, 255)})
        
        # Create logo image
        img = np.ones((80, 200, 3), dtype=np.uint8)
        img[:] = style['bg']
        
        # Add text
        font = cv2.FONT_HERSHEY_SIMPLEX
        text = sponsor_name.upper()
        cv2.putText(img, text, (10, 50), font, 1.2, style['color'], 2)
        
        return img
    
    def detect_cars(self, frame: np.ndarray) -> List[Dict]:
        """Detect race cars in frame using color and motion analysis"""
        cars = []
        
        # Convert to HSV for better color detection
        hsv = cv2.cvtColor(frame, cv2.COLOR_BGR2HSV)
        
        # Define color ranges for common racing car colors
        car_colors = [
            {'name': 'red', 'lower': np.array([0, 50, 50]), 'upper': np.array([10, 255, 255])},
            {'name': 'blue', 'lower': np.array([100, 50, 50]), 'upper': np.array([130, 255, 255])},
            {'name': 'green', 'lower': np.array([40, 50, 50]), 'upper': np.array([80, 255, 255])},
            {'name': 'yellow', 'lower': np.array([20, 50, 50]), 'upper': np.array([40, 255, 255])},
            {'name': 'white', 'lower': np.array([0, 0, 200]), 'upper': np.array([180, 30, 255])},
            {'name': 'black', 'lower': np.array([0, 0, 0]), 'upper': np.array([180, 255, 30])}
        ]
        
        for color_info in car_colors:
            # Create mask for this color
            mask = cv2.inRange(hsv, color_info['lower'], color_info['upper'])
            
            # Find contours
            contours, _ = cv2.findContours(mask, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            
            for contour in contours:
                area = cv2.contourArea(contour)
                if area > 5000:  # Minimum area for a car
                    x, y, w, h = cv2.boundingRect(contour)
                    
                    # Filter by aspect ratio (cars are typically longer than tall)
                    aspect_ratio = w / h
                    if 1.5 < aspect_ratio < 4.0:
                        cars.append({
                            'bbox': (x, y, w, h),
                            'color': color_info['name'],
                            'area': area,
                            'confidence': min(area / 50000, 1.0)  # Normalize confidence
                        })
        
        return cars
    
    def detect_sponsors_on_car(self, frame: np.ndarray, car_bbox: Tuple[int, int, int, int]) -> List[Dict]:
        """Detect sponsor logos on a specific car"""
        x, y, w, h = car_bbox
        
        # Extract car region with padding
        padding = 20
        x1 = max(0, x - padding)
        y1 = max(0, y - padding)
        x2 = min(frame.shape[1], x + w + padding)
        y2 = min(frame.shape[0], y + h + padding)
        
        car_region = frame[y1:y2, x1:x2]
        
        detected_sponsors = []
        
        # Apply preprocessing to handle motion blur
        if RACING_SPONSORS['detection_config']['motion_compensation']:
            car_region = self._compensate_motion_blur(car_region)
        
        # Detect sponsors at multiple scales and angles
        for sponsor_name, template in self.templates.items():
            best_match = self._detect_logo_robust(car_region, template, sponsor_name)
            
            if best_match and best_match['confidence'] >= RACING_SPONSORS['detection_config']['confidence_threshold']:
                # Adjust coordinates to frame space
                best_match['position']['x'] += x1
                best_match['position']['y'] += y1
                detected_sponsors.append(best_match)
        
        return detected_sponsors
    
    def _compensate_motion_blur(self, image: np.ndarray) -> np.ndarray:
        """Compensate for motion blur in fast-moving cars"""
        # Apply sharpening kernel
        kernel = np.array([[-1,-1,-1],
                          [-1, 9,-1],
                          [-1,-1,-1]])
        sharpened = cv2.filter2D(image, -1, kernel)
        
        # Denoise
        denoised = cv2.fastNlMeansDenoisingColored(sharpened, None, 10, 10, 7, 21)
        
        return denoised
    
    def _detect_logo_robust(self, image: np.ndarray, template: np.ndarray, logo_name: str) -> Optional[Dict]:
        """Robust logo detection with rotation and scale invariance"""
        best_match = None
        max_confidence = 0
        
        # Convert to grayscale
        gray_img = cv2.cvtColor(image, cv2.COLOR_BGR2GRAY)
        gray_template = cv2.cvtColor(template, cv2.COLOR_BGR2GRAY)
        
        # Try multiple scales
        scales = [0.3, 0.5, 0.7, 0.9, 1.0, 1.2]
        
        # Try multiple angles (cars can be at various angles)
        angles = [0, -15, 15, -30, 30] if RACING_SPONSORS['detection_config']['multi_angle_detection'] else [0]
        
        for scale in scales:
            # Resize template
            width = int(template.shape[1] * scale)
            height = int(template.shape[0] * scale)
            if width < 10 or height < 10:
                continue
            resized = cv2.resize(gray_template, (width, height))
            
            for angle in angles:
                # Rotate template
                if angle != 0:
                    center = (width // 2, height // 2)
                    M = cv2.getRotationMatrix2D(center, angle, 1.0)
                    rotated = cv2.warpAffine(resized, M, (width, height))
                else:
                    rotated = resized
                
                # Skip if template is larger than image
                if rotated.shape[0] > gray_img.shape[0] or rotated.shape[1] > gray_img.shape[1]:
                    continue
                
                # Template matching
                result = cv2.matchTemplate(gray_img, rotated, cv2.TM_CCOEFF_NORMED)
                min_val, max_val, min_loc, max_loc = cv2.minMaxLoc(result)
                
                if max_val > max_confidence:
                    max_confidence = max_val
                    best_match = {
                        'logo_name': logo_name,
                        'confidence': float(max_val),
                        'position': {
                            'x': int(max_loc[0]),
                            'y': int(max_loc[1]),
                            'width': width,
                            'height': height
                        },
                        'scale': scale,
                        'angle': angle
                    }
        
        return best_match
    
    def track_sponsors_in_video(self, video_path: str) -> Dict:
        """Track sponsor visibility throughout the race video"""
        cap = cv2.VideoCapture(video_path)
        fps = cap.get(cv2.CAP_PROP_FPS)
        frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
        
        results = {
            'total_frames': frame_count,
            'fps': fps,
            'sponsors_timeline': [],
            'sponsor_summary': {},
            'car_tracking': []
        }
        
        frame_idx = 0
        sample_rate = 5  # Process every 5th frame for speed
        
        while True:
            ret, frame = cap.read()
            if not ret:
                break
            
            if frame_idx % sample_rate == 0:
                timestamp = frame_idx / fps
                
                # Detect cars
                cars = self.detect_cars(frame)
                
                frame_sponsors = []
                for car in cars:
                    # Detect sponsors on each car
                    sponsors = self.detect_sponsors_on_car(frame, car['bbox'])
                    
                    for sponsor in sponsors:
                        sponsor_data = {
                            'timestamp': timestamp,
                            'frame': frame_idx,
                            'car_color': car['color'],
                            'sponsor': sponsor['logo_name'],
                            'confidence': sponsor['confidence'],
                            'position': sponsor['position']
                        }
                        frame_sponsors.append(sponsor_data)
                        
                        # Update summary
                        if sponsor['logo_name'] not in results['sponsor_summary']:
                            results['sponsor_summary'][sponsor['logo_name']] = {
                                'first_seen': timestamp,
                                'last_seen': timestamp,
                                'total_detections': 0,
                                'avg_confidence': 0,
                                'screen_time': 0,
                                'car_associations': set()
                            }
                        
                        summary = results['sponsor_summary'][sponsor['logo_name']]
                        summary['last_seen'] = timestamp
                        summary['total_detections'] += 1
                        summary['avg_confidence'] = (
                            (summary['avg_confidence'] * (summary['total_detections'] - 1) + 
                             sponsor['confidence']) / summary['total_detections']
                        )
                        summary['car_associations'].add(car['color'])
                
                if frame_sponsors:
                    results['sponsors_timeline'].append({
                        'timestamp': timestamp,
                        'frame': frame_idx,
                        'sponsors': frame_sponsors
                    })
                
                # Log progress
                if frame_idx % (sample_rate * 30) == 0:  # Every second at 30fps
                    logger.info(f"Processing: {frame_idx}/{frame_count} frames, "
                               f"Found {len(results['sponsor_summary'])} unique sponsors")
            
            frame_idx += 1
        
        cap.release()
        
        # Calculate screen time for each sponsor
        for sponsor_name, summary in results['sponsor_summary'].items():
            summary['screen_time'] = summary['last_seen'] - summary['first_seen']
            summary['car_associations'] = list(summary['car_associations'])
        
        return results


class RacingTAMSHydrator:
    """Hydrate TAMS with racing-specific segment data"""
    
    def __init__(self, tams_url: str):
        self.tams_url = tams_url
        
    def create_racing_segments(self, flow_id: str, sponsor_data: Dict) -> bool:
        """Create TAMS segments with sponsor visibility data"""
        import requests
        
        # Group timeline into segments (e.g., 10-second chunks)
        segment_duration = 10.0  # seconds
        segments = []
        
        current_segment = {
            'start_time': 0,
            'end_time': segment_duration,
            'sponsors': {},
            'dominant_sponsors': []
        }
        
        for timeline_entry in sponsor_data['sponsors_timeline']:
            timestamp = timeline_entry['timestamp']
            
            # Check if we need a new segment
            if timestamp > current_segment['end_time']:
                # Finalize current segment
                if current_segment['sponsors']:
                    segments.append(current_segment)
                
                # Start new segment
                current_segment = {
                    'start_time': current_segment['end_time'],
                    'end_time': current_segment['end_time'] + segment_duration,
                    'sponsors': {},
                    'dominant_sponsors': []
                }
            
            # Add sponsors to current segment
            for sponsor_detection in timeline_entry['sponsors']:
                sponsor_name = sponsor_detection['sponsor']
                if sponsor_name not in current_segment['sponsors']:
                    current_segment['sponsors'][sponsor_name] = {
                        'count': 0,
                        'avg_confidence': 0,
                        'cars': set()
                    }
                
                current_segment['sponsors'][sponsor_name]['count'] += 1
                current_segment['sponsors'][sponsor_name]['cars'].add(
                    sponsor_detection['car_color']
                )
        
        # Add final segment
        if current_segment['sponsors']:
            segments.append(current_segment)
        
        # Create TAMS segments
        success_count = 0
        for idx, segment in enumerate(segments):
            # Determine dominant sponsors
            sorted_sponsors = sorted(
                segment['sponsors'].items(),
                key=lambda x: x[1]['count'],
                reverse=True
            )
            dominant_sponsors = [s[0] for s in sorted_sponsors[:3]]  # Top 3
            
            # Prepare metadata
            metadata = {
                'segment_type': 'racing',
                'sponsors_visible': list(segment['sponsors'].keys()),
                'dominant_sponsors': dominant_sponsors,
                'sponsor_details': {
                    name: {
                        'appearances': data['count'],
                        'cars': list(data['cars'])
                    }
                    for name, data in segment['sponsors'].items()
                },
                'is_worthy': len(segment['sponsors']) > 0,
                'tags': ['racing', 'sponsors'] + [f'sponsor:{s}' for s in dominant_sponsors]
            }
            
            # Create segment via TAMS API
            payload = {
                'flow_id': flow_id,
                'segment_number': idx + 1,
                'start_time': segment['start_time'],
                'end_time': segment['end_time'],
                'metadata': metadata
            }
            
            try:
                response = requests.post(
                    f"{self.tams_url}/api/v1/flows/{flow_id}/segments",
                    json=payload
                )
                if response.status_code == 200:
                    success_count += 1
                    logger.info(f"Created racing segment {idx + 1} with "
                               f"{len(segment['sponsors'])} sponsors")
            except Exception as e:
                logger.error(f"Failed to create segment {idx + 1}: {e}")
        
        return success_count == len(segments)


def process_racing_video(video_path: str, output_dir: str = './racing_results') -> Dict:
    """Main function to process racing video for sponsor detection"""
    
    logger.info(f"Processing racing video: {video_path}")
    
    # Initialize detector
    detector = RacingLogoDetector()
    
    # Process video
    logger.info("Detecting sponsors on race cars...")
    results = detector.track_sponsors_in_video(video_path)
    
    # Generate report
    Path(output_dir).mkdir(exist_ok=True)
    report_path = Path(output_dir) / f"sponsor_report_{datetime.now().strftime('%Y%m%d_%H%M%S')}.json"
    
    # Prepare summary
    summary = {
        'video': os.path.basename(video_path),
        'processing_time': datetime.now().isoformat(),
        'total_frames': results['total_frames'],
        'frames_analyzed': len(results['sponsors_timeline']),
        'unique_sponsors_detected': len(results['sponsor_summary']),
        'sponsor_rankings': []
    }
    
    # Rank sponsors by screen time
    for sponsor, data in sorted(
        results['sponsor_summary'].items(),
        key=lambda x: x[1]['screen_time'],
        reverse=True
    ):
        summary['sponsor_rankings'].append({
            'rank': len(summary['sponsor_rankings']) + 1,
            'sponsor': sponsor,
            'screen_time_seconds': round(data['screen_time'], 2),
            'detections': data['total_detections'],
            'confidence': round(data['avg_confidence'], 3),
            'associated_cars': data['car_associations']
        })
    
    # Save detailed results
    with open(report_path, 'w') as f:
        json.dump({
            'summary': summary,
            'detailed_results': results
        }, f, indent=2)
    
    # Print summary
    logger.info("\n" + "="*60)
    logger.info("SPONSOR DETECTION SUMMARY")
    logger.info("="*60)
    logger.info(f"Video: {os.path.basename(video_path)}")
    logger.info(f"Unique sponsors detected: {len(results['sponsor_summary'])}")
    logger.info("\nTop Sponsors by Screen Time:")
    logger.info("-"*40)
    
    for sponsor in summary['sponsor_rankings'][:10]:
        logger.info(f"  #{sponsor['rank']:2d} {sponsor['sponsor']:15s} - "
                   f"{sponsor['screen_time_seconds']:6.1f}s "
                   f"({sponsor['detections']} detections, "
                   f"{sponsor['confidence']:.1%} confidence)")
    
    logger.info("\nReport saved to: " + str(report_path))
    
    return results


def main():
    """Process racing videos for sponsor detection"""
    
    # Example racing video paths
    racing_videos = [
        'nvidia-ai/race1.mp4',
        'nvidia-ai/race2.mp4',
        'nvidia-ai/race3.mp4'
    ]
    
    # Download from VAST if needed
    s3_client = boto3.client(
        's3',
        endpoint_url=VAST_CONFIG['endpoint'],
        aws_access_key_id=VAST_CONFIG['access_key'],
        aws_secret_access_key=VAST_CONFIG['secret_key'],
        verify=False
    )
    
    with tempfile.TemporaryDirectory() as temp_dir:
        for video_key in racing_videos:
            local_path = os.path.join(temp_dir, os.path.basename(video_key))
            
            try:
                # Download video
                logger.info(f"Downloading {video_key} from VAST...")
                s3_client.download_file(VAST_CONFIG['bucket'], video_key, local_path)
                
                # Process for sponsors
                results = process_racing_video(local_path)
                
                # Hydrate TAMS
                hydrator = RacingTAMSHydrator('http://34.216.9.25:8000')
                # Create flow and segments (would need proper flow creation first)
                
            except Exception as e:
                logger.error(f"Failed to process {video_key}: {e}")
    
    logger.info("\n✓ Racing sponsor detection complete!")


if __name__ == "__main__":
    main()