from setuptools import setup, find_packages

with open("README.md", "r", encoding="utf-8") as fh:
    long_description = fh.read()

setup(
    name="sdwan-device-agent",
    version="0.1.0",
    author="SD-WAN Team",
    author_email="team@sdwan.example.com",
    description="SD-WAN Device Agent for configuration management and telemetry",
    long_description=long_description,
    long_description_content_type="text/markdown",
    url="https://github.com/sdwan/speedfusion-like",
    packages=find_packages(),
    classifiers=[
        "Development Status :: 3 - Alpha",
        "Intended Audience :: System Administrators",
        "License :: OSI Approved :: MIT License",
        "Operating System :: POSIX :: Linux",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
    ],
    python_requires=">=3.8",
    install_requires=[
        "prometheus-client>=0.16.0",
        "requests>=2.28.0",
        "pyyaml>=6.0",
        "psutil>=5.9.0",
        "netifaces>=0.11.0",
        "click>=8.1.0",
        "structlog>=23.0.0",
        "aiohttp>=3.8.0",
        "asyncio-mqtt>=0.11.0",
    ],
    extras_require={
        "dev": [
            "pytest>=7.0.0",
            "pytest-asyncio>=0.21.0",
            "black>=23.0.0",
            "isort>=5.12.0",
            "flake8>=6.0.0",
            "mypy>=1.0.0",
        ],
    },
    entry_points={
        "console_scripts": [
            "sdwan-device-agent=device_agent.main:main",
        ],
    },
) 