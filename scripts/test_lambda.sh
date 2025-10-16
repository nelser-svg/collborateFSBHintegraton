
#!/bin/bash
# Script to test Lambda function locally or remotely

set -e

FUNCTION_NAME="${LAMBDA_FUNCTION_NAME:-collaboratemd-salesforce-sync}"
REGION="${AWS_REGION:-us-east-1}"

echo "========================================="
echo "Testing Lambda Function"
echo "========================================="

# Create test payload
cat > /tmp/test-payload.json <<EOF
{
  "full_sync": false
}
EOF

echo ""
echo "Test payload:"
cat /tmp/test-payload.json

echo ""
echo ""
echo "Invoking Lambda function: $FUNCTION_NAME"
echo ""

aws lambda invoke \
    --function-name $FUNCTION_NAME \
    --payload file:///tmp/test-payload.json \
    --region $REGION \
    /tmp/lambda-response.json

echo ""
echo "========================================="
echo "Response:"
echo "========================================="
cat /tmp/lambda-response.json | python3 -m json.tool

echo ""
echo ""
echo "========================================="
echo "CloudWatch Logs:"
echo "========================================="
echo "View logs at:"
echo "https://${REGION}.console.aws.amazon.com/cloudwatch/home?region=${REGION}#logsV2:log-groups/log-group/\$252Faws\$252Flambda\$252F${FUNCTION_NAME}"
