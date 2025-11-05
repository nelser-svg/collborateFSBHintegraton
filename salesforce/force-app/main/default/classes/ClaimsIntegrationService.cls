/**
 * @description Service class for Claims integration business logic
 * @author Salesforce Integration Team
 * @date 2025-10-16
 * 
 * Handles:
 * - Data validation and transformation
 * - Lookup resolution for related objects
 * - Claim upsert operations
 * - Error handling and logging
 */
public class ClaimsIntegrationService {
    
    /**
     * @description Upsert result wrapper class
     */
    public class UpsertResult {
        public Integer totalRecords;
        public Integer totalSuccessful;
        public Integer totalFailed;
        public List<String> errors;
        
        public UpsertResult() {
            this.totalRecords = 0;
            this.totalSuccessful = 0;
            this.totalFailed = 0;
            this.errors = new List<String>();
        }
    }
    
    /**
     * @description Main method to upsert claims
     * @param claimDataList List of claim data from REST API
     * @return UpsertResult containing statistics and errors
     */
    public UpsertResult upsertClaims(List<ClaimsIntegrationRestService.ClaimData> claimDataList) {
        UpsertResult result = new UpsertResult();
        result.totalRecords = claimDataList.size();
        
        try {
            // Step 1: Collect Authorization Numbers and MR Numbers for lookup
            Set<String> authNumbers = new Set<String>();
            Set<String> mrNumbers = new Set<String>();
            
            for (ClaimsIntegrationRestService.ClaimData claimData : claimDataList) {
                if (String.isNotBlank(claimData.primaryAuth)) {
                    authNumbers.add(claimData.primaryAuth);
                }
                if (String.isNotBlank(claimData.mrNumber)) {
                    mrNumbers.add(claimData.mrNumber);
                }
            }
            
            // Step 2: Query Service Authorizations with related Patient data
            Map<String, Services_Authorization__c> authMap = getServiceAuthorizationsMap(authNumbers);
            
            // Step 3: Query Claim Payors
            Map<String, Id> payorMap = getClaimPayorMap();
            
            // Step 4: Query existing Claims for upsert logic
            Set<String> claimNumbers = new Set<String>();
            for (ClaimsIntegrationRestService.ClaimData claimData : claimDataList) {
                if (String.isNotBlank(claimData.claimNumber)) {
                    claimNumbers.add(claimData.claimNumber);
                }
            }
            Map<String, Claims__c> existingClaimsMap = getExistingClaimsMap(claimNumbers);
            
            // Step 5: Transform and validate data
            List<Claims__c> claimsToUpsert = new List<Claims__c>();
            
            for (ClaimsIntegrationRestService.ClaimData claimData : claimDataList) {
                try {
                    // Validate required fields
                    if (String.isBlank(claimData.claimNumber)) {
                        result.errors.add('Missing required field: claimNumber');
                        result.totalFailed++;
                        continue;
                    }
                    
                    if (String.isBlank(claimData.primaryAuth)) {
                        result.errors.add('Claim ' + claimData.claimNumber + ': Missing required field: primaryAuth');
                        result.totalFailed++;
                        continue;
                    }
                    
                    // Get Service Authorization
                    Services_Authorization__c serviceAuth = authMap.get(claimData.primaryAuth);
                    if (serviceAuth == null) {
                        result.errors.add('Claim ' + claimData.claimNumber + ': Service Authorization not found: ' + claimData.primaryAuth);
                        result.totalFailed++;
                        continue;
                    }
                    
                    // Build Claims__c record
                    Claims__c claim = existingClaimsMap.get(claimData.claimNumber);
                    if (claim == null) {
                        claim = new Claims__c();
                    }
                    
                    // Map fields
                    claim.Claim_Number__c = claimData.claimNumber;
                    claim.Name = truncate(claimData.patientNameId, 80); // Name field limit
                    claim.Insurance_Authorization_Number__c = claimData.primaryAuth;
                    claim.Related_Services_Authorization__c = serviceAuth.Id;
                    claim.LOC__c = serviceAuth.Level_of_Care__c;
                    claim.ServiceAuth_Record_ID__c = serviceAuth.Id;
                    
                    // Related Patient
                    if (serviceAuth.Related_Patient__c != null) {
                        claim.Related_Patient__c = serviceAuth.Related_Patient__c;
                        claim.MR_Number__c = serviceAuth.Related_Patient__r.MR_Number__c;
                    }
                    
                    // Payor fields
                    if (String.isNotBlank(claimData.payerId)) {
                        claim.Payer__c = claimData.payerId;
                    }
                    
                    // Lookup Claim Payor
                    if (String.isNotBlank(claimData.payerName) && String.isNotBlank(claimData.payerId)) {
                        String payorKey = claimData.payerName + ' (' + claimData.payerId + ')';
                        if (payorMap.containsKey(payorKey)) {
                            claim.Claim_Payor__c = payorMap.get(payorKey);
                        } else if (payorMap.containsKey(claimData.payerName)) {
                            claim.Claim_Payor__c = payorMap.get(claimData.payerName);
                        }
                    }
                    
                    // Date fields
                    if (String.isNotBlank(claimData.dosStart)) {
                        claim.DOS__c = parseDate(claimData.dosStart);
                    }
                    if (String.isNotBlank(claimData.dosEnd)) {
                        claim.DOS_End__c = parseDate(claimData.dosEnd);
                    }
                    if (String.isNotBlank(claimData.claimSubmittedDate)) {
                        claim.Claim_Submitted_Date__c = parseDate(claimData.claimSubmittedDate);
                    }
                    if (String.isNotBlank(claimData.paymentDate)) {
                        claim.Paid_Date__c = parseDate(claimData.paymentDate);
                        claim.Paid_Y_or_N__c = 'Yes';
                    } else {
                        claim.Paid_Y_or_N__c = 'No';
                    }
                    
                    // Currency fields
                    if (claimData.chargedAmount != null) {
                        claim.Charged_Amount__c = claimData.chargedAmount;
                    }
                    if (claimData.paidAmount != null) {
                        claim.Paid_Amount__c = claimData.paidAmount;
                    }
                    if (claimData.balance != null) {
                        claim.Total_BDP__c = claimData.balance;
                    }
                    
                    // Text fields
                    if (String.isNotBlank(claimData.paymentCheck)) {
                        claim.EFT_or_Paper_Check__c = claimData.paymentCheck;
                    }
                    
                    claimsToUpsert.add(claim);
                    
                } catch (Exception e) {
                    result.errors.add('Claim ' + claimData.claimNumber + ': ' + e.getMessage());
                    result.totalFailed++;
                }
            }
            
            // Step 6: Perform upsert operation
            if (!claimsToUpsert.isEmpty()) {
                Database.UpsertResult[] upsertResults = Database.upsert(
                    claimsToUpsert, 
                    Claims__c.Claim_Number__c, 
                    false // Allow partial success
                );
                
                // Process results
                for (Integer i = 0; i < upsertResults.size(); i++) {
                    Database.UpsertResult upsertResult = upsertResults[i];
                    
                    if (upsertResult.isSuccess()) {
                        result.totalSuccessful++;
                    } else {
                        result.totalFailed++;
                        
                        String claimNumber = claimsToUpsert[i].Claim_Number__c;
                        String errorMessage = 'Claim ' + claimNumber + ': ';
                        
                        for (Database.Error err : upsertResult.getErrors()) {
                            errorMessage += err.getMessage() + '; ';
                        }
                        
                        result.errors.add(errorMessage);
                    }
                }
            }
            
        } catch (Exception e) {
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.ERROR,
                'ClaimsIntegrationService',
                'upsertClaims',
                'Unexpected error: ' + e.getMessage(),
                e.getStackTraceString()
            );
            
            result.errors.add('Unexpected error: ' + e.getMessage());
            result.totalFailed = result.totalRecords;
            result.totalSuccessful = 0;
        }
        
        return result;
    }
    
    /**
     * @description Get Service Authorizations mapped by Authorization Number
     * @param authNumbers Set of Authorization Numbers
     * @return Map of Authorization Number to Service Authorization record
     */
    private Map<String, Services_Authorization__c> getServiceAuthorizationsMap(Set<String> authNumbers) {
        Map<String, Services_Authorization__c> authMap = new Map<String, Services_Authorization__c>();
        
        if (authNumbers.isEmpty()) {
            return authMap;
        }
        
        for (Services_Authorization__c auth : [
            SELECT Id, 
                   Authorization_Number__c, 
                   Level_of_Care__c,
                   Related_Patient__c,
                   Related_Patient__r.MR_Number__c
            FROM Services_Authorization__c
            WHERE Authorization_Number__c IN :authNumbers
        ]) {
            authMap.put(auth.Authorization_Number__c, auth);
        }
        
        return authMap;
    }
    
    /**
     * @description Get Claim Payor mapping
     * @return Map of Payor Name to Payor Id
     */
    private Map<String, Id> getClaimPayorMap() {
        Map<String, Id> payorMap = new Map<String, Id>();
        
        for (Claim_Payor__c payor : [SELECT Id, Name FROM Claim_Payor__c]) {
            payorMap.put(payor.Name, payor.Id);
            
            // Also map without Payer ID for fallback matching
            if (payor.Name.contains('(#')) {
                String nameWithoutId = payor.Name.substringBefore('(#').trim();
                payorMap.put(nameWithoutId, payor.Id);
            }
        }
        
        return payorMap;
    }
    
    /**
     * @description Get existing Claims mapped by Claim Number
     * @param claimNumbers Set of Claim Numbers
     * @return Map of Claim Number to Claims__c record
     */
    private Map<String, Claims__c> getExistingClaimsMap(Set<String> claimNumbers) {
        Map<String, Claims__c> claimsMap = new Map<String, Claims__c>();
        
        if (claimNumbers.isEmpty()) {
            return claimsMap;
        }
        
        for (Claims__c claim : [
            SELECT Id, 
                   Claim_Number__c,
                   Name,
                   Insurance_Authorization_Number__c,
                   Related_Services_Authorization__c,
                   Related_Patient__c
            FROM Claims__c
            WHERE Claim_Number__c IN :claimNumbers
        ]) {
            claimsMap.put(claim.Claim_Number__c, claim);
        }
        
        return claimsMap;
    }
    
    /**
     * @description Parse date string (YYYY-MM-DD or ISO format)
     * @param dateString Date string to parse
     * @return Date value
     */
    private Date parseDate(String dateString) {
        if (String.isBlank(dateString)) {
            return null;
        }
        
        try {
            // Handle ISO format (2024-02-01T00:00:00.000Z)
            if (dateString.contains('T')) {
                dateString = dateString.substringBefore('T');
            }
            
            // Parse YYYY-MM-DD format
            return Date.valueOf(dateString);
            
        } catch (Exception e) {
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.WARNING,
                'ClaimsIntegrationService',
                'parseDate',
                'Failed to parse date: ' + dateString,
                null
            );
            return null;
        }
    }
    
    /**
     * @description Truncate string to specified length
     * @param value String to truncate
     * @param maxLength Maximum length
     * @return Truncated string
     */
    private String truncate(String value, Integer maxLength) {
        if (String.isBlank(value)) {
            return value;
        }
        return value.length() > maxLength ? value.substring(0, maxLength) : value;
    }
}
