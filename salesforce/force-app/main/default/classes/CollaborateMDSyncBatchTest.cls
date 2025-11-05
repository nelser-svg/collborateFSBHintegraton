
/**
 * @description Test class for CollaborateMDSyncBatch
 * @author Salesforce Integration Team
 * @date 2025-10-16
 */
@IsTest
private class CollaborateMDSyncBatchTest {
    
    @IsTest
    static void testBatchExecution() {
        // Set up mock response for HTTP callout
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        Test.startTest();
        
        CollaborateMDSyncBatch batch = new CollaborateMDSyncBatch();
        Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        // Verify integration logs were created
        List<Integration_Log__c> logs = [
            SELECT Id, Log_Level__c, Class_Name__c, Message__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'CollaborateMDSyncBatch'
        ];
        
        System.assert(logs.size() > 0, 'Integration logs should be created');
        
        // Verify success log exists
        Boolean hasSuccessLog = false;
        for (Integration_Log__c log : logs) {
            if (log.Message__c.contains('Lambda triggered successfully')) {
                hasSuccessLog = true;
                break;
            }
        }
        System.assert(hasSuccessLog, 'Should have success log');
    }
    
    @IsTest
    static void testScheduledExecution() {
        // Set up mock response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseSuccess());
        
        Test.startTest();
        
        // Schedule the batch
        String cronExp = '0 0 2 * * ?';
        String jobId = System.schedule(
            'Test CollaborateMD Sync', 
            cronExp, 
            new CollaborateMDSyncBatch()
        );
        
        Test.stopTest();
        
        // Verify job was scheduled
        CronTrigger ct = [
            SELECT Id, CronExpression, TimesTriggered
            FROM CronTrigger
            WHERE Id = :jobId
        ];
        
        System.assertEquals(cronExp, ct.CronExpression, 'Cron expression should match');
    }
    
    @IsTest
    static void testHttpCalloutError() {
        // Set up mock error response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseError());
        
        Test.startTest();
        
        CollaborateMDSyncBatch batch = new CollaborateMDSyncBatch();
        Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        // Verify error logs were created
        List<Integration_Log__c> errorLogs = [
            SELECT Id, Log_Level__c, Message__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'CollaborateMDSyncBatch'
            AND Log_Level__c = 'ERROR'
        ];
        
        System.assert(errorLogs.size() > 0, 'Error logs should be created');
        
        Boolean hasErrorMessage = false;
        for (Integration_Log__c log : errorLogs) {
            if (log.Message__c.contains('Lambda returned error')) {
                hasErrorMessage = true;
                break;
            }
        }
        System.assert(hasErrorMessage, 'Should have error message about Lambda failure');
    }
    
    @IsTest
    static void testHttpCalloutTimeout() {
        // Set up mock timeout response
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseTimeout());
        
        Test.startTest();
        
        CollaborateMDSyncBatch batch = new CollaborateMDSyncBatch();
        Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        // Verify error was logged
        List<Integration_Log__c> errorLogs = [
            SELECT Id, Message__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'CollaborateMDSyncBatch'
            AND Log_Level__c = 'ERROR'
        ];
        
        System.assert(errorLogs.size() > 0, 'Should log timeout error');
    }
    
    @IsTest
    static void testBatchStatistics() {
        // Set up mock response with statistics
        Test.setMock(HttpCalloutMock.class, new MockHttpResponseWithStats());
        
        Test.startTest();
        
        CollaborateMDSyncBatch batch = new CollaborateMDSyncBatch();
        Database.executeBatch(batch, 1);
        
        Test.stopTest();
        
        // Verify batch statistics were logged
        List<Integration_Log__c> batchLogs = [
            SELECT Id, Records_Processed__c, Records_Successful__c, Records_Failed__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'CollaborateMDSyncBatch'
            AND Records_Processed__c != null
        ];
        
        System.assert(batchLogs.size() > 0, 'Batch statistics should be logged');
    }
    
    // Mock HTTP response classes
    
    /**
     * Mock successful HTTP response
     */
    private class MockHttpResponseSuccess implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseBody = new Map<String, Object>();
            responseBody.put('statusCode', 200);
            responseBody.put('body', JSON.serialize(new Map<String, Object>{
                'message' => 'Sync completed successfully',
                'records_processed' => 0,
                'records_successful' => 0,
                'records_failed' => 0
            }));
            
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
    
    /**
     * Mock error HTTP response
     */
    private class MockHttpResponseError implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(500);
            res.setBody('{"error": "Internal server error"}');
            return res;
        }
    }
    
    /**
     * Mock timeout response
     */
    private class MockHttpResponseTimeout implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            // Simulate timeout by throwing exception
            throw new CalloutException('Read timed out');
        }
    }
    
    /**
     * Mock response with statistics
     */
    private class MockHttpResponseWithStats implements HttpCalloutMock {
        public HTTPResponse respond(HTTPRequest req) {
            HttpResponse res = new HttpResponse();
            res.setHeader('Content-Type', 'application/json');
            res.setStatusCode(200);
            
            Map<String, Object> responseBody = new Map<String, Object>();
            responseBody.put('statusCode', 200);
            responseBody.put('body', JSON.serialize(new Map<String, Object>{
                'message' => 'Sync completed successfully',
                'records_processed' => 150,
                'records_successful' => 145,
                'records_failed' => 5
            }));
            
            res.setBody(JSON.serialize(responseBody));
            return res;
        }
    }
}
