#!/usr/bin/env python3
"""
SD-WAN Device Agent - Main Entry Point
"""

import sys
import logging
from device_agent.agent import DeviceAgent
from device_agent.config import load_config

def main():
    """Main entry point for the device agent."""
    try:
        # Load configuration
        config = load_config()
        
        # Setup logging
        logging.basicConfig(
            level=getattr(logging, config.get('log_level', 'INFO').upper()),
            format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        
        # Create and start the device agent
        agent = DeviceAgent(config)
        agent.start()
        
    except KeyboardInterrupt:
        logging.info("Device agent stopped by user")
        sys.exit(0)
    except Exception as e:
        logging.error(f"Device agent failed: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()
