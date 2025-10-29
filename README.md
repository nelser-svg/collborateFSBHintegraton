# CollaborateMD - Salesforce Integration

A comprehensive integration solution that syncs claims data from CollaborateMD Web API to Salesforce, enabling automated claims processing and management.

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Features](#features)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Deployment](#deployment)
- [Usage](#usage)
- [Monitoring](#monitoring)
- [Troubleshooting](#troubleshooting)
- [Development](#development)
- [Contributing](#contributing)

## 🔍 Overview

This integration connects CollaborateMD's claims management system with Salesforce, automatically syncing claims data to enable:

- **Automated Claims Sync**: Real-time synchronization of claims from CollaborateMD to Salesforce
- **Batch Processing**: Efficient processing of large volumes of claims data
- **Service Authorization Matching**: Automatic linking of claims to service authorization records
- **Claim Payor Management**: Intelligent matching and creation of claim payor records
- **Error Handling & Logging**: Comprehensive logging and error tracking via Integration_Log__c

## 🏗️ Architecture

The integration consists of three main components:

### 1. **AWS Lambda Middleware** (Python)
- Fetches claims data from CollaborateMD Web API
- Transforms data to Salesforce format
- Manages sync state via DynamoDB
- Handles authentication and retries

### 2. **Salesforce Apex Classes**
- **CollabBatch**: Batch Apex class that processes Service Authorization records
- **ColborateMDRes**: Response wrapper class for parsing API JSON responses

### 3. **CollaborateMD Web API**
- Source system providing claims data
- Report-based API with configurable filters

```
┌─────────────────┐
│ CollaborateMD   │
│    Web API      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐       ┌──────────────┐
│  AWS Lambda     │◄─────►│  DynamoDB    │
│  (Middleware)   │       │ (State Mgmt) │
└────────┬────────┘       └──────────────┘
         │
         ▼
┌─────────────────┐
│   Salesforce    │
│  (Apex Batch)   │
└─────────────────┘
```

## ✨ Features

### Data Synchronization
- ✅ Bi-directional sync support (currently one-way: CollaborateMD → Salesforce)
- ✅ Incremental sync based on last modified timestamp
- ✅ Full sync capability for initial data load
- ✅ Automatic duplicate detection and upsert logic

### Processing
- ✅ Batch processing for high-volume claims
- ✅ Configurable batch sizes
- ✅ Retry logic with exponential backoff
- ✅ Concurrent processing support

### Monitoring & Logging
- ✅ Integration logs stored in Salesforce (Integration_Log__c)
- ✅ CloudWatch logs for Lambda execution
- ✅ Success/failure metrics
- ✅ Error notifications

## 📦 Prerequisites

### Required Accounts & Access
1. **CollaborateMD**
   - Web API access
   - Valid username and password
   - Report ID and Filter ID configured

2. **Salesforce**
   - Salesforce org (Sandbox or Production)
   - System Administrator access
   - API access enabled

3. **AWS Account**
   - Lambda function creation permissions
   - DynamoDB table creation permissions
   - IAM role creation permissions
   - CloudWatch Logs access

### Required Software (for local development)
- Python 3.9+
- pip
- AWS CLI (configured)
- Salesforce CLI (sfdx)
- Git

## 🚀 Installation

### Step 1: Clone the Repository

```bash
git clone https://github.com/nelser-svg/collaborateFSBHintegration.git
cd collaborateFSBHintegration
```

### Step 2: Install Python Dependencies

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
# On Linux/Mac:
source venv/bin/activate
# On Windows:
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your credentials
nano .env  # or use your preferred editor
```

Fill in the required values:

```bash
# CollaborateMD Configuration
COLLABORATEMD_API_BASE_URL=https://api.collaboratemd.com
COLLABORATEMD_USERNAME=your_username
COLLABORATEMD_PASSWORD=your_password
COLLABORATEMD_CUSTOMER=your_customer_id
COLLABORATEMD_REPORT_ID=10060198
COLLABORATEMD_FILTER_ID=10060198

# Salesforce Configuration
SALESFORCE_USERNAME=your_salesforce_username@company.com
SALESFORCE_PASSWORD=your_password
SALESFORCE_SECURITY_TOKEN=your_security_token
SALESFORCE_DOMAIN=test  # 'test' for sandbox, 'login' for production

# Processing Configuration
BATCH_SIZE=100
STATE_TABLE_NAME=collaboratemd-state
LOG_LEVEL=INFO
```

## ⚙️ Configuration

### Salesforce Setup

#### 1. Deploy Apex Classes

```bash
# Authenticate to Salesforce
sfdx auth:web:login --setalias myorg --instanceurl https://test.salesforce.com

# Deploy Apex classes
sfdx force:source:deploy \
  --sourcepath salesforce/force-app/main/default/classes \
  --targetusername myorg
```

Or use the Python deployment script:

```bash
python scripts/deploy_salesforce.py
```

#### 2. Create Integration_Log__c Custom Fields

Navigate to: **Setup → Object Manager → Integration_Log__c → Fields & Relationships → New**

Create these fields:

| Field Name | Type | Length/Options | Required |
|------------|------|----------------|----------|
| Integration_Type__c | Text | 100 | No |
| Status__c | Picklist | Success, Error, Warning | No |
| Request_Payload__c | Long Text Area | 32,000 | No |
| Response_Payload__c | Long Text Area | 32,000 | No |
| Error_Message__c | Long Text Area | 5,000 | No |
| Timestamp__c | Date/Time | - | No |
| Related_Record_Id__c | Text | 18 | No |

#### 3. Configure Named Credentials

**Path:** Setup → Named Credentials → New Named Credential

```
Label: Claims API
Name: Claims_API
URL: https://api.collaboratemd.com
Identity Type: Named Principal
Authentication Protocol: Password Authentication
Username: [Your CollaborateMD Username]
Password: [Your CollaborateMD Password]
```

#### 4. Configure Remote Site Settings

**Path:** Setup → Remote Site Settings → New Remote Site

```
Remote Site Name: CollaborateMD_API
Remote Site URL: https://api.collaboratemd.com
Active: ✅ Checked
```

### AWS Setup

#### 1. Create DynamoDB Table

```bash
aws dynamodb create-table \
  --table-name collaboratemd-state \
  --attribute-definitions \
    AttributeName=id,AttributeType=S \
  --key-schema \
    AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

#### 2. Create IAM Role for Lambda

```bash
# Create trust policy
cat > trust-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "lambda.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name collaboratemd-lambda-role \
  --assume-role-policy-document file://trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name collaboratemd-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name collaboratemd-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

#### 3. Build Lambda Package

```bash
# Run the build script
./scripts/build_lambda_package_docker.sh
```

Or manually:

```bash
# Create package directory
mkdir -p lambda_package

# Install dependencies
pip install -r requirements.txt -t lambda_package/

# Copy source code
cp -r src lambda_package/
cp lambda_handler.py lambda_package/

# Create zip file
cd lambda_package
zip -r ../lambda_deployment.zip .
cd ..
```

#### 4. Deploy Lambda Function

```bash
# Using AWS CLI
aws lambda create-function \
  --function-name collaboratemd-salesforce-sync \
  --runtime python3.9 \
  --role arn:aws:iam::YOUR_ACCOUNT_ID:role/collaboratemd-lambda-role \
  --handler lambda_handler.lambda_handler \
  --zip-file fileb://lambda_deployment.zip \
  --timeout 900 \
  --memory-size 512 \
  --environment Variables="{
    COLLABORATEMD_USERNAME=your_username,
    COLLABORATEMD_PASSWORD=your_password,
    COLLABORATEMD_REPORT_ID=10060198,
    COLLABORATEMD_FILTER_ID=10060198,
    SALESFORCE_USERNAME=your_sf_username,
    SALESFORCE_PASSWORD=your_sf_password,
    SALESFORCE_SECURITY_TOKEN=your_sf_token,
    STATE_TABLE_NAME=collaboratemd-state
  }"
```

Or use the automated script:

```bash
python scripts/aws_deploy_simplified.py
```

## 📖 Usage

### Running the Lambda Function

#### Trigger Manually (AWS Console)
1. Navigate to AWS Lambda console
2. Select the function
3. Click "Test"
4. Use this test event:
```json
{
  "full_sync": false
}
```

#### Trigger via AWS CLI
```bash
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": false}' \
  response.json

cat response.json
```

#### Schedule with EventBridge
```bash
# Create rule for daily execution at 2 AM
aws events put-rule \
  --name collaboratemd-daily-sync \
  --schedule-expression "cron(0 2 * * ? *)"

# Add Lambda as target
aws events put-targets \
  --rule collaboratemd-daily-sync \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT_ID:function:collaboratemd-salesforce-sync"

# Grant permission
aws lambda add-permission \
  --function-name collaboratemd-salesforce-sync \
  --statement-id collaboratemd-daily-sync \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:ACCOUNT_ID:rule/collaboratemd-daily-sync
```

### Running the Salesforce Batch Job

#### Execute Anonymous Apex
```apex
// Test the batch job
CollabBatch batch = new CollabBatch();
Database.executeBatch(batch, 200);
```

#### Schedule the Batch Job
```apex
// Schedule to run daily at 2 AM
String cronExp = '0 0 2 * * ?';
String jobName = 'CollaborateMD Claims Sync';
CollabBatch batch = new CollabBatch();
System.schedule(jobName, cronExp, batch);
```

Or via Setup:
1. **Setup → Apex Classes → Schedule Apex**
2. Select "CollabBatch"
3. Configure schedule

## 📊 Monitoring

### Salesforce Monitoring

#### View Integration Logs
```apex
// Query recent logs
List<Integration_Log__c> logs = [
    SELECT Id, Status__c, Integration_Type__c, 
           Error_Message__c, Timestamp__c
    FROM Integration_Log__c 
    ORDER BY CreatedDate DESC 
    LIMIT 100
];
```

#### Check Batch Job Status
```apex
// Query batch jobs
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, 
           JobItemsProcessed, TotalJobItems,
           CreatedDate, CompletedDate
    FROM AsyncApexJob
    WHERE ApexClass.Name = 'CollabBatch'
    ORDER BY CreatedDate DESC
    LIMIT 10
];
```

### AWS Monitoring

#### View Lambda Logs
```bash
# Get recent logs
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow
```

#### Check DynamoDB State
```bash
# Query sync state
aws dynamodb get-item \
  --table-name collaboratemd-state \
  --key '{"id":{"S":"last_sync"}}'
```

## 🔧 Troubleshooting

### Common Issues

#### Issue: Lambda Timeout
**Symptoms:** Function times out before completing

**Solutions:**
- Increase timeout in Lambda configuration (max 15 minutes)
- Reduce batch size
- Check CollaborateMD API response time

#### Issue: Salesforce Authentication Failed
**Symptoms:** "INVALID_LOGIN" or "INVALID_SESSION_ID"

**Solutions:**
- Verify credentials in environment variables
- Check security token (reset if needed)
- Verify IP restrictions in Salesforce

#### Issue: No Claims Synced
**Symptoms:** Job runs successfully but no claims created

**Solutions:**
- Check Service Authorization records exist
- Verify Authorization_Number__c is populated
- Review Integration_Log__c for errors
- Check Named Credential configuration

#### Issue: Duplicate Claims Created
**Symptoms:** Multiple claims with same Claim_Number__c

**Solutions:**
- Verify upsert logic in batch class
- Check external ID field configuration
- Review batch execution logs

### Debug Mode

Enable detailed logging:

```bash
# In .env
LOG_LEVEL=DEBUG
```

```apex
// In Salesforce
System.debug(LoggingLevel.DEBUG, 'Detailed message');
```

## 💻 Development

### Local Testing

#### Test Lambda Handler Locally
```bash
python lambda_handler.py
```

#### Test Salesforce Classes
Use Salesforce Developer Console:
1. **Debug → Open Execute Anonymous Window**
2. Run test code
3. Check debug logs

### Running Tests

#### Python Tests
```bash
pytest tests/
```

#### Apex Tests
```bash
sfdx force:apex:test:run --targetusername myorg --codecoverage --resultformat human
```

### Code Quality

```bash
# Python linting
pylint src/

# Type checking
mypy src/

# Format code
black src/
```

## 📁 Project Structure

```
collaboratemd-salesforce-middleware/
├── src/                          # Python source code
│   ├── __init__.py
│   ├── config.py                # Configuration management
│   ├── logger.py                # Logging setup
│   ├── collaboratemd_client.py  # CollaborateMD API client
│   ├── salesforce_client.py     # Salesforce API client
│   ├── data_transformer.py      # Data transformation logic
│   ├── state_manager.py         # DynamoDB state management
│   └── utils.py                 # Utility functions
├── salesforce/                   # Salesforce metadata
│   └── force-app/
│       └── main/
│           └── default/
│               └── classes/
│                   ├── CollabBatch.cls
│                   ├── CollabBatch.cls-meta.xml
│                   ├── ColborateMDRes.cls
│                   └── ColborateMDRes.cls-meta.xml
├── scripts/                      # Deployment scripts
│   ├── deploy_salesforce.py
│   ├── aws_deploy_simplified.py
│   ├── build_lambda_package_docker.sh
│   └── deploy_lambda.sh
├── docs/                         # Documentation
│   ├── DEPLOYMENT_SUMMARY.md
│   ├── PROJECT_SUMMARY.md
│   └── QUICKSTART.md
├── tests/                        # Test files
├── lambda_handler.py            # Lambda entry point
├── requirements.txt             # Python dependencies
├── .env.example                 # Environment template
├── .gitignore                   # Git ignore rules
└── README.md                    # This file
```

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is proprietary and confidential.

## 📞 Support

For issues or questions:
- Email: support@yourcompany.com
- Salesforce Org: firststepbh--dev.sandbox.my.salesforce.com

## 🔄 Version History

### v1.0.0 (October 2025)
- Initial release
- AWS Lambda middleware implementation
- Salesforce Apex batch processing
- DynamoDB state management
- Comprehensive logging and error handling

---

**Note:** This integration handles sensitive healthcare data. Ensure all security best practices are followed and comply with HIPAA regulations.
