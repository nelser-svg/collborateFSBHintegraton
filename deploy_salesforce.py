#!/usr/bin/env python3
"""
Salesforce Deployment Script
Deploys Apex classes and metadata to Salesforce Sandbox
"""

import os
import sys
from simple_salesforce import Salesforce
import base64
import json

# Salesforce Credentials
SF_USERNAME = "Nelser@dnfcpro.com7"
SF_PASSWORD = "Holymoly123!@#"
SF_SECURITY_TOKEN = "fim8TcSqCQKt97lHaQYKzDPj"
SF_DOMAIN = "test"  # for sandbox

def connect_to_salesforce():
    """Connect to Salesforce"""
    try:
        print("🔐 Connecting to Salesforce Sandbox...")
        sf = Salesforce(
            username=SF_USERNAME,
            password=SF_PASSWORD,
            security_token=SF_SECURITY_TOKEN,
            domain=SF_DOMAIN
        )
        print(f"✅ Successfully connected to Salesforce!")
        print(f"   Instance URL: {sf.sf_instance}")
        print(f"   Session ID: {sf.session_id[:20]}...")
        return sf
    except Exception as e:
        print(f"❌ Failed to connect to Salesforce: {str(e)}")
        sys.exit(1)

def read_apex_class(file_path):
    """Read Apex class content from file"""
    with open(file_path, 'r') as f:
        return f.read()

def deploy_apex_classes(sf):
    """Deploy Apex classes to Salesforce"""
    print("\n📦 Deploying Apex Classes...")
    
    classes_dir = "/home/ubuntu/collaboratemd-salesforce-middleware/salesforce/force-app/main/default/classes"
    
    apex_classes = [
        {
            "name": "CollabBatch",
            "file": f"{classes_dir}/CollabBatch.cls"
        },
        {
            "name": "ColborateMDRes",
            "file": f"{classes_dir}/ColborateMDRes.cls"
        }
    ]
    
    for apex_class in apex_classes:
        try:
            print(f"\n  📄 Deploying {apex_class['name']}...")
            
            # Read the class content
            class_body = read_apex_class(apex_class['file'])
            
            # Check if class already exists
            existing = None
            try:
                query = f"SELECT Id FROM ApexClass WHERE Name = '{apex_class['name']}'"
                result = sf.query(query)
                if result['totalSize'] > 0:
                    existing = result['records'][0]['Id']
                    print(f"     ℹ️  Class already exists, updating...")
            except Exception as e:
                print(f"     ℹ️  Class doesn't exist, creating new...")
            
            # Deploy the class
            if existing:
                # Update existing class
                sf.ApexClass.update(existing, {'Body': class_body})
                print(f"     ✅ Updated {apex_class['name']}")
            else:
                # Create new class
                result = sf.ApexClass.create({
                    'Name': apex_class['name'],
                    'Body': class_body,
                    'Status': 'Active'
                })
                print(f"     ✅ Created {apex_class['name']}")
                
        except Exception as e:
            print(f"     ❌ Error deploying {apex_class['name']}: {str(e)}")
            # Continue with other classes

def check_remote_site_settings(sf):
    """Check and display remote site settings"""
    print("\n🌐 Checking Remote Site Settings...")
    try:
        # Query for remote site settings (this is metadata, so we use Tooling API)
        query = "SELECT Id, DeveloperName, EndpointUrl FROM RemoteProxy"
        result = sf.query(query)
        
        if result['totalSize'] > 0:
            print(f"   Found {result['totalSize']} remote site settings:")
            for record in result['records']:
                print(f"     - {record['DeveloperName']}: {record.get('EndpointUrl', 'N/A')}")
        else:
            print("   ⚠️  No remote site settings found.")
            print("   ℹ️  You'll need to manually create 'Claims_API' Named Credential")
    except Exception as e:
        print(f"   ℹ️  Could not query remote site settings: {str(e)}")
        print("   ℹ️  This is normal - you'll need to set up Named Credentials manually")

def create_named_credential_instructions():
    """Display instructions for creating Named Credential"""
    print("\n📝 Manual Setup Required: Named Credential")
    print("=" * 70)
    print("You need to create a Named Credential in Salesforce:")
    print()
    print("1. Go to Setup → Named Credentials")
    print("2. Click 'New Named Credential'")
    print("3. Configure:")
    print("   Label: Claims API")
    print("   Name: Claims_API")
    print("   URL: [Your CollaborateMD API endpoint]")
    print("   Identity Type: Named Principal")
    print("   Authentication Protocol: Password Authentication")
    print("   Username: nelser")
    print("   Password: May052023!@#$%%")
    print("   Generate Authorization Header: ✓")
    print("   Allow Merge Fields in HTTP Header: ✓")
    print("   Allow Merge Fields in HTTP Body: ✓")
    print()
    print("4. Save the Named Credential")
    print("=" * 70)

def verify_custom_objects(sf):
    """Verify that required custom objects exist"""
    print("\n🔍 Verifying Custom Objects...")
    
    required_objects = [
        'Services_Authorization__c',
        'Claims__c',
        'Claim_Payor__c'
    ]
    
    for obj in required_objects:
        try:
            # Try to describe the object
            sf.__getattr__(obj).describe()
            print(f"   ✅ {obj} exists")
        except Exception as e:
            print(f"   ⚠️  {obj} not found - needs to be created")

def schedule_batch_job(sf):
    """Schedule the CollabBatch job"""
    print("\n⏰ Scheduling Batch Job...")
    print("   ℹ️  To schedule the batch job, run this in Developer Console:")
    print()
    print("   // Schedule to run daily at 2 AM")
    print("   CollabBatch batch = new CollabBatch();")
    print("   String sch = '0 0 2 * * ?'; // Daily at 2 AM")
    print("   System.schedule('CollaborateMD Claims Sync', sch, batch);")
    print()

def main():
    """Main deployment function"""
    print("=" * 70)
    print("CollaborateMD - Salesforce Integration Deployment")
    print("=" * 70)
    
    # Connect to Salesforce
    sf = connect_to_salesforce()
    
    # Deploy Apex classes
    deploy_apex_classes(sf)
    
    # Check remote site settings
    check_remote_site_settings(sf)
    
    # Verify custom objects
    verify_custom_objects(sf)
    
    # Display manual setup instructions
    create_named_credential_instructions()
    
    # Display batch scheduling instructions
    schedule_batch_job(sf)
    
    print("\n" + "=" * 70)
    print("✅ Salesforce Deployment Complete!")
    print("=" * 70)
    print()
    print("⚠️  IMPORTANT: Complete the manual steps above before running the integration")
    print()

if __name__ == "__main__":
    main()
