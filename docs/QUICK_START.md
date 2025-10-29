# Quick Start Guide - CollaborateMD Salesforce Integration

## 🚀 Your Integration is LIVE!

The AWS Lambda function is deployed and ready to sync CollaborateMD claims to Salesforce.

---

## ⚡ Quick Actions

### 1. Test the Integration Now

```bash
aws lambda invoke \
    --function-name collaboratemd-salesforce-sync \
    --region us-east-1 \
    --cli-binary-format raw-in-base64-out \
    --payload '{"test_mode": false}' \
    response.json && cat response.json
```

### 2. Set Up Hourly Automatic Sync

```bash
# Create schedule (replace YOUR_ACCOUNT_ID with your AWS account number)
aws events put-rule \
    --name "CollaborateMD-Hourly-Sync" \
    --schedule-expression "rate(1 hour)" \
    --state ENABLED \
    --region us-east-1

aws events put-targets \
    --rule "CollaborateMD-Hourly-Sync" \
    --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:YOUR_ACCOUNT_ID:function:collaboratemd-salesforce-sync" \
    --region us-east-1

aws lambda add-permission \
    --function-name collaboratemd-salesforce-sync \
    --statement-id CollaborateMDHourlySync \
    --action 'lambda:InvokeFunction' \
    --principal events.amazonaws.com \
    --source-arn arn:aws:events:us-east-1:YOUR_ACCOUNT_ID:rule/CollaborateMD-Hourly-Sync \
    --region us-east-1
```

### 3. View Logs

```bash
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow --region us-east-1
```

---

## 📋 What You Need to Do

### ✅ Completed
- Lambda function deployed
- All credentials configured
- Integration tested

### ⏳ Your Action Required

1. **Deploy Salesforce Components** (30-60 minutes)
   - Open: `SALESFORCE_DEPLOYMENT_GUIDE.md`
   - Follow step-by-step instructions
   - Deploy Apex classes and objects

2. **Set Up Scheduled Sync** (5 minutes)
   - Use commands above
   - Choose your sync frequency

3. **Test End-to-End** (15 minutes)
   - Run Lambda function
   - Check Salesforce for new claims
   - Verify data accuracy

---

## 🔗 Important Links

- **Lambda Function:** https://console.aws.amazon.com/lambda/home?region=us-east-1#/functions/collaboratemd-salesforce-sync
- **CloudWatch Logs:** https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/$252Faws$252Flambda$252Fcollaboratemd-salesforce-sync
- **Salesforce Sandbox:** https://test.salesforce.com

---

## 📚 Documentation

- **Full Status Report:** `FINAL_DEPLOYMENT_STATUS.md`
- **Salesforce Guide:** `SALESFORCE_DEPLOYMENT_GUIDE.md`
- **Project README:** `README.md`

---

## 💡 Common Commands

```bash
# Test Lambda
aws lambda invoke --function-name collaboratemd-salesforce-sync --region us-east-1 --cli-binary-format raw-in-base64-out --payload '{}' out.json

# View recent logs
aws logs tail /aws/lambda/collaboratemd-salesforce-sync --follow --region us-east-1

# Check environment variables
aws lambda get-function-configuration --function-name collaboratemd-salesforce-sync --region us-east-1 --query 'Environment.Variables'

# List schedules
aws events list-rules --region us-east-1
```

---

**Status:** ✅ Ready for Use  
**Region:** us-east-1  
**Function:** collaboratemd-salesforce-sync
