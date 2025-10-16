# CollaborateMD to Salesforce Middleware

A robust AWS Lambda-based middleware solution for synchronizing claims data from CollaborateMD to Salesforce Claims__c objects.

## 🎯 Overview

This middleware automates the process of:
1. **Fetching** claims data from CollaborateMD using their Reports API
2. **Transforming** the data to match Salesforce Claims__c field structure
3. **Syncing** transformed data to Salesforce in batches of 200 records
4. **Tracking** sync state using DynamoDB for incremental updates
5. **Handling** errors with exponential backoff retry logic

### Key Features

- ✅ **Incremental Sync**: Tracks last sync timestamp to only fetch modified records
- ✅ **Batch Processing**: Handles up to 700,000+ records efficiently in batches
- ✅ **Error Recovery**: Exponential backoff retry logic for API failures
- ✅ **State Management**: DynamoDB-based state tracking for reliability
- ✅ **Comprehensive Logging**: Detailed logging for debugging and monitoring
- ✅ **AWS Lambda Ready**: Optimized for serverless deployment
- ✅ **Field Mapping**: Automatic transformation of CollaborateMD fields to Salesforce

## 📋 Prerequisites

### Required Accounts & Access
- **CollaborateMD**: Web API credentials with report access
  - Username and Password
  - Customer number (8 digits)
  - Report sequence ID and Filter sequence ID
- **Salesforce**: API access with Claims__c object permissions
  - Username, Password, and Security Token
  - Or OAuth2 Consumer Key/Secret
- **AWS Account**: For Lambda, DynamoDB, and CloudWatch

### Required Software (for local development)
- Python 3.11 or higher
- AWS CLI configured with appropriate credentials
- Git (for version control)
- pip (Python package manager)

## 🏗️ Architecture

```
┌─────────────────┐
│  AWS Lambda     │
│  (Python 3.11)  │
└────────┬────────┘
         │
         ├──────────────┐
         │              │
         ▼              ▼
┌─────────────────┐  ┌─────────────────┐
│ CollaborateMD   │  │  Salesforce     │
│   Reports API   │  │   REST API      │
└─────────────────┘  └─────────────────┘
         │              ▲
         │              │
         ▼              │
    [Transform Data]────┘
         │
         ▼
┌─────────────────┐
│   DynamoDB      │
│  (State Store)  │
└─────────────────┘
```

## 📁 Project Structure

```
collaboratemd-salesforce-middleware/
├── src/
│   ├── __init__.py
│   ├── config.py                    # Configuration management
│   ├── logger.py                    # Logging setup
│   ├── utils.py                     # Utility functions (retry, chunking)
│   ├── collaboratemd_client.py      # CollaborateMD API client
│   ├── salesforce_client.py         # Salesforce API client
│   ├── data_transformer.py          # Data transformation logic
│   └── state_manager.py             # DynamoDB state management
├── scripts/
│   ├── deploy.sh                    # Deployment script
│   ├── create_lambda.sh             # Lambda creation script
│   └── test_lambda.sh               # Testing script
├── tests/                           # Unit tests (to be added)
├── lambda_handler.py                # Main Lambda entry point
├── requirements.txt                 # Python dependencies
├── .env.example                     # Example environment variables
├── .gitignore                       # Git ignore rules
└── README.md                        # This file
```

## 🚀 Quick Start

### 1. Clone and Setup

```bash
# Navigate to project directory
cd /home/ubuntu/collaboratemd-salesforce-middleware

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2. Configure Environment Variables

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your credentials
nano .env
```

Required environment variables:

```bash
# CollaborateMD Configuration
COLLABORATE_MD_USERNAME=your_username
COLLABORATE_MD_PASSWORD=your_password
COLLABORATE_MD_CUSTOMER=10001001
COLLABORATE_MD_REPORT_SEQ=10001234
COLLABORATE_MD_FILTER_SEQ=10004321

# Salesforce Configuration
SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com
SALESFORCE_USERNAME=your_salesforce_username
SALESFORCE_PASSWORD=your_salesforce_password
SALESFORCE_SECURITY_TOKEN=your_security_token

# Processing Configuration
BATCH_SIZE=200
MAX_RETRIES=3
LOG_LEVEL=INFO

# AWS Configuration
DYNAMODB_TABLE_NAME=collaboratemd-sync-state
AWS_REGION=us-east-1
```

### 3. Deploy to AWS Lambda

#### Option A: Automated Deployment (Recommended)

```bash
# Create all resources (Lambda, IAM role, DynamoDB)
./scripts/create_lambda.sh

# Update environment variables via AWS CLI
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables="{
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
  }" \
  --region us-east-1
```

#### Option B: Manual Deployment

1. **Create IAM Role** with these policies:
   - `AWSLambdaBasicExecutionRole`
   - Custom policy for DynamoDB access

2. **Create DynamoDB Table**:
```bash
aws dynamodb create-table \
  --table-name collaboratemd-sync-state \
  --attribute-definitions AttributeName=sync_id,AttributeType=S \
  --key-schema AttributeName=sync_id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

3. **Deploy Lambda**:
```bash
./scripts/deploy.sh
```

### 4. Test the Function

```bash
# Test via AWS CLI
./scripts/test_lambda.sh

# Or invoke directly
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": false}' \
  --region us-east-1 \
  response.json
```

### 5. Schedule Recurring Sync

Create EventBridge rule for automated syncs:

```bash
# Create rule for daily sync at 2 AM UTC
aws events put-rule \
  --name "collaboratemd-daily-sync" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --region us-east-1

# Add Lambda as target
aws events put-targets \
  --rule "collaboratemd-daily-sync" \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT_ID:function:collaboratemd-salesforce-sync" \
  --region us-east-1

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name collaboratemd-salesforce-sync \
  --statement-id "EventBridgeInvoke" \
  --action "lambda:InvokeFunction" \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:us-east-1:ACCOUNT_ID:rule/collaboratemd-daily-sync"
```

## 🔧 Configuration

### Environment Variables Reference

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `COLLABORATE_MD_BASE_URL` | No | `https://webapi.collaboratemd.com` | CollaborateMD API base URL |
| `COLLABORATE_MD_USERNAME` | **Yes** | - | CollaborateMD API username |
| `COLLABORATE_MD_PASSWORD` | **Yes** | - | CollaborateMD API password |
| `COLLABORATE_MD_CUSTOMER` | **Yes** | - | 8-digit customer number |
| `COLLABORATE_MD_REPORT_SEQ` | **Yes** | - | Report sequence ID |
| `COLLABORATE_MD_FILTER_SEQ` | **Yes** | - | Filter sequence ID |
| `SALESFORCE_INSTANCE_URL` | **Yes** | - | Salesforce instance URL |
| `SALESFORCE_USERNAME` | **Yes** | - | Salesforce username |
| `SALESFORCE_PASSWORD` | **Yes** | - | Salesforce password |
| `SALESFORCE_SECURITY_TOKEN` | **Yes** | - | Salesforce security token |
| `SALESFORCE_CONSUMER_KEY` | No | - | OAuth2 consumer key (optional) |
| `SALESFORCE_CONSUMER_SECRET` | No | - | OAuth2 consumer secret (optional) |
| `BATCH_SIZE` | No | `200` | Records per batch for Salesforce |
| `MAX_RETRIES` | No | `3` | Maximum retry attempts |
| `RETRY_BACKOFF_FACTOR` | No | `2.0` | Exponential backoff multiplier |
| `INITIAL_RETRY_DELAY` | No | `1.0` | Initial retry delay (seconds) |
| `DYNAMODB_TABLE_NAME` | No | `collaboratemd-sync-state` | DynamoDB table name |
| `AWS_REGION` | No | `us-east-1` | AWS region |
| `LOG_LEVEL` | No | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |

### CollaborateMD Report Setup

1. **Log into CollaborateMD** web application
2. **Navigate to** Reports → Central Business Intelligence
3. **Create custom report** with these fields:
   - ClaimID
   - PateintNameID
   - ClaimPrimaryPayerName
   - PayerID
   - PrimaryAuth
   - StatementCoversFromDate
   - StatementCoversToDate
   - ClaimDateEntered
   - ClaimTotalAmount
   - ClaimAmountPaid
   - ClaimBalance
   - PaymentCheck
   - PaymentReceived
   - PatientReference
4. **Save filter set** for the report
5. **Note the Report Seq and Filter Seq** from the URL

See [CollaborateMD Help Article](https://help.collaboratemd.com/help/web-reporting) for details.

## 📊 Field Mappings

### CollaborateMD → Salesforce Claims__c

| CollaborateMD Field | Salesforce Field | Type | Notes |
|---------------------|------------------|------|-------|
| `ClaimID` | `Claim_Number__c` | Text | External ID for upsert |
| `PateintNameID` | `Name` | Text | Record name |
| `StatementCoversFromDate` | `DOS__c` | Date | Date of Service start |
| `StatementCoversToDate` | `DOS_End__c` | Date | Date of Service end |
| `ClaimDateEntered` | `Claim_Submitted_Date__c` | Date | Submission date |
| `ClaimTotalAmount` | `Charged_Amount__c` | Currency | Total charges |
| `ClaimAmountPaid` | `Paid_Amount__c` | Currency | Amount paid |
| `ClaimBalance` | `Total_BDP__c` | Currency | Balance |
| `PaymentCheck` | `EFT_or_Paper_Check__c` | Text | Payment reference |
| `PaymentReceived` | `Paid_Date__c` | Date | Payment date |
| `PrimaryAuth` | `Insurance_Authorization_Number__c` | Text | Auth number |
| `PayerID` | `Payer__c` | Text | Payer ID |
| `PatientReference` | `MR_Number__c` | Text | Medical record number |
| `ClaimPrimaryPayerName` + `PayerID` | `Claim_Payor__c` | Lookup | Lookup to Claim_Payor__c |
| Calculated | `Paid_Y_or_N__c` | Picklist | 'Yes' if paid, 'No' otherwise |

## 🔍 Monitoring & Logging

### CloudWatch Logs

Logs are automatically sent to:
```
/aws/lambda/collaboratemd-salesforce-sync
```

### Log Levels

- **DEBUG**: Detailed information for diagnosing issues
- **INFO**: General information about execution flow (default)
- **WARNING**: Warnings about potential issues
- **ERROR**: Errors that don't stop execution
- **CRITICAL**: Fatal errors

### Viewing Logs

```bash
# Via AWS CLI
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow

# Via AWS Console
# Navigate to: CloudWatch → Log groups → /aws/lambda/collaboratemd-salesforce-sync
```

### Metrics to Monitor

- **Invocations**: Total executions
- **Errors**: Failed executions
- **Duration**: Execution time
- **Throttles**: Rate-limited invocations
- **DynamoDB**: Read/Write capacity usage

## 🧪 Testing

### Local Testing

```bash
# Activate virtual environment
source venv/bin/activate

# Set environment variables
export $(cat .env | xargs)

# Run local test
python lambda_handler.py
```

### Unit Tests (Future Enhancement)

```bash
# Install test dependencies
pip install pytest pytest-cov

# Run tests
pytest tests/

# Run with coverage
pytest --cov=src tests/
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Authentication Failures

**CollaborateMD:**
```
Error: 401 Unauthorized
```
- Verify username and password are correct
- Check Basic Auth encoding
- Ensure API access is enabled for your account

**Salesforce:**
```
SalesforceAuthenticationFailed
```
- Verify username, password, and security token
- Check IP restrictions in Salesforce
- Ensure user has API access enabled

#### 2. Report Not Running

```
Error: Report execution timed out
```
- Report filters may be too broad
- Narrow the date range in filter settings
- Check CollaborateMD system status

#### 3. DynamoDB Errors

```
ResourceNotFoundException: Table not found
```
- Ensure DynamoDB table exists
- Verify Lambda has DynamoDB permissions
- Check region configuration

#### 4. Salesforce Upsert Failures

```
Error: Field not found: Claim_Number__c
```
- Verify Claims__c object exists in Salesforce
- Check all field API names match
- Ensure user has field-level security access

### Debug Mode

Enable verbose logging:

```bash
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables='{..., LOG_LEVEL=DEBUG}' \
  --region us-east-1
```

## 📈 Performance Optimization

### For Large Datasets (>100K records)

1. **Increase Lambda Memory**: More memory = more CPU
   ```bash
   aws lambda update-function-configuration \
     --function-name collaboratemd-salesforce-sync \
     --memory-size 1024 \
     --timeout 900
   ```

2. **Use Salesforce Bulk API**: For even larger batches
   - Modify `salesforce_client.py` to use Bulk API v2
   - Reference: [Salesforce Bulk API Documentation](https://developer.salesforce.com/docs/atlas.en-us.api_asynch.meta/api_asynch/)

3. **Parallel Processing**: Split into multiple Lambda invocations
   - Use Step Functions for orchestration
   - Process date ranges in parallel

4. **Optimize DynamoDB**: 
   - Use on-demand billing for unpredictable loads
   - Or provision sufficient read/write capacity

## 🔒 Security Best Practices

1. **Credentials Management**
   - ✅ Store credentials in AWS Secrets Manager
   - ✅ Rotate credentials regularly
   - ✅ Use IAM roles with least privilege

2. **Network Security**
   - ✅ Deploy Lambda in VPC if required
   - ✅ Use VPC endpoints for AWS services
   - ✅ Restrict outbound traffic

3. **Data Protection**
   - ✅ Enable CloudWatch Logs encryption
   - ✅ Use SSL/TLS for all API calls
   - ✅ Sanitize logs to remove sensitive data

4. **Monitoring**
   - ✅ Set up CloudWatch alarms
   - ✅ Enable AWS CloudTrail
   - ✅ Review logs regularly

## 🤝 Contributing

### Development Setup

```bash
# Clone repository
git clone <repository-url>
cd collaboratemd-salesforce-middleware

# Create virtual environment
python3 -m venv venv
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt

# Install development dependencies
pip install pytest pytest-cov black flake8
```

### Code Style

- Follow PEP 8 guidelines
- Use type hints
- Write docstrings for all functions
- Keep functions focused and testable

### Pull Request Process

1. Create feature branch
2. Write/update tests
3. Ensure all tests pass
4. Update documentation
5. Submit PR with description

## 📝 License

This project is proprietary and confidential.

## 📞 Support

For issues or questions:
- Check the [Troubleshooting](#-troubleshooting) section
- Review CloudWatch logs
- Contact your system administrator

## 🗺️ Roadmap

Future enhancements:
- [ ] Unit and integration tests
- [ ] Support for Salesforce Bulk API
- [ ] Parallel processing with Step Functions
- [ ] Webhook support for real-time sync
- [ ] Enhanced error notification (SNS/Email)
- [ ] Dashboard for sync statistics
- [ ] Support for additional CollaborateMD objects

## 📚 Additional Resources

- [CollaborateMD API Documentation](https://help.collaboratemd.com/help/web-api)
- [Salesforce REST API Guide](https://developer.salesforce.com/docs/atlas.en-us.api_rest.meta/api_rest/)
- [AWS Lambda Developer Guide](https://docs.aws.amazon.com/lambda/latest/dg/welcome.html)
- [DynamoDB Developer Guide](https://docs.aws.amazon.com/dynamodb/index.html)

---

**Version**: 1.0.0  
**Last Updated**: October 16, 2025  
**Developed for**: AWS Lambda deployment with Python 3.11
