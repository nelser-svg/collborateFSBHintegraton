#!/bin/bash
# Script to deploy Lambda function with proper environment variables
# This script excludes AWS_REGION as it's automatically provided by Lambda runtime

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=========================================${NC}"
echo -e "${BLUE}  Lambda Deployment Script${NC}"
echo -e "${BLUE}=========================================${NC}"
echo ""

# Configuration
FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-collaboratemd-salesforce-sync}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
ROLE_NAME="CollaborateMD-Lambda-Role"
DYNAMODB_TABLE="collaboratemd-state"

# Check if .env.production exists
if [ ! -f ".env.production" ]; then
    echo -e "${RED}Error: .env.production file not found${NC}"
    exit 1
fi

# Load environment variables
source .env.production

echo -e "${YELLOW}Step 1: Checking if Lambda function exists...${NC}"
if aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION" &> /dev/null; then
    FUNCTION_EXISTS=true
    echo -e "${GREEN}✓ Lambda function exists${NC}"
else
    FUNCTION_EXISTS=false
    echo -e "${YELLOW}! Lambda function does not exist, will create it${NC}"
fi

echo ""
echo -e "${YELLOW}Step 2: Checking IAM Role...${NC}"
ROLE_ARN=$(aws iam get-role --role-name "$ROLE_NAME" --query 'Role.Arn' --output text 2>/dev/null || echo "")

if [ -z "$ROLE_ARN" ]; then
    echo -e "${YELLOW}Creating IAM Role...${NC}"
    
    # Create trust policy
    cat > /tmp/lambda-trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

    ROLE_ARN=$(aws iam create-role \
        --role-name "$ROLE_NAME" \
        --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
        --query 'Role.Arn' \
        --output text)
    
    echo -e "${GREEN}✓ IAM Role created: $ROLE_ARN${NC}"
    
    # Attach policies
    echo -e "${YELLOW}Attaching policies...${NC}"
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    # Create and attach DynamoDB policy
    cat > /tmp/dynamodb-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:CreateTable",
        "dynamodb:DescribeTable"
      ],
      "Resource": "arn:aws:dynamodb:${REGION}:*:table/${DYNAMODB_TABLE}"
    }
  ]
}
EOF

    aws iam put-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-name DynamoDBAccess \
        --policy-document file:///tmp/dynamodb-policy.json
    
    echo -e "${GREEN}✓ Policies attached${NC}"
    
    # Wait for role to propagate
    echo -e "${YELLOW}Waiting for IAM role to propagate (10 seconds)...${NC}"
    sleep 10
else
    echo -e "${GREEN}✓ IAM Role exists: $ROLE_ARN${NC}"
fi

echo ""
echo -e "${YELLOW}Step 3: Checking DynamoDB Table...${NC}"
if aws dynamodb describe-table --table-name "$DYNAMODB_TABLE" --region "$REGION" &> /dev/null; then
    echo -e "${GREEN}✓ DynamoDB table exists${NC}"
else
    echo -e "${YELLOW}Creating DynamoDB table...${NC}"
    aws dynamodb create-table \
        --table-name "$DYNAMODB_TABLE" \
        --attribute-definitions AttributeName=sync_id,AttributeType=S \
        --key-schema AttributeName=sync_id,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region "$REGION"
    
    echo -e "${GREEN}✓ DynamoDB table created${NC}"
fi

echo ""
echo -e "${YELLOW}Step 4: Checking deployment package...${NC}"
if [ ! -f "lambda_deployment.zip" ]; then
    echo -e "${RED}Error: lambda_deployment.zip not found${NC}"
    echo -e "${YELLOW}Please run the package creation script first${NC}"
    exit 1
fi

PACKAGE_SIZE=$(du -h lambda_deployment.zip | cut -f1)
echo -e "${GREEN}✓ Deployment package found (${PACKAGE_SIZE})${NC}"

echo ""
echo -e "${YELLOW}Step 5: Deploying Lambda function...${NC}"

# Build environment variables JSON (EXCLUDING AWS_REGION)
# AWS_REGION is automatically provided by Lambda runtime
cat > /tmp/lambda-env-vars.json <<EOF
{
    "Variables": {
        "COLLABORATEMD_API_BASE_URL": "${COLLABORATEMD_API_BASE_URL}",
        "COLLABORATEMD_USERNAME": "${COLLABORATEMD_USERNAME}",
        "COLLABORATEMD_PASSWORD": "${COLLABORATEMD_PASSWORD}",
        "COLLABORATEMD_REPORT_ID": "${COLLABORATEMD_REPORT_ID}",
        "COLLABORATEMD_FILTER_ID": "${COLLABORATEMD_FILTER_ID}",
        "SALESFORCE_USERNAME": "${SALESFORCE_USERNAME}",
        "SALESFORCE_PASSWORD": "${SALESFORCE_PASSWORD}",
        "SALESFORCE_SECURITY_TOKEN": "${SALESFORCE_SECURITY_TOKEN}",
        "SALESFORCE_DOMAIN": "${SALESFORCE_DOMAIN}",
        "SALESFORCE_API_VERSION": "${SALESFORCE_API_VERSION}",
        "LOG_LEVEL": "${LOG_LEVEL}",
        "DYNAMODB_TABLE_NAME": "${STATE_TABLE_NAME:-collaboratemd-state}",
        "BATCH_SIZE": "${BATCH_SIZE:-100}"
    }
}
EOF

if [ "$FUNCTION_EXISTS" = true ]; then
    echo -e "${YELLOW}Updating existing Lambda function...${NC}"
    
    # Update function code
    aws lambda update-function-code \
        --function-name "$FUNCTION_NAME" \
        --zip-file fileb://lambda_deployment.zip \
        --region "$REGION" \
        > /dev/null
    
    echo -e "${GREEN}✓ Function code updated${NC}"
    
    # Wait a moment for the update to complete
    sleep 3
    
    # Update function configuration
    aws lambda update-function-configuration \
        --function-name "$FUNCTION_NAME" \
        --environment file:///tmp/lambda-env-vars.json \
        --timeout 900 \
        --memory-size 512 \
        --region "$REGION" \
        > /dev/null
    
    echo -e "${GREEN}✓ Function configuration updated${NC}"
else
    echo -e "${YELLOW}Creating new Lambda function...${NC}"
    
    aws lambda create-function \
        --function-name "$FUNCTION_NAME" \
        --runtime python3.11 \
        --role "$ROLE_ARN" \
        --handler lambda_handler.lambda_handler \
        --zip-file fileb://lambda_deployment.zip \
        --timeout 900 \
        --memory-size 512 \
        --environment file:///tmp/lambda-env-vars.json \
        --region "$REGION" \
        > /dev/null
    
    echo -e "${GREEN}✓ Lambda function created${NC}"
fi

echo ""
echo -e "${YELLOW}Step 6: Retrieving function details...${NC}"

# Get function details
FUNCTION_INFO=$(aws lambda get-function --function-name "$FUNCTION_NAME" --region "$REGION")
FUNCTION_ARN=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.FunctionArn')
FUNCTION_SIZE=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.CodeSize')
LAST_MODIFIED=$(echo "$FUNCTION_INFO" | jq -r '.Configuration.LastModified')

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}  Deployment Successful!${NC}"
echo -e "${GREEN}=========================================${NC}"
echo ""
echo -e "${BLUE}Function Details:${NC}"
echo -e "  Name: ${GREEN}${FUNCTION_NAME}${NC}"
echo -e "  ARN: ${GREEN}${FUNCTION_ARN}${NC}"
echo -e "  Region: ${GREEN}${REGION}${NC}"
echo -e "  Runtime: ${GREEN}python3.11${NC}"
echo -e "  Memory: ${GREEN}512 MB${NC}"
echo -e "  Timeout: ${GREEN}900 seconds (15 minutes)${NC}"
echo -e "  Code Size: ${GREEN}${FUNCTION_SIZE} bytes${NC}"
echo -e "  Last Modified: ${GREEN}${LAST_MODIFIED}${NC}"
echo ""
echo -e "${BLUE}Environment Variables Set:${NC}"
echo -e "  ✓ CollaborateMD API credentials"
echo -e "  ✓ Salesforce credentials"
echo -e "  ✓ DynamoDB table name: ${STATE_TABLE_NAME:-collaboratemd-state}"
echo -e "  ✓ Batch size: ${BATCH_SIZE:-100}"
echo -e "  ✓ Log level: ${LOG_LEVEL}"
echo -e "  ${GREEN}✓ AWS_REGION (automatically provided by Lambda runtime)${NC}"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo "  1. Test the function: ./scripts/test_lambda.sh"
echo "  2. Set up EventBridge schedule for periodic execution"
echo "  3. Monitor CloudWatch Logs for execution results"
echo ""
