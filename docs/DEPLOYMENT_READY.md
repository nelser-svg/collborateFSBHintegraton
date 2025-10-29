# CollaborateMD-Salesforce Integration - Ready for Deployment 🚀

**Status:** ✅ All deployment files prepared and ready  
**Date:** October 23, 2025  
**Prepared by:** DeepAgent - Abacus.AI

---

## 📦 What's Been Prepared

A complete AWS Lambda + API Gateway deployment package for CollaborateMD-Salesforce integration with multiple deployment options to suit your needs.

---

## 🎯 Quick Start - Choose Your Deployment Method

### Option 1: One-Command Deployment (Fastest) ⚡

```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware
chmod +x QUICK_DEPLOY.sh
./QUICK_DEPLOY.sh
```

**This will:**
- ✅ Deploy everything via CloudFormation
- ✅ Create Lambda function, API Gateway, IAM roles, Secrets Manager
- ✅ Test the deployment
- ✅ Give you the API Gateway URL for Salesforce

**Time:** 2-3 minutes

---

### Option 2: AWS CLI CloudFormation (Recommended for Production)

```bash
cd /home/ubuntu/collaboratemd-salesforce-middleware

aws cloudformation create-stack \
  --stack-name collaboratemd-salesforce-integration \
  --template-body file://cloudformation-template.yaml \
  --parameters \
    ParameterKey=CollaborateMDApiUrl,ParameterValue=https://ws.collaboratemd.com/api/v1 \
    ParameterKey=CollaborateMDUsername,ParameterValue=nicolasmd \
    ParameterKey=CollaborateMDPassword,ParameterValue='Nic@2024!' \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1

# Wait for completion
aws cloudformation wait stack-create-complete \
  --stack-name collaboratemd-salesforce-integration \
  --region us-east-1

# Get API Gateway URL
aws cloudformation describe-stacks \
  --stack-name collaboratemd-salesforce-integration \
  --region us-east-1 \
  --query 'Stacks[0].Outputs[?OutputKey==`ApiGatewayEndpoint`].OutputValue' \
  --output text
```

---

### Option 3: AWS Console (GUI) 🖱️

1. Go to AWS CloudFormation Console
2. Create Stack → Upload template
3. Upload: `cloudformation-template.yaml`
4. Follow the wizard
5. Get API URL from "Outputs" tab

**Detailed instructions:** See `aws_deployment_report.md` → "AWS Console Deployment"

---

## 📁 Deployment Files Overview

| File | Purpose |
|------|---------|
| **cloudformation-template.yaml** | Complete infrastructure as code - Lambda, API Gateway, IAM, Secrets Manager |
| **QUICK_DEPLOY.sh** | One-command deployment script with testing |
| **aws_deployment_report.md** | Comprehensive 200+ line deployment guide with all options |
| **aws_deploy_simplified.py** | Python deployment script (alternative to CloudFormation) |
| **lambda_handler.py** | Full Lambda function code with CollaborateMD integration |
| **lambda_handler_env.py** | Simplified Lambda handler using environment variables |

---

## 🔑 Critical Information

### AWS Credentials Note
The AWS credentials currently in use have limited IAM permissions. To deploy, you'll need credentials with permissions for:
- CloudFormation
- Lambda
- API Gateway
- IAM (create roles)
- Secrets Manager
- CloudWatch Logs

**The provided AWS Access Key (AKIATTSKFWMSPURY7YH3) returned an "InvalidClientTokenId" error.**

**Options:**
1. Use different AWS credentials with full permissions
2. Deploy from AWS Console with your AWS account
3. Generate new access keys from AWS IAM Console

---

## 🔗 What Gets Deployed

### AWS Resources:
1. **Lambda Function**
   - Name: `CollaborateMD-Salesforce-Integration`
   - Runtime: Python 3.11
   - Memory: 512 MB
   - Timeout: 60 seconds

2. **API Gateway HTTP API**
   - Name: `CollaborateMD-API`
   - Endpoints: 
     - POST /claims (trigger sync)
     - GET /status (check health)

3. **IAM Role**
   - Name: `CollaborateMDLambdaRole`
   - Permissions: Lambda execution + Secrets Manager access

4. **Secrets Manager Secret**
   - Name: `collaboratemd-credentials`
   - Contains: CollaborateMD API credentials (encrypted)

5. **CloudWatch Log Group**
   - Name: `/aws/lambda/CollaborateMD-Salesforce-Integration`

---

## 🎯 After Deployment: Salesforce Setup

**YOU MUST ADD THE API GATEWAY URL TO SALESFORCE**

Once deployed, you'll get an API Gateway URL like:
```
https://abc123xyz.execute-api.us-east-1.amazonaws.com
```

### Add to Salesforce:
1. Login to Salesforce
2. Go to Setup → Security → Remote Site Settings
3. Click "New Remote Site"
4. Fill in:
   - **Name:** `CollaborateMD_API`
   - **URL:** `https://your-api-gateway-url.amazonaws.com`
   - **Active:** ✓ Checked
5. Save

**Detailed Salesforce setup:** See `aws_deployment_report.md` → "Salesforce Integration Setup"

---

## 🧪 Testing Your Deployment

### Test 1: Lambda Function
```bash
aws lambda invoke \
  --function-name CollaborateMD-Salesforce-Integration \
  --payload '{"full_sync": false}' \
  --region us-east-1 \
  response.json

cat response.json
```

### Test 2: API Gateway
```bash
# Replace <API_URL> with your API Gateway endpoint
curl -X POST https://<API_URL>/claims \
  -H "Content-Type: application/json" \
  -d '{"full_sync": false}'
```

### Test 3: From Salesforce
```apex
HttpRequest req = new HttpRequest();
req.setEndpoint('https://<YOUR_API_URL>/claims');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setBody('{"full_sync": false}');

Http http = new Http();
HttpResponse res = http.send(req);
System.debug('Response: ' + res.getBody());
```

---

## 📊 Monitoring

### View Lambda Logs
```bash
aws logs tail /aws/lambda/CollaborateMD-Salesforce-Integration --follow
```

### View Lambda Metrics
```bash
# AWS Console
https://console.aws.amazon.com/lambda/

# Navigate to: CollaborateMD-Salesforce-Integration → Monitoring
```

### View API Gateway Metrics
```bash
# AWS Console
https://console.aws.amazon.com/apigateway/
```

---

## 🔄 Updating the Deployment

### Update Lambda Code
```bash
aws lambda update-function-code \
  --function-name CollaborateMD-Salesforce-Integration \
  --zip-file fileb://lambda_deployment_simple.zip \
  --region us-east-1
```

### Update CloudFormation Stack
```bash
aws cloudformation update-stack \
  --stack-name collaboratemd-salesforce-integration \
  --template-body file://cloudformation-template.yaml \
  --capabilities CAPABILITY_NAMED_IAM \
  --region us-east-1
```

---

## 🗑️ Cleanup / Delete Everything

### Delete CloudFormation Stack (Removes Everything)
```bash
aws cloudformation delete-stack \
  --stack-name collaboratemd-salesforce-integration \
  --region us-east-1
```

---

## 📚 Documentation

### Primary Documents:
1. **aws_deployment_report.md** - 200+ line comprehensive guide
   - All deployment methods
   - Troubleshooting
   - Cost estimates
   - API documentation
   - Complete reference

2. **This file (DEPLOYMENT_READY.md)** - Quick reference

3. **QUICK_DEPLOY.sh** - Automated deployment script

4. **cloudformation-template.yaml** - Infrastructure definition

---

## 💰 Cost Estimate

**Monthly Cost (estimated):**
- Lambda: $0.00 - $0.50 (within free tier for typical usage)
- API Gateway: $0.00 - $0.10 (within free tier)
- Secrets Manager: $0.40
- CloudWatch Logs: $0.00 - $0.50

**Total: ~$1-2 per month** (mostly within AWS free tier)

---

## ⚠️ Important Notes

1. **Credentials:** The CollaborateMD credentials are:
   - Stored encrypted in AWS Secrets Manager
   - Also in Lambda environment variables (encrypted at rest)
   
2. **Security:** 
   - IAM role has minimal required permissions
   - CORS enabled for Salesforce integration
   - All traffic over HTTPS

3. **Scalability:**
   - Lambda automatically scales
   - No server management needed
   - Pay only for what you use

4. **Backup:**
   - CloudFormation template = infrastructure backup
   - Can redeploy anytime
   - Version control recommended

---

## 🆘 Getting Help

### Common Issues:

**"InvalidClientTokenId"**
- AWS credentials are invalid/expired
- Solution: Generate new credentials in AWS IAM Console

**"AccessDenied"**
- AWS credentials lack required permissions
- Solution: Use credentials with CloudFormation, Lambda, IAM permissions

**"Stack already exists"**
- Stack name is taken
- Solution: Use `update-stack` or delete existing stack first

**CORS errors from Salesforce**
- API Gateway URL not in Salesforce Remote Site Settings
- Solution: Follow Salesforce setup instructions above

### Full Troubleshooting Guide:
See `aws_deployment_report.md` → "Troubleshooting" section

---

## ✅ Pre-Deployment Checklist

Before deploying, verify you have:

- [ ] AWS account access
- [ ] AWS credentials with required permissions
- [ ] AWS CLI installed (for CLI deployment)
- [ ] `jq` installed (for QUICK_DEPLOY.sh script)
- [ ] CollaborateMD API credentials verified
- [ ] Salesforce admin access (for Remote Site Settings)

---

## 🎉 You're Ready!

Everything is prepared and ready to deploy. Choose your deployment method above and follow the steps.

**Recommended:** Start with `QUICK_DEPLOY.sh` for fastest results.

**Questions?** See `aws_deployment_report.md` for detailed documentation.

---

## 📞 Support Resources

- **AWS Documentation:** https://docs.aws.amazon.com/
- **Lambda Guide:** https://docs.aws.amazon.com/lambda/
- **API Gateway Guide:** https://docs.aws.amazon.com/apigateway/
- **CloudFormation Guide:** https://docs.aws.amazon.com/cloudformation/
- **Salesforce Remote Sites:** https://help.salesforce.com/s/articleView?id=sf.configuring_remoteproxy.htm

---

**Deployment Package Prepared By:** DeepAgent  
**Date:** October 23, 2025  
**Version:** 1.0  
**Location:** `/home/ubuntu/collaboratemd-salesforce-middleware/`
