
#!/bin/bash
# Deployment script for AWS Lambda

set -e

echo "========================================="
echo "CollaborateMD to Salesforce Middleware"
echo "AWS Lambda Deployment Script"
echo "========================================="

# Configuration
FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-collaboratemd-salesforce-sync}"
REGION="${AWS_REGION:-us-east-1}"
RUNTIME="python3.11"
HANDLER="lambda_handler.lambda_handler"
MEMORY_SIZE="${LAMBDA_MEMORY_SIZE:-512}"
TIMEOUT="${LAMBDA_TIMEOUT:-900}"
PACKAGE_FILE="lambda-deployment-package.zip"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}Error: AWS CLI is not installed${NC}"
    exit 1
fi

echo ""
echo "Step 1: Cleaning up old deployment package..."
rm -rf lambda-package
rm -f $PACKAGE_FILE

echo ""
echo "Step 2: Creating deployment package directory..."
mkdir -p lambda-package

echo ""
echo "Step 3: Installing dependencies..."
pip install -r requirements.txt -t lambda-package/ --upgrade

echo ""
echo "Step 4: Copying source files..."
cp -r src lambda-package/
cp lambda_handler.py lambda-package/

echo ""
echo "Step 5: Creating deployment ZIP..."
cd lambda-package
zip -r ../$PACKAGE_FILE . -x "*.pyc" -x "*__pycache__*"
cd ..

PACKAGE_SIZE=$(du -h $PACKAGE_FILE | cut -f1)
echo -e "${GREEN}Deployment package created: $PACKAGE_FILE ($PACKAGE_SIZE)${NC}"

echo ""
echo "Step 6: Checking if Lambda function exists..."
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION &> /dev/null; then
    echo -e "${YELLOW}Function exists. Updating code...${NC}"
    aws lambda update-function-code \
        --function-name $FUNCTION_NAME \
        --zip-file fileb://$PACKAGE_FILE \
        --region $REGION
    
    echo "Waiting for update to complete..."
    aws lambda wait function-updated \
        --function-name $FUNCTION_NAME \
        --region $REGION
    
    echo -e "${GREEN}Lambda function code updated successfully!${NC}"
else
    echo -e "${YELLOW}Function does not exist. Please create it manually or use scripts/create_lambda.sh${NC}"
    echo ""
    echo "To create the function, you need:"
    echo "  1. IAM Role ARN with Lambda execution permissions"
    echo "  2. VPC configuration (if needed for Salesforce connectivity)"
    echo "  3. Environment variables configured"
    echo ""
    echo "Example create command:"
    echo "aws lambda create-function \\"
    echo "  --function-name $FUNCTION_NAME \\"
    echo "  --runtime $RUNTIME \\"
    echo "  --role YOUR_ROLE_ARN \\"
    echo "  --handler $HANDLER \\"
    echo "  --zip-file fileb://$PACKAGE_FILE \\"
    echo "  --timeout $TIMEOUT \\"
    echo "  --memory-size $MEMORY_SIZE \\"
    echo "  --region $REGION"
fi

echo ""
echo "========================================="
echo "Deployment Complete!"
echo "========================================="
