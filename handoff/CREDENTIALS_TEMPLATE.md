# CollaborateMD-Salesforce Integration - Credentials Template

## 🔐 Credential Requirements

This document lists all credentials required for the CollaborateMD-Salesforce integration deployment. For security, **actual credential values are NOT included** in this document. Replace placeholders with actual values during deployment.

---

## 1. AWS Credentials

### 1.1 AWS Account Access

**Purpose:** Deploy and manage Lambda function, DynamoDB, IAM roles, CloudWatch

**Required Information:**
- AWS Account ID: `248189924154`
- Region: `us-east-1` (US East - N. Virginia)
- Access Method: IAM User or IAM Role

**Format:**
```bash
# Environment Variables
export AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export AWS_SECRET_ACCESS_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
export AWS_DEFAULT_REGION="us-east-1"

# OR use AWS CLI configuration
aws configure
# AWS Access Key ID [None]: AKIAIOSFODNN7EXAMPLE
# AWS Secret Access Key [None]: wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
# Default region name [None]: us-east-1
# Default output format [None]: json
```

**Required Permissions:**
- `AWSLambda_FullAccess` (or equivalent)
- `IAMFullAccess` (for role creation)
- `AmazonDynamoDBFullAccess` (or specific table permissions)
- `CloudWatchLogsFullAccess`
- `AmazonEventBridgeFullAccess` (for scheduling)

**Verification:**
```bash
# Test AWS credentials
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAIOSFODNN7EXAMPLE",
#     "Account": "248189924154",
#     "Arn": "arn:aws:iam::248189924154:user/username"
# }
```

**Where Used:**
- Lambda function deployment
- DynamoDB table creation
- IAM role management
- CloudWatch monitoring
- EventBridge scheduling

---

## 2. Salesforce Credentials

### 2.1 Salesforce Sandbox Access

**Purpose:** Deploy Apex classes, access REST API, manage metadata

**Required Information:**

| Field | Value Template | Example | Notes |
|-------|---------------|---------|-------|
| **Username** | `[username]@[domain].com.dev` | `john.doe@firststepbh.com.dev` | Must include `.dev` for sandbox |
| **Password** | `[your_password]` | `MyP@ssw0rd!` | Salesforce account password |
| **Security Token** | `[token]` | `ABC123xyz789DEF456` | From Salesforce settings |
| **Combined Auth** | `[password][token]` | `MyP@ssw0rd!ABC123xyz789DEF456` | No space between |
| **Org URL** | `firststepbh--dev.sandbox.my.salesforce.com` | - | Sandbox instance |
| **Login URL** | `https://test.salesforce.com` | - | Sandbox login |
| **Domain** | `test` | - | For OAuth |

**How to Get Security Token:**
1. Login to Salesforce sandbox
2. Navigate to: **Personal Information** → **Reset My Security Token**
3. Check your email for the token
4. Token format: 25 alphanumeric characters

**Format for Lambda Environment Variables:**
```bash
SALESFORCE_USERNAME="john.doe@firststepbh.com.dev"
SALESFORCE_PASSWORD="MyP@ssw0rd!"
SALESFORCE_SECURITY_TOKEN="ABC123xyz789DEF456"
SALESFORCE_DOMAIN="test"
```

**Format for Python Code:**
```python
from simple_salesforce import Salesforce

sf = Salesforce(
    username='john.doe@firststepbh.com.dev',
    password='MyP@ssw0rd!',
    security_token='ABC123xyz789DEF456',
    domain='test'
)
```

**Verification:**
```bash
# Test via curl (after getting session)
curl https://firststepbh--dev.sandbox.my.salesforce.com/services/data/v58.0/ \
  -H "Authorization: Bearer [access_token]"
```

**Where Used:**
- Lambda function (Salesforce API client)
- Deployment scripts (sfdx auth)
- Testing and verification

**Required Permissions:**
- API Enabled
- Modify All Data (or specific object permissions)
- Author Apex
- Deploy Custom Applications

### 2.2 Salesforce Connected App (Optional but Recommended)

**Purpose:** OAuth2 authentication for better security

**Required Information:**
- Consumer Key (Client ID)
- Consumer Secret (Client Secret)
- Callback URL

**Not currently implemented, but recommended for production.**

---

## 3. CollaborateMD API Credentials

### 3.1 CollaborateMD Web API Access

**Purpose:** Fetch claims data from CollaborateMD system

**Required Information:**

| Field | Value | Example | Notes |
|-------|-------|---------|-------|
| **API Base URL** | `https://ws.collaboratemd.com/api/v1` | - | Production API |
| **Username** | `nicolasmd` | - | API username |
| **Password** | `Nic@2024!` | - | API password |
| **Customer ID** | (if required) | - | Organization ID |
| **Report ID** | `10060198` | - | Claims report ID |
| **Filter ID** | `10060198` | - | Report filter ID |

**Format for Lambda Environment Variables:**
```bash
COLLABORATEMD_API_BASE_URL="https://ws.collaboratemd.com/api/v1"
COLLABORATEMD_USERNAME="nicolasmd"
COLLABORATEMD_PASSWORD="Nic@2024!"
COLLABORATEMD_REPORT_ID="10060198"
COLLABORATEMD_FILTER_ID="10060198"
```

**Authentication Request:**
```bash
# Test authentication
curl -X POST https://ws.collaboratemd.com/api/v1/authentication/login \
  -H "Content-Type: application/json" \
  -d '{
    "username": "nicolasmd",
    "password": "Nic@2024!"
  }'

# Expected response:
# {
#   "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "expires_at": "2024-10-16T14:30:00Z"
# }
```

**Where Used:**
- Lambda function (CollaborateMD client)
- Data extraction process

**Required Permissions:**
- API access enabled
- Reports access (Report ID 10060198)
- Read claims data

---

## 4. EC2 / SSH Access (Optional)

### 4.1 EC2 Instance Access

**Purpose:** Direct server access for troubleshooting or manual deployment

**Required Information:**

| Field | Value | Notes |
|-------|-------|-------|
| **Instance ID** | `i-083968dabdd297425` | EC2 instance |
| **Region** | `us-east-1` | N. Virginia |
| **Public IP** | `34.225.81.96` | May change if stopped |
| **Private IP** | `172.31.94.187` | Internal IP |
| **Key Pair Name** | `nicolas` | SSH key name |
| **Key File** | `/home/ubuntu/Uploads/Collaborate-Key.pem` | Private key location |
| **User** | `ubuntu` | Default Ubuntu user |

**SSH Connection:**
```bash
# Set correct permissions on key file
chmod 400 /home/ubuntu/Uploads/Collaborate-Key.pem

# Connect to instance
ssh -i /home/ubuntu/Uploads/Collaborate-Key.pem ubuntu@34.225.81.96

# Or using private IP (from within VPC)
ssh -i /home/ubuntu/Uploads/Collaborate-Key.pem ubuntu@172.31.94.187
```

**Verification:**
```bash
# Check instance status
aws ec2 describe-instances --instance-ids i-083968dabdd297425 --region us-east-1

# Check if instance is running
aws ec2 describe-instance-status --instance-ids i-083968dabdd297425 --region us-east-1
```

**Where Used:**
- Manual deployment
- Debugging
- Log file access
- Code updates

---

## 5. DynamoDB Access

### 5.1 State Management Table

**Purpose:** Store last sync timestamp and integration state

**Required Information:**

| Field | Value | Notes |
|-------|-------|-------|
| **Table Name** | `collaboratemd-state` | State table |
| **Region** | `us-east-1` | Same as Lambda |
| **Primary Key** | `id` (String) | Partition key |
| **Billing Mode** | Pay-per-request | On-demand |

**Table Structure:**
```json
{
  "id": "last_sync",
  "timestamp": "2024-11-05T14:30:00.000Z",
  "status": "success",
  "claims_processed": 150,
  "last_execution_duration": 23.5
}
```

**Access Required:**
- `dynamodb:GetItem`
- `dynamodb:PutItem`
- `dynamodb:UpdateItem`
- `dynamodb:Query`

**Verification:**
```bash
# Check if table exists
aws dynamodb describe-table --table-name collaboratemd-state --region us-east-1

# Query current state
aws dynamodb get-item \
  --table-name collaboratemd-state \
  --key '{"id":{"S":"last_sync"}}' \
  --region us-east-1
```

**Where Used:**
- Lambda function (state manager)
- Incremental sync logic

---

## 6. Additional Service Credentials (Optional)

### 6.1 AWS Secrets Manager (Recommended)

**Purpose:** Secure credential storage instead of environment variables

**Format:**
```json
{
  "collaboratemd_username": "nicolasmd",
  "collaboratemd_password": "Nic@2024!",
  "salesforce_username": "john.doe@firststepbh.com.dev",
  "salesforce_password": "MyP@ssw0rd!",
  "salesforce_token": "ABC123xyz789DEF456"
}
```

**Create Secret:**
```bash
aws secretsmanager create-secret \
  --name collaboratemd-credentials \
  --secret-string file://credentials.json \
  --region us-east-1
```

### 6.2 API Gateway (Optional)

**Purpose:** Public HTTP endpoint for Salesforce to call Lambda

**Configuration:**
- API Type: HTTP API
- Authorization: API Key or Lambda authorizer
- CORS: Enabled for Salesforce domains

**Not currently implemented, but mentioned in CloudFormation template.**

---

## 7. Environment Variables Summary

### Complete Lambda Environment Variables

**Template:**
```bash
# CollaborateMD Configuration
COLLABORATEMD_USERNAME="nicolasmd"
COLLABORATEMD_PASSWORD="Nic@2024!"
COLLABORATEMD_API_BASE_URL="https://ws.collaboratemd.com/api/v1"
COLLABORATEMD_REPORT_ID="10060198"
COLLABORATEMD_FILTER_ID="10060198"

# Salesforce Configuration
SALESFORCE_USERNAME="[REPLACE]@firststepbh.com.dev"
SALESFORCE_PASSWORD="[REPLACE]"
SALESFORCE_SECURITY_TOKEN="[REPLACE]"
SALESFORCE_DOMAIN="test"

# Processing Configuration
STATE_TABLE_NAME="collaboratemd-state"
BATCH_SIZE="200"
LOG_LEVEL="INFO"

# Optional
SALESFORCE_API_VERSION="58.0"
RETRY_MAX_ATTEMPTS="3"
RETRY_BACKOFF_SECONDS="5"
```

**AWS CLI Command:**
```bash
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables="{
    COLLABORATEMD_USERNAME='nicolasmd',
    COLLABORATEMD_PASSWORD='Nic@2024!',
    COLLABORATEMD_API_BASE_URL='https://ws.collaboratemd.com/api/v1',
    COLLABORATEMD_REPORT_ID='10060198',
    COLLABORATEMD_FILTER_ID='10060198',
    SALESFORCE_USERNAME='[REPLACE]@firststepbh.com.dev',
    SALESFORCE_PASSWORD='[REPLACE]',
    SALESFORCE_SECURITY_TOKEN='[REPLACE]',
    SALESFORCE_DOMAIN='test',
    STATE_TABLE_NAME='collaboratemd-state',
    BATCH_SIZE='200',
    LOG_LEVEL='INFO'
  }" \
  --region us-east-1
```

---

## 8. Salesforce Custom Object: Integration_Log__c

### Field Definitions

This custom object needs to be created manually in Salesforce before running the integration.

**Object Settings:**
- **Label:** Integration Log
- **Plural Label:** Integration Logs
- **Object Name:** Integration_Log
- **Record Name Label:** Log Number
- **Data Type:** Auto Number
- **Display Format:** IL-{00000}
- **Starting Number:** 1

**Custom Fields:**

| Field Label | API Name | Data Type | Length/Precision | Required | Description |
|-------------|----------|-----------|-----------------|----------|-------------|
| Integration Type | `Integration_Type__c` | Text | 100 | No | Source of integration (e.g., "Claims Sync") |
| Status | `Status__c` | Picklist | - | No | Success, Error, Warning, Info |
| Request Payload | `Request_Payload__c` | Long Text Area | 32,000 | No | Input data (JSON) |
| Response Payload | `Response_Payload__c` | Long Text Area | 32,000 | No | Output data (JSON) |
| Error Message | `Error_Message__c` | Long Text Area | 5,000 | No | Error details and stack trace |
| Timestamp | `Timestamp__c` | Date/Time | - | No | When log was created |
| Related Record ID | `Related_Record_Id__c` | Text | 18 | No | Salesforce record ID (if applicable) |
| Source System | `Source_System__c` | Text | 100 | No | Source system name |
| Target System | `Target_System__c` | Text | 100 | No | Target system name |
| Duration (ms) | `Duration_MS__c` | Number | 18,0 | No | Execution time in milliseconds |
| Records Processed | `Records_Processed__c` | Number | 18,0 | No | Count of records processed |

**Status Picklist Values:**
- Success
- Error
- Warning
- Info

**Page Layout:**
- Make all fields visible
- Set as read-only for standard users
- Create custom tab for easy access

**List Views:**
- Recent Logs (last 7 days)
- Errors Only
- Today's Logs
- By Integration Type

**Creation Steps:**
1. Setup → Object Manager → Create → Custom Object
2. Fill in object details
3. Save
4. Add custom fields one by one
5. Create page layout
6. Set field-level security
7. Create custom tab (optional)

---

## 9. Security Best Practices

### ✅ DO:
- Store credentials in AWS Secrets Manager (recommended)
- Rotate credentials regularly (every 90 days)
- Use IAM roles instead of IAM users when possible
- Enable MFA on all accounts
- Use least-privilege access
- Monitor CloudWatch Logs for suspicious activity
- Encrypt sensitive data at rest and in transit

### ❌ DON'T:
- Hardcode credentials in source code
- Commit credentials to Git repositories
- Share credentials via email or chat
- Use the same password across systems
- Leave default permissions on S3 buckets or databases
- Disable SSL/TLS verification

### Credential Rotation Schedule:

| Credential Type | Rotation Frequency | Method |
|----------------|-------------------|---------|
| Salesforce Password | Every 90 days | Manual (Salesforce settings) |
| Salesforce Security Token | When password changes | Automatic (emailed) |
| CollaborateMD Password | Every 90 days | Contact CollaborateMD admin |
| AWS Access Keys | Every 90 days | IAM console |
| Lambda Environment Vars | After rotation | AWS CLI or console update |

---

## 10. Credential Checklist

Use this checklist before deployment:

### Pre-Deployment Verification

- [ ] AWS credentials tested and working
- [ ] AWS user has required permissions (Lambda, DynamoDB, IAM)
- [ ] Salesforce username includes `.dev` suffix (for sandbox)
- [ ] Salesforce password is correct
- [ ] Salesforce security token obtained and valid
- [ ] Salesforce user has API access enabled
- [ ] Salesforce user has required permissions (Modify All Data)
- [ ] CollaborateMD username is correct
- [ ] CollaborateMD password is correct
- [ ] CollaborateMD API accessible (test curl)
- [ ] CollaborateMD Report ID exists and accessible
- [ ] EC2 SSH key file has correct permissions (400)
- [ ] DynamoDB table name matches environment variable
- [ ] All environment variables spelled correctly (no typos)

### Post-Deployment Verification

- [ ] Lambda can authenticate to CollaborateMD
- [ ] Lambda can authenticate to Salesforce
- [ ] Lambda can read/write to DynamoDB
- [ ] CloudWatch Logs show successful execution
- [ ] No credential errors in logs
- [ ] Integration_Log__c records created in Salesforce
- [ ] Claims data synced successfully

---

## 11. Quick Reference Card

**Keep this handy during deployment:**

```
┌────────────────────────────────────────────────────────────┐
│                  QUICK CREDENTIAL REFERENCE                 │
├────────────────────────────────────────────────────────────┤
│ AWS Account ID: 248189924154                                │
│ AWS Region: us-east-1                                       │
│                                                              │
│ Salesforce Sandbox: firststepbh--dev.sandbox...            │
│ Salesforce Login: https://test.salesforce.com              │
│                                                              │
│ CollaborateMD API: https://ws.collaboratemd.com/api/v1     │
│ CollaborateMD Username: nicolasmd                           │
│                                                              │
│ EC2 Instance: i-083968dabdd297425                           │
│ EC2 Public IP: 34.225.81.96                                │
│ EC2 User: ubuntu                                            │
│                                                              │
│ DynamoDB Table: collaboratemd-state                         │
│ Lambda Function: collaboratemd-salesforce-sync              │
│                                                              │
│ Project Path: /home/ubuntu/collaboratemd-salesforce-...    │
│ Deployment Packages:                                        │
│   - lambda_deployment_verified.zip                          │
│   - salesforce/force-app/                                   │
└────────────────────────────────────────────────────────────┘
```

---

## 12. Troubleshooting Credential Issues

### Error: "INVALID_LOGIN: Invalid username, password, security token"

**Check:**
1. Username has `.dev` suffix for sandbox
2. Password is correct
3. Security token is appended (no space)
4. No typos in environment variables
5. IP restrictions in Salesforce

**Test:**
```python
from simple_salesforce import Salesforce
try:
    sf = Salesforce(
        username='test@example.com.dev',
        password='password',
        security_token='token',
        domain='test'
    )
    print("Success!")
except Exception as e:
    print(f"Error: {e}")
```

### Error: "AccessDeniedException" (AWS)

**Check:**
1. AWS credentials are correct
2. IAM user/role has required permissions
3. Resource is in correct region
4. Resource exists

**Test:**
```bash
aws sts get-caller-identity
aws lambda list-functions --region us-east-1
```

### Error: "Authentication failed" (CollaborateMD)

**Check:**
1. Username is correct
2. Password is correct (may have special characters)
3. API URL is correct
4. Network connectivity

**Test:**
```bash
curl -X POST https://ws.collaboratemd.com/api/v1/authentication/login \
  -H "Content-Type: application/json" \
  -d '{"username":"nicolasmd","password":"Nic@2024!"}' \
  -v
```

---

## 13. Emergency Contacts

**If credentials are compromised:**

1. **Immediately:**
   - Rotate all affected credentials
   - Check CloudWatch Logs for unauthorized access
   - Review Salesforce Login History
   - Disable compromised API keys

2. **Contact:**
   - AWS Support (for AWS resources)
   - Salesforce Support (for Salesforce access)
   - CollaborateMD Support (for API access)
   - Internal security team

3. **Review:**
   - All recent integration logs
   - Data access patterns
   - Unusual API calls

---

**Document Version:** 1.0  
**Last Updated:** November 5, 2024  
**Classification:** CONFIDENTIAL - Handle with care
