
/**
 * @description Test class for ClaimsIntegrationService
 * @author Salesforce Integration Team
 * @date 2025-10-16
 */
@IsTest
private class ClaimsIntegrationServiceTest {
    
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
        
        // Create existing claim for update test
        Claims__c existingClaim = new Claims__c();
        existingClaim.Claim_Number__c = '227094000';
        existingClaim.Name = 'WILCKEN, CHRISTOPHER (53336657)';
        existingClaim.Related_Services_Authorization__c = serviceAuth.Id;
        existingClaim.Related_Patient__c = patient.Id;
        insert existingClaim;
    }
    
    @IsTest
    static void testUpsertNewClaim() {
        // Prepare test data
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094001'; // New claim
        claimData.patientNameId = 'Test Patient Name';
        claimData.primaryAuth = 'VA0033039419';
        claimData.payerId = '13038645';
        claimData.payerName = 'VA CCN OPTUM';
        claimData.dosStart = '2024-02-01';
        claimData.dosEnd = '2024-02-02';
        claimData.claimSubmittedDate = '2024-02-06';
        claimData.chargedAmount = 4900.00;
        claimData.paidAmount = 901.36;
        claimData.balance = 0.00;
        claimData.paymentCheck = '3004700011';
        claimData.paymentDate = '2024-02-15';
        claimData.mrNumber = 'FSB2023-3725898041';
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, result.totalRecords, 'Should process 1 record');
        System.assertEquals(1, result.totalSuccessful, 'Should succeed');
        System.assertEquals(0, result.totalFailed, 'Should have no failures');
        
        // Verify claim was created
        Claims__c newClaim = [
            SELECT Id, Claim_Number__c, Name, Charged_Amount__c, Paid_Amount__c
            FROM Claims__c
            WHERE Claim_Number__c = '227094001'
        ];
        
        System.assertNotEquals(null, newClaim, 'Claim should be created');
        System.assertEquals(4900.00, newClaim.Charged_Amount__c);
        System.assertEquals(901.36, newClaim.Paid_Amount__c);
    }
    
    @IsTest
    static void testUpdateExistingClaim() {
        // Prepare test data
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094000'; // Existing claim
        claimData.patientNameId = 'Updated Patient Name';
        claimData.primaryAuth = 'VA0033039419';
        claimData.payerId = '13038645';
        claimData.payerName = 'VA CCN OPTUM';
        claimData.dosStart = '2024-02-01';
        claimData.dosEnd = '2024-02-02';
        claimData.claimSubmittedDate = '2024-02-06';
        claimData.chargedAmount = 5000.00; // Updated amount
        claimData.paidAmount = 1000.00; // Updated amount
        claimData.balance = 0.00;
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify results
        System.assertEquals(1, result.totalSuccessful, 'Should succeed');
        
        // Verify claim was updated
        Claims__c updatedClaim = [
            SELECT Id, Claim_Number__c, Charged_Amount__c, Paid_Amount__c
            FROM Claims__c
            WHERE Claim_Number__c = '227094000'
        ];
        
        System.assertEquals(5000.00, updatedClaim.Charged_Amount__c, 'Amount should be updated');
        System.assertEquals(1000.00, updatedClaim.Paid_Amount__c, 'Paid amount should be updated');
    }
    
    @IsTest
    static void testMissingClaimNumber() {
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        // Missing claimNumber
        claimData.primaryAuth = 'VA0033039419';
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify validation error
        System.assertEquals(1, result.totalFailed, 'Should fail validation');
        System.assert(result.errors.size() > 0, 'Should have error message');
    }
    
    @IsTest
    static void testMissingPrimaryAuth() {
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094002';
        // Missing primaryAuth
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify validation error
        System.assertEquals(1, result.totalFailed, 'Should fail validation');
    }
    
    @IsTest
    static void testAuthorizationNotFound() {
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094003';
        claimData.primaryAuth = 'NONEXISTENT123'; // Auth doesn't exist
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify error
        System.assertEquals(1, result.totalFailed, 'Should fail lookup');
        System.assert(
            result.errors[0].contains('Service Authorization not found'), 
            'Should have lookup error message'
        );
    }
    
    @IsTest
    static void testBulkUpsert() {
        // Prepare bulk test data
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        for (Integer i = 0; i < 50; i++) {
            ClaimsIntegrationRestService.ClaimData claimData = 
                new ClaimsIntegrationRestService.ClaimData();
            claimData.claimNumber = '227094' + String.valueOf(100 + i);
            claimData.patientNameId = 'Test Patient ' + i;
            claimData.primaryAuth = 'VA0033039419';
            claimData.dosStart = '2024-02-01';
            claimData.chargedAmount = 1000.00 * i;
            
            claimDataList.add(claimData);
        }
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify bulk processing
        System.assertEquals(50, result.totalRecords, 'Should process 50 records');
        System.assertEquals(50, result.totalSuccessful, 'All should succeed');
        System.assertEquals(0, result.totalFailed, 'No failures');
    }
    
    @IsTest
    static void testDateParsing() {
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094999';
        claimData.patientNameId = 'Test Patient';
        claimData.primaryAuth = 'VA0033039419';
        claimData.dosStart = '2024-02-01T00:00:00.000Z'; // ISO format
        claimData.dosEnd = '2024-02-02'; // Simple format
        claimData.paymentDate = '2024-02-15';
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        System.assertEquals(1, result.totalSuccessful, 'Should succeed with date parsing');
        
        // Verify dates were parsed correctly
        Claims__c claim = [
            SELECT DOS__c, DOS_End__c, Paid_Date__c, Paid_Y_or_N__c
            FROM Claims__c
            WHERE Claim_Number__c = '227094999'
        ];
        
        System.assertEquals(Date.valueOf('2024-02-01'), claim.DOS__c);
        System.assertEquals(Date.valueOf('2024-02-02'), claim.DOS_End__c);
        System.assertEquals(Date.valueOf('2024-02-15'), claim.Paid_Date__c);
        System.assertEquals('Yes', claim.Paid_Y_or_N__c);
    }
    
    @IsTest
    static void testPayorMatching() {
        List<ClaimsIntegrationRestService.ClaimData> claimDataList = 
            new List<ClaimsIntegrationRestService.ClaimData>();
        
        ClaimsIntegrationRestService.ClaimData claimData = 
            new ClaimsIntegrationRestService.ClaimData();
        claimData.claimNumber = '227094888';
        claimData.patientNameId = 'Test Patient';
        claimData.primaryAuth = 'VA0033039419';
        claimData.payerId = '13038645';
        claimData.payerName = 'VA CCN OPTUM';
        
        claimDataList.add(claimData);
        
        Test.startTest();
        
        ClaimsIntegrationService service = new ClaimsIntegrationService();
        ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimDataList);
        
        Test.stopTest();
        
        // Verify payor was matched
        Claims__c claim = [
            SELECT Claim_Payor__c, Payer__c
            FROM Claims__c
            WHERE Claim_Number__c = '227094888'
        ];
        
        System.assertNotEquals(null, claim.Claim_Payor__c, 'Payor should be matched');
        System.assertEquals('13038645', claim.Payer__c);
    }
}
