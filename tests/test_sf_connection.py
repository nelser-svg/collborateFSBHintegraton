#!/usr/bin/env python3
from simple_salesforce import Salesforce
import sys

USERNAME = "jmcmillan@collaboratemd.com.dev"
PASSWORD = "Holymoly1234!@#$"
SECURITY_TOKEN = "t19pdcEaP3j8k6Yul0is80JG"

print("Testing Salesforce connection...")
print(f"Username: {USERNAME}")
print(f"Password: {'*' * len(PASSWORD)}")
print(f"Security Token: {SECURITY_TOKEN[:5]}...{SECURITY_TOKEN[-5:]}")
print(f"Domain: test (sandbox)")

try:
    sf = Salesforce(
        username=USERNAME,
        password=PASSWORD,
        security_token=SECURITY_TOKEN,
        domain='test'
    )
    print(f"\n✅ Connection successful!")
    print(f"Instance: {sf.sf_instance}")
    print(f"Session ID: {sf.session_id[:20]}...")
except Exception as e:
    print(f"\n❌ Connection failed!")
    print(f"Error type: {type(e).__name__}")
    print(f"Error message: {str(e)}")
    sys.exit(1)
