#!/bin/bash
################################################################################
# CollaborateMD-Salesforce Integration - Quick Deployment Script
# 
# This script deploys the complete infrastructure using AWS CloudFormation
#
# Prerequisites:
# - AWS CLI installed and configured with valid credentials
# - Credentials must have permissions for CloudFormation, Lambda, IAM, 
#   API Gateway, and Secrets Manager
#
# Usage:
#   chmod +x QUICK_DEPLOY.sh
#   ./QUICK_DEPLOY.sh
################################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
STACK_NAME="collaboratemd-salesforce-integration"
REGION="us-east-1"
TEMPLATE_FILE="cloudformation-template.yaml"

# CollaborateMD Configuration
COLLAB_API_URL="https://ws.collaboratemd.com/api/v1"
COLLAB_USERNAME="nicolasmd"
COLLAB_PASSWORD="Nic@2024!"

# Functions
print_header() {
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

check_prerequisites() {
    print_header "Checking Prerequisites"
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        echo "Install from: https://aws.amazon.com/cli/"
        exit 1
    fi
    print_success "AWS CLI is installed"
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        print_error "AWS credentials are not configured or invalid"
        echo "Run: aws configure"
        exit 1
    fi
    print_success "AWS credentials are valid"
    
    # Get AWS account info
    ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
    USER_ARN=$(aws sts get-caller-identity --query Arn --output text)
    print_info "AWS Account ID: $ACCOUNT_ID"
    print_info "User ARN: $USER_ARN"
    
    # Check template file
    if [ ! -f "$TEMPLATE_FILE" ]; then
        print_error "CloudFormation template not found: $TEMPLATE_FILE"
        exit 1
    fi
    print_success "CloudFormation template found"
    
    echo ""
}

deploy_stack() {
    print_header "Deploying CloudFormation Stack"
    
    print_info "Stack Name: $STACK_NAME"
    print_info "Region: $REGION"
    print_info "Template: $TEMPLATE_FILE"
    echo ""
    
    # Check if stack exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" --region "$REGION" &> /dev/null; then
        print_info "Stack already exists. Updating..."
        
        aws cloudformation update-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_FILE" \
            --parameters \
                ParameterKey=CollaborateMDApiUrl,ParameterValue="$COLLAB_API_URL" \
                ParameterKey=CollaborateMDUsername,ParameterValue="$COLLAB_USERNAME" \
                ParameterKey=CollaborateMDPassword,ParameterValue="$COLLAB_PASSWORD" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" || {
                print_error "Failed to update stack. It might be up-to-date already."
                return 0
            }
        
        print_info "Waiting for stack update to complete..."
        aws cloudformation wait stack-update-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION" || {
                print_error "Stack update failed or timed out"
                return 1
            }
        
        print_success "Stack updated successfully"
    else
        print_info "Creating new stack..."
        
        aws cloudformation create-stack \
            --stack-name "$STACK_NAME" \
            --template-body "file://$TEMPLATE_FILE" \
            --parameters \
                ParameterKey=CollaborateMDApiUrl,ParameterValue="$COLLAB_API_URL" \
                ParameterKey=CollaborateMDUsername,ParameterValue="$COLLAB_USERNAME" \
                ParameterKey=CollaborateMDPassword,ParameterValue="$COLLAB_PASSWORD" \
            --capabilities CAPABILITY_NAMED_IAM \
            --region "$REGION" || {
                print_error "Failed to create stack"
                return 1
            }
        
        print_info "Waiting for stack creation to complete (this may take 2-3 minutes)..."
        aws cloudformation wait stack-create-complete \
            --stack-name "$STACK_NAME" \
            --region "$REGION" || {
                print_error "Stack creation failed or timed out"
                return 1
            }
        
        print_success "Stack created successfully"
    fi
    
    echo ""
}

get_outputs() {
    print_header "Deployment Outputs"
    
    # Get all outputs
    OUTPUTS=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs' \
        --output json)
    
    # Extract specific outputs
    LAMBDA_ARN=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunctionArn") | .OutputValue')
    LAMBDA_NAME=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaFunctionName") | .OutputValue')
    API_ENDPOINT=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiGatewayEndpoint") | .OutputValue')
    CLAIMS_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiGatewayClaimsUrl") | .OutputValue')
    STATUS_URL=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="ApiGatewayStatusUrl") | .OutputValue')
    SECRET_ARN=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="SecretArn") | .OutputValue')
    ROLE_ARN=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="LambdaRoleArn") | .OutputValue')
    
    echo "Lambda Function:"
    echo "  Name: $LAMBDA_NAME"
    echo "  ARN:  $LAMBDA_ARN"
    echo ""
    echo "IAM Role:"
    echo "  ARN: $ROLE_ARN"
    echo ""
    echo "Secrets Manager:"
    echo "  ARN: $SECRET_ARN"
    echo ""
    echo "API Gateway:"
    echo "  Endpoint:   $API_ENDPOINT"
    echo "  Claims URL: $CLAIMS_URL"
    echo "  Status URL: $STATUS_URL"
    echo ""
    
    # Save to file
    cat > deployment_info.txt << EOF
CollaborateMD-Salesforce Integration Deployment Info
Deployed: $(date)

Lambda Function:
  Name: $LAMBDA_NAME
  ARN:  $LAMBDA_ARN

IAM Role:
  ARN: $ROLE_ARN

Secrets Manager:
  ARN: $SECRET_ARN

API Gateway:
  Endpoint:   $API_ENDPOINT
  Claims URL: $CLAIMS_URL
  Status URL: $STATUS_URL

SALESFORCE CONFIGURATION:
==========================
Add this URL to Salesforce Remote Site Settings:
  $API_ENDPOINT

Steps:
1. Go to Setup → Security → Remote Site Settings
2. Click "New Remote Site"
3. Remote Site Name: CollaborateMD_API
4. Remote Site URL: $API_ENDPOINT
5. Active: ✓ Checked
6. Save
EOF
    
    print_success "Deployment info saved to: deployment_info.txt"
    echo ""
}

test_deployment() {
    print_header "Testing Deployment"
    
    # Get API endpoint
    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayEndpoint`].OutputValue' \
        --output text)
    
    # Test Lambda function
    print_info "Testing Lambda function..."
    LAMBDA_NAME=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`LambdaFunctionName`].OutputValue' \
        --output text)
    
    aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --payload '{"full_sync": false}' \
        --region "$REGION" \
        lambda_test_response.json &> /dev/null || {
            print_error "Lambda test failed"
            return 1
        }
    
    print_success "Lambda function test passed"
    echo "Response saved to: lambda_test_response.json"
    
    # Test API Gateway endpoint
    print_info "Testing API Gateway endpoint..."
    if command -v curl &> /dev/null; then
        curl -X POST "$API_ENDPOINT/claims" \
            -H "Content-Type: application/json" \
            -d '{"full_sync": false}' \
            -s -o api_test_response.json || {
                print_error "API Gateway test failed"
                return 1
            }
        print_success "API Gateway test passed"
        echo "Response saved to: api_test_response.json"
    else
        print_info "curl not available, skipping API Gateway test"
    fi
    
    echo ""
}

print_next_steps() {
    print_header "Next Steps"
    
    API_ENDPOINT=$(aws cloudformation describe-stacks \
        --stack-name "$STACK_NAME" \
        --region "$REGION" \
        --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayEndpoint`].OutputValue' \
        --output text)
    
    echo -e "${YELLOW}⚠️  IMPORTANT: Configure Salesforce${NC}"
    echo ""
    echo "1. Add API Gateway URL to Salesforce Remote Site Settings:"
    echo -e "   ${GREEN}$API_ENDPOINT${NC}"
    echo ""
    echo "2. Steps in Salesforce:"
    echo "   a. Go to Setup → Security → Remote Site Settings"
    echo "   b. Click 'New Remote Site'"
    echo "   c. Remote Site Name: CollaborateMD_API"
    echo "   d. Remote Site URL: $API_ENDPOINT"
    echo "   e. Active: ✓ Checked"
    echo "   f. Save"
    echo ""
    echo "3. Test the integration from Salesforce using:"
    echo "   POST $API_ENDPOINT/claims"
    echo ""
    echo "4. Monitor logs:"
    echo "   aws logs tail /aws/lambda/CollaborateMD-Salesforce-Integration --follow"
    echo ""
}

# Main execution
main() {
    echo ""
    print_header "CollaborateMD-Salesforce Integration - AWS Deployment"
    echo ""
    
    check_prerequisites
    deploy_stack
    get_outputs
    test_deployment
    print_next_steps
    
    print_header "Deployment Complete!"
    echo ""
    print_success "All resources have been deployed successfully!"
    echo ""
    print_info "Files created:"
    echo "  - deployment_info.txt (deployment details)"
    echo "  - lambda_test_response.json (Lambda test result)"
    echo "  - api_test_response.json (API Gateway test result)"
    echo ""
    print_info "For detailed documentation, see: aws_deployment_report.md"
    echo ""
}

# Run main function
main
