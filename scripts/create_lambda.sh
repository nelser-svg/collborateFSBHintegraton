
#!/bin/bash
# Script to create Lambda function and required resources

set -e

echo "========================================="
echo "Creating Lambda Function and Resources"
echo "========================================="

# Configuration
FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-collaboratemd-salesforce-sync}"
REGION="${AWS_REGION:-us-east-1}"
RUNTIME="python3.11"
HANDLER="lambda_handler.lambda_handler"
MEMORY_SIZE="${LAMBDA_MEMORY_SIZE:-512}"
TIMEOUT="${LAMBDA_TIMEOUT:-900}"
ROLE_NAME="collaboratemd-lambda-role"
DYNAMODB_TABLE="collaboratemd-sync-state"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo "Step 1: Creating IAM Role..."

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

# Create role
ROLE_ARN=$(aws iam create-role \
    --role-name $ROLE_NAME \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    --query 'Role.Arn' \
    --output text 2>/dev/null || \
    aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)

echo -e "${GREEN}Role ARN: $ROLE_ARN${NC}"

# Attach policies
echo "Attaching policies to role..."
aws iam attach-role-policy \
    --role-name $ROLE_NAME \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

# Create custom policy for DynamoDB
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
    --role-name $ROLE_NAME \
    --policy-name DynamoDBAccess \
    --policy-document file:///tmp/dynamodb-policy.json

echo ""
echo "Step 2: Creating DynamoDB Table..."
aws dynamodb create-table \
    --table-name $DYNAMODB_TABLE \
    --attribute-definitions AttributeName=sync_id,AttributeType=S \
    --key-schema AttributeName=sync_id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region $REGION 2>/dev/null || echo "Table already exists"

echo ""
echo "Step 3: Building deployment package..."
./scripts/deploy.sh

echo ""
echo "Step 4: Creating Lambda function..."
# Wait for role to propagate
echo "Waiting for IAM role to propagate..."
sleep 10

aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime $RUNTIME \
    --role $ROLE_ARN \
    --handler $HANDLER \
    --zip-file fileb://lambda-deployment-package.zip \
    --timeout $TIMEOUT \
    --memory-size $MEMORY_SIZE \
    --region $REGION

echo ""
echo "Step 5: Setting environment variables..."
echo -e "${YELLOW}Please update environment variables using AWS Console or CLI${NC}"
echo ""
echo "Example command:"
echo "aws lambda update-function-configuration \\"
echo "  --function-name $FUNCTION_NAME \\"
echo "  --environment Variables='{
      COLLABORATE_MD_USERNAME=your_username,
      COLLABORATE_MD_PASSWORD=your_password,
      COLLABORATE_MD_CUSTOMER=10001001,
      COLLABORATE_MD_REPORT_SEQ=10001234,
      COLLABORATE_MD_FILTER_SEQ=10004321,
      SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com,
      SALESFORCE_USERNAME=your_salesforce_username,
      SALESFORCE_PASSWORD=your_salesforce_password,
      SALESFORCE_SECURITY_TOKEN=your_security_token,
      BATCH_SIZE=200,
      LOG_LEVEL=INFO
    }' \\"
echo "  --region $REGION"

echo ""
echo "========================================="
echo "Setup Complete!"
echo "========================================="
echo ""
echo "Lambda Function: $FUNCTION_NAME"
echo "Region: $REGION"
echo "DynamoDB Table: $DYNAMODB_TABLE"
echo ""
echo "Next steps:"
echo "1. Update environment variables"
echo "2. Test the function"
echo "3. Set up EventBridge/CloudWatch Events for scheduling"
