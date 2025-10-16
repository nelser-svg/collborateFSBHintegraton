# Quick Start Guide

## 🚀 Get Started in 5 Minutes

### Prerequisites Checklist

- [ ] CollaborateMD API credentials (username, password, customer #)
- [ ] CollaborateMD Report Seq ID and Filter Seq ID
- [ ] Salesforce credentials (username, password, security token)
- [ ] AWS account with CLI configured
- [ ] Python 3.11+ installed

### Step 1: Configure Credentials (2 minutes)

```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware
cp .env.example .env
nano .env  # Edit with your credentials
```

### Step 2: Deploy to AWS (2 minutes)

```bash
# One command to create everything
./scripts/create_lambda.sh

# Update environment variables
aws lambda update-function-configuration \
  --function-name collaboratemd-salesforce-sync \
  --environment Variables="{
    COLLABORATE_MD_USERNAME=YOUR_USERNAME,
    COLLABORATE_MD_PASSWORD=YOUR_PASSWORD,
    COLLABORATE_MD_CUSTOMER=10001001,
    COLLABORATE_MD_REPORT_SEQ=10001234,
    COLLABORATE_MD_FILTER_SEQ=10004321,
    SALESFORCE_INSTANCE_URL=https://your-instance.salesforce.com,
    SALESFORCE_USERNAME=YOUR_SF_USERNAME,
    SALESFORCE_PASSWORD=YOUR_SF_PASSWORD,
    SALESFORCE_SECURITY_TOKEN=YOUR_SF_TOKEN,
    BATCH_SIZE=200,
    LOG_LEVEL=INFO
  }" \
  --region us-east-1
```

### Step 3: Test (1 minute)

```bash
./scripts/test_lambda.sh
```

### Step 4: Schedule Automatic Sync

```bash
# Run daily at 2 AM UTC
aws events put-rule \
  --name "collaboratemd-daily-sync" \
  --schedule-expression "cron(0 2 * * ? *)" \
  --region us-east-1

aws events put-targets \
  --rule "collaboratemd-daily-sync" \
  --targets "Id"="1","Arn"="arn:aws:lambda:us-east-1:ACCOUNT_ID:function:collaboratemd-salesforce-sync" \
  --region us-east-1
```

## 🎯 What Happens During Sync?

1. **Fetch**: Lambda fetches claims from CollaborateMD Reports API
2. **Filter**: Only new/modified claims since last sync (incremental)
3. **Transform**: Maps CollaborateMD fields to Salesforce Claims__c
4. **Upsert**: Sends to Salesforce in batches of 200 records
5. **Track**: Updates DynamoDB with sync timestamp

## 📊 Monitor Your Sync

View logs in CloudWatch:
```
https://console.aws.amazon.com/cloudwatch/home?region=us-east-1#logsV2:log-groups/log-group/$252Faws$252Flambda$252Fcollaboratemd-salesforce-sync
```

Check sync statistics in DynamoDB:
```bash
aws dynamodb get-item \
  --table-name collaboratemd-sync-state \
  --key '{"sync_id": {"S": "default"}}' \
  --region us-east-1
```

## 🐛 Troubleshooting

### Lambda times out
- Increase timeout: `--timeout 900` (15 minutes max)
- Increase memory: `--memory-size 1024`

### Authentication errors
- Verify credentials in environment variables
- Check CollaborateMD API access is enabled
- Ensure Salesforce security token is correct

### No claims fetched
- Verify Report Seq and Filter Seq IDs
- Check report has data in CollaborateMD UI
- Try force full sync: `{"full_sync": true}`

## 💡 Pro Tips

1. **Test locally first**: Use `python lambda_handler.py` before deploying
2. **Start with small date range**: Narrow filter to test with less data
3. **Monitor costs**: Check AWS billing for Lambda, DynamoDB usage
4. **Enable alarms**: Set up CloudWatch alarms for failures

## 📞 Need Help?

Refer to the main [README.md](README.md) for detailed documentation.
