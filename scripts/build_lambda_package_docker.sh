#!/bin/bash
# Build Lambda deployment package with Amazon Linux 2 compatible libraries using Docker

set -e

echo "========================================="
echo "Building Lambda Deployment Package"
echo "========================================="

# Clean up previous build
echo "Cleaning up previous build..."
rm -rf lambda_package_new
rm -f lambda_deployment_new.zip

# Create package directory
mkdir -p lambda_package_new

echo ""
echo "Installing dependencies using Docker (Amazon Linux 2)..."

# Use Docker to install dependencies for Amazon Linux 2
docker run --rm -v "$PWD":/var/task \
  -w /var/task \
  public.ecr.aws/lambda/python:3.11 \
  pip install -r requirements.txt -t lambda_package_new/

echo ""
echo "Copying application code..."
cp lambda_handler.py lambda_package_new/
cp -r src lambda_package_new/

echo ""
echo "Creating deployment package..."
cd lambda_package_new
zip -r ../lambda_deployment_new.zip . -q
cd ..

# Replace old package with new one
mv lambda_deployment_new.zip lambda_deployment.zip
rm -rf lambda_package_new

PACKAGE_SIZE=$(du -h lambda_deployment.zip | cut -f1)

echo ""
echo "========================================="
echo "Package built successfully!"
echo "========================================="
echo "Package size: $PACKAGE_SIZE"
echo "Location: lambda_deployment.zip"
echo ""
echo "Next step: Deploy with ./scripts/deploy_lambda.sh"
