
/**
 * @description Custom logging framework for integration events
 * @author Salesforce Integration Team
 * @date 2025-10-16
 * 
 * Usage:
 * IntegrationLogger.log(
 *     IntegrationLogger.LogLevel.INFO,
 *     'ClassName',
 *     'methodName',
 *     'Log message',
 *     null
 * );
 */
public class IntegrationLogger {
    
    /**
     * @description Log level enumeration
     */
    public enum LogLevel {
        INFO,
        WARNING,
        ERROR
    }
    
    /**
     * @description Log an integration event
     * @param level Log level (INFO, WARNING, ERROR)
     * @param className Name of the class logging the event
     * @param methodName Name of the method logging the event
     * @param message Log message
     * @param stackTrace Stack trace (for errors)
     */
    public static void log(LogLevel level, String className, String methodName, String message, String stackTrace) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();
            logRecord.Log_Level__c = level.name();
            logRecord.Class_Name__c = className;
            logRecord.Method_Name__c = methodName;
            logRecord.Message__c = truncate(message, 32768); // Long Text Area limit
            logRecord.Stack_Trace__c = truncate(stackTrace, 32768);
            logRecord.Timestamp__c = System.now();
            
            insert logRecord;
            
        } catch (Exception e) {
            // If logging fails, output to debug log but don't throw exception
            System.debug(LoggingLevel.ERROR, 'Failed to create Integration_Log__c record: ' + e.getMessage());
            System.debug(LoggingLevel.ERROR, 'Original message: ' + message);
        }
    }
    
    /**
     * @description Log API callout information
     * @param endpoint API endpoint URL
     * @param method HTTP method
     * @param requestBody Request body
     * @param responseCode Response status code
     * @param responseBody Response body
     */
    public static void logApiCallout(
        String endpoint, 
        String method, 
        String requestBody, 
        Integer responseCode, 
        String responseBody
    ) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();
            logRecord.Log_Level__c = (responseCode >= 200 && responseCode < 300) ? 'INFO' : 'ERROR';
            logRecord.Class_Name__c = 'API_Callout';
            logRecord.Method_Name__c = method;
            logRecord.Message__c = String.format(
                'Endpoint: {0}\nStatus Code: {1}',
                new List<Object>{endpoint, responseCode}
            );
            logRecord.Request_Body__c = truncate(requestBody, 32768);
            logRecord.Response_Body__c = truncate(responseBody, 32768);
            logRecord.Timestamp__c = System.now();
            
            insert logRecord;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log API callout: ' + e.getMessage());
        }
    }
    
    /**
     * @description Log batch execution statistics
     * @param batchName Name of the batch class
     * @param recordsProcessed Number of records processed
     * @param recordsSuccessful Number of successful records
     * @param recordsFailed Number of failed records
     * @param executionTime Execution time in milliseconds
     */
    public static void logBatchStats(
        String batchName,
        Integer recordsProcessed,
        Integer recordsSuccessful,
        Integer recordsFailed,
        Long executionTime
    ) {
        try {
            Integration_Log__c logRecord = new Integration_Log__c();
            logRecord.Log_Level__c = (recordsFailed > 0) ? 'WARNING' : 'INFO';
            logRecord.Class_Name__c = batchName;
            logRecord.Method_Name__c = 'execute';
            logRecord.Message__c = String.format(
                'Batch Execution Stats:\n' +
                'Records Processed: {0}\n' +
                'Successful: {1}\n' +
                'Failed: {2}\n' +
                'Execution Time: {3}ms',
                new List<Object>{
                    recordsProcessed,
                    recordsSuccessful,
                    recordsFailed,
                    executionTime
                }
            );
            logRecord.Records_Processed__c = recordsProcessed;
            logRecord.Records_Successful__c = recordsSuccessful;
            logRecord.Records_Failed__c = recordsFailed;
            logRecord.Timestamp__c = System.now();
            
            insert logRecord;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to log batch stats: ' + e.getMessage());
        }
    }
    
    /**
     * @description Log multiple events at once (bulk logging)
     * @param logRecords List of Integration_Log__c records to insert
     */
    public static void logBulk(List<Integration_Log__c> logRecords) {
        try {
            if (logRecords != null && !logRecords.isEmpty()) {
                insert logRecords;
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to bulk insert logs: ' + e.getMessage());
        }
    }
    
    /**
     * @description Truncate string to specified length
     * @param value String to truncate
     * @param maxLength Maximum length
     * @return Truncated string
     */
    private static String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
    
    /**
     * @description Delete old log records (for scheduled cleanup)
     * @param daysToKeep Number of days to keep logs
     * @return Number of records deleted
     */
    public static Integer cleanupOldLogs(Integer daysToKeep) {
        try {
            Date cutoffDate = Date.today().addDays(-daysToKeep);
            
            List<Integration_Log__c> oldLogs = [
                SELECT Id 
                FROM Integration_Log__c 
                WHERE CreatedDate < :cutoffDate
                LIMIT 10000
            ];
            
            if (!oldLogs.isEmpty()) {
                delete oldLogs;
                
                log(
                    LogLevel.INFO,
                    'IntegrationLogger',
                    'cleanupOldLogs',
                    'Deleted ' + oldLogs.size() + ' old log records',
                    null
                );
                
                return oldLogs.size();
            }
            
            return 0;
            
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Failed to cleanup old logs: ' + e.getMessage());
            return 0;
        }
    }
}
