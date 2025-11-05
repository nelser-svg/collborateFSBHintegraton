# CollaborateMD Batch Job Execution Guide

## Quick Reference: How to Execute the "Create Face Sheet" Batch Job

---

## 🎯 Overview

The **CollaborateMDSyncBatch** class is a batchable Apex class that:
- Syncs claim data from CollaborateMD to Salesforce
- Creates face sheets for patients based on claim information
- Processes records in configurable batch sizes (default: 200)
- Logs all operations for audit and troubleshooting

---

## 🚀 Execution Methods

### Method 1: Schedule for Recurring Execution (Recommended)

**Via Setup UI:**
1. Log into Salesforce Sandbox
2. Navigate to: **Setup → Apex Classes**
3. Click **Schedule Apex**
4. Configure:
   - **Job Name:** `CollaborateMD Daily Sync`
   - **Apex Class:** Select `CollaborateMDSyncBatch`
   - **Frequency:** Choose your preference
     - Daily (recommended)
     - Weekly
     - Monthly
   - **Start Date:** Select start date
   - **Preferred Start Time:** Choose time (e.g., 2:00 AM)
5. Click **Save**

**Via Anonymous Apex:**
```apex
// Schedule to run daily at 2 AM
String cronExp = '0 0 2 * * ?';
String jobName = 'CollaborateMD Daily Sync';
System.schedule(jobName, cronExp, new CollaborateMDSyncBatch());
```

**Common Cron Expressions:**
- Daily at 2 AM: `0 0 2 * * ?`
- Every 6 hours: `0 0 0/6 * * ?`
- Weekdays at 9 AM: `0 0 9 ? * MON-FRI`
- Every Sunday at midnight: `0 0 0 ? * SUN`

### Method 2: Execute Immediately (One-Time)

**Via Developer Console:**
1. Open **Developer Console**
2. Click **Debug → Open Execute Anonymous Window**
3. Paste this code:
```apex
// Execute with default batch size (200)
Database.executeBatch(new CollaborateMDSyncBatch());

// Or specify custom batch size
Database.executeBatch(new CollaborateMDSyncBatch(), 100);
```
4. Click **Execute**
5. Check **Debug Logs** for execution status

**Via Workbench:**
1. Go to https://workbench.developerforce.com/
2. Login to your Sandbox
3. Navigate to: **utilities → Apex Execute**
4. Paste the code above
5. Click **Execute**

### Method 3: Execute via REST API

**Endpoint:**
```
POST /services/data/v59.0/tooling/executeAnonymous/
```

**Request Body:**
```json
{
  "anonymousBody": "Database.executeBatch(new CollaborateMDSyncBatch(), 200);"
}
```

**cURL Example:**
```bash
curl -X POST \
  https://test.salesforce.com/services/data/v59.0/tooling/executeAnonymous/ \
  -H "Authorization: Bearer YOUR_ACCESS_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"anonymousBody": "Database.executeBatch(new CollaborateMDSyncBatch(), 200);"}'
```

---

## 📊 Monitoring Batch Execution

### Check Batch Job Status

**Via Setup UI:**
1. Navigate to: **Setup → Apex Jobs**
2. Look for jobs with Class: `CollaborateMDSyncBatch`
3. Check:
   - Status (Queued, Processing, Completed, Failed)
   - Records Processed
   - Failures
   - Start/End Time

**Via SOQL Query:**
```apex
// Get recent batch jobs
List<AsyncApexJob> jobs = [
    SELECT Id, Status, NumberOfErrors, JobItemsProcessed, 
           TotalJobItems, CreatedDate, CompletedDate
    FROM AsyncApexJob 
    WHERE ApexClass.Name = 'CollaborateMDSyncBatch'
    ORDER BY CreatedDate DESC 
    LIMIT 10
];

for(AsyncApexJob job : jobs) {
    System.debug('Job ID: ' + job.Id);
    System.debug('Status: ' + job.Status);
    System.debug('Processed: ' + job.JobItemsProcessed + '/' + job.TotalJobItems);
    System.debug('Errors: ' + job.NumberOfErrors);
}
```

### Check Integration Logs

**Via SOQL Query:**
```apex
// Get recent integration logs
List<Integration_Log__c> logs = [
    SELECT Id, Operation__c, Status__c, Message__c, 
           Timestamp__c, Record_ID__c
    FROM Integration_Log__c 
    WHERE Operation__c = 'CollaborateMD Sync'
    ORDER BY Timestamp__c DESC 
    LIMIT 50
];

for(Integration_Log__c log : logs) {
    System.debug(log.Status__c + ': ' + log.Message__c);
}
```

**Via Reports:**
1. Create a custom report on Integration_Log__c
2. Filter by Operation = 'CollaborateMD Sync'
3. Group by Status
4. Add date filters as needed

---

## 🔧 Configuration Options

### Batch Size

The batch size determines how many records are processed in each batch:

```apex
// Small batch size (good for testing or complex processing)
Database.executeBatch(new CollaborateMDSyncBatch(), 50);

// Default batch size (balanced)
Database.executeBatch(new CollaborateMDSyncBatch(), 200);

// Large batch size (faster but uses more resources)
Database.executeBatch(new CollaborateMDSyncBatch(), 2000);
```

**Recommendations:**
- **Testing:** 10-50 records
- **Production:** 200-500 records
- **Large volumes:** 1000-2000 records (monitor governor limits)

### Query Filters

The batch job processes claims based on the query in the `start()` method. You can modify the class to add filters:

```apex
// Example: Only process claims from last 30 days
public Database.QueryLocator start(Database.BatchableContext bc) {
    Date thirtyDaysAgo = Date.today().addDays(-30);
    return Database.getQueryLocator([
        SELECT Id, Claim_Number__c, Patient_Name__c, Service_Date__c
        FROM Claims__c 
        WHERE Service_Date__c >= :thirtyDaysAgo
        AND Status__c != 'Processed'
    ]);
}
```

---

## 🐛 Troubleshooting

### Issue: Batch Job Not Starting

**Possible Causes:**
- Too many concurrent batch jobs (max 5)
- Insufficient permissions
- Class not deployed correctly

**Solutions:**
1. Check Apex Jobs: Setup → Apex Jobs
2. Wait for other jobs to complete
3. Verify user has "Run Batch Apex" permission
4. Redeploy the class if needed

### Issue: Batch Job Failing

**Check Debug Logs:**
1. Setup → Debug Logs
2. Create a new log for your user
3. Set log level to FINEST
4. Re-run the batch job
5. Review the log for errors

**Common Errors:**
- **UNABLE_TO_LOCK_ROW:** Reduce batch size or add retry logic
- **LIMIT_EXCEEDED:** Reduce batch size or optimize queries
- **FIELD_CUSTOM_VALIDATION_EXCEPTION:** Check validation rules on Claims__c

### Issue: Records Not Processing

**Verify Query:**
```apex
// Test the query in Developer Console
List<Claims__c> claims = [
    SELECT Id, Claim_Number__c, Patient_Name__c 
    FROM Claims__c 
    LIMIT 10
];
System.debug('Found ' + claims.size() + ' claims');
```

**Check Filters:**
- Ensure claims meet the query criteria
- Verify Status__c values
- Check date ranges

---

## 📈 Performance Optimization

### Best Practices

1. **Batch Size:**
   - Start with 200 and adjust based on processing time
   - Monitor governor limits in debug logs
   - Reduce if hitting limits, increase if processing is slow

2. **Query Optimization:**
   - Use selective filters (indexed fields)
   - Avoid querying unnecessary fields
   - Use LIMIT for testing

3. **Bulkification:**
   - The class already processes records in bulk
   - Avoid SOQL/DML inside loops
   - Use collections for database operations

4. **Error Handling:**
   - The class logs errors to Integration_Log__c
   - Failed records don't stop the entire batch
   - Review logs regularly for patterns

### Monitoring Metrics

Track these metrics to optimize performance:
- **Average processing time per batch**
- **Records processed per hour**
- **Error rate**
- **Governor limit usage**

---

## 🔄 Integration with AWS Lambda

The batch job works in conjunction with the AWS Lambda function:

**Flow:**
1. Lambda fetches data from CollaborateMD API
2. Lambda pushes data to Salesforce via REST API
3. Batch job processes the new/updated claims
4. Batch job creates face sheets
5. Integration logs track the entire process

**Coordination:**
- Lambda runs hourly (via EventBridge)
- Batch job runs daily (via Scheduled Apex)
- Both log to Integration_Log__c for audit trail

---

## 📋 Execution Checklist

Before running the batch job:
- [ ] Verify CollaborateMDSyncBatch class is deployed
- [ ] Confirm Integration_Log__c custom object exists
- [ ] Check Claims__c has required fields
- [ ] Ensure user has necessary permissions
- [ ] Review recent Integration_Log__c entries
- [ ] Check for any active batch jobs (max 5 concurrent)

After running the batch job:
- [ ] Check Apex Jobs for completion status
- [ ] Review Integration_Log__c for errors
- [ ] Verify face sheets were created
- [ ] Monitor system performance
- [ ] Document any issues or observations

---

## 📞 Quick Commands Reference

**Execute Batch Job:**
```apex
Database.executeBatch(new CollaborateMDSyncBatch(), 200);
```

**Schedule Batch Job:**
```apex
System.schedule('CollaborateMD Daily Sync', '0 0 2 * * ?', new CollaborateMDSyncBatch());
```

**Check Job Status:**
```apex
AsyncApexJob job = [SELECT Status, NumberOfErrors FROM AsyncApexJob WHERE Id = :jobId];
```

**Abort Scheduled Job:**
```apex
System.abortJob(jobId);
```

**Get All Scheduled Jobs:**
```apex
List<CronTrigger> jobs = [SELECT Id, CronJobDetail.Name, State FROM CronTrigger];
```

---

## 🎓 Additional Resources

- **Salesforce Batch Apex Guide:** https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_batch.htm
- **Scheduling Apex:** https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_scheduler.htm
- **Governor Limits:** https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/apex_gov_limits.htm

---

**Last Updated:** October 22, 2025  
**Class Name:** CollaborateMDSyncBatch  
**API Version:** 59.0
