import requests
import json
from datetime import datetime

print("=" * 80)
print("CollaborateMD API Testing - Multiple Methods")
print("=" * 80)

cmd_username = "nelser"
cmd_password = "May052023!@#$%%"
report_url = "https://webapi.collaboratemd.com/v1/customer/10027191/reports/10060198/filter/10140792/run"
start_date = "2025-10-01"
end_date = "2025-10-30"

results = []

# Test 1: POST with JSON body
print("\n[Test 1] POST request with JSON body...")
try:
    response = requests.post(
        report_url,
        json={
            "startDate": start_date,
            "endDate": end_date
        },
        auth=(cmd_username, cmd_password),
        timeout=60
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ SUCCESS!")
        try:
            data = response.json()
            print(f"Response type: {type(data)}")
            if isinstance(data, list):
                print(f"Records: {len(data)}")
            print(f"Sample: {json.dumps(data[:2] if isinstance(data, list) else data, indent=2)[:500]}")
            results.append(("POST with JSON body", response.status_code, data))
        except:
            print(f"Response (text): {response.text[:500]}")
            results.append(("POST with JSON body", response.status_code, response.text[:500]))
    else:
        print(f"Failed: {response.text[:200]}")
        results.append(("POST with JSON body", response.status_code, response.text[:200]))
except Exception as e:
    print(f"Error: {e}")
    results.append(("POST with JSON body", "ERROR", str(e)))

# Test 2: POST with query parameters
print("\n[Test 2] POST request with query parameters...")
try:
    response = requests.post(
        report_url,
        params={
            "startDate": start_date,
            "endDate": end_date
        },
        auth=(cmd_username, cmd_password),
        timeout=60
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ SUCCESS!")
        try:
            data = response.json()
            print(f"Response type: {type(data)}")
            if isinstance(data, list):
                print(f"Records: {len(data)}")
            results.append(("POST with query params", response.status_code, data))
        except:
            print(f"Response (text): {response.text[:500]}")
            results.append(("POST with query params", response.status_code, response.text[:500]))
    else:
        print(f"Failed: {response.text[:200]}")
        results.append(("POST with query params", response.status_code, response.text[:200]))
except Exception as e:
    print(f"Error: {e}")
    results.append(("POST with query params", "ERROR", str(e)))

# Test 3: POST with form data
print("\n[Test 3] POST request with form data...")
try:
    response = requests.post(
        report_url,
        data={
            "startDate": start_date,
            "endDate": end_date
        },
        auth=(cmd_username, cmd_password),
        timeout=60
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ SUCCESS!")
        try:
            data = response.json()
            print(f"Response type: {type(data)}")
            if isinstance(data, list):
                print(f"Records: {len(data)}")
            results.append(("POST with form data", response.status_code, data))
        except:
            print(f"Response (text): {response.text[:500]}")
            results.append(("POST with form data", response.status_code, response.text[:500]))
    else:
        print(f"Failed: {response.text[:200]}")
        results.append(("POST with form data", response.status_code, response.text[:200]))
except Exception as e:
    print(f"Error: {e}")
    results.append(("POST with form data", "ERROR", str(e)))

# Test 4: GET with different date format
print("\n[Test 4] GET request with different date format (YYYY/MM/DD)...")
try:
    response = requests.get(
        report_url,
        params={
            "startDate": "2025/10/01",
            "endDate": "2025/10/30"
        },
        auth=(cmd_username, cmd_password),
        timeout=60
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ SUCCESS!")
        try:
            data = response.json()
            results.append(("GET with date format YYYY/MM/DD", response.status_code, data))
        except:
            results.append(("GET with date format YYYY/MM/DD", response.status_code, response.text[:500]))
    else:
        print(f"Failed: {response.text[:200]}")
        results.append(("GET with date format YYYY/MM/DD", response.status_code, response.text[:200]))
except Exception as e:
    print(f"Error: {e}")
    results.append(("GET with date format YYYY/MM/DD", "ERROR", str(e)))

# Test 5: POST without dates (maybe defaults to current month)
print("\n[Test 5] POST request without date parameters...")
try:
    response = requests.post(
        report_url,
        auth=(cmd_username, cmd_password),
        timeout=60
    )
    print(f"Status: {response.status_code}")
    if response.status_code == 200:
        print("✓ SUCCESS!")
        try:
            data = response.json()
            print(f"Response type: {type(data)}")
            if isinstance(data, list):
                print(f"Records: {len(data)}")
            results.append(("POST without dates", response.status_code, data))
        except:
            print(f"Response (text): {response.text[:500]}")
            results.append(("POST without dates", response.status_code, response.text[:500]))
    else:
        print(f"Failed: {response.text[:200]}")
        results.append(("POST without dates", response.status_code, response.text[:200]))
except Exception as e:
    print(f"Error: {e}")
    results.append(("POST without dates", "ERROR", str(e)))

print("\n" + "=" * 80)
print("Summary of All Tests")
print("=" * 80)
for method, status, _ in results:
    print(f"{method}: {status}")

# Find successful method
successful = [r for r in results if r[1] == 200]
if successful:
    print(f"\n✓ Found working method: {successful[0][0]}")
    with open("/home/ubuntu/collaboratemd_success.json", "w") as f:
        f.write(json.dumps({
            "method": successful[0][0],
            "status": successful[0][1],
            "response": successful[0][2]
        }, indent=2, default=str))
    print("Response saved to: /home/ubuntu/collaboratemd_success.json")
else:
    print("\n✗ No successful method found")
    print("\nThis suggests:")
    print("1. The credentials may be incorrect")
    print("2. The API endpoint URL may be wrong")
    print("3. The account may not have API access")
    print("4. IP whitelisting may be required")

