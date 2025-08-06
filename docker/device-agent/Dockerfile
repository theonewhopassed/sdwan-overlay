FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY python/device-agent/setup.py .
COPY python/device-agent/device_agent ./device_agent

# Install the device agent
RUN pip install -e .

# Copy configuration files
COPY config/device-agent ./config

EXPOSE 9092

CMD ["python", "-m", "device_agent"] 