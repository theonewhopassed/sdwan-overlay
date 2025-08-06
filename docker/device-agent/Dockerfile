FROM python:3.9-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy the entire device agent directory
COPY python/device-agent ./device-agent

# Install the device agent
WORKDIR /app/device-agent
RUN pip install -e .

# Copy configuration files
COPY config/device-agent /app/config

EXPOSE 9092

CMD ["python", "-m", "device_agent"] 