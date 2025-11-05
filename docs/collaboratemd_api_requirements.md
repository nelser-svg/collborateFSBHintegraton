# CollaborateMD Web API - Complete Requirements & Integration Guide

**Documentation Version:** v1.11  
**Last Updated:** August 16, 2021  
**Analysis Date:** October 30, 2025

---

## 🔐 Authentication Requirements

### Authentication Method
**Basic Authentication (HTTP Basic Auth)**

### Required Credentials

| Credential | Type | Format | Example | Description |
|------------|------|--------|---------|-------------|
| **Username** | String | Alphanumeric | `apiuser123` | API username provided by CollaborateMD |
| **Password** | String | Alphanumeric | `P@ssw0rd!` | API password provided by CollaborateMD |
| **Customer Number** | String | 8-digit number | `10001001` | CollaborateMD customer identifier (always 8 digits) |

### Authentication Implementation

**Header Format:**
```
Authorization: Basic {base64_encoded_credentials}
```

**Credential Encoding Process:**
1. Combine username and password with colon separator: `username:password`
2. Convert to byte sequence using Latin-1 or ASCII encoding
3. Encode to Base64
4. Prepend with "Basic "

**Example:**
```
Username: Aladdin
Password: open sesame
Combined: Aladdin:open sesame
Base64: QWxhZGRpbjpvcGVuIHNlc2FtZQ==
Header: Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
```

### Security Notes
- ✅ All API calls MUST use SSL/HTTPS (encryption required)
- ✅ Basic Auth credentials are NOT encrypted - SSL is mandatory
- ✅ CollaborateMD only provides SSL API endpoints
- ❌ HTTP 401 Unauthorized returned if credentials are missing or invalid

---

## 🌐 API Base URL & Endpoints

### Base URL
```
https://webapi.collaboratemd.com
```

### API Version
```
v1 (primary)
v2 (for snapshot downloads only)
```

---

## 📋 Request Headers

### Required Headers

| Header | Values | Required | Default | Description |
|--------|--------|----------|---------|-------------|
| **Authorization** | `Basic {base64}` | ✅ Yes | None | Authentication credentials |
| **Accept** | `application/json` or `application/xml` | ⚠️ Recommended | `application/xml` | Response format preference |
| **Content-Type** | `application/json` or `application/xml` or `text/plain` | ✅ Yes (for POST) | N/A | Request body format |

### Response Format
- **Supported formats:** XML and JSON
- **Default:** XML (if Accept header not specified)
- **Unsupported Accept types:** Returns HTTP 415 Unsupported Media Type

---

## 🔑 Key API Endpoints for Salesforce Integration

### 1. **Patient Management**

#### Find Patient
```http
GET /v1/customer/{customer}/patient/find
```
**Query Parameters:**
- `firstName` (optional) - Patient first name
- `lastName` (optional) - Patient last name
- `birthDate` (optional) - Format: MM/DD/YYYY
- `SSN` (optional) - Format: ###-##-#### or #########

**Matching Algorithm:**
- First Name + Last Name + DOB (all exact matches) OR
- SSN + (Last Name OR DOB)

**Response:** `PatientResponse` with `AccountNumber` (unique patient ID)

**Example:**
```
https://webapi.collaboratemd.com/v1/customer/10001011/patient/find?firstName=JOHN&lastName=SMITH&birthDate=01/28/1945&SSN=555-01-1234
```

---

#### Create/Update Patient
```http
POST /v1/customer/{customer}/patient/xml
POST /v1/customer/{customer}/patient/hl7
```

**Formats Supported:**
- **XML:** Send PatientUpdate object in request body
- **HL7:** Send raw HL7 ADT message in request body

**Example XML Structure:**
```xml
<ns2:PatientUpdate xmlns:ns2="http://www.collaboratemd.com/api/v1/">
    <Provider>
        <Identifier>10011001</Identifier>
        <LastName>SMITH</LastName>
        <FirstName>JOHN</FirstName>
    </Provider>
    <Patient>
        <LastName>Doe</LastName>
        <FirstName>Jane</FirstName>
        <BirthDate>01/01/2016</BirthDate>
        <Gender>F</Gender>
        <SSN>012-34-5678</SSN>
        <Address>
            <Line1>11601 TEST DRIVE</Line1>
            <City>ORLANDO</City>
            <State>FL</State>
            <Zipcode>32801</Zipcode>
        </Address>
    </Patient>
    <Facility>
        <Name>SPARTAN ALLERGIC CENTER</Name>
    </Facility>
</ns2:PatientUpdate>
```

---

#### Retrieve Patient Updates
```http
GET /v1/customer/{customer}/patient/updates/find/xml
GET /v1/customer/{customer}/patient/updates/find/hl7
```

**Query Parameters:**
- `response_count` (optional) - Max updates to retrieve (max: 1,000)

**Response:** Queued patient updates from CollaborateMD
**Recommendation:** Poll regularly to prevent backup

---

### 2. **Patient Balance & Financial Information**

#### Get Patient Balance
```http
GET /v1/customer/{customer}/patient/{patient}/balance
```

**Response:** `BalanceResponse` with:
- `Balance` - Decimal value (e.g., -145.67 or 1867.99)
- `FormattedBalance` - User-friendly format (e.g., -$145.67 or $1,867.99)

**Example:**
```
https://webapi.collaboratemd.com/v1/customer/10001001/patient/14268678/balance
```

---

#### Get Patient Balance Details
```http
GET /v1/customer/{customer}/patient/{patient}/balanceDetails
```

**Response:** `BalanceDetailsResponse` with:
- Overall balance
- **List of ChargeItem objects** (outstanding charges only):
  - TranID (unique charge identifier)
  - CPT code
  - Procedure description
  - Total charges
  - Insurance payments
  - Insurance adjustments
  - Patient payments
  - Other adjustments
  - Balance
  - Service dates (from/to)
  - Claim ID

**Note:** Only returns charges contributing to outstanding balance (excludes paid charges)

---

#### Get Patient Charge History
```http
GET /v1/customer/{customer}/patient/{patient}/chargeHistory
```

**Response:** `ChargeHistoryResponse` with:
- Overall balance
- **List of ALL ChargeItem objects** (paid, unpaid, and unprocessed):
  - All fields from balanceDetails
  - **Status** field (e.g., "PAID", "BALANCE DUE PATIENT", "AT INSURANCE", "PENDING PATIENT")

**Note:** Includes all charges, not just outstanding ones

---

### 3. **Insurance Eligibility**

#### Primary Insurance Eligibility
```http
GET /v1/customer/{customer}/patient/{patient}/primaryEligibility
```

**Response:** `EligibilityResponse` with eligibility report for primary insurance

---

#### All Insurance Eligibility
```http
GET /v1/customer/{customer}/patient/{patient}/allEligibility
```

**Response:** `EligibilityResponse` with eligibility reports for all active policies

---

#### Specific Policy Eligibility
```http
GET /v1/customer/{customer}/patient/{patient}/eligibility?memberID={memberID}
```

**Query Parameters:**
- `memberID` (required) - Insurance member ID

**Response:** Eligibility report for specific policy

---

### 4. **Claims Management**

#### Create Professional Claim
```http
POST /v1/customer/{customer}/claim/xml
POST /v1/customer/{customer}/claim/hl7
```

**Formats Supported:**
- **XML:** Send Claim object in request body
- **HL7:** Send raw HL7 claim message

---

#### Create Institutional Claim
```http
POST /v1/customer/{customer}/iclaim/xml
```

**Format:** XML only (IClaim object schema)

---

### 5. **Appointments**

#### Create/Update Appointment
```http
POST /v1/customer/{customer}/appointment/xml
POST /v1/customer/{customer}/appointment/hl7
```

**Formats Supported:**
- **XML:** Send Appointment object in request body
- **HL7:** Send raw HL7 SIU message

---

#### Retrieve Appointment Updates
```http
GET /v1/customer/{customer}/appointment/updates/find/xml
GET /v1/customer/{customer}/appointment/updates/find/hl7
```

**Query Parameters:**
- `response_count` (optional) - Max updates to retrieve (max: 1,000)

**Response:** Queued appointment updates from CollaborateMD
**Recommendation:** Poll regularly to prevent backup

---

### 6. **Referring Providers**

#### Find Referring Provider
```http
GET /v1/customer/{customer}/referring/find
```

**Query Parameters:**
- `firstName` (optional) - Provider first name
- `lastName` (optional) - Provider last name or organization name
- `NPI` (optional) - National Provider Identifier
- `referenceID` (optional) - Custom unique identifier

**Response:** `ReferringResponse` with:
- Full provider representation
- Unique provider identifier

---

#### Create Referring Provider
```http
POST /v1/customer/{customer}/referring
```

**Format:** XML (Referring object)

**Behavior:**
- First attempts to find existing provider
- If exists: Returns `INVALID_CRITERIA` status with existing provider ID
- If new: Creates provider and returns new provider ID

---

### 7. **Custom Reports** (Requires Approval)

#### Run Custom Report
```http
POST /v1/customer/{customer}/reports/{reportSeq}/filter/{filterSeq}/run
```

**Path Parameters:**
- `reportSeq` - Unique report identifier (from CollaborateMD app)
- `filterSeq` - Unique filter identifier (from CollaborateMD app)

**Response:** `GenericResponse` with:
- Status (SUCCESS, ERROR, NOT FOUND, INVALID CRITERIA, **REPORT RUNNING**)
- Identifier for retrieving results

**Notes:**
- Only one report per partner at a time
- Requires approval from CollaborateMD
- Only CBI (Central Business Intelligence) reports supported
- Report/filter IDs must be obtained from CollaborateMD Application

---

#### Get Report Results
```http
POST /v1/customer/{customer}/reports/results/{requestSeq}
```

**Path Parameters:**
- `requestSeq` - Request identifier from report run

**Response:** `ReportResponse` with:
- Status (SUCCESS, REPORT RUNNING, **REPORT TIMED OUT**)
- Data (Base64 encoded ZIP file with results)

**Timeout:** 15 minutes maximum

---

### 8. **Data Snapshots** (Requires Approval)

#### Download Customer Snapshot
```http
GET /v2/customer/{customer}/snapshot
```

#### Download Account Snapshot
```http
GET /v2/account/{account}/snapshot
```

**Response:** Direct ZIP file download (not a JSON/XML response object)

**HTTP Status Codes:**
- `200 OK` - File successfully returned
- `401 Unauthorized` - Invalid credentials or API not enabled
- `404 Not Found` - Invalid customer/account or no snapshot configured

**Notes:**
- Only most recent snapshot available
- Created in morning (Eastern Time)
- Requesting too early may return previous day's snapshot

---

## 📊 Response Structure

### Standard Response Object

All authenticated requests return a response object with:

```json
{
  "Status": "SUCCESS | ERROR | NOT FOUND | INVALID CRITERIA",
  "StatusMessage": "Human-readable description",
  "Data": { /* endpoint-specific data */ }
}
```

### Response Status Values

| Status | Description |
|--------|-------------|
| `SUCCESS` | Request successful, no problems |
| `ERROR` | Unexpected error occurred (see StatusMessage) |
| `NOT FOUND` | Request valid but requested information not found |
| `INVALID CRITERIA` | Request parameters not valid |
| `REPORT RUNNING` | (Reports only) Previous report still processing |
| `REPORT TIMED OUT` | (Reports only) Report took longer than 15 minutes |

### HTTP Status Codes

| Code | Meaning |
|------|---------|
| `200 OK` | Request successful |
| `401 Unauthorized` | Missing or invalid authentication |
| `404 Not Found` | Resource not found |
| `415 Unsupported Media Type` | Invalid Accept header |

---

## 🔧 Integration Best Practices

### 1. **Polling Recommendations**
- **Patient Updates:** Poll `/patient/updates/find` regularly to prevent queue backup
- **Appointment Updates:** Poll `/appointment/updates/find` regularly
- **Snapshots:** Download in afternoon (Eastern Time) to ensure latest data

### 2. **Response Count Strategy**
- Maximum: 1,000 records per request
- Recommended: 20-100 records per poll for balanced performance
- Queue persistence: Unprocessed updates remain queued for next request

### 3. **Data Format Selection**
- **XML vs HL7:** No processing difference, choose based on implementation convenience
- **JSON vs XML responses:** Functionally identical, choose based on system preference

### 4. **Error Handling**
- Always check `Status` field in responses
- Log `StatusMessage` for debugging
- Implement retry logic for ERROR status
- Handle 401/404/415 HTTP errors appropriately

### 5. **Security**
- Never transmit credentials over HTTP (only HTTPS)
- Store API credentials securely (encrypted storage)
- Rotate credentials periodically
- Monitor for 401 errors indicating credential issues

### 6. **Rate Limiting**
- Reports: Only one concurrent report per partner
- Updates: Max 1,000 records per request
- No explicit rate limits documented (use reasonable polling intervals)

---

## 📁 Additional Documentation Files

The API package includes detailed implementation guides:

### XML Implementation Guides
- `XML Implementation Guide - Patient Update.pdf`
- `XML Implementation Guide - Professional Claim.pdf`
- `XML Implementation Guide - Institutional Claim.pdf`
- `XML Implementation Guide - Appointment.pdf`
- `XML Implementation Guide - Referring.pdf`

### HL7 Documentation
- `CollaborateMD_hl7_specification.pdf`

### Eligibility Documentation
- `Eligibility Response Info.pdf`
- Example files for JSON and XML responses

### Schema Definition
- `schema.xsd` - XML Schema Definitions for API objects

### Example Files
Located in respective folders (XML/, HL7/, Eligibility/):
- Patient update examples
- Claim examples (professional & institutional)
- Appointment examples
- Eligibility response examples

---

## ✅ Credential Verification Checklist

For Salesforce integration, you need to obtain from CollaborateMD:

- [ ] **API Username** - Provided by CollaborateMD
- [ ] **API Password** - Provided by CollaborateMD
- [ ] **Customer Number(s)** - 8-digit identifier(s) for your organization
- [ ] **API Access Enabled** - Confirm web API is enabled for your customer account
- [ ] **SSL Certificate Trust** - Ensure your system trusts CollaborateMD's SSL cert
- [ ] **Test Environment** - (Optional) Test credentials/customer number if available
- [ ] **Approval for Advanced Features:**
  - [ ] Custom Reports (if needed)
  - [ ] Data Snapshots (if needed)

---

## 🔗 Key Endpoints Summary for Salesforce Integration

### Essential Endpoints (Priority 1)
1. **Find Patient** - `GET /v1/customer/{customer}/patient/find`
2. **Patient Balance** - `GET /v1/customer/{customer}/patient/{patient}/balance`
3. **Balance Details** - `GET /v1/customer/{customer}/patient/{patient}/balanceDetails`
4. **Charge History** - `GET /v1/customer/{customer}/patient/{patient}/chargeHistory`
5. **Create/Update Patient** - `POST /v1/customer/{customer}/patient/xml`

### Important Endpoints (Priority 2)
6. **Primary Eligibility** - `GET /v1/customer/{customer}/patient/{patient}/primaryEligibility`
7. **Create Claim** - `POST /v1/customer/{customer}/claim/xml`
8. **Patient Updates** - `GET /v1/customer/{customer}/patient/updates/find/xml`
9. **Find Referring Provider** - `GET /v1/customer/{customer}/referring/find`

### Optional Endpoints (Priority 3)
10. **Appointments** - Various appointment endpoints
11. **Custom Reports** - Report generation and retrieval
12. **Data Snapshots** - Full data downloads

---

## 💡 Implementation Notes for Salesforce

### Recommended Approach
1. **Store credentials securely** in Salesforce Named Credentials or Custom Metadata
2. **Implement Apex HTTP callouts** with proper Basic Auth header construction
3. **Parse JSON responses** (easier in Apex than XML)
4. **Create custom objects** to store CollaborateMD identifiers:
   - Patient Account Number field on Contact/Patient object
   - Transaction IDs for charges
   - Claim IDs for claims
5. **Implement scheduled jobs** for polling patient/appointment updates
6. **Error logging** for failed API calls with StatusMessage details
7. **Field mapping** between Salesforce and CollaborateMD data structures

### Sample Apex Code Structure
```apex
// Build Basic Auth header
String username = 'your_api_username';
String password = 'your_api_password';
String credentials = username + ':' + password;
Blob headerValue = Blob.valueOf(credentials);
String authorizationHeader = 'Basic ' + EncodingUtil.base64Encode(headerValue);

// Make API call
HttpRequest req = new HttpRequest();
req.setEndpoint('https://webapi.collaboratemd.com/v1/customer/10001001/patient/find?firstName=JOHN&lastName=SMITH');
req.setMethod('GET');
req.setHeader('Authorization', authorizationHeader);
req.setHeader('Accept', 'application/json');

Http http = new Http();
HTTPResponse res = http.send(req);

// Parse response
Map<String, Object> jsonResponse = (Map<String, Object>) JSON.deserializeUntyped(res.getBody());
```

---

## 📞 Support Resources

### Documentation
- **Help Center:** https://help.collaboratemd.com/help/web-reporting
- **This Package:** v1.11 CMD WebAPI Package

### Contact CollaborateMD
- For API credentials and access
- To enable advanced features (reports, snapshots)
- For technical support and troubleshooting

---

## 🎯 Next Steps

1. **Obtain API credentials** from CollaborateMD
2. **Test authentication** with a simple GET request (Find Patient)
3. **Verify customer number(s)** are correct (8 digits)
4. **Implement core endpoints** in Salesforce (Find Patient, Balance, Balance Details)
5. **Build error handling** and logging framework
6. **Test data synchronization** between systems
7. **Implement scheduled polling** for updates
8. **Document field mappings** between systems
9. **User acceptance testing** with real data
10. **Production deployment** and monitoring

---

**Document prepared by:** DeepAgent  
**Based on:** CollaborateMD Web API Documentation v1.11  
**Analysis Date:** October 30, 2025  
**Status:** ✅ Complete and ready for implementation

