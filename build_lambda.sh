#!/bin/bash
set -e

# Install dependencies
pip install -r requirements.txt -t /package/ --upgrade

# Copy source code
cp -r /src/* /package/
cp /lambda_handler.py /package/

# Create zip file
cd /package
zip -r /output/lambda_deployment_compatible.zip . -q
