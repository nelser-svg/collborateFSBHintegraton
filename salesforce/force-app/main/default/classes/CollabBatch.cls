
global class CollabBatch implements Database.Batchable<sObject>, Database.Stateful, Database.AllowsCallouts, Schedulable {
    
    global List<String> ReportDataList = new List<String>();
    
    global Database.QueryLocator start(Database.BatchableContext bc) {
        ReportDataList = makeApiCallout();
        
        return Database.getQueryLocator('SELECT Id, Name, Start_Date__c, End_Date__c, Level_of_Care__c, Authorization_Number__c, Related_Patient__r.MR_Number__c FROM Services_Authorization__c WHERE Authorization_Number__c != null AND Related_Patient__r.MR_Number__c != null');
    }
    
    global void execute(Database.BatchableContext bc, List<Services_Authorization__c> ServicesAuthList) {
        Map<String, String> mapofclaim = new Map<String, String>();
        List<Claims__c> claimlist = new List<Claims__c>();
        
        claimlist = [SELECT Id, Name, Claim_Number__c, Claim_Payor__c, DOS__c, ServiceAuth_Record_ID__c, DOS_End__c, Claim_Submitted_Date__c, Charged_Amount__c, Total_BDP__c, Paid_Amount__c, EFT_or_Paper_Check__c, Paid_Date__c, Related_Services_Authorization__c, Related_Services_Authorization__r.Insurance_Company__c, Related_Services_Authorization__r.MR_Number__c, Payer__c, MR_Number__c, Paid_Y_or_N__c, LOC__c, Related_Services_Authorization__r.Level_of_Care__c, Related_Services_Authorization__r.Authorization_Number__c, Related_Services_Authorization__r.Related_Patient__r.MR_Number__c, Related_Services_Authorization__r.Related_Patient__c FROM Claims__c WHERE Related_Services_Authorization__c IN :ServicesAuthList AND Related_Services_Authorization__r.Authorization_Number__c != null AND Claim_Number__c != null];
        
        Set<String> AuthNumberClaimset = new Set<String>();
        for (Claims__c cc : claimlist) {
            mapofclaim.put(cc.Claim_Number__c, cc.ID);
            AuthNumberClaimset.add(cc.Claim_Number__c + cc.Related_Services_Authorization__r.Authorization_Number__c);
        }
        
        Map<String, String> mapofClaimPayor = new Map<String, String>();
        Map<String, String> mapofClaimPayorWithoutPayerIds = new Map<String, String>();
        for (Claim_Payor__c cp : [SELECT Id, Name FROM Claim_Payor__c]) {
            mapofClaimPayor.put(cp.Name, cp.Id);
            if (cp.Name.contains('#')) {
                mapofClaimPayorWithoutPayerIds.put(cp.Name.substringBefore(' (#'), cp.Id);
            }
        }
        
        System.debug('==mapofClaimPayor==>' + mapofClaimPayor);
        
        List<Claims__c> claimlistDML = new List<Claims__c>();
        for (Services_Authorization__c sauth : ServicesAuthList) {
            for (String dat : ReportDataList) {
                List<ColborateMDRes.data> dataList = (List<ColborateMDRes.data>) JSON.deserialize(dat, List<ColborateMDRes.data>.class);
                Set<String> processedClaimIds = new Set<String>();
                
                // Iterate through the deserialized data list
                for (ColborateMDRes.data record : dataList) {
                    System.debug('UniqueKey==>' + record.UniqueKey);
                    String primaryAuth = record.PrimaryAuth;
                    String claimId = record.ClaimID;
                    String patientReference = record.PatientReference;
                    
                    System.debug('sauth.Authorization_Number__c==>' + sauth.Authorization_Number__c);
                    System.debug('beforeprimaryAuth==>' + primaryAuth);
                    System.debug('patientReference==>' + patientReference);
                    
                    if (primaryAuth != '' && sauth.Authorization_Number__c == primaryAuth && sauth.Related_Patient__r.MR_Number__c == patientReference) {
                        System.debug('sauth.Related_Patient__r.MR_Number__c==>' + sauth.Related_Patient__r.MR_Number__c);
                        System.debug('primaryAuth==>' + primaryAuth);
                        System.debug('processedClaimIds==>' + processedClaimIds);
                        
                        if (!processedClaimIds.contains(claimId)) {
                            Claims__c cla = new Claims__c();
                            if (AuthNumberClaimset.contains(claimId + primaryAuth)) {
                                cla.ID = mapofclaim.get(claimId);
                            } else {
                                cla.Related_Services_Authorization__c = sauth.Id;
                            }
                            
                            System.debug('sauth.Related_Patient==>' + sauth.Related_Patient__c);
                            if (sauth.Related_Patient__c != null && sauth.Related_Patient__r.MR_Number__c != '') {
                                System.debug('sauth.Related_Patient==>' + sauth.Related_Patient__c);
                                cla.MR_Number__c = sauth.Related_Patient__r.MR_Number__c;
                                cla.Related_Patient__c = sauth.Related_Patient__c;
                            }
                            
                            cla.LOC__c = sauth.Level_of_Care__c;
                            cla.ServiceAuth_Record_ID__c = sauth.Id;
                            
                            if (record.PayerID != '' && record.ClaimPrimaryPayerName != '') {
                                String ClaimPrimaryPayerName = record.ClaimPrimaryPayerName;
                                String PayerID = record.PayerID;
                                String ClaimPayor = ClaimPrimaryPayerName + ' (#' + PayerID + ')';
                                if (mapofClaimPayor.containsKey(ClaimPayor)) {
                                    cla.Claim_Payor__c = mapofClaimPayor.get(ClaimPayor);
                                }
                            } else if (record.PayerID == '' && record.ClaimPrimaryPayerName != '') {
                                String ClaimPrimaryPayerName = record.ClaimPrimaryPayerName;
                                if (mapofClaimPayorWithoutPayerIds.containsKey(ClaimPrimaryPayerName)) {
                                    cla.Claim_Payor__c = mapofClaimPayorWithoutPayerIds.get(ClaimPrimaryPayerName);
                                }
                            }
                            
                            if (record.PayerID != '') {
                                cla.Payer__c = record.PayerID;
                            }
                            if (record.PrimaryAuth != '') {
                                cla.Insurance_Authorization_Number__c = record.PrimaryAuth;
                            }
                            if (record.PateintNameID != '') {
                                cla.Name = record.PateintNameID;
                            }
                            if (claimId != '') {
                                cla.Claim_Number__c = claimId;
                            }
                            if (record.StatementCoversFromDate != '') {
                                cla.DOS__c = Date.valueOf(record.StatementCoversFromDate);
                            }
                            if (record.StatementCoversToDate != '') {
                                cla.DOS_End__c = Date.valueOf(record.StatementCoversToDate);
                            }
                            if (record.ClaimDateEntered != '') {
                                cla.Claim_Submitted_Date__c = Date.valueOf(record.ClaimDateEntered);
                            }
                            if (record.ClaimTotalAmount != '') {
                                cla.Charged_Amount__c = Decimal.valueOf(record.ClaimTotalAmount);
                            }
                            if (record.ClaimAmountPaid != '') {
                                cla.Paid_Amount__c = Decimal.valueOf(record.ClaimAmountPaid);
                            }
                            if (record.PaymentReceived != '' && record.PaymentReceived != null) {
                                cla.Paid_Date__c = Date.valueOf(record.PaymentReceived);
                                cla.Paid_Y_or_N__c = 'Yes';
                            } else {
                                cla.Paid_Y_or_N__c = 'No';
                            }
                            if (record.ClaimBalance != '') {
                                cla.Total_BDP__c = Decimal.valueOf(record.ClaimBalance);
                            }
                            if (record.PaymentCheck != '') {
                                cla.EFT_or_Paper_Check__c = record.PaymentCheck;
                            }
                            
                            claimlistDML.add(cla);
                            processedClaimIds.add(claimId);
                        }
                    }
                }
            }
        }
        
        if (claimlistDML.size() > 0) {
            upsert claimlistDML;
            System.debug('claimlistDML==>' + claimlistDML);
        }
    }
    
    global void finish(Database.BatchableContext bc) {}
    
    global void execute(SchedulableContext sc) {
        CollabBatch Collabatch = new CollabBatch();
        Database.executeBatch(Collabatch, 200);
    }
    
    private List<String> makeApiCallout() {
        List<String> reportdata = new List<String>();
        HttpRequest req = new HttpRequest();
        req.setEndpoint('callout:Claims_API');
        req.setMethod('GET');
        req.setHeader('Accept', 'application/json');
        req.setTimeout(120000);
        Http http = new Http();
        String GBody = '';
        String StatusCode = '';
        
        if (!Test.isRunningTest()) {
            HTTPResponse res = http.send(req);
            GBody = res.getBody();
            StatusCode = res.getStatus();
            System.debug('--RESPONSE BODY-- ' + res.getBody());
        } else {
            GBody = '{"totalRecords":1,"currentPage":1,"totalPages":1,"data":[{"_id":"test","UniqueKey":"TEST","PateintNameID":"TEST PATIENT","ClaimPrimaryPayerName":"TEST PAYER","PayerID":"12345","ClaimReference":"","ClaimLastBilledDate":"","PrimaryAuth":"TEST123","ClaimID":"123456","StatementCoversFromDate":"2024-01-01T00:00:00.000Z","StatementCoversToDate":"2024-01-02T00:00:00.000Z","ClaimFromDate":"2024-01-01T00:00:00.000Z","ClaimDateEntered":"2024-01-05T00:00:00.000Z","ClaimTotalAmount":"1000","ClaimAmountPaid":"900","ClaimBalance":"100","PaymentCheck":"CHK001","ClaimTotalAmount1":"1000","PaymentReceived":"2024-01-15T00:00:00.000Z","PatientReference":"","createdAt":"2024-01-01T00:00:00.000Z","updatedAt":"2024-01-01T00:00:00.000Z","__v":0}]}';
        }
        
        if (GBody != '' && GBody != null) {
            ColborateMDRes reportRes = (ColborateMDRes) JSON.deserialize(GBody, ColborateMDRes.class);
            if (reportRes.data != null && reportRes.data.size() > 0) {
                reportdata.add(JSON.serialize(reportRes.data));
            }
        }
        
        return reportdata;
    }
}
