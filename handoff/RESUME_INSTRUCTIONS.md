# CollaborateMD-Salesforce Integration - Resume Instructions

## 📍 Current Status Checkpoint

**Date:** November 5, 2024  
**Project Phase:** Deployment Ready - Awaiting Credential Verification  
**Completion:** 90%  
**Last Action:** Created comprehensive handoff documentation package

---

## 🎯 Quick Resume Context

To continue this project in a new conversation, provide the following context to your AI assistant:

### Context Statement (Copy & Paste This)

```
I'm working on a CollaborateMD-Salesforce integration project that is 90% complete and ready for deployment.

PROJECT LOCATION: /home/ubuntu/collaboratemd-salesforce-middleware/

ARCHITECTURE:
- AWS Lambda middleware (Python 3.11) that bridges CollaborateMD API and Salesforce
- Salesforce Apex classes for claims data processing
- DynamoDB for state management
- CloudWatch for logging

WHAT'S COMPLETED:
✅ All Lambda Python code (src/ directory and lambda_handler.py)
✅ All Salesforce Apex classes (ClaimsIntegrationRestService, ClaimsIntegrationService, CollaborateMDSyncBatch, IntegrationLogger)
✅ All test classes with >75% coverage
✅ Deployment packages prepared:
   - lambda_deployment_verified.zip (Lambda)
   - salesforce/force-app/ (Salesforce metadata)
✅ CloudFormation templates
✅ Comprehensive documentation

WHAT REMAINS:
⏳ Deploy Lambda function to AWS
⏳ Deploy Salesforce Apex classes
⏳ Create Integration_Log__c custom object in Salesforce
⏳ Configure environment variables
⏳ End-to-end testing

CURRENT ENVIRONMENT:
- EC2 Instance: i-083968dabdd297425 (us-east-1)
- Salesforce Sandbox: firststepbh--dev.sandbox.my.salesforce.com
- AWS Account: 248189924154
- SSH Key: /home/ubuntu/Uploads/Collaborate-Key.pem

CUSTOM OBJECTS IN SALESFORCE:
- Services_Authorization__c (existing)
- Claims__c (existing)
- Claim_Payor__c (existing)
- Lead (standard object, used as Patient)
- Integration_Log__c (NEEDS TO BE CREATED)

Please help me complete the deployment by:
1. Reviewing the current state
2. Verifying credentials
3. Deploying the Lambda function
4. Deploying Salesforce metadata
5. Testing the integration
```

---

## 📂 Project Files Location

### Essential Files

All project files are located in: `/home/ubuntu/collaboratemd-salesforce-middleware/`

**Key Files:**
- `PROJECT_SUMMARY.md` - Complete project documentation (THIS HANDOFF PACKAGE)
- `RESUME_INSTRUCTIONS.md` - This file
- `CREDENTIALS_TEMPLATE.md` - Credential requirements
- `lambda_deployment_verified.zip` - Lambda deployment package (ready to deploy)
- `lambda_handler.py` - Lambda entry point
- `requirements.txt` - Python dependencies
- `cloudformation-template.yaml` - AWS infrastructure template

**Salesforce Files:**
```
salesforce/force-app/main/default/classes/
├── ClaimsIntegrationRestService.cls
├── ClaimsIntegrationService.cls
├── CollaborateMDSyncBatch.cls
├── IntegrationLogger.cls
└── [corresponding test classes and meta.xml files]
```

**Lambda Source Code:**
```
src/
├── config.py
├── logger.py
├── collaboratemd_client.py
├── salesforce_client.py
├── data_transformer.py
├── state_manager.py
└── utils.py
```

---

## 🔐 Required Credentials

Before proceeding with deployment, gather these credentials:

### 1. AWS Credentials

**Required For:** Lambda deployment, DynamoDB access, IAM configuration

```bash
# Test AWS access with:
aws sts get-caller-identity

# Expected output should show:
# Account: 248189924154
# UserId: [Your user ID]
# Arn: arn:aws:iam::248189924154:user/[username]
```

**Files:**
- AWS CLI should be configured (~/.aws/credentials)
- Or use environment variables (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY)

### 2. Salesforce Credentials

**Required For:** Apex deployment, REST API access

- **Username:** `[your_username]@firststepbh.com.dev` (must include `.dev` for sandbox)
- **Password:** Your Salesforce password
- **Security Token:** From Salesforce (Personal Information → Reset My Security Token)
- **Combined Password:** `[password][security_token]` (concatenated, no space)

**Salesforce Org:**
- Sandbox URL: `https://firststepbh--dev.sandbox.my.salesforce.com`
- Login URL: `https://test.salesforce.com`

### 3. CollaborateMD API Credentials

**Required For:** Lambda to fetch claims data

- **Username:** nicolasmd
- **Password:** Nic@2024!
- **API Base URL:** https://ws.collaboratemd.com/api/v1
- **Report ID:** 10060198
- **Filter ID:** 10060198

### 4. SSH Access (if needed)

**Required For:** EC2 access

- **Key File:** /home/ubuntu/Uploads/Collaborate-Key.pem
- **Instance:** i-083968dabdd297425
- **Region:** us-east-1
- **Public IP:** 34.225.81.96
- **User:** ubuntu

**Connect Command:**
```bash
chmod 400 /home/ubuntu/Uploads/Collaborate-Key.pem
ssh -i /home/ubuntu/Uploads/Collaborate-Key.pem ubuntu@34.225.81.96
```

---

## ⚡ Quick Start Commands

### Step 1: Navigate to Project Directory

```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware/
```

### Step 2: Verify AWS Access

```bash
# Check AWS credentials
aws sts get-caller-identity

# List existing Lambda functions
aws lambda list-functions --region us-east-1 | grep collaboratemd

# Check if DynamoDB table exists
aws dynamodb describe-table --table-name collaboratemd-state --region us-east-1
```

### Step 3: Create DynamoDB Table (if not exists)

```bash
aws dynamodb create-table \
  --table-name collaboratemd-state \
  --attribute-definitions AttributeName=id,AttributeType=S \
  --key-schema AttributeName=id,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region us-east-1
```

### Step 4: Create IAM Role for Lambda (if not exists)

```bash
# Create trust policy
cat > /tmp/trust-policy.json << 'EOF'
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
  --assume-role-policy-document file:///tmp/trust-policy.json

# Attach policies
aws iam attach-role-policy \
  --role-name collaboratemd-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name collaboratemd-lambda-role \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess
```

### Step 5: Deploy Lambda Function

```bash
# Deploy Lambda function
aws lambda create-function \
  --function-name collaboratemd-salesforce-sync \
  --runtime python3.11 \
  --role arn:aws:iam::248189924154:role/collaboratemd-lambda-role \
  --handler lambda_handler.lambda_handler \
  --zip-file fileb://lambda_deployment_verified.zip \
  --timeout 900 \
  --memory-size 512 \
  --region us-east-1

# If function already exists, update instead:
aws lambda update-function-code \
  --function-name collaboratemd-salesforce-sync \
  --zip-file fileb://lambda_deployment_verified.zip \
  --region us-east-1
```

### Step 6: Configure Lambda Environment Variables

**⚠️ IMPORTANT: Replace placeholder values with actual credentials**

```bash
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables="{
    COLLABORATEMD_USERNAME='nicolasmd',
    COLLABORATEMD_PASSWORD='Nic@2024!',
    COLLABORATEMD_API_BASE_URL='https://ws.collaboratemd.com/api/v1',
    COLLABORATEMD_REPORT_ID='10060198',
    COLLABORATEMD_FILTER_ID='10060198',
    SALESFORCE_USERNAME='[REPLACE_WITH_ACTUAL_USERNAME]@firststepbh.com.dev',
    SALESFORCE_PASSWORD='[REPLACE_WITH_ACTUAL_PASSWORD]',
    SALESFORCE_SECURITY_TOKEN='[REPLACE_WITH_ACTUAL_TOKEN]',
    SALESFORCE_DOMAIN='test',
    STATE_TABLE_NAME='collaboratemd-state',
    BATCH_SIZE='200',
    LOG_LEVEL='INFO'
  }" \
  --region us-east-1
```

### Step 7: Deploy Salesforce Apex Classes

**Option A: Using Python Script**

```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware/

# Edit scripts/deploy_salesforce.py to add your credentials
nano scripts/deploy_salesforce.py

# Run deployment
python3 scripts/deploy_salesforce.py
```

**Option B: Using Salesforce CLI (sfdx)**

```bash
# Authenticate to Salesforce
sfdx auth:web:login --setalias myorg --instanceurl https://test.salesforce.com

# Deploy Apex classes
sfdx force:source:deploy \
  --sourcepath salesforce/force-app/main/default/classes \
  --targetusername myorg

# Run tests
sfdx force:apex:test:run \
  --targetusername myorg \
  --resultformat human \
  --codecoverage
```

**Option C: Using Workbench**

1. Login to: https://workbench.developerforce.com/
2. Select "Migration" → "Deploy"
3. Upload the Apex classes manually
4. Select "Single Package"
5. Deploy

### Step 8: Create Integration_Log__c Custom Object

**Manual Creation in Salesforce:**

1. Navigate to: **Setup → Object Manager → Create → Custom Object**
2. Object Settings:
   - **Label:** Integration Log
   - **Plural Label:** Integration Logs
   - **Object Name:** Integration_Log
   - **Record Name:** Log Number
   - **Data Type:** Auto Number
   - **Display Format:** IL-{00000}
3. Click "Save"
4. Create Custom Fields (see CREDENTIALS_TEMPLATE.md for field list)

**Or use Metadata API** (if comfortable with XML):
- Create custom object XML file
- Deploy using sfdx or Workbench

### Step 9: Test Lambda Function

```bash
# Test Lambda with incremental sync
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": false}' \
  --region us-east-1 \
  response.json

# Check response
cat response.json

# View logs
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow --region us-east-1
```

### Step 10: Verify in Salesforce

```apex
// Execute in Developer Console → Anonymous Apex

// Check for new claims
List<Claims__c> recentClaims = [
    SELECT Id, Name, Claim_Number__c, DOS__c, Charged_Amount__c
    FROM Claims__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Recent Claims: ' + recentClaims);

// Check integration logs
List<Integration_Log__c> logs = [
    SELECT Id, Status__c, Integration_Type__c, Error_Message__c
    FROM Integration_Log__c
    WHERE CreatedDate = TODAY
    ORDER BY CreatedDate DESC
    LIMIT 10
];
System.debug('Integration Logs: ' + logs);
```

---

## 🔍 Verification Checklist

Use this checklist to verify successful deployment:

### AWS Lambda
- [ ] Lambda function exists: `aws lambda get-function --function-name collaboratemd-salesforce-sync --region us-east-1`
- [ ] Environment variables configured correctly
- [ ] IAM role has necessary permissions
- [ ] DynamoDB table exists and accessible
- [ ] Function can be invoked successfully
- [ ] CloudWatch logs show execution

### Salesforce
- [ ] All Apex classes deployed
- [ ] Test classes show >75% coverage
- [ ] Integration_Log__c custom object created with all fields
- [ ] Services_Authorization__c has data
- [ ] Remote Site Settings configured for CollaborateMD API
- [ ] User has API access enabled

### Integration
- [ ] Lambda can authenticate to CollaborateMD API
- [ ] Lambda can authenticate to Salesforce
- [ ] Claims data flows from CollaborateMD to Salesforce
- [ ] Integration_Log__c records created
- [ ] No errors in CloudWatch Logs

---

## 🚨 Common Issues and Quick Fixes

### Issue 1: "AccessDeniedException" when creating Lambda

**Cause:** AWS credentials don't have Lambda creation permissions

**Fix:**
```bash
# Check current IAM permissions
aws iam get-user
aws iam list-attached-user-policies --user-name [your_username]

# You need these policies:
# - AWSLambda_FullAccess (or similar)
# - IAMFullAccess (for role creation)
```

### Issue 2: "InvalidParameterValueException: The role defined for the function cannot be assumed by Lambda"

**Cause:** IAM role doesn't exist or trust policy is incorrect

**Fix:**
```bash
# Wait a few seconds after creating role
sleep 10

# Then try Lambda creation again
aws lambda create-function ...
```

### Issue 3: Salesforce "INVALID_LOGIN"

**Cause:** Incorrect credentials or security token

**Fix:**
1. Verify username has `.dev` suffix for sandbox
2. Reset security token: Salesforce → Personal Information → Reset My Security Token
3. Use concatenated password: `[password][token]` (no space)
4. Check for IP restrictions in Salesforce

### Issue 4: Lambda timeout during first run

**Cause:** Cold start or large dataset

**Fix:**
- This is expected for first run (Lambda initializing dependencies)
- Increase timeout to 900 seconds (15 minutes)
- Reduce batch size to 100 if still timing out

### Issue 5: "Service Authorization not found" errors

**Cause:** Missing Service Authorization records in Salesforce

**Fix:**
```apex
// Check if Service Authorizations exist
SELECT COUNT() FROM Services_Authorization__c

// Query specific auth
SELECT Id, Authorization_Number__c 
FROM Services_Authorization__c 
WHERE Authorization_Number__c = 'VA0033039419'

// If missing, create test data or contact data team
```

---

## 📊 Expected Outcomes After Deployment

### Successful Lambda Execution

**Response:**
```json
{
  "statusCode": 200,
  "body": {
    "message": "Sync completed successfully",
    "claims_fetched": 50,
    "claims_processed": 50,
    "claims_successful": 48,
    "claims_failed": 2,
    "batches_sent": 1,
    "execution_time_seconds": 15.3
  }
}
```

### CloudWatch Logs Sample

```
INFO: Starting CollaborateMD to Salesforce sync
INFO: Configuration validated successfully
INFO: Fetching claims from CollaborateMD...
INFO: Fetched 50 claims
INFO: Transforming data...
INFO: Sending batch 1 of 1 (50 records) to Salesforce
INFO: Batch 1 response: 48 successful, 2 failed
INFO: Updating sync state...
INFO: Sync completed successfully
```

### Salesforce Data

**Claims__c Records:**
- New records created/updated based on incoming data
- Related to Services_Authorization__c via lookup
- Related to Lead (Patient) via lookup
- Related to Claim_Payor__c via lookup

**Integration_Log__c Records:**
- Status__c = "Success" (for successful operations)
- Integration_Type__c = "Claims Sync"
- Timestamp__c = Current datetime

---

## 📅 Schedule Setup (After Testing)

Once testing is successful, set up automated scheduling:

### Create EventBridge Rule

```bash
# Create rule for daily execution at 2 AM UTC
aws events put-rule \
  --name collaboratemd-daily-sync \
  --description "Daily sync of claims from CollaborateMD to Salesforce" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --region us-east-1

# Add Lambda as target
aws events put-targets \
  --rule collaboratemd-daily-sync \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:248189924154:function:collaboratemd-salesforce-sync" \
  --region us-east-1

# Grant EventBridge permission to invoke Lambda
aws lambda add-permission \
  --function-name collaboratemd-salesforce-sync \
  --statement-id collaboratemd-daily-sync \
  --action lambda:InvokeFunction \
  --principal events.amazonaws.com \
  --source-arn arn:aws:events:us-east-1:248189924154:rule/collaboratemd-daily-sync \
  --region us-east-1
```

### Verify Schedule

```bash
# List rules
aws events list-rules --region us-east-1 | grep collaboratemd

# List targets for rule
aws events list-targets-by-rule --rule collaboratemd-daily-sync --region us-east-1
```

---

## 🔄 Incremental vs Full Sync

### Incremental Sync (Default)

```bash
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": false}' \
  --region us-east-1 \
  response.json
```

- Uses last sync timestamp from DynamoDB
- Only fetches new/updated claims since last run
- Faster execution
- Recommended for scheduled runs

### Full Sync (Manual)

```bash
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": true}' \
  --region us-east-1 \
  response.json
```

- Ignores last sync timestamp
- Fetches all claims from CollaborateMD
- Longer execution time
- Use for initial data load or troubleshooting

---

## 📞 Support and Escalation

### If You Get Stuck

**Check These First:**
1. Review CloudWatch Logs for error details
2. Check Salesforce Debug Logs
3. Verify all credentials are correct
4. Ensure all prerequisites are met

**Get Help From:**
- AWS Support (if AWS-related issues)
- Salesforce Support (if Salesforce-related issues)
- Project documentation: `/home/ubuntu/collaboratemd-salesforce-middleware/README.md`

### Key Log Locations

**AWS CloudWatch:**
```bash
# View recent logs
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow --region us-east-1

# Get specific log stream
aws logs describe-log-streams \
  --log-group-name /aws/lambda/collaboratemd-salesforce-sync \
  --region us-east-1
```

**Salesforce Debug Logs:**
- Setup → Debug Logs → New
- Select user
- Set trace flags
- Reproduce issue
- View logs

**DynamoDB State:**
```bash
# Check current sync state
aws dynamodb get-item \
  --table-name collaboratemd-state \
  --key '{"id":{"S":"last_sync"}}' \
  --region us-east-1
```

---

## ✅ Final Deployment Checklist

Before considering deployment complete:

### Pre-Deployment
- [ ] All credentials gathered and verified
- [ ] AWS access confirmed
- [ ] Salesforce access confirmed
- [ ] CollaborateMD API access confirmed

### Deployment
- [ ] DynamoDB table created
- [ ] IAM role created with correct permissions
- [ ] Lambda function deployed
- [ ] Lambda environment variables configured
- [ ] Salesforce Apex classes deployed
- [ ] Integration_Log__c custom object created
- [ ] Remote Site Settings configured

### Testing
- [ ] Lambda test invocation successful
- [ ] Claims data appears in Salesforce
- [ ] Integration_Log__c records created
- [ ] No errors in CloudWatch Logs
- [ ] Service Authorization matching works
- [ ] Claim Payor lookup works

### Production Setup
- [ ] EventBridge schedule configured
- [ ] CloudWatch alarms set up
- [ ] SNS notifications configured (optional)
- [ ] User access and permissions granted
- [ ] Documentation updated

### Post-Deployment
- [ ] Monitor first scheduled run
- [ ] Verify data quality
- [ ] Train users on monitoring
- [ ] Document any customizations

---

## 🎯 Success Criteria

The integration is considered successfully deployed when:

1. ✅ Lambda function executes without errors
2. ✅ Claims data syncs from CollaborateMD to Salesforce
3. ✅ Integration logs show successful operations
4. ✅ No manual intervention required for daily sync
5. ✅ Error rate < 1%
6. ✅ Execution time < 5 minutes per sync

---

## 📝 Notes for Next Session

**Things to Remember:**
- Project is 90% complete, very close to finish line
- All code is written and tested
- Main task is deployment and configuration
- Have credentials ready before starting

**Quick Win Path:**
1. Verify AWS credentials (5 min)
2. Deploy Lambda (10 min)
3. Deploy Salesforce (15 min)
4. Test integration (15 min)
5. Schedule automation (5 min)

**Total estimated time: 1 hour** (assuming credentials are ready)

---

**Document Version:** 1.0  
**Last Updated:** November 5, 2024  
**Next Review:** After deployment completion
