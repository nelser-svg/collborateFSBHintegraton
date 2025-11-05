#!/bin/bash

###############################################################################
# CollaborateMD API Test Commands
# 
# These commands will work once API authentication is properly configured
# 
# Prerequisites:
# 1. Valid API credentials from CollaborateMD
# 2. API access enabled for your account
# 3. IP whitelisting configured (if required)
#
# Usage:
#   chmod +x api_test_commands.sh
#   ./api_test_commands.sh
###############################################################################

# Configuration
BASE_URL="https://webapi.collaboratemd.com"
CUSTOMER_ID="10027191"
REPORT_ID="10060198"
FILTER_ID="10140792"

# Credentials (UPDATE THESE ONCE CONFIRMED)
USERNAME="nelser"
PASSWORD="May052023!@#$%%"

# Date range for October 2025
START_DATE="2025-10-01"
END_DATE="2025-10-30"

# Output directory
OUTPUT_DIR="./api_test_results"
mkdir -p "$OUTPUT_DIR"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo "=========================================="
    echo "$1"
    echo "=========================================="
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

check_response() {
    local status_code=$1
    local response_file=$2
    
    if [ "$status_code" -eq 200 ]; then
        print_success "Success (HTTP $status_code)"
        echo "Response saved to: $response_file"
        cat "$response_file" | jq '.' 2>/dev/null || cat "$response_file"
        return 0
    elif [ "$status_code" -eq 401 ]; then
        print_error "Authentication Failed (HTTP $status_code)"
        return 1
    elif [ "$status_code" -eq 404 ]; then
        print_error "Not Found (HTTP $status_code)"
        return 1
    else
        print_error "Failed (HTTP $status_code)"
        return 1
    fi
}

###############################################################################
# Test 1: Find Patient
###############################################################################

test_find_patient() {
    print_header "Test 1: Find Patient"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/patient/find"
    url="${url}?firstName=JOHN&lastName=SMITH&birthDate=01/28/1945"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/patient_find_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/patient_find_response.json"
}

###############################################################################
# Test 2: Get Patient Balance
###############################################################################

test_patient_balance() {
    print_header "Test 2: Get Patient Balance"
    
    # Note: This requires a valid patient account number
    # Update PATIENT_ID after running test_find_patient successfully
    local PATIENT_ID="14268678"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/patient/${PATIENT_ID}/balance"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/patient_balance_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/patient_balance_response.json"
}

###############################################################################
# Test 3: Get Patient Balance Details
###############################################################################

test_patient_balance_details() {
    print_header "Test 3: Get Patient Balance Details"
    
    local PATIENT_ID="14268678"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/patient/${PATIENT_ID}/balanceDetails"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/patient_balance_details_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/patient_balance_details_response.json"
}

###############################################################################
# Test 4: Run Report
###############################################################################

test_run_report() {
    print_header "Test 4: Run Report"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/reports/${REPORT_ID}/filter/${FILTER_ID}/run"
    
    echo "Endpoint: POST $url"
    echo "Report ID: $REPORT_ID"
    echo "Filter ID: $FILTER_ID"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -X POST \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/report_run_response.json"
    
    if check_response "$status_code" "${OUTPUT_DIR}/report_run_response.json"; then
        # Extract report identifier for next test
        local identifier=$(echo "$body" | jq -r '.identifier' 2>/dev/null)
        if [ -n "$identifier" ] && [ "$identifier" != "null" ]; then
            echo "$identifier" > "${OUTPUT_DIR}/report_identifier.txt"
            print_success "Report identifier saved: $identifier"
            return 0
        fi
    fi
    
    return 1
}

###############################################################################
# Test 5: Get Report Results
###############################################################################

test_get_report_results() {
    print_header "Test 5: Get Report Results"
    
    # Check if we have a report identifier from previous test
    if [ ! -f "${OUTPUT_DIR}/report_identifier.txt" ]; then
        print_error "No report identifier found. Run test_run_report first."
        return 1
    fi
    
    local REQUEST_SEQ=$(cat "${OUTPUT_DIR}/report_identifier.txt")
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/reports/results/${REQUEST_SEQ}"
    
    echo "Endpoint: POST $url"
    echo "Request Seq: $REQUEST_SEQ"
    
    # Poll for results (max 10 attempts, 30 seconds apart)
    local max_attempts=10
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo ""
        echo "Attempt $attempt of $max_attempts..."
        
        local response=$(curl -s -w "\n%{http_code}" \
            -X POST \
            -u "${USERNAME}:${PASSWORD}" \
            -H "Accept: application/json" \
            "$url")
        
        local status_code=$(echo "$response" | tail -n1)
        local body=$(echo "$response" | sed '$d')
        
        echo "$body" > "${OUTPUT_DIR}/report_results_response.json"
        
        if [ "$status_code" -eq 200 ]; then
            local status=$(echo "$body" | jq -r '.status' 2>/dev/null)
            
            if [ "$status" = "SUCCESS" ]; then
                print_success "Report completed successfully!"
                
                # Extract and decode base64 ZIP data
                local zip_data=$(echo "$body" | jq -r '.data' 2>/dev/null)
                if [ -n "$zip_data" ] && [ "$zip_data" != "null" ]; then
                    echo "$zip_data" | base64 -d > "${OUTPUT_DIR}/report_results.zip"
                    print_success "Report data saved to: ${OUTPUT_DIR}/report_results.zip"
                    
                    # Try to extract ZIP
                    if command -v unzip &> /dev/null; then
                        unzip -o "${OUTPUT_DIR}/report_results.zip" -d "${OUTPUT_DIR}/report_extracted/"
                        print_success "Report extracted to: ${OUTPUT_DIR}/report_extracted/"
                    fi
                fi
                
                return 0
                
            elif [ "$status" = "REPORT RUNNING" ]; then
                print_warning "Report still running... waiting 30 seconds"
                sleep 30
                
            elif [ "$status" = "REPORT TIMED OUT" ]; then
                print_error "Report timed out"
                return 1
                
            else
                print_error "Report failed with status: $status"
                return 1
            fi
        else
            print_error "Failed to get report results (HTTP $status_code)"
            return 1
        fi
        
        attempt=$((attempt + 1))
    done
    
    print_error "Report did not complete within timeout period"
    return 1
}

###############################################################################
# Test 6: Get Patient Charge History
###############################################################################

test_patient_charge_history() {
    print_header "Test 6: Get Patient Charge History"
    
    local PATIENT_ID="14268678"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/patient/${PATIENT_ID}/chargeHistory"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/patient_charge_history_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/patient_charge_history_response.json"
}

###############################################################################
# Test 7: Get Primary Eligibility
###############################################################################

test_primary_eligibility() {
    print_header "Test 7: Get Primary Eligibility"
    
    local PATIENT_ID="14268678"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/patient/${PATIENT_ID}/primaryEligibility"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/primary_eligibility_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/primary_eligibility_response.json"
}

###############################################################################
# Test 8: Find Referring Provider
###############################################################################

test_find_referring_provider() {
    print_header "Test 8: Find Referring Provider"
    
    local url="${BASE_URL}/v1/customer/${CUSTOMER_ID}/referring/find"
    url="${url}?firstName=JOHN&lastName=DOE&NPI=1234567890"
    
    echo "Endpoint: GET $url"
    
    local response=$(curl -s -w "\n%{http_code}" \
        -u "${USERNAME}:${PASSWORD}" \
        -H "Accept: application/json" \
        "$url")
    
    local status_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    echo "$body" > "${OUTPUT_DIR}/referring_provider_response.json"
    check_response "$status_code" "${OUTPUT_DIR}/referring_provider_response.json"
}

###############################################################################
# Main Execution
###############################################################################

main() {
    print_header "CollaborateMD API Test Suite"
    echo "Base URL: $BASE_URL"
    echo "Customer ID: $CUSTOMER_ID"
    echo "Output Directory: $OUTPUT_DIR"
    echo ""
    
    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        print_warning "jq is not installed. JSON output will not be formatted."
        echo "Install with: sudo apt-get install jq"
    fi
    
    # Run tests
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Find Patient
    if test_find_patient; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 2: Patient Balance
    if test_patient_balance; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 3: Patient Balance Details
    if test_patient_balance_details; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 4: Run Report
    if test_run_report; then
        tests_passed=$((tests_passed + 1))
        
        # Test 5: Get Report Results (only if report was queued successfully)
        sleep 5  # Wait a bit before checking results
        if test_get_report_results; then
            tests_passed=$((tests_passed + 1))
        else
            tests_failed=$((tests_failed + 1))
        fi
    else
        tests_failed=$((tests_failed + 1))
        print_warning "Skipping Test 5 (Get Report Results) - no report identifier"
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 6: Charge History
    if test_patient_charge_history; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 7: Primary Eligibility
    if test_primary_eligibility; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Test 8: Find Referring Provider
    if test_find_referring_provider; then
        tests_passed=$((tests_passed + 1))
    else
        tests_failed=$((tests_failed + 1))
    fi
    
    # Summary
    print_header "Test Summary"
    echo "Tests Passed: $tests_passed"
    echo "Tests Failed: $tests_failed"
    echo ""
    echo "All responses saved to: $OUTPUT_DIR"
    
    if [ $tests_failed -eq 0 ]; then
        print_success "All tests passed!"
        return 0
    else
        print_error "Some tests failed. Check the output above for details."
        return 1
    fi
}

# Run main function
main
