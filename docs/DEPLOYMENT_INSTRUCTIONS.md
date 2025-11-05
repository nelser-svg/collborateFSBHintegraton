# 🚀 Salesforce Deployment Instructions

## 📦 Deployment Package Location

Your deployment package is ready and available in **two locations** for easy access:

1. **`/home/ubuntu/SALESFORCE_DEPLOYMENT_PACKAGE.zip`** ← **Use this one!**
2. `/home/ubuntu/deploy_repaired.zip` (backup copy)

---

## 📥 Step 1: Download the Deployment Package

### How to Download from DeepAgent:

1. Look at the **top-right corner** of the DeepAgent interface
2. Click the **"Files"** button (📁 icon)
3. Find and download: **`SALESFORCE_DEPLOYMENT_PACKAGE.zip`**
4. Save it to your local computer

---

## 🔐 Step 2: Salesforce Credentials

**Salesforce Login:**
- **Username:** `nelser`
- **Password:** `May052023!@#$%%`
- **Security Token:** `fim8TcSqCQKt97lHaQYKzDPj`

**Full Login String for API/Workbench:**
```
Password + Security Token: May052023!@#$%%fim8TcSqCQKt97lHaQYKzDPj
```

---

## ⚠️ CRITICAL: Pre-Deployment Requirement

### Create the Primary_Contact__c Field FIRST

**Before deploying the package**, you MUST create a custom field on the Account object:

1. Go to **Setup** → **Object Manager** → **Account**
2. Click **Fields & Relationships** → **New**
3. Create a **Lookup Relationship** field with these settings:
   - **Field Label:** `Primary Contact`
   - **Field Name:** `Primary_Contact__c`
   - **Related To:** `Contact`
   - **Field-Level Security:** Make visible to all profiles
   - **Page Layouts:** Add to relevant layouts

**Why?** The deployment package references this field, and deployment will fail if it doesn't exist.

---

## 🛠️ Step 3: Deploy Using Salesforce Workbench

### A. Access Workbench

1. Go to: **https://workbench.developerforce.com/**
2. Select **Environment:** `Production` (or `Sandbox` if testing)
3. Check **"I agree to the terms of service"**
4. Click **Login with Salesforce**
5. Enter credentials:
   - Username: `nelser`
   - Password: `May052023!@#$%%fim8TcSqCQKt97lHaQYKzDPj`

### B. Deploy the Package

1. In Workbench, go to: **migration** → **Deploy**
2. Click **Choose File** and select `SALESFORCE_DEPLOYMENT_PACKAGE.zip`
3. **Important Deployment Options:**
   - ✅ Check **"Rollback On Error"**
   - ✅ Check **"Single Package"**
   - ✅ Check **"Run All Tests"** (recommended for production)
   - OR ✅ Check **"Run Specified Tests"** and enter the test classes below
4. Click **Next** → **Deploy**

### C. Monitor Deployment

- Watch the deployment status in real-time
- Deployment typically takes 2-5 minutes
- You'll see a success message when complete

---

## 🧪 Step 4: Test Classes to Run

If you choose **"Run Specified Tests"**, enter these test class names:

```
CollaborateMDSyncBatchTest
IntegrationLoggerTest
ClaimsIntegrationRestServiceTest
ClaimsIntegrationServiceTest
```

**Expected Test Coverage:** All tests should pass with >75% code coverage

---

## 📋 What's Being Deployed

The package contains **8 Apex classes**:

### Core Integration Classes:
1. **`ClaimsIntegrationService`** - Main service for claims integration
2. **`ClaimsIntegrationRestService`** - REST API endpoint for claims
3. **`CollaborateMDSyncBatch`** - Batch job for syncing data
4. **`IntegrationLogger`** - Logging utility for integration events

### Test Classes:
5. **`ClaimsIntegrationServiceTest`**
6. **`ClaimsIntegrationRestServiceTest`**
7. **`CollaborateMDSyncBatchTest`**
8. **`IntegrationLoggerTest`**

---

## ✅ Step 5: Post-Deployment Verification

After successful deployment:

1. **Verify Classes Deployed:**
   - Go to **Setup** → **Apex Classes**
   - Search for "CollaborateMD" and "Claims"
   - Confirm all 8 classes are present

2. **Check Test Results:**
   - Go to **Setup** → **Apex Test Execution**
   - Verify all tests passed

3. **Verify REST Endpoint:**
   - The REST service will be available at:
   ```
   /services/apexrest/ClaimsIntegration
   ```

4. **Test the Integration:**
   - Run the batch job manually to test:
   ```apex
   Database.executeBatch(new CollaborateMDSyncBatch(), 200);
   ```

---

## 🔧 Troubleshooting

### Common Issues:

**Issue:** "Field Primary_Contact__c does not exist"
- **Solution:** Create the Primary_Contact__c lookup field on Account (see Step 2)

**Issue:** "Insufficient access rights"
- **Solution:** Ensure your user has "Modify All Data" permission or System Administrator profile

**Issue:** "Test failures"
- **Solution:** Check that all custom fields referenced in the code exist in your org

**Issue:** "Deployment timeout"
- **Solution:** Try deploying during off-peak hours or use "Quick Deploy" if tests already passed

---

## 📞 Need Help?

If you encounter issues during deployment:

1. Check the deployment log in Workbench for specific error messages
2. Verify all prerequisites are met (especially the Primary_Contact__c field)
3. Ensure you're using the correct credentials
4. Try deploying to a Sandbox first to test

---

## 🎯 Quick Deployment Checklist

- [ ] Downloaded `SALESFORCE_DEPLOYMENT_PACKAGE.zip` from Files section
- [ ] Created `Primary_Contact__c` field on Account object
- [ ] Logged into Salesforce Workbench
- [ ] Selected correct environment (Production/Sandbox)
- [ ] Uploaded deployment package
- [ ] Selected deployment options (Rollback On Error, Run Tests)
- [ ] Monitored deployment to completion
- [ ] Verified all classes deployed successfully
- [ ] Confirmed all tests passed
- [ ] Tested REST endpoint and batch job

---

**Package Version:** Repaired v1.0  
**Last Updated:** October 23, 2025  
**Package Size:** 20KB  
**Total Classes:** 8 (4 main + 4 test)
