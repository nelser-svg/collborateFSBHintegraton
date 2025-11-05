
/**
 * @description Test class for ClaimsIntegrationRestService
 * @author Salesforce Integration Team
 * @date 2025-10-16
 */
@IsTest
private class ClaimsIntegrationRestServiceTest {
    
    @TestSetup
    static void setupTestData() {
        // Create test Patient
        Patient__c patient = new Patient__c();
        patient.Name = 'Test Patient';
        patient.MR_Number__c = 'FSB2023-3725898041';
        insert patient;
        
        // Create test Service Authorization
        Services_Authorization__c serviceAuth = new Services_Authorization__c();
        serviceAuth.Name = 'Test Auth';
        serviceAuth.Authorization_Number__c = 'VA0033039419';
        serviceAuth.Level_of_Care__c = 'Residential';
        serviceAuth.Related_Patient__c = patient.Id;
        insert serviceAuth;
        
        // Create test Claim Payor
        Claim_Payor__c payor = new Claim_Payor__c();
        payor.Name = 'VA CCN OPTUM (13038645)';
        insert payor;
    }
    
    @IsTest
    static void testSuccessfulUpsert() {
        // Prepare REST request
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        // Build request body
        Map<String, Object> requestBody = new Map<String, Object>();
        List<Map<String, Object>> claims = new List<Map<String, Object>>();
        
        Map<String, Object> claim = new Map<String, Object>();
        claim.put('claimNumber', '227094000');
        claim.put('patientNameId', 'WILCKEN, CHRISTOPHER (53336657)');
        claim.put('primaryAuth', 'VA0033039419');
        claim.put('payerId', '13038645');
        claim.put('payerName', 'VA CCN OPTUM');
        claim.put('dosStart', '2024-02-01');
        claim.put('dosEnd', '2024-02-02');
        claim.put('claimSubmittedDate', '2024-02-06');
        claim.put('chargedAmount', 4900.00);
        claim.put('paidAmount', 901.36);
        claim.put('balance', 0.00);
        claim.put('paymentCheck', '3004700011');
        claim.put('paymentDate', '2024-02-15');
        claim.put('mrNumber', 'FSB2023-3725898041');
        
        claims.add(claim);
        requestBody.put('claims', claims);
        
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify response
        System.assertEquals(true, response.success, 'Should succeed');
        System.assertEquals(1, response.totalRecords, 'Should process 1 record');
        System.assertEquals(1, response.successfulRecords, 'Should have 1 successful');
        System.assertEquals(0, response.failedRecords, 'Should have 0 failed');
        System.assertEquals(200, res.statusCode, 'Should return 200 status');
        
        // Verify claim was created
        List<Claims__c> claimsList = [
            SELECT Id, Claim_Number__c
            FROM Claims__c
            WHERE Claim_Number__c = '227094000'
        ];
        
        System.assertEquals(1, claimsList.size(), 'Claim should be created');
    }
    
    @IsTest
    static void testEmptyRequest() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        // Empty request body
        Map<String, Object> requestBody = new Map<String, Object>();
        requestBody.put('claims', new List<Map<String, Object>>());
        
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify response
        System.assertEquals(false, response.success, 'Should fail');
        System.assertEquals(400, res.statusCode, 'Should return 400 status');
        System.assert(response.message.contains('No claims data'), 'Should have error message');
    }
    
    @IsTest
    static void testBatchSizeExceeded() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        // Build request with 201 claims (exceeds limit)
        Map<String, Object> requestBody = new Map<String, Object>();
        List<Map<String, Object>> claims = new List<Map<String, Object>>();
        
        for (Integer i = 0; i < 201; i++) {
            Map<String, Object> claim = new Map<String, Object>();
            claim.put('claimNumber', '22709400' + i);
            claim.put('primaryAuth', 'VA0033039419');
            claims.add(claim);
        }
        
        requestBody.put('claims', claims);
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify response
        System.assertEquals(false, response.success, 'Should fail');
        System.assertEquals(400, res.statusCode, 'Should return 400 status');
        System.assert(response.message.contains('exceeds maximum limit'), 'Should have size limit error');
    }
    
    @IsTest
    static void testPartialSuccess() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        Map<String, Object> requestBody = new Map<String, Object>();
        List<Map<String, Object>> claims = new List<Map<String, Object>>();
        
        // Valid claim
        Map<String, Object> validClaim = new Map<String, Object>();
        validClaim.put('claimNumber', '227094001');
        validClaim.put('patientNameId', 'Test Patient 1');
        validClaim.put('primaryAuth', 'VA0033039419');
        validClaim.put('dosStart', '2024-02-01');
        claims.add(validClaim);
        
        // Invalid claim (missing primaryAuth)
        Map<String, Object> invalidClaim = new Map<String, Object>();
        invalidClaim.put('claimNumber', '227094002');
        invalidClaim.put('patientNameId', 'Test Patient 2');
        // Missing primaryAuth
        claims.add(invalidClaim);
        
        requestBody.put('claims', claims);
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify partial success
        System.assertEquals(2, response.totalRecords, 'Should process 2 records');
        System.assertEquals(1, response.successfulRecords, 'Should have 1 successful');
        System.assertEquals(1, response.failedRecords, 'Should have 1 failed');
        System.assertEquals(207, res.statusCode, 'Should return 207 (Multi-Status)');
    }
    
    @IsTest
    static void testInvalidJSON() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        // Invalid JSON
        req.requestBody = Blob.valueOf('{ invalid json }');
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify error response
        System.assertEquals(false, response.success, 'Should fail');
        System.assertEquals(500, res.statusCode, 'Should return 500 status');
    }
    
    @IsTest
    static void testBulkUpsert() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        
        Map<String, Object> requestBody = new Map<String, Object>();
        List<Map<String, Object>> claims = new List<Map<String, Object>>();
        
        // Create 50 valid claims
        for (Integer i = 0; i < 50; i++) {
            Map<String, Object> claim = new Map<String, Object>();
            claim.put('claimNumber', '227094' + String.valueOf(100 + i));
            claim.put('patientNameId', 'Test Patient ' + i);
            claim.put('primaryAuth', 'VA0033039419');
            claim.put('dosStart', '2024-02-01');
            claim.put('chargedAmount', 1000.00);
            claims.add(claim);
        }
        
        requestBody.put('claims', claims);
        req.requestBody = Blob.valueOf(JSON.serialize(requestBody));
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify bulk processing
        System.assertEquals(50, response.totalRecords, 'Should process 50 records');
        System.assertEquals(50, response.successfulRecords, 'All should succeed');
        System.assertEquals(0, response.failedRecords, 'No failures');
        System.assertEquals(200, res.statusCode, 'Should return 200 status');
    }
    
    @IsTest
    static void testNullRequestBody() {
        RestRequest req = new RestRequest();
        RestResponse res = new RestResponse();
        
        req.requestURI = '/services/apexrest/ClaimsIntegration/v1';
        req.httpMethod = 'POST';
        req.requestBody = null;
        
        RestContext.request = req;
        RestContext.response = res;
        
        Test.startTest();
        
        ClaimsIntegrationRestService.ClaimsResponse response = 
            ClaimsIntegrationRestService.upsertClaims();
        
        Test.stopTest();
        
        // Verify error handling
        System.assertEquals(false, response.success, 'Should fail');
        System.assertEquals(500, res.statusCode, 'Should return 500 status');
    }
}
