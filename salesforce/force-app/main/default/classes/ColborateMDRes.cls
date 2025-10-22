
public class ColborateMDRes {
    public Integer totalRecords {get; set;}
    public Integer currentPage {get; set;}
    public Integer totalPages {get; set;}
    public List<data> data {get; set;}
    public String Status {get; set;}
    public String StatusMessage {get; set;}
    
    public class data {
        public String _id {get; set;}
        public String UniqueKey {get; set;}
        public String PateintNameID {get; set;}
        public String ClaimPrimaryPayerName {get; set;}
        public String PayerID {get; set;}
        public String ClaimReference {get; set;}
        public String ClaimLastBilledDate {get; set;}
        public String PrimaryAuth {get; set;}
        public String ClaimID {get; set;}
        public String StatementCoversFromDate {get; set;}
        public String StatementCoversToDate {get; set;}
        public String ClaimFromDate {get; set;}
        public String ClaimDateEntered {get; set;}
        public String ClaimTotalAmount {get; set;}
        public String ClaimAmountPaid {get; set;}
        public String ClaimBalance {get; set;}
        public String PaymentCheck {get; set;}
        public String ClaimTotalAmount1 {get; set;}
        public String PaymentReceived {get; set;}
        public String PatientReference {get; set;}
        public String createdAt {get; set;}
        public String updatedAt {get; set;}
        public Integer __v {get; set;}
    }
}
