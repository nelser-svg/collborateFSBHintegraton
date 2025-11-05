# CollaborateMD Web API Authentication Requirements

## Authentication Method
**Basic Authentication** over SSL/HTTPS

---

## Required Credentials

1. **Username** - Provided by CollaborateMD
2. **Password** - Provided by CollaborateMD

---

## How to Format the Credentials

### Step-by-Step Process:

1. **Combine credentials** into a single string separated by a colon:
   ```
   username:password
   ```

2. **Convert to byte sequence** using Latin-1 or ASCII encoding

3. **Encode to Base64** string

4. **Prepend with "Basic "** (note the space after "Basic")

5. **Set as Authorization header** for all API requests

---

## Authorization Header Format

```
Authorization: Basic <Base64EncodedCredentials>
```

### Example from Documentation:
For credentials `Aladdin:open sesame`:

```
Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
```

---

## Important Security Notes

- ⚠️ **SSL/HTTPS Required**: Basic authentication credentials are NOT encrypted, so they MUST only be sent over SSL-protected connections
- ✅ CollaborateMD only provides SSL API endpoints
- 🔒 The authorization header must be set for **ALL** REST service invocation requests

---

## Error Handling

### HTTP 401 Unauthorized
Returned when:
- No credentials are specified
- Invalid credentials are provided
- Authorization header is incorrect

### HTTP 415 Unsupported Media Type
Returned when an unsupported Accept type is specified (only `application/xml` and `application/json` are supported)

---

## Additional Request Headers

### Response Media Type (Optional)
Specify preferred response format using the `Accept` header:

```
Accept: application/xml
```
or
```
Accept: application/json
```

**Default**: If not specified, the API defaults to `application/xml`

---

## API Base URL
```
https://webapi.collaboratemd.com
```

---

## Required Path Parameters

All API endpoints require:
- **customer**: The CollaborateMD customer number (always 8 digits)
  - Example: `10001001`

---

## Complete Request Example

```http
GET https://webapi.collaboratemd.com/v1/customer/10001001/patient/14268678/balance
Authorization: Basic QWxhZGRpbjpvcGVuIHNlc2FtZQ==
Accept: application/json
```

---

## Summary Checklist

- [ ] Obtain username and password from CollaborateMD
- [ ] Combine as `username:password`
- [ ] Base64 encode the combined string
- [ ] Add `Basic ` prefix
- [ ] Include in `Authorization` header for every request
- [ ] Ensure all requests use HTTPS
- [ ] Include 8-digit customer number in API path
- [ ] Optionally specify `Accept` header for response format preference

---

**Document Version**: 1.11  
**Last Updated**: August 16, 2021  
**Source**: CollaborateMD Web API Documentation v1.11
