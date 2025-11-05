# Deployment Resources

This directory contains all resources needed to deploy the CollaborateMD-Salesforce integration.

## Contents

### CloudFormation Template
- `cloudformation-template.yaml` - AWS infrastructure deployment template

### Environment Configuration
- `.env.example` - Template for environment variables (copy to `.env` and fill in values)

### Deployment Packages
- `packages/salesforce_deploy.zip` - Salesforce Apex classes deployment package
- `packages/lambda_deployment_new.zip` - Lambda function deployment package (with all dependencies)

### Scripts
- See the `scripts/` directory in the root for deployment automation scripts

## Quick Start

### AWS Infrastructure Deployment

1. Configure your AWS credentials:
   ```bash
   aws configure
   ```

2. Deploy using CloudFormation:
   ```bash
   aws cloudformation create-stack \
     --stack-name collaboratemd-salesforce-integration \
     --template-body file://cloudformation-template.yaml \
     --capabilities CAPABILITY_IAM \
     --parameters \
       ParameterKey=CollaborateMDUsername,ParameterValue=YOUR_USERNAME \
       ParameterKey=CollaborateMDPassword,ParameterValue=YOUR_PASSWORD \
       ParameterKey=SalesforceUsername,ParameterValue=YOUR_SF_USERNAME \
       ParameterKey=SalesforcePassword,ParameterValue=YOUR_SF_PASSWORD \
       ParameterKey=SalesforceSecurityToken,ParameterValue=YOUR_SF_TOKEN
   ```

### Salesforce Deployment

1. Install Salesforce CLI:
   ```bash
   npm install -g @salesforce/cli
   ```

2. Authenticate with Salesforce:
   ```bash
   sf org login web --alias myorg
   ```

3. Deploy the Apex classes:
   ```bash
   cd ../salesforce
   sf project deploy start --source-dir force-app
   ```

Or use the deployment package:
```bash
sf project deploy start --zip-file deployment/packages/salesforce_deploy.zip
```

### Lambda Deployment

If not using CloudFormation, you can deploy the Lambda function manually:

```bash
aws lambda update-function-code \
  --function-name CollaborateMD-Salesforce-Integration \
  --zip-file fileb://deployment/packages/lambda_deployment_new.zip
```

## Environment Variables

Copy `.env.example` to `.env` and configure the following:

- `COLLABORATEMD_USERNAME` - CollaborateMD API username
- `COLLABORATEMD_PASSWORD` - CollaborateMD API password
- `SALESFORCE_USERNAME` - Salesforce username
- `SALESFORCE_PASSWORD` - Salesforce password
- `SALESFORCE_SECURITY_TOKEN` - Salesforce security token
- `DYNAMODB_TABLE_NAME` - DynamoDB table name (default: collaboratemd-sync-state)
- `AWS_REGION` - AWS region (default: us-east-1)

## Post-Deployment Steps

1. **Test the Integration**
   ```bash
   cd ../tests
   python test_integration.py
   ```

2. **Configure Salesforce Remote Site Settings**
   - Add your Lambda function URL to Remote Site Settings in Salesforce

3. **Schedule the Batch Job** (if using batch processing)
   - See `docs/BATCH_JOB_EXECUTION_GUIDE.md` for instructions

## Troubleshooting

See the documentation in the `docs/` directory for troubleshooting guides and detailed deployment instructions.
