
/**
 * @description Test class for IntegrationLogger
 * @author Salesforce Integration Team
 * @date 2025-10-16
 */
@IsTest
private class IntegrationLoggerTest {
    
    @IsTest
    static void testLogInfo() {
        Test.startTest();
        
        IntegrationLogger.log(
            IntegrationLogger.LogLevel.INFO,
            'TestClass',
            'testMethod',
            'Test info message',
            null
        );
        
        Test.stopTest();
        
        // Verify log record was created
        List<Integration_Log__c> logs = [
            SELECT Id, Log_Level__c, Class_Name__c, Method_Name__c, Message__c
            FROM Integration_Log__c
            WHERE Log_Level__c = 'INFO'
        ];
        
        System.assertEquals(1, logs.size(), 'One INFO log should be created');
        System.assertEquals('TestClass', logs[0].Class_Name__c);
        System.assertEquals('testMethod', logs[0].Method_Name__c);
        System.assertEquals('Test info message', logs[0].Message__c);
    }
    
    @IsTest
    static void testLogWarning() {
        Test.startTest();
        
        IntegrationLogger.log(
            IntegrationLogger.LogLevel.WARNING,
            'TestClass',
            'testMethod',
            'Test warning message',
            null
        );
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Log_Level__c
            FROM Integration_Log__c
            WHERE Log_Level__c = 'WARNING'
        ];
        
        System.assertEquals(1, logs.size(), 'One WARNING log should be created');
    }
    
    @IsTest
    static void testLogError() {
        Test.startTest();
        
        IntegrationLogger.log(
            IntegrationLogger.LogLevel.ERROR,
            'TestClass',
            'testMethod',
            'Test error message',
            'Test stack trace'
        );
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Log_Level__c, Stack_Trace__c
            FROM Integration_Log__c
            WHERE Log_Level__c = 'ERROR'
        ];
        
        System.assertEquals(1, logs.size(), 'One ERROR log should be created');
        System.assertEquals('Test stack trace', logs[0].Stack_Trace__c);
    }
    
    @IsTest
    static void testLogApiCallout() {
        Test.startTest();
        
        IntegrationLogger.logApiCallout(
            'https://api.example.com/endpoint',
            'POST',
            '{"test": "request"}',
            200,
            '{"test": "response"}'
        );
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Method_Name__c, Request_Body__c, Response_Body__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'API_Callout'
        ];
        
        System.assertEquals(1, logs.size(), 'One API callout log should be created');
        System.assertEquals('POST', logs[0].Method_Name__c);
        System.assert(logs[0].Request_Body__c.contains('test'), 'Request body should be logged');
        System.assert(logs[0].Response_Body__c.contains('test'), 'Response body should be logged');
    }
    
    @IsTest
    static void testLogBatchStats() {
        Test.startTest();
        
        IntegrationLogger.logBatchStats(
            'TestBatch',
            100,
            95,
            5,
            5000
        );
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Records_Processed__c, Records_Successful__c, Records_Failed__c
            FROM Integration_Log__c
            WHERE Class_Name__c = 'TestBatch'
        ];
        
        System.assertEquals(1, logs.size(), 'One batch stats log should be created');
        System.assertEquals(100, logs[0].Records_Processed__c);
        System.assertEquals(95, logs[0].Records_Successful__c);
        System.assertEquals(5, logs[0].Records_Failed__c);
    }
    
    @IsTest
    static void testLogBulk() {
        List<Integration_Log__c> logsToInsert = new List<Integration_Log__c>();
        
        for (Integer i = 0; i < 5; i++) {
            Integration_Log__c log = new Integration_Log__c();
            log.Log_Level__c = 'INFO';
            log.Class_Name__c = 'BulkTest';
            log.Method_Name__c = 'test' + i;
            log.Message__c = 'Bulk log message ' + i;
            log.Timestamp__c = System.now();
            logsToInsert.add(log);
        }
        
        Test.startTest();
        
        IntegrationLogger.logBulk(logsToInsert);
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id
            FROM Integration_Log__c
            WHERE Class_Name__c = 'BulkTest'
        ];
        
        System.assertEquals(5, logs.size(), 'Five bulk logs should be created');
    }
    
    @IsTest
    static void testCleanupOldLogs() {
        // Create old log records
        List<Integration_Log__c> oldLogs = new List<Integration_Log__c>();
        
        for (Integer i = 0; i < 10; i++) {
            Integration_Log__c log = new Integration_Log__c();
            log.Log_Level__c = 'INFO';
            log.Class_Name__c = 'OldLog';
            log.Message__c = 'Old log message ' + i;
            log.Timestamp__c = System.now().addDays(-40);
            oldLogs.add(log);
        }
        
        insert oldLogs;
        
        // Also create some recent logs
        Integration_Log__c recentLog = new Integration_Log__c();
        recentLog.Log_Level__c = 'INFO';
        recentLog.Class_Name__c = 'RecentLog';
        recentLog.Message__c = 'Recent log message';
        recentLog.Timestamp__c = System.now();
        insert recentLog;
        
        Test.startTest();
        
        Integer deletedCount = IntegrationLogger.cleanupOldLogs(30);
        
        Test.stopTest();
        
        // Verify old logs are deleted
        List<Integration_Log__c> remainingOldLogs = [
            SELECT Id
            FROM Integration_Log__c
            WHERE Class_Name__c = 'OldLog'
        ];
        
        System.assertEquals(0, remainingOldLogs.size(), 'Old logs should be deleted');
        
        // Verify recent log is still there
        List<Integration_Log__c> remainingRecentLogs = [
            SELECT Id
            FROM Integration_Log__c
            WHERE Class_Name__c = 'RecentLog'
        ];
        
        System.assertEquals(1, remainingRecentLogs.size(), 'Recent log should remain');
    }
    
    @IsTest
    static void testTruncateLongMessage() {
        // Create a very long message
        String longMessage = '';
        for (Integer i = 0; i < 40000; i++) {
            longMessage += 'x';
        }
        
        Test.startTest();
        
        IntegrationLogger.log(
            IntegrationLogger.LogLevel.INFO,
            'TestClass',
            'testMethod',
            longMessage,
            null
        );
        
        Test.stopTest();
        
        List<Integration_Log__c> logs = [
            SELECT Id, Message__c
            FROM Integration_Log__c
        ];
        
        System.assertEquals(1, logs.size());
        System.assert(logs[0].Message__c.length() <= 32768, 'Message should be truncated');
    }
}
