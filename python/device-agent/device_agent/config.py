#!/usr/bin/env python3
"""
SD-WAN Device Agent Configuration
"""

import os
import yaml
from typing import Dict, Any

def load_config() -> Dict[str, Any]:
    """Load configuration from file or environment variables."""
    
    # Default configuration
    default_config = {
        'site_id': 'site-a',
        'controller_endpoint': 'http://localhost:8080',
        'log_level': 'INFO',
        'metrics_interval': 30,
        'prometheus_port': 9092
    }
    
    # Try to load from config file
    config_file = os.environ.get('CONFIG_FILE', '/app/config/config.yml')
    
    try:
        if os.path.exists(config_file):
            with open(config_file, 'r') as f:
                file_config = yaml.safe_load(f) or {}
                default_config.update(file_config)
    except Exception as e:
        print(f"Warning: Could not load config file {config_file}: {e}")
    
    # Override with environment variables
    if os.environ.get('SITE_ID'):
        default_config['site_id'] = os.environ['SITE_ID']
    
    if os.environ.get('CONTROLLER_ENDPOINT'):
        default_config['controller_endpoint'] = os.environ['CONTROLLER_ENDPOINT']
    
    if os.environ.get('LOG_LEVEL'):
        default_config['log_level'] = os.environ['LOG_LEVEL']
    
    if os.environ.get('METRICS_INTERVAL'):
        try:
            default_config['metrics_interval'] = int(os.environ['METRICS_INTERVAL'])
        except ValueError:
            pass
    
    if os.environ.get('PROMETHEUS_PORT'):
        try:
            default_config['prometheus_port'] = int(os.environ['PROMETHEUS_PORT'])
        except ValueError:
            pass
    
    return default_config
