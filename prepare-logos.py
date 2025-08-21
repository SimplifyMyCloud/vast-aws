#!/usr/bin/env python3
"""
Prepare logo templates for video processing
Downloads or creates logo templates for detection in videos
"""

import os
import cv2
import numpy as np
import urllib.request
from pathlib import Path
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_logo_templates():
    """Create or download logo templates for detection"""
    
    logo_dir = Path('./logo_templates')
    logo_dir.mkdir(exist_ok=True)
    
    # Define logos to create/download
    logos = {
        'nvidia': {
            'text': 'NVIDIA',
            'color': (118, 185, 0),  # NVIDIA green
            'font_scale': 2.0
        },
        'aws': {
            'text': 'AWS',
            'color': (255, 153, 0),  # AWS orange
            'font_scale': 2.5
        },
        'vast': {
            'text': 'VAST DATA',
            'color': (0, 123, 255),  # VAST blue
            'font_scale': 1.8
        },
        'bbc': {
            'text': 'BBC',
            'color': (0, 0, 0),  # BBC black
            'font_scale': 2.5
        },
        'netflix': {
            'text': 'NETFLIX',
            'color': (229, 9, 20),  # Netflix red
            'font_scale': 2.0
        },
        'youtube': {
            'text': 'YouTube',
            'color': (255, 0, 0),  # YouTube red
            'font_scale': 2.0
        },
        'apple': {
            'text': 'Apple',
            'color': (0, 0, 0),  # Apple black
            'font_scale': 2.2
        },
        'google': {
            'text': 'Google',
            'color': (66, 133, 244),  # Google blue
            'font_scale': 2.0
        },
        'microsoft': {
            'text': 'Microsoft',
            'color': (0, 164, 239),  # Microsoft blue
            'font_scale': 1.8
        },
        'meta': {
            'text': 'Meta',
            'color': (0, 119, 181),  # Meta blue
            'font_scale': 2.5
        }
    }
    
    # Create logo images
    for name, config in logos.items():
        logo_path = logo_dir / f"{name}.png"
        
        if logo_path.exists():
            logger.info(f"Logo already exists: {name}")
            continue
        
        # Create logo image
        img = create_text_logo(
            config['text'],
            config['color'],
            config.get('font_scale', 2.0)
        )
        
        # Save logo
        cv2.imwrite(str(logo_path), img)
        logger.info(f"Created logo template: {name}")
    
    # Create some variations for better detection
    create_logo_variations(logo_dir)
    
    logger.info(f"\nLogo templates ready in: {logo_dir}")
    logger.info(f"Total logos: {len(list(logo_dir.glob('*.png')))}")

def create_text_logo(text, color, font_scale=2.0):
    """Create a text-based logo image"""
    # Calculate text size
    font = cv2.FONT_HERSHEY_SIMPLEX
    thickness = 3
    (text_width, text_height), baseline = cv2.getTextSize(
        text, font, font_scale, thickness
    )
    
    # Create image with padding
    padding = 40
    img_width = text_width + 2 * padding
    img_height = text_height + baseline + 2 * padding
    
    # Create white background
    img = np.ones((img_height, img_width, 3), dtype=np.uint8) * 255
    
    # Add text
    text_x = padding
    text_y = img_height - padding - baseline
    cv2.putText(img, text, (text_x, text_y), font, font_scale, color, thickness)
    
    # Add border for better detection
    cv2.rectangle(img, (5, 5), (img_width-5, img_height-5), color, 2)
    
    return img

def create_logo_variations(logo_dir):
    """Create variations of logos for better detection"""
    variations_dir = logo_dir / 'variations'
    variations_dir.mkdir(exist_ok=True)
    
    for logo_file in logo_dir.glob('*.png'):
        if 'variation' in logo_file.stem:
            continue
            
        img = cv2.imread(str(logo_file))
        if img is None:
            continue
        
        base_name = logo_file.stem
        
        # Create grayscale version
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        gray_bgr = cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR)
        gray_path = variations_dir / f"{base_name}_gray.png"
        cv2.imwrite(str(gray_path), gray_bgr)
        
        # Create inverted version
        inverted = cv2.bitwise_not(img)
        inverted_path = variations_dir / f"{base_name}_inverted.png"
        cv2.imwrite(str(inverted_path), inverted)
        
        # Create scaled versions
        for scale in [0.5, 0.75, 1.25, 1.5]:
            width = int(img.shape[1] * scale)
            height = int(img.shape[0] * scale)
            scaled = cv2.resize(img, (width, height))
            scale_path = variations_dir / f"{base_name}_scale{int(scale*100)}.png"
            cv2.imwrite(str(scale_path), scaled)
        
        logger.info(f"Created variations for: {base_name}")

def download_real_logos():
    """Download real logo images from URLs (if available)"""
    # In production, you would download actual logo images
    # For demo, we'll just log this
    logger.info("\nTo improve logo detection accuracy:")
    logger.info("1. Add actual logo PNG/JPG files to ./logo_templates/")
    logger.info("2. Use high-quality logo images with transparent backgrounds")
    logger.info("3. Include multiple sizes and variations")
    logger.info("4. Consider logos at different angles and lighting conditions")

def test_logo_detection():
    """Test logo detection on a sample image"""
    logo_dir = Path('./logo_templates')
    
    # Create a test image with logos
    test_img = np.ones((720, 1280, 3), dtype=np.uint8) * 240  # Light gray background
    
    # Add some logos to the test image
    y_positions = [100, 300, 500]
    x_positions = [100, 400, 700, 1000]
    
    font = cv2.FONT_HERSHEY_SIMPLEX
    test_logos = ['NVIDIA', 'AWS', 'VAST DATA', 'BBC']
    
    for i, (x, logo_text) in enumerate(zip(x_positions, test_logos)):
        y = y_positions[i % len(y_positions)]
        color = [(118, 185, 0), (255, 153, 0), (0, 123, 255), (0, 0, 0)][i]
        cv2.putText(test_img, logo_text, (x, y), font, 1.5, color, 3)
    
    # Save test image
    cv2.imwrite('test_logos.jpg', test_img)
    logger.info("\nCreated test image: test_logos.jpg")
    logger.info("Use this to verify logo detection is working")

if __name__ == "__main__":
    logger.info("Preparing logo templates for video processing...")
    
    # Create logo templates
    create_logo_templates()
    
    # Download real logos (placeholder)
    download_real_logos()
    
    # Create test image
    test_logo_detection()
    
    logger.info("\n✓ Logo preparation complete!")
    logger.info("Run process-videos-ai.py to detect logos in your videos")