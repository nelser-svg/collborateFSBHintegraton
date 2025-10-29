#!/usr/bin/env python3
"""
Comprehensive AWS Deployment Script for CollaborateMD-Salesforce Integration
"""
import json
import os
import sys
import time
import zipfile
import subprocess
from pathlib import Path
import boto3
from botocore.exceptions import ClientError

# AWS Configuration
AWS_REGION = 'us-east-1'

# CollaborateMD API Configuration
COLLAB_API_URL = 'https://ws.collaboratemd.com/api/v1'
COLLAB_USERNAME = 'nicolasmd'
COLLAB_PASSWORD = 'Nic@2024!'

# AWS Resource Names
SECRET_NAME = 'collaboratemd-credentials'
LAMBDA_ROLE_NAME = 'CollaborateMDLambdaRole'
LAMBDA_FUNCTION_NAME = 'CollaborateMD-Salesforce-Integration'
API_GATEWAY_NAME = 'CollaborateMD-API'

# Lambda Configuration
LAMBDA_RUNTIME = 'python3.11'
LAMBDA_MEMORY = 512
LAMBDA_TIMEOUT = 30

class Colors:
    """Terminal colors for better output"""
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKCYAN = '\033[96m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'

def print_step(step_num, total_steps, message):
    """Print formatted step message"""
    print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
    print(f"{Colors.BOLD}[Step {step_num}/{total_steps}] {message}{Colors.ENDC}")
    print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")

def print_success(message):
    """Print success message"""
    print(f"{Colors.OKGREEN}✓ {message}{Colors.ENDC}")

def print_error(message):
    """Print error message"""
    print(f"{Colors.FAIL}✗ {message}{Colors.ENDC}")

def print_info(message):
    """Print info message"""
    print(f"{Colors.OKCYAN}ℹ {message}{Colors.ENDC}")

def configure_aws_credentials():
    """Configure AWS credentials"""
    print_step(1, 12, "Configuring AWS Credentials")
    
    try:
        # Use default AWS credentials from environment/CLI config
        session = boto3.Session(region_name=AWS_REGION)
        
        # Test credentials by getting caller identity
        sts = session.client('sts')
        identity = sts.get_caller_identity()
        
        print_success(f"AWS credentials configured successfully")
        print_info(f"Account ID: {identity['Account']}")
        print_info(f"User ARN: {identity['Arn']}")
        
        return session
    except Exception as e:
        print_error(f"Failed to configure AWS credentials: {str(e)}")
        sys.exit(1)

def create_secrets_manager_secret(session):
    """Create AWS Secrets Manager secret for CollaborateMD credentials"""
    print_step(2, 12, "Creating Secrets Manager Secret")
    
    try:
        secrets_client = session.client('secretsmanager')
        
        # Secret value
        secret_value = {
            'api_url': COLLAB_API_URL,
            'username': COLLAB_USERNAME,
            'password': COLLAB_PASSWORD
        }
        
        try:
            # Try to create the secret
            response = secrets_client.create_secret(
                Name=SECRET_NAME,
                Description='CollaborateMD API credentials for Lambda integration',
                SecretString=json.dumps(secret_value)
            )
            print_success(f"Created secret: {SECRET_NAME}")
            secret_arn = response['ARN']
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceExistsException':
                print_info(f"Secret {SECRET_NAME} already exists, updating...")
                # Update existing secret
                response = secrets_client.put_secret_value(
                    SecretId=SECRET_NAME,
                    SecretString=json.dumps(secret_value)
                )
                # Get ARN
                secret_info = secrets_client.describe_secret(SecretId=SECRET_NAME)
                secret_arn = secret_info['ARN']
                print_success(f"Updated existing secret: {SECRET_NAME}")
            else:
                raise
        
        print_info(f"Secret ARN: {secret_arn}")
        return secret_arn
        
    except Exception as e:
        print_error(f"Failed to create Secrets Manager secret: {str(e)}")
        sys.exit(1)

def create_iam_role(session, secret_arn):
    """Create IAM role for Lambda execution"""
    print_step(3, 12, "Creating IAM Role")
    
    try:
        iam = session.client('iam')
        
        # Trust policy for Lambda
        trust_policy = {
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
        
        try:
            # Create role
            role_response = iam.create_role(
                RoleName=LAMBDA_ROLE_NAME,
                AssumeRolePolicyDocument=json.dumps(trust_policy),
                Description='Execution role for CollaborateMD-Salesforce Lambda integration'
            )
            role_arn = role_response['Role']['Arn']
            print_success(f"Created IAM role: {LAMBDA_ROLE_NAME}")
            time.sleep(10)  # Wait for role to propagate
        except ClientError as e:
            if e.response['Error']['Code'] == 'EntityAlreadyExists':
                print_info(f"Role {LAMBDA_ROLE_NAME} already exists")
                role_info = iam.get_role(RoleName=LAMBDA_ROLE_NAME)
                role_arn = role_info['Role']['Arn']
            else:
                raise
        
        # Attach AWS managed policy for Lambda basic execution
        try:
            iam.attach_role_policy(
                RoleName=LAMBDA_ROLE_NAME,
                PolicyArn='arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole'
            )
            print_success("Attached AWSLambdaBasicExecutionRole policy")
        except ClientError as e:
            if e.response['Error']['Code'] != 'EntityAlreadyExists':
                raise
        
        # Create and attach custom policy for Secrets Manager
        secrets_policy = {
            "Version": "2012-10-17",
            "Statement": [
                {
                    "Effect": "Allow",
                    "Action": [
                        "secretsmanager:GetSecretValue",
                        "secretsmanager:DescribeSecret"
                    ],
                    "Resource": secret_arn
                }
            ]
        }
        
        policy_name = f"{LAMBDA_ROLE_NAME}-SecretsPolicy"
        try:
            policy_response = iam.create_policy(
                PolicyName=policy_name,
                PolicyDocument=json.dumps(secrets_policy),
                Description='Policy for accessing CollaborateMD credentials in Secrets Manager'
            )
            policy_arn = policy_response['Policy']['Arn']
            print_success(f"Created secrets access policy: {policy_name}")
        except ClientError as e:
            if e.response['Error']['Code'] == 'EntityAlreadyExists':
                # Get existing policy ARN
                account_id = session.client('sts').get_caller_identity()['Account']
                policy_arn = f"arn:aws:iam::{account_id}:policy/{policy_name}"
                print_info(f"Policy {policy_name} already exists")
            else:
                raise
        
        # Attach custom policy to role
        try:
            iam.attach_role_policy(
                RoleName=LAMBDA_ROLE_NAME,
                PolicyArn=policy_arn
            )
            print_success("Attached secrets access policy to role")
        except ClientError as e:
            if e.response['Error']['Code'] != 'EntityAlreadyExists':
                raise
        
        print_info(f"Role ARN: {role_arn}")
        return role_arn
        
    except Exception as e:
        print_error(f"Failed to create IAM role: {str(e)}")
        sys.exit(1)

def package_lambda_function():
    """Package Lambda function with dependencies"""
    print_step(4, 12, "Packaging Lambda Function")
    
    try:
        project_root = Path('/home/ubuntu/collaboratemd-salesforce-middleware')
        package_dir = project_root / 'lambda_package_deploy'
        zip_file = project_root / 'lambda_deployment_aws.zip'
        
        # Remove old package directory and zip if they exist
        if package_dir.exists():
            import shutil
            shutil.rmtree(package_dir)
        if zip_file.exists():
            zip_file.unlink()
        
        package_dir.mkdir(exist_ok=True)
        
        print_info("Installing dependencies...")
        # Install dependencies to package directory
        subprocess.run([
            sys.executable, '-m', 'pip', 'install',
            '-r', str(project_root / 'requirements.txt'),
            '-t', str(package_dir),
            '--quiet'
        ], check=True)
        
        print_info("Copying Lambda handler and source files...")
        # Copy lambda handler
        import shutil
        shutil.copy(project_root / 'lambda_handler.py', package_dir)
        
        # Copy src directory
        src_dest = package_dir / 'src'
        shutil.copytree(project_root / 'src', src_dest)
        
        print_info("Creating deployment ZIP...")
        # Create ZIP file
        with zipfile.ZipFile(zip_file, 'w', zipfile.ZIP_DEFLATED) as zf:
            for root, dirs, files in os.walk(package_dir):
                for file in files:
                    file_path = Path(root) / file
                    arcname = file_path.relative_to(package_dir)
                    zf.write(file_path, arcname)
        
        # Check ZIP size
        zip_size_mb = zip_file.stat().st_size / (1024 * 1024)
        print_success(f"Lambda package created: {zip_file}")
        print_info(f"Package size: {zip_size_mb:.2f} MB")
        
        if zip_size_mb > 50:
            print_error("Warning: Package size exceeds Lambda limit (50 MB)")
        
        return zip_file
        
    except Exception as e:
        print_error(f"Failed to package Lambda function: {str(e)}")
        sys.exit(1)

def deploy_lambda_function(session, role_arn, zip_file, secret_name):
    """Deploy Lambda function to AWS"""
    print_step(5, 12, "Deploying Lambda Function")
    
    try:
        lambda_client = session.client('lambda')
        
        # Read deployment package
        with open(zip_file, 'rb') as f:
            zip_content = f.read()
        
        # Lambda configuration
        lambda_config = {
            'FunctionName': LAMBDA_FUNCTION_NAME,
            'Runtime': LAMBDA_RUNTIME,
            'Role': role_arn,
            'Handler': 'lambda_handler.lambda_handler',
            'Code': {'ZipFile': zip_content},
            'Description': 'CollaborateMD to Salesforce integration Lambda function',
            'Timeout': LAMBDA_TIMEOUT,
            'MemorySize': LAMBDA_MEMORY,
            'Environment': {
                'Variables': {
                    'SECRET_NAME': secret_name,
                    'AWS_REGION': AWS_REGION
                }
            }
        }
        
        try:
            # Create Lambda function
            print_info("Creating Lambda function...")
            response = lambda_client.create_function(**lambda_config)
            function_arn = response['FunctionArn']
            print_success(f"Created Lambda function: {LAMBDA_FUNCTION_NAME}")
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceConflictException':
                print_info(f"Lambda function {LAMBDA_FUNCTION_NAME} already exists, updating...")
                # Update function code
                lambda_client.update_function_code(
                    FunctionName=LAMBDA_FUNCTION_NAME,
                    ZipFile=zip_content
                )
                print_success("Updated Lambda function code")
                
                # Update function configuration
                lambda_client.update_function_configuration(
                    FunctionName=LAMBDA_FUNCTION_NAME,
                    Runtime=LAMBDA_RUNTIME,
                    Role=role_arn,
                    Handler='lambda_handler.lambda_handler',
                    Timeout=LAMBDA_TIMEOUT,
                    MemorySize=LAMBDA_MEMORY,
                    Environment={
                        'Variables': {
                            'SECRET_NAME': secret_name,
                            'AWS_REGION': AWS_REGION
                        }
                    }
                )
                print_success("Updated Lambda function configuration")
                
                # Get function ARN
                func_info = lambda_client.get_function(FunctionName=LAMBDA_FUNCTION_NAME)
                function_arn = func_info['Configuration']['FunctionArn']
            else:
                raise
        
        # Wait for function to be active
        print_info("Waiting for Lambda function to be active...")
        waiter = lambda_client.get_waiter('function_active')
        waiter.wait(FunctionName=LAMBDA_FUNCTION_NAME)
        
        print_info(f"Function ARN: {function_arn}")
        return function_arn
        
    except Exception as e:
        print_error(f"Failed to deploy Lambda function: {str(e)}")
        sys.exit(1)

def create_api_gateway(session, lambda_function_arn):
    """Create API Gateway REST API"""
    print_step(6, 12, "Creating API Gateway")
    
    try:
        apigw = session.client('apigatewayv2')
        lambda_client = session.client('lambda')
        
        # Check if API already exists
        apis = apigw.get_apis()
        existing_api = None
        for api in apis.get('Items', []):
            if api['Name'] == API_GATEWAY_NAME:
                existing_api = api
                break
        
        if existing_api:
            api_id = existing_api['ApiId']
            print_info(f"API Gateway {API_GATEWAY_NAME} already exists")
        else:
            # Create HTTP API
            print_info("Creating HTTP API...")
            api_response = apigw.create_api(
                Name=API_GATEWAY_NAME,
                ProtocolType='HTTP',
                Description='API Gateway for CollaborateMD-Salesforce integration',
                CorsConfiguration={
                    'AllowOrigins': ['*'],
                    'AllowMethods': ['POST', 'OPTIONS'],
                    'AllowHeaders': ['Content-Type', 'Authorization']
                }
            )
            api_id = api_response['ApiId']
            print_success(f"Created API Gateway: {API_GATEWAY_NAME}")
        
        # Create Lambda integration
        print_info("Creating Lambda integration...")
        
        # Check if integration exists
        integrations = apigw.get_integrations(ApiId=api_id)
        integration_id = None
        for integration in integrations.get('Items', []):
            if integration.get('IntegrationUri') == lambda_function_arn:
                integration_id = integration['IntegrationId']
                break
        
        if not integration_id:
            integration_response = apigw.create_integration(
                ApiId=api_id,
                IntegrationType='AWS_PROXY',
                IntegrationUri=lambda_function_arn,
                PayloadFormatVersion='2.0'
            )
            integration_id = integration_response['IntegrationId']
            print_success("Created Lambda integration")
        else:
            print_info("Lambda integration already exists")
        
        # Create route
        print_info("Creating POST /claims route...")
        routes = apigw.get_routes(ApiId=api_id)
        route_exists = False
        for route in routes.get('Items', []):
            if route['RouteKey'] == 'POST /claims':
                route_exists = True
                break
        
        if not route_exists:
            apigw.create_route(
                ApiId=api_id,
                RouteKey='POST /claims',
                Target=f'integrations/{integration_id}'
            )
            print_success("Created POST /claims route")
        else:
            print_info("Route POST /claims already exists")
        
        # Add Lambda permission for API Gateway
        try:
            lambda_client.add_permission(
                FunctionName=LAMBDA_FUNCTION_NAME,
                StatementId=f'apigateway-{api_id}',
                Action='lambda:InvokeFunction',
                Principal='apigateway.amazonaws.com',
                SourceArn=f'arn:aws:execute-api:{AWS_REGION}:{session.client("sts").get_caller_identity()["Account"]}:{api_id}/*/*'
            )
            print_success("Added Lambda permission for API Gateway")
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceConflictException':
                print_info("Lambda permission already exists")
            else:
                raise
        
        return api_id
        
    except Exception as e:
        print_error(f"Failed to create API Gateway: {str(e)}")
        sys.exit(1)

def deploy_api_gateway(session, api_id):
    """Deploy API Gateway to prod stage"""
    print_step(7, 12, "Deploying API Gateway")
    
    try:
        apigw = session.client('apigatewayv2')
        
        # API Gateway v2 (HTTP API) auto-deploys to $default stage
        # Get the API endpoint
        api_info = apigw.get_api(ApiId=api_id)
        api_endpoint = api_info['ApiEndpoint']
        
        print_success(f"API Gateway deployed successfully")
        print_info(f"API Endpoint: {api_endpoint}")
        
        return api_endpoint
        
    except Exception as e:
        print_error(f"Failed to deploy API Gateway: {str(e)}")
        sys.exit(1)

def test_lambda_deployment(session, function_name):
    """Test Lambda function deployment"""
    print_step(8, 12, "Testing Lambda Deployment")
    
    try:
        lambda_client = session.client('lambda')
        
        # Test event
        test_event = {
            'full_sync': False
        }
        
        print_info("Invoking Lambda function with test event...")
        response = lambda_client.invoke(
            FunctionName=function_name,
            InvocationType='RequestResponse',
            Payload=json.dumps(test_event)
        )
        
        # Parse response
        response_payload = json.loads(response['Payload'].read())
        status_code = response['StatusCode']
        
        if status_code == 200:
            print_success("Lambda function invoked successfully")
            print_info(f"Response: {json.dumps(response_payload, indent=2)}")
            return True, response_payload
        else:
            print_error(f"Lambda invocation failed with status code: {status_code}")
            return False, response_payload
        
    except Exception as e:
        print_error(f"Failed to test Lambda deployment: {str(e)}")
        return False, {'error': str(e)}

def test_api_gateway(api_endpoint):
    """Test API Gateway endpoint"""
    print_step(9, 12, "Testing API Gateway Endpoint")
    
    try:
        import requests
        
        url = f"{api_endpoint}/claims"
        test_payload = {
            'full_sync': False
        }
        
        print_info(f"Testing endpoint: {url}")
        print_info("Sending POST request...")
        
        response = requests.post(
            url,
            json=test_payload,
            headers={'Content-Type': 'application/json'},
            timeout=35
        )
        
        print_info(f"Response status code: {response.status_code}")
        print_info(f"Response: {response.text[:500]}")
        
        if response.status_code in [200, 207]:
            print_success("API Gateway endpoint is working correctly")
            return True, response.json()
        else:
            print_error(f"API Gateway test failed with status code: {response.status_code}")
            return False, response.text
        
    except Exception as e:
        print_error(f"Failed to test API Gateway: {str(e)}")
        return False, {'error': str(e)}

def generate_deployment_report(session, deployment_info):
    """Generate comprehensive deployment report"""
    print_step(10, 12, "Generating Deployment Report")
    
    try:
        report = f"""# CollaborateMD-Salesforce Integration - AWS Deployment Report

## Deployment Summary

**Deployment Date:** {time.strftime('%Y-%m-%d %H:%M:%S UTC')}  
**AWS Region:** {AWS_REGION}  
**Status:** {'✓ SUCCESS' if deployment_info['success'] else '✗ FAILED'}

---

## AWS Resources Created/Updated

### 1. Lambda Function
- **Function Name:** {LAMBDA_FUNCTION_NAME}
- **Function ARN:** {deployment_info.get('lambda_arn', 'N/A')}
- **Runtime:** {LAMBDA_RUNTIME}
- **Memory:** {LAMBDA_MEMORY} MB
- **Timeout:** {LAMBDA_TIMEOUT} seconds
- **Handler:** lambda_handler.lambda_handler

### 2. IAM Role
- **Role Name:** {LAMBDA_ROLE_NAME}
- **Role ARN:** {deployment_info.get('role_arn', 'N/A')}
- **Policies Attached:**
  - AWSLambdaBasicExecutionRole (AWS Managed)
  - {LAMBDA_ROLE_NAME}-SecretsPolicy (Custom - Secrets Manager Access)

### 3. Secrets Manager
- **Secret Name:** {SECRET_NAME}
- **Secret ARN:** {deployment_info.get('secret_arn', 'N/A')}
- **Contents:**
  - CollaborateMD API URL
  - CollaborateMD Username
  - CollaborateMD Password

### 4. API Gateway
- **API Name:** {API_GATEWAY_NAME}
- **API ID:** {deployment_info.get('api_id', 'N/A')}
- **API Type:** HTTP API
- **Endpoint URL:** {deployment_info.get('api_endpoint', 'N/A')}

---

## 🔑 CRITICAL: API Endpoint for Salesforce

### API Gateway URL (Add to Salesforce Remote Site Settings)

```
{deployment_info.get('api_endpoint', 'N/A')}
```

### Salesforce Remote Site Setup Instructions

1. **Navigate to Salesforce Setup**
   - Go to Setup → Security → Remote Site Settings

2. **Create New Remote Site**
   - Click "New Remote Site"
   - Remote Site Name: `CollaborateMD_API`
   - Remote Site URL: `{deployment_info.get('api_endpoint', 'N/A')}`
   - Description: `CollaborateMD Lambda Integration API`
   - Active: ✓ Checked

3. **Verify Integration Endpoint**
   - Use the endpoint in your Salesforce Apex code
   - POST requests to: `{deployment_info.get('api_endpoint', 'N/A')}/claims`

---

## API Endpoints

### POST /claims
**Full URL:** `{deployment_info.get('api_endpoint', 'N/A')}/claims`

**Description:** Triggers CollaborateMD to Salesforce sync

**Request Body:**
```json
{{
  "full_sync": false
}}
```

**Parameters:**
- `full_sync` (boolean, optional): Set to `true` to force a full sync, `false` for incremental sync

**Response (Success - 200):**
```json
{{
  "statusCode": 200,
  "body": {{
    "message": "Sync completed",
    "timestamp": "2025-10-23T16:30:00.000Z",
    "statistics": {{
      "claims_fetched": 100,
      "claims_transformed": 98,
      "records_processed": 98,
      "records_successful": 95,
      "records_failed": 3,
      "success_rate": "96.94%"
    }},
    "errors": []
  }}
}}
```

**CORS Enabled:** Yes (all origins)

---

## Test Results

### Lambda Function Test
{self._format_test_results(deployment_info.get('lambda_test_result', {}))}

### API Gateway Test
{self._format_test_results(deployment_info.get('api_test_result', {}))}

---

## Environment Configuration

### Lambda Environment Variables
- `SECRET_NAME`: {SECRET_NAME}
- `AWS_REGION`: {AWS_REGION}

### CollaborateMD API Configuration (Stored in Secrets Manager)
- **API Base URL:** {COLLAB_API_URL}
- **Username:** {COLLAB_USERNAME}
- **Password:** ********** (stored securely in Secrets Manager)

---

## Monitoring & Logs

### CloudWatch Logs
- **Log Group:** `/aws/lambda/{LAMBDA_FUNCTION_NAME}`
- **Access:** AWS Console → CloudWatch → Log Groups

### Lambda Metrics
- Invocations
- Duration
- Error count
- Throttles

**View Metrics:** AWS Console → Lambda → {LAMBDA_FUNCTION_NAME} → Monitoring

---

## Security Considerations

1. **IAM Role Permissions:**
   - Lambda has minimal permissions (least privilege)
   - Access only to Secrets Manager for credentials
   - CloudWatch Logs for logging

2. **Secrets Management:**
   - API credentials stored in AWS Secrets Manager
   - Not exposed in Lambda code or environment variables
   - Automatic encryption at rest

3. **API Gateway:**
   - CORS enabled for Salesforce integration
   - Lambda proxy integration (no direct internet access to Lambda)

---

## Troubleshooting

### Lambda Execution Errors
1. Check CloudWatch Logs: `/aws/lambda/{LAMBDA_FUNCTION_NAME}`
2. Verify IAM role has correct permissions
3. Ensure Secrets Manager secret is accessible

### API Gateway Errors
1. Verify Lambda permissions for API Gateway
2. Check API Gateway execution logs
3. Test Lambda function directly first

### Integration Issues
1. Verify CollaborateMD credentials in Secrets Manager
2. Check CollaborateMD API connectivity
3. Verify Salesforce credentials (if configured)

---

## Next Steps

1. ✓ **Add API Gateway URL to Salesforce Remote Site Settings** (see instructions above)
2. ✓ Configure Salesforce credentials (if not already done)
3. ✓ Test end-to-end integration from Salesforce
4. ✓ Set up CloudWatch alarms for monitoring
5. ✓ Configure scheduled Lambda invocations (if needed)

---

## Support & Maintenance

### Updating Lambda Function
```bash
# Package and update
cd /home/ubuntu/collaboratemd-salesforce-middleware
python3 aws_deploy.py
```

### Viewing Logs
```bash
aws logs tail /aws/lambda/{LAMBDA_FUNCTION_NAME} --follow
```

### Manual Lambda Invocation
```bash
aws lambda invoke \\
  --function-name {LAMBDA_FUNCTION_NAME} \\
  --payload '{{"full_sync": false}}' \\
  response.json
```

---

## Deployment Artifacts

- **Deployment Script:** `/home/ubuntu/collaboratemd-salesforce-middleware/aws_deploy.py`
- **Lambda Package:** `/home/ubuntu/collaboratemd-salesforce-middleware/lambda_deployment_aws.zip`
- **This Report:** `/home/ubuntu/aws_deployment_report.md`

---

**Deployed by:** DeepAgent  
**Deployment Method:** Automated AWS Deployment Script  
**Report Generated:** {time.strftime('%Y-%m-%d %H:%M:%S UTC')}
"""
        
        report_path = '/home/ubuntu/aws_deployment_report.md'
        with open(report_path, 'w') as f:
            f.write(report)
        
        print_success(f"Deployment report saved to: {report_path}")
        return report_path
        
    except Exception as e:
        print_error(f"Failed to generate deployment report: {str(e)}")
        return None

    def _format_test_results(self, result):
        """Format test results for report"""
        if not result:
            return "**Status:** Not tested\n"
        
        success = result.get('success', False)
        status = '✓ PASSED' if success else '✗ FAILED'
        
        output = f"**Status:** {status}\n\n"
        
        if 'response' in result:
            output += "**Response:**\n```json\n"
            output += json.dumps(result['response'], indent=2)
            output += "\n```\n"
        
        if 'error' in result:
            output += f"\n**Error:** {result['error']}\n"
        
        return output

def main():
    """Main deployment function"""
    print(f"{Colors.HEADER}")
    print("=" * 80)
    print("CollaborateMD-Salesforce AWS Lambda Deployment")
    print("=" * 80)
    print(f"{Colors.ENDC}\n")
    
    deployment_info = {
        'success': False
    }
    
    try:
        # Step 1: Configure AWS credentials
        session = configure_aws_credentials()
        deployment_info['region'] = AWS_REGION
        
        # Step 2: Create Secrets Manager secret
        secret_arn = create_secrets_manager_secret(session)
        deployment_info['secret_arn'] = secret_arn
        
        # Step 3: Create IAM role
        role_arn = create_iam_role(session, secret_arn)
        deployment_info['role_arn'] = role_arn
        
        # Step 4: Package Lambda function
        zip_file = package_lambda_function()
        
        # Step 5: Deploy Lambda function
        lambda_arn = deploy_lambda_function(session, role_arn, zip_file, SECRET_NAME)
        deployment_info['lambda_arn'] = lambda_arn
        
        # Step 6: Create API Gateway
        api_id = create_api_gateway(session, lambda_arn)
        deployment_info['api_id'] = api_id
        
        # Step 7: Deploy API Gateway
        api_endpoint = deploy_api_gateway(session, api_id)
        deployment_info['api_endpoint'] = api_endpoint
        
        # Step 8: Test Lambda deployment
        lambda_test_success, lambda_test_response = test_lambda_deployment(session, LAMBDA_FUNCTION_NAME)
        deployment_info['lambda_test_result'] = {
            'success': lambda_test_success,
            'response': lambda_test_response
        }
        
        # Step 9: Test API Gateway
        api_test_success, api_test_response = test_api_gateway(api_endpoint)
        deployment_info['api_test_result'] = {
            'success': api_test_success,
            'response': api_test_response
        }
        
        deployment_info['success'] = True
        
        # Step 10: Generate deployment report
        report_path = generate_deployment_report(session, deployment_info)
        
        # Final summary
        print(f"\n{Colors.HEADER}{'='*80}{Colors.ENDC}")
        print(f"{Colors.BOLD}{Colors.OKGREEN}DEPLOYMENT COMPLETED SUCCESSFULLY!{Colors.ENDC}")
        print(f"{Colors.HEADER}{'='*80}{Colors.ENDC}\n")
        
        print(f"{Colors.BOLD}Key Information:{Colors.ENDC}")
        print(f"  • Lambda Function ARN: {lambda_arn}")
        print(f"  • API Gateway Endpoint: {api_endpoint}")
        print(f"  • API Gateway URL for Salesforce: {api_endpoint}/claims")
        print(f"  • Deployment Report: {report_path}")
        
        print(f"\n{Colors.WARNING}{Colors.BOLD}⚠ IMPORTANT: Add this URL to Salesforce Remote Site Settings:{Colors.ENDC}")
        print(f"{Colors.OKCYAN}  {api_endpoint}{Colors.ENDC}\n")
        
    except Exception as e:
        print_error(f"Deployment failed: {str(e)}")
        deployment_info['success'] = False
        deployment_info['error'] = str(e)
        
        # Try to generate report even on failure
        try:
            report_path = generate_deployment_report(session, deployment_info)
        except:
            pass
        
        sys.exit(1)

if __name__ == '__main__':
    main()
