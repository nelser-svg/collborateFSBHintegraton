
"""Data transformation between CollaborateMD and Salesforce formats"""
from typing import Dict, List, Any, Optional
from datetime import datetime
from src.logger import setup_logger
from src.utils import safe_get

logger = setup_logger(__name__)


class DataTransformer:
    """Transform CollaborateMD data to Salesforce Claims__c format"""
    
    def __init__(self, claim_payor_mapping: Optional[Dict[str, str]] = None):
        """
        Initialize transformer
        
        Args:
            claim_payor_mapping: Optional mapping of payor names to Salesforce IDs
        """
        self.claim_payor_mapping = claim_payor_mapping or {}
    
    def transform_claims(
        self, 
        collab_claims: List[Dict[str, Any]]
    ) -> List[Dict[str, Any]]:
        """
        Transform CollaborateMD claims to Salesforce format
        
        Args:
            collab_claims: List of claims from CollaborateMD
        
        Returns:
            List of transformed claims ready for Salesforce
        """
        logger.info(f"Transforming {len(collab_claims)} claims")
        
        transformed_claims = []
        
        for claim in collab_claims:
            try:
                transformed = self._transform_single_claim(claim)
                if transformed:
                    transformed_claims.append(transformed)
            except Exception as e:
                logger.error(
                    f"Failed to transform claim {claim.get('ClaimID', 'unknown')}: {str(e)}"
                )
                continue
        
        logger.info(f"Successfully transformed {len(transformed_claims)} claims")
        return transformed_claims
    
    def _transform_single_claim(self, claim: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """
        Transform a single claim record
        
        Args:
            claim: Single claim from CollaborateMD
        
        Returns:
            Transformed claim or None if invalid
        """
        claim_id = claim.get('ClaimID', '')
        
        if not claim_id:
            logger.warning("Skipping claim without ClaimID")
            return None
        
        # Build the transformed claim
        transformed = {
            # Required/Key fields
            'Claim_Number__c': claim_id,
            'Name': claim.get('PateintNameID', claim_id),
            
            # Date fields
            'DOS__c': self._parse_date(claim.get('StatementCoversFromDate')),
            'DOS_End__c': self._parse_date(claim.get('StatementCoversToDate')),
            'Claim_Submitted_Date__c': self._parse_date(claim.get('ClaimDateEntered')),
            'Paid_Date__c': self._parse_date(claim.get('PaymentReceived')),
            
            # Amount fields
            'Charged_Amount__c': self._parse_decimal(claim.get('ClaimTotalAmount')),
            'Paid_Amount__c': self._parse_decimal(claim.get('ClaimAmountPaid')),
            'Total_BDP__c': self._parse_decimal(claim.get('ClaimBalance')),
            
            # String fields
            'EFT_or_Paper_Check__c': claim.get('PaymentCheck', ''),
            'Insurance_Authorization_Number__c': claim.get('PrimaryAuth', ''),
            'Payer__c': claim.get('PayerID', ''),
            'MR_Number__c': claim.get('PatientReference', ''),
            
            # Paid status
            'Paid_Y_or_N__c': self._determine_paid_status(claim),
        }
        
        # Handle Claim Payor lookup
        claim_payor_id = self._get_claim_payor_id(claim)
        if claim_payor_id:
            transformed['Claim_Payor__c'] = claim_payor_id
        
        # Remove None values
        transformed = {k: v for k, v in transformed.items() if v is not None}
        
        return transformed
    
    def _parse_date(self, date_str: Optional[str]) -> Optional[str]:
        """
        Parse date string to Salesforce format (YYYY-MM-DD)
        
        Args:
            date_str: Date string in various formats
        
        Returns:
            Date in YYYY-MM-DD format or None
        """
        if not date_str:
            return None
        
        try:
            # Handle ISO format with time
            if 'T' in date_str:
                dt = datetime.fromisoformat(date_str.replace('Z', '+00:00'))
                return dt.strftime('%Y-%m-%d')
            
            # Handle MM/DD/YYYY format
            if '/' in date_str:
                dt = datetime.strptime(date_str, '%m/%d/%Y')
                return dt.strftime('%Y-%m-%d')
            
            # Handle YYYY-MM-DD format (already correct)
            if '-' in date_str and len(date_str) == 10:
                return date_str
            
            logger.warning(f"Unrecognized date format: {date_str}")
            return None
            
        except (ValueError, TypeError) as e:
            logger.warning(f"Failed to parse date '{date_str}': {str(e)}")
            return None
    
    def _parse_decimal(self, value: Any) -> Optional[float]:
        """
        Parse numeric value to decimal
        
        Args:
            value: Numeric value (can be string, int, or float)
        
        Returns:
            Float value or None
        """
        if value is None or value == '':
            return None
        
        try:
            return float(value)
        except (ValueError, TypeError) as e:
            logger.warning(f"Failed to parse decimal '{value}': {str(e)}")
            return None
    
    def _determine_paid_status(self, claim: Dict[str, Any]) -> str:
        """
        Determine if claim is paid based on payment date
        
        Args:
            claim: Claim record
        
        Returns:
            'Yes' or 'No'
        """
        payment_date = claim.get('PaymentReceived')
        
        if payment_date and payment_date != '' and payment_date is not None:
            return 'Yes'
        else:
            return 'No'
    
    def _get_claim_payor_id(self, claim: Dict[str, Any]) -> Optional[str]:
        """
        Get Salesforce ID for claim payor
        
        Args:
            claim: Claim record
        
        Returns:
            Salesforce Claim_Payor__c ID or None
        """
        payor_name = claim.get('ClaimPrimaryPayerName', '')
        payor_id = claim.get('PayerID', '')
        
        if not payor_name:
            return None
        
        # Try full name with payor ID
        if payor_id:
            full_name = f"{payor_name} ({payor_id})"
            if full_name in self.claim_payor_mapping:
                return self.claim_payor_mapping[full_name]
        
        # Try name without payor ID
        if payor_name in self.claim_payor_mapping:
            return self.claim_payor_mapping[payor_name]
        
        logger.debug(f"No Salesforce ID found for payor: {payor_name}")
        return None
