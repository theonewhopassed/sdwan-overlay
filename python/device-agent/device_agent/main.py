#!/usr/bin/env python3
"""
SD-WAN Device Agent

Manages device configuration, telemetry collection, and communication with the controller.
"""

import asyncio
import os
import signal
import sys
from pathlib import Path
from typing import Optional

import click
import structlog
from prometheus_client import start_http_server

from device_agent.config import Config
from device_agent.controller import ControllerClient
from device_agent.telemetry import TelemetryCollector
from device_agent.watcher import ConfigWatcher


@click.command()
@click.option("--config", default="config/device-agent.yml", help="Configuration file path")
@click.option("--controller", default="http://localhost:8080", help="Controller endpoint")
@click.option("--site-id", default="site-a", help="Site identifier")
@click.option("--log-level", default="info", help="Log level")
@click.option("--metrics-port", default=9092, help="Prometheus metrics port")
def main(
    config: str,
    controller: str,
    site_id: str,
    log_level: str,
    metrics_port: int,
) -> None:
    """SD-WAN Device Agent"""
    
    # Setup logging
    structlog.configure(
        processors=[
            structlog.stdlib.filter_by_level,
            structlog.stdlib.add_logger_name,
            structlog.stdlib.add_log_level,
            structlog.stdlib.PositionalArgumentsFormatter(),
            structlog.processors.TimeStamper(fmt="iso"),
            structlog.processors.StackInfoRenderer(),
            structlog.processors.format_exc_info,
            structlog.processors.UnicodeDecoder(),
            structlog.processors.JSONRenderer()
        ],
        wrapper_class=structlog.stdlib.BoundLogger,
        logger_factory=structlog.stdlib.LoggerFactory(),
        cache_logger_on_first_use=True,
    )
    
    logger = structlog.get_logger()
    logger.setLevel(getattr(structlog.stdlib.LogLevel, log_level.upper()))
    
    logger.info("Starting SD-WAN Device Agent", 
                config=config, controller=controller, site_id=site_id)
    
    # Load configuration
    try:
        cfg = Config.from_file(config)
    except Exception as e:
        logger.error("Failed to load configuration", error=str(e))
        sys.exit(1)
    
    # Start metrics server
    start_http_server(metrics_port)
    logger.info("Started Prometheus metrics server", port=metrics_port)
    
    # Run the agent
    try:
        asyncio.run(run_agent(cfg, controller, site_id, logger))
    except KeyboardInterrupt:
        logger.info("Received interrupt signal, shutting down")
    except Exception as e:
        logger.error("Agent error", error=str(e))
        sys.exit(1)


async def run_agent(
    config: Config,
    controller_url: str,
    site_id: str,
    logger: structlog.BoundLogger,
) -> None:
    """Run the device agent"""
    
    # Initialize components
    controller_client = ControllerClient(controller_url, site_id)
    telemetry_collector = TelemetryCollector(config)
    config_watcher = ConfigWatcher(config.config_dir)
    
    # Start background tasks
    tasks = [
        asyncio.create_task(controller_client.run()),
        asyncio.create_task(telemetry_collector.run()),
        asyncio.create_task(config_watcher.run()),
    ]
    
    # Setup signal handlers
    loop = asyncio.get_event_loop()
    for sig in (signal.SIGTERM, signal.SIGINT):
        loop.add_signal_handler(sig, lambda: asyncio.create_task(shutdown(tasks, logger)))
    
    try:
        # Wait for all tasks
        await asyncio.gather(*tasks)
    except asyncio.CancelledError:
        logger.info("Tasks cancelled")
    finally:
        await shutdown(tasks, logger)


async def shutdown(tasks: list, logger: structlog.BoundLogger) -> None:
    """Gracefully shutdown the agent"""
    logger.info("Shutting down agent")
    
    # Cancel all tasks
    for task in tasks:
        task.cancel()
    
    # Wait for tasks to complete
    await asyncio.gather(*tasks, return_exceptions=True)
    logger.info("Agent shutdown complete")


if __name__ == "__main__":
    main() 