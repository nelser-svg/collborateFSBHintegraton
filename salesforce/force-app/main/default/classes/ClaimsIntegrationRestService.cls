
/**
 * @description REST API endpoint to receive batched claims data from Python middleware
 * @author Salesforce Integration Team
 * @date 2025-10-16
 * 
 * Endpoint: /services/apexrest/ClaimsIntegration/v1
 * Method: POST
 * 
 * Request Body Example:
 * {
 *   "claims": [
 *     {
 *       "claimNumber": "227094000",
 *       "patientNameId": "WILCKEN, CHRISTOPHER (53336657)",
 *       "primaryAuth": "VA0033039419",
 *       "payerId": "13038645",
 *       "payerName": "VA CCN OPTUM",
 *       "dosStart": "2024-02-01",
 *       "dosEnd": "2024-02-02",
 *       "claimSubmittedDate": "2024-02-06",
 *       "chargedAmount": 4900.00,
 *       "paidAmount": 901.36,
 *       "balance": 0.00,
 *       "paymentCheck": "3004700011",
 *       "paymentDate": "2024-02-15",
 *       "mrNumber": "FSB2023-3725898041"
 *     }
 *   ]
 * }
 */
@RestResource(urlMapping='/ClaimsIntegration/v1')
global with sharing class ClaimsIntegrationRestService {
    
    /**
     * @description POST endpoint to receive and process batched claims data
     * @return ClaimsResponse containing success/failure details
     */
    @HttpPost
    global static ClaimsResponse upsertClaims() {
        ClaimsResponse response = new ClaimsResponse();
        
        try {
            // Get request body
            RestRequest req = RestContext.request;
            RestResponse res = RestContext.response;
            
            // Log the incoming request
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.INFO,
                'ClaimsIntegrationRestService',
                'upsertClaims',
                'Received claims upsert request',
                null
            );
            
            // Parse request body
            String requestBody = req.requestBody.toString();
            ClaimsRequest claimsRequest = (ClaimsRequest) JSON.deserialize(
                requestBody, 
                ClaimsRequest.class
            );
            
            // Validate request
            if (claimsRequest == null || claimsRequest.claims == null || claimsRequest.claims.isEmpty()) {
                response.success = false;
                response.message = 'No claims data provided';
                res.statusCode = 400;
                
                IntegrationLogger.log(
                    IntegrationLogger.LogLevel.WARNING,
                    'ClaimsIntegrationRestService',
                    'upsertClaims',
                    'Invalid request: No claims data provided',
                    null
                );
                
                return response;
            }
            
            // Check batch size limit (max 200 records per batch)
            if (claimsRequest.claims.size() > 200) {
                response.success = false;
                response.message = 'Batch size exceeds maximum limit of 200 records';
                res.statusCode = 400;
                
                IntegrationLogger.log(
                    IntegrationLogger.LogLevel.WARNING,
                    'ClaimsIntegrationRestService',
                    'upsertClaims',
                    'Batch size exceeds limit: ' + claimsRequest.claims.size(),
                    null
                );
                
                return response;
            }
            
            // Process claims using service class
            ClaimsIntegrationService service = new ClaimsIntegrationService();
            ClaimsIntegrationService.UpsertResult result = service.upsertClaims(claimsRequest.claims);
            
            // Build response
            response.success = result.totalFailed == 0;
            response.message = String.format(
                'Processed {0} claims: {1} successful, {2} failed',
                new List<Object>{
                    result.totalRecords,
                    result.totalSuccessful,
                    result.totalFailed
                }
            );
            response.totalRecords = result.totalRecords;
            response.successfulRecords = result.totalSuccessful;
            response.failedRecords = result.totalFailed;
            response.errors = result.errors;
            
            // Set HTTP status code
            res.statusCode = response.success ? 200 : 207; // 207 = Multi-Status (partial success)
            
            // Log success
            IntegrationLogger.log(
                response.success ? IntegrationLogger.LogLevel.INFO : IntegrationLogger.LogLevel.WARNING,
                'ClaimsIntegrationRestService',
                'upsertClaims',
                response.message,
                null
            );
            
        } catch (Exception e) {
            // Handle unexpected errors
            response.success = false;
            response.message = 'Error processing claims: ' + e.getMessage();
            RestContext.response.statusCode = 500;
            
            IntegrationLogger.log(
                IntegrationLogger.LogLevel.ERROR,
                'ClaimsIntegrationRestService',
                'upsertClaims',
                'Unexpected error: ' + e.getMessage(),
                e.getStackTraceString()
            );
        }
        
        return response;
    }
    
    /**
     * @description Request wrapper class
     */
    global class ClaimsRequest {
        public List<ClaimData> claims;
    }
    
    /**
     * @description Individual claim data structure
     */
    global class ClaimData {
        public String claimNumber;
        public String patientNameId;
        public String primaryAuth;
        public String payerId;
        public String payerName;
        public String dosStart;
        public String dosEnd;
        public String claimSubmittedDate;
        public Decimal chargedAmount;
        public Decimal paidAmount;
        public Decimal balance;
        public String paymentCheck;
        public String paymentDate;
        public String mrNumber;
    }
    
    /**
     * @description Response wrapper class
     */
    global class ClaimsResponse {
        public Boolean success;
        public String message;
        public Integer totalRecords;
        public Integer successfulRecords;
        public Integer failedRecords;
        public List<String> errors;
        
        public ClaimsResponse() {
            this.success = false;
            this.totalRecords = 0;
            this.successfulRecords = 0;
            this.failedRecords = 0;
            this.errors = new List<String>();
        }
    }
}
