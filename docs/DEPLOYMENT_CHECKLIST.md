# Deployment Checklist

## Pre-Deployment Verification ✅

### 1. CollaborateMD Setup
- [ ] Have CollaborateMD username and password
- [ ] Have 8-digit customer number
- [ ] Have Report Sequence ID (from CollaborateMD Reports UI)
- [ ] Have Filter Sequence ID (from saved filter in CollaborateMD)
- [ ] Verified API access is enabled for your account
- [ ] Tested report runs successfully in CollaborateMD UI

### 2. Salesforce Setup
- [ ] Have Salesforce username
- [ ] Have Salesforce password
- [ ] Have Salesforce security token (or know how to get it)
- [ ] Verified Claims__c object exists with all required fields
- [ ] Verified Claim_Payor__c object exists
- [ ] API access is enabled for your Salesforce user
- [ ] User has permissions on Claims__c object

### 3. AWS Setup
- [ ] AWS CLI installed and configured
- [ ] Have AWS account credentials
- [ ] Can create Lambda functions
- [ ] Can create DynamoDB tables
- [ ] Can create IAM roles
- [ ] Selected target AWS region (e.g., us-east-1)

## Deployment Steps

### Step 1: Download and Configure (5 minutes)
```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware

# Copy environment template
cp .env.example .env

# Edit with your credentials
nano .env
```

**Required Variables:**
- COLLABORATE_MD_USERNAME
- COLLABORATE_MD_PASSWORD
- COLLABORATE_MD_CUSTOMER
- COLLABORATE_MD_REPORT_SEQ
- COLLABORATE_MD_FILTER_SEQ
- SALESFORCE_INSTANCE_URL
- SALESFORCE_USERNAME
- SALESFORCE_PASSWORD
- SALESFORCE_SECURITY_TOKEN

### Step 2: Deploy Infrastructure (5 minutes)
```bash
# Automated deployment
./scripts/create_lambda.sh

# Or update existing function
./scripts/deploy.sh
```

### Step 3: Configure Lambda Environment (2 minutes)
```bash
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables='{
    "COLLABORATE_MD_USERNAME":"YOUR_USERNAME",
    "COLLABORATE_MD_PASSWORD":"YOUR_PASSWORD",
    "COLLABORATE_MD_CUSTOMER":"10001001",
    "COLLABORATE_MD_REPORT_SEQ":"10001234",
    "COLLABORATE_MD_FILTER_SEQ":"10004321",
    "SALESFORCE_INSTANCE_URL":"https://your-instance.salesforce.com",
    "SALESFORCE_USERNAME":"YOUR_SF_USER",
    "SALESFORCE_PASSWORD":"YOUR_SF_PASS",
    "SALESFORCE_SECURITY_TOKEN":"YOUR_TOKEN",
    "BATCH_SIZE":"200",
    "LOG_LEVEL":"INFO"
  }' \
  --region us-east-1
```

### Step 4: Test First Sync (2 minutes)
```bash
# Run test
./scripts/test_lambda.sh

# Check response
cat /tmp/lambda-response.json
```

### Step 5: Verify in Salesforce (2 minutes)
- [ ] Log into Salesforce
- [ ] Navigate to Claims__c object
- [ ] Verify new records were created
- [ ] Check field values are populated correctly

### Step 6: Set Up Scheduling (3 minutes)
```bash
# Daily at 2 AM UTC
aws events put-rule \
  --name "collaboratemd-daily-sync" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --region us-east-1

# Replace ACCOUNT_ID with your AWS account ID
aws events put-targets \
  --rule "collaboratemd-daily-sync" \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT_ID:function:collaboratemd-salesforce-sync" \
  --region us-east-1

# Grant permission
aws lambda add-permission \
  --function-name collaboratemd-salesforce-sync \
  --statement-id "EventBridgeInvoke" \
  --action "lambda:InvokeFunction" \
  --principal events.amazonaws.com \
  --source-arn "arn:aws:events:us-east-1:ACCOUNT_ID:rule/collaboratemd-daily-sync"
```

## Post-Deployment Verification

### 1. CloudWatch Logs
```bash
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow
```
- [ ] Logs show successful execution
- [ ] No ERROR level messages
- [ ] Claims were fetched
- [ ] Claims were transformed
- [ ] Claims were upserted to Salesforce

### 2. DynamoDB State
```bash
aws dynamodb get-item \
  --table-name collaboratemd-sync-state \
  --key '{"sync_id": {"S": "default"}}' \
  --region us-east-1
```
- [ ] Table exists
- [ ] Last sync timestamp is recorded
- [ ] Statistics show successful records

### 3. Salesforce Verification
- [ ] Claims__c records exist
- [ ] Claim_Number__c is populated
- [ ] DOS__c dates are correct
- [ ] Amounts are correct (Charged_Amount__c, Paid_Amount__c)
- [ ] Claim_Payor__c lookups are resolved
- [ ] Paid_Y_or_N__c is set correctly

### 4. Test Incremental Sync
```bash
# Run again - should only process new/modified claims
aws lambda invoke \
  --function-name collaboratemd-salesforce-sync \
  --payload '{"full_sync": false}' \
  response.json
```
- [ ] Second run completes faster
- [ ] Only new claims are processed
- [ ] Existing claims are not duplicated

## Monitoring Setup

### CloudWatch Alarms
```bash
# Create alarm for errors
aws cloudwatch put-metric-alarm \
  --alarm-name "CollaborateMD-Sync-Errors" \
  --alarm-description "Alert on Lambda errors" \
  --metric-name Errors \
  --namespace AWS/Lambda \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold \
  --evaluation-periods 1 \
  --dimensions Name=FunctionName,Value=collaboratemd-salesforce-sync
```

### Log Insights Queries
```sql
-- View all error messages
fields @timestamp, @message
| filter @message like /ERROR/
| sort @timestamp desc
| limit 20

-- View sync statistics
fields @timestamp, @message
| filter @message like /Sync completed/
| sort @timestamp desc
| limit 10
```

## Troubleshooting

### Lambda Times Out
```bash
# Increase timeout to 15 minutes
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --timeout 900 \
  --region us-east-1
```

### Memory Issues
```bash
# Increase memory to 1024 MB
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --memory-size 1024 \
  --region us-east-1
```

### Authentication Errors
- Verify all credentials in environment variables
- Check Salesforce security token is current
- Ensure CollaborateMD API access is enabled

### No Claims Fetched
- Verify Report Seq and Filter Seq are correct
- Check report in CollaborateMD UI has data
- Try force full sync: `{"full_sync": true}`

## Success Criteria ✅

- [ ] Lambda function deploys successfully
- [ ] First sync completes without errors
- [ ] Claims appear in Salesforce
- [ ] Incremental sync works (only new claims)
- [ ] DynamoDB state is updated
- [ ] CloudWatch logs show detailed execution
- [ ] Scheduled sync is configured
- [ ] Monitoring alarms are set up

## Support

- **Documentation**: See README.md for detailed info
- **Quick Start**: See QUICKSTART.md for fast deployment
- **CloudWatch Logs**: Check for detailed error messages
- **DynamoDB State**: Check sync_id = "default" for statistics

---

**Estimated Total Deployment Time**: 20-30 minutes

**Next Steps After Deployment**:
1. Monitor first few scheduled runs
2. Adjust batch size if needed
3. Set up additional alarms
4. Review sync statistics in DynamoDB
5. Train team on monitoring dashboards

✅ **Deployment Complete!**
