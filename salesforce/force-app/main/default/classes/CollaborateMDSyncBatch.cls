
/**
 * @description Schedulable batch class to trigger Python middleware (AWS Lambda)
 * @author Salesforce Integration Team
 * @date 2025-10-16
 * 
 * Purpose: Triggers the Python middleware to fetch claims from CollaborateMD
 *          and send them back to Salesforce in batches
 * 
 * Usage:
 * // Schedule to run daily at 2 AM
 * String cronExp = '0 0 2 * * ?';
 * String jobId = System.schedule('CollaborateMD Daily Sync', cronExp, new CollaborateMDSyncBatch());
 * 
 * // Or run immediately
 * Database.executeBatch(new CollaborateMDSyncBatch(), 1);
 */
global class CollaborateMDSyncBatch implements 
    Schedulable, 
    Database.Batchable<sObject>, 
    Database.AllowsCallouts,
    Database.Stateful {
    
    // Stateful variables to track execution
    private Integer totalRecordsProcessed = 0;
    private Integer totalRecordsSuccessful = 0;
    private Integer totalRecordsFailed = 0;
    private Long executionStartTime;
    private List<String> executionErrors = new List<String>();
    
    /**
     * @description Schedulable execute method
     */
    global void execute(SchedulableContext sc) {
        // Execute batch with batch size of 1 (we only need one execution)
        Database.executeBatch(new CollaborateMDSyncBatch(), 1);
    }
    
    /**
     * @description Batch start method
     */
    global Database.QueryLocator start(Database.BatchableContext bc) {
        executionStartTime = System.currentTimeMillis();
        
        IntegrationLogger.log(
            IntegrationLogger.LogLevel.INFO,
            'CollaborateMDSyncBatch',
            'start',
            'Starting CollaborateMD sync batch',
            null
        );
        
        // Return a dummy query - we just need one execution
        return Database.getQueryLocator([
            SELECT Id 
            FROM User 
            WHERE Id = :UserInfo.getUserId() 
            LIMIT 1
        ]);
    }
    
    /**
     * @description Batch execute method - triggers Lambda
     */
    global void execute(Database.BatchableContext bc, List<sObject> scope) {
        try {
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.INFO,
                'CollaborateMDSyncBatch',
                'execute',
                'Triggering Lambda endpoint',
                null
            );
            
            // Make callout to Lambda endpoint
            HttpRequest req = new HttpRequest();
            req.setEndpoint('callout:CollaborateMD_Lambda');
            req.setMethod('POST');
            req.setHeader('Content-Type', 'application/json');
            req.setTimeout(120000); // 120 seconds
            
            // Optional: Pass parameters to Lambda
            Map<String, Object> requestBody = new Map<String, Object>();
            requestBody.put('trigger_source', 'salesforce_batch');
            requestBody.put('timestamp', String.valueOf(System.now()));
            requestBody.put('full_sync', false); // Set to true for full sync
            
            req.setBody(JSON.serialize(requestBody));
            
            // Send request
            Http http = new Http();
            HttpResponse res = http.send(req);
            
            // Parse response
            Integer statusCode = res.getStatusCode();
            String responseBody = res.getBody();
            
            // Log API callout
            IntegrationLogger.logApiCallout(
                'callout:CollaborateMD_Lambda',
                'POST',
                req.getBody(),
                statusCode,
                responseBody
            );
            
            // Check response status
            if (statusCode >= 200 && statusCode < 300) {
                // Success
                IntegrationLogger.log(
                    IntegrationLogger.LogLevel.INFO,
                    'CollaborateMDSyncBatch',
                    'execute',
                    'Lambda triggered successfully. Status: ' + statusCode,
                    null
                );
                
                // Parse response to get statistics
                try {
                    Map<String, Object> responseMap = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
                    
                    if (responseMap.containsKey('body')) {
                        String bodyString = String.valueOf(responseMap.get('body'));
                        Map<String, Object> bodyMap = (Map<String, Object>) JSON.deserializeUntyped(bodyString);
                        
                        if (bodyMap.containsKey('records_processed')) {
                            totalRecordsProcessed = Integer.valueOf(bodyMap.get('records_processed'));
                        }
                        if (bodyMap.containsKey('records_successful')) {
                            totalRecordsSuccessful = Integer.valueOf(bodyMap.get('records_successful'));
                        }
                        if (bodyMap.containsKey('records_failed')) {
                            totalRecordsFailed = Integer.valueOf(bodyMap.get('records_failed'));
                        }
                    }
                } catch (Exception e) {
                    // If parsing fails, just log the raw response
                    System.debug('Could not parse Lambda response: ' + e.getMessage());
                }
                
            } else {
                // Error
                String errorMessage = 'Lambda returned error status: ' + statusCode + '. Response: ' + responseBody;
                executionErrors.add(errorMessage);
                
                IntegrationLogger.log(
                    IntegrationLogger.LogLevel.ERROR,
                    'CollaborateMDSyncBatch',
                    'execute',
                    errorMessage,
                    null
                );
            }
            
        } catch (Exception e) {
            String errorMessage = 'Error triggering Lambda: ' + e.getMessage();
            executionErrors.add(errorMessage);
            
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.ERROR,
                'CollaborateMDSyncBatch',
                'execute',
                errorMessage,
                e.getStackTraceString()
            );
        }
    }
    
    /**
     * @description Batch finish method - log statistics
     */
    global void finish(Database.BatchableContext bc) {
        Long executionEndTime = System.currentTimeMillis();
        Long executionTime = executionEndTime - executionStartTime;
        
        // Log batch statistics
        IntegrationLogger.logBatchStats(
            'CollaborateMDSyncBatch',
            totalRecordsProcessed,
            totalRecordsSuccessful,
            totalRecordsFailed,
            executionTime
        );
        
        // Log completion
        String completionMessage = String.format(
            'CollaborateMD sync batch completed. Records Processed: {0}, Successful: {1}, Failed: {2}, Execution Time: {3}ms',
            new List<Object>{
                totalRecordsProcessed,
                totalRecordsSuccessful,
                totalRecordsFailed,
                executionTime
            }
        );
        
        IntegrationLogger.log(
            (totalRecordsFailed > 0 || !executionErrors.isEmpty()) ? 
                IntegrationLogger.LogLevel.WARNING : IntegrationLogger.LogLevel.INFO,
            'CollaborateMDSyncBatch',
            'finish',
            completionMessage,
            null
        );
        
        // Log errors if any
        if (!executionErrors.isEmpty()) {
            for (String error : executionErrors) {
                IntegrationLogger.log(
                    IntegrationLogger.LogLevel.ERROR,
                    'CollaborateMDSyncBatch',
                    'finish',
                    'Execution error: ' + error,
                    null
                );
            }
        }
        
        // Optional: Send email notification
        sendNotificationEmail(bc, completionMessage);
    }
    
    /**
     * @description Send notification email to admin
     */
    private void sendNotificationEmail(Database.BatchableContext bc, String message) {
        try {
            // Get admin email from custom setting or hardcode
            String adminEmail = getAdminEmail();
            
            if (String.isBlank(adminEmail)) {
                return;
            }
            
            Messaging.SingleEmailMessage mail = new Messaging.SingleEmailMessage();
            mail.setToAddresses(new String[] { adminEmail });
            mail.setSubject('CollaborateMD Sync Batch - Execution Summary');
            mail.setPlainTextBody(buildEmailBody(bc, message));
            
            Messaging.sendEmail(new Messaging.SingleEmailMessage[] { mail });
            
        } catch (Exception e) {
            System.debug('Failed to send notification email: ' + e.getMessage());
        }
    }
    
    /**
     * @description Build email body
     */
    private String buildEmailBody(Database.BatchableContext bc, String message) {
        String emailBody = 'CollaborateMD Sync Batch Execution Summary\n\n';
        emailBody += 'Batch Job ID: ' + bc.getJobId() + '\n';
        emailBody += 'Execution Time: ' + String.valueOf(System.now()) + '\n\n';
        emailBody += 'Summary:\n';
        emailBody += message + '\n\n';
        
        if (!executionErrors.isEmpty()) {
            emailBody += 'Errors:\n';
            for (String error : executionErrors) {
                emailBody += '- ' + error + '\n';
            }
        }
        
        emailBody += '\n\nPlease check Integration Logs for more details.';
        
        return emailBody;
    }
    
    /**
     * @description Get admin email from custom metadata or user
     */
    private String getAdminEmail() {
        // Option 1: Return current user's email
        // return UserInfo.getUserEmail();
        
        // Option 2: Query from custom metadata type (recommended)
        // List<Integration_Config__mdt> configs = [
        //     SELECT Admin_Email__c 
        //     FROM Integration_Config__mdt 
        //     WHERE DeveloperName = 'Default' 
        //     LIMIT 1
        // ];
        // return !configs.isEmpty() ? configs[0].Admin_Email__c : null;
        
        // Option 3: Hardcode for testing
        return UserInfo.getUserEmail();
    }
}
