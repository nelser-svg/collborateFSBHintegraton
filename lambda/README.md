# Lambda Middleware Function

This directory contains the AWS Lambda function that serves as middleware between CollaborateMD and Salesforce.

## Structure

- `lambda_handler.py` - Main Lambda handler function
- `requirements.txt` - Python dependencies
- `src/` - Source code modules
  - `collaboratemd_client.py` - CollaborateMD API client
  - `salesforce_client.py` - Salesforce API client
  - `data_transformer.py` - Data transformation logic
  - `state_manager.py` - DynamoDB state management
  - `logger.py` - Logging utilities
  - `config.py` - Configuration management
  - `utils.py` - Utility functions

## Deployment

To deploy the Lambda function:

1. Build the deployment package (includes dependencies):
   ```bash
   cd /home/ubuntu/collaboratemd-salesforce-middleware
   ./scripts/build_lambda_package_docker.sh
   ```

2. Deploy to AWS:
   ```bash
   ./scripts/deploy_lambda.sh
   ```

Or use the CloudFormation template in the root directory for complete infrastructure deployment.

## Environment Variables

The Lambda function requires the following environment variables:

- `COLLABORATEMD_USERNAME` - CollaborateMD API username
- `COLLABORATEMD_PASSWORD` - CollaborateMD API password
- `SALESFORCE_USERNAME` - Salesforce username
- `SALESFORCE_PASSWORD` - Salesforce password
- `SALESFORCE_SECURITY_TOKEN` - Salesforce security token
- `DYNAMODB_TABLE_NAME` - DynamoDB table for state management
- `AWS_REGION` - AWS region (default: us-east-1)

## Testing

See the `tests/` directory for API test scripts.
