
"""Salesforce API Client"""
import requests
from typing import Dict, List, Any, Optional
from simple_salesforce import Salesforce, SalesforceAuthenticationFailed
from src.config import Config
from src.logger import setup_logger
from src.utils import retry_with_backoff, chunk_list

logger = setup_logger(__name__)


class SalesforceClient:
    """Client for interacting with Salesforce REST API"""
    
    def __init__(self):
        self.instance_url = Config.SALESFORCE_INSTANCE_URL
        self.username = Config.SALESFORCE_USERNAME
        self.password = Config.SALESFORCE_PASSWORD
        self.security_token = Config.SALESFORCE_SECURITY_TOKEN
        self.domain = Config.SALESFORCE_DOMAIN
        self.consumer_key = Config.SALESFORCE_CONSUMER_KEY
        self.consumer_secret = Config.SALESFORCE_CONSUMER_SECRET
        self._sf_client = None
    
    @retry_with_backoff(exceptions=(SalesforceAuthenticationFailed, ConnectionError))
    def authenticate(self) -> Salesforce:
        """
        Authenticate with Salesforce
        
        Returns:
            Authenticated Salesforce client
        
        Raises:
            SalesforceAuthenticationFailed: If authentication fails
        """
        if self._sf_client:
            return self._sf_client
        
        logger.info("Authenticating with Salesforce")
        
        try:
            # Try OAuth2 authentication if consumer key/secret provided
            if self.consumer_key and self.consumer_secret:
                self._sf_client = Salesforce(
                    username=self.username,
                    password=self.password,
                    consumer_key=self.consumer_key,
                    consumer_secret=self.consumer_secret,
                    domain=self.domain
                )
            else:
                # Fallback to username/password/token authentication
                self._sf_client = Salesforce(
                    username=self.username,
                    password=self.password,
                    security_token=self.security_token,
                    domain=self.domain
                )
            
            logger.info("Successfully authenticated with Salesforce")
            return self._sf_client
            
        except Exception as e:
            logger.error(f"Salesforce authentication failed: {str(e)}")
            raise
    
    @retry_with_backoff()
    def upsert_claims(
        self, 
        claims: List[Dict[str, Any]], 
        external_id_field: str = 'Claim_Number__c'
    ) -> Dict[str, Any]:
        """
        Upsert claims to Salesforce in batches
        
        Args:
            claims: List of claim records to upsert
            external_id_field: Field to use for upsert matching
        
        Returns:
            Dictionary with success/failure statistics
        """
        if not claims:
            logger.warning("No claims to upsert")
            return {
                'total': 0,
                'successful': 0,
                'failed': 0,
                'errors': []
            }
        
        logger.info(f"Upserting {len(claims)} claims to Salesforce")
        
        sf = self.authenticate()
        
        # Split claims into batches
        batches = chunk_list(claims, Config.BATCH_SIZE)
        logger.info(f"Split into {len(batches)} batches of max {Config.BATCH_SIZE} records")
        
        total_successful = 0
        total_failed = 0
        all_errors = []
        
        for i, batch in enumerate(batches, 1):
            logger.info(f"Processing batch {i}/{len(batches)} ({len(batch)} records)")
            
            try:
                result = self._upsert_batch(sf, batch, external_id_field)
                total_successful += result['successful']
                total_failed += result['failed']
                all_errors.extend(result['errors'])
                
                logger.info(
                    f"Batch {i} complete: {result['successful']} successful, "
                    f"{result['failed']} failed"
                )
                
            except Exception as e:
                logger.error(f"Batch {i} failed completely: {str(e)}")
                total_failed += len(batch)
                all_errors.append({
                    'batch': i,
                    'error': str(e),
                    'records': len(batch)
                })
        
        summary = {
            'total': len(claims),
            'successful': total_successful,
            'failed': total_failed,
            'errors': all_errors
        }
        
        logger.info(
            f"Upsert complete: {total_successful}/{len(claims)} successful, "
            f"{total_failed} failed"
        )
        
        return summary
    
    def _upsert_batch(
        self, 
        sf: Salesforce, 
        batch: List[Dict[str, Any]], 
        external_id_field: str
    ) -> Dict[str, Any]:
        """
        Upsert a single batch of claims
        
        Args:
            sf: Authenticated Salesforce client
            batch: Batch of claim records
            external_id_field: Field to use for upsert matching
        
        Returns:
            Dictionary with batch results
        """
        successful = 0
        failed = 0
        errors = []
        
        # Use Salesforce Bulk API for better performance
        # For now, we'll use individual upserts with error handling
        for claim in batch:
            try:
                external_id = claim.get(external_id_field)
                
                if not external_id:
                    logger.warning(f"Claim missing {external_id_field}, skipping")
                    failed += 1
                    errors.append({
                        'claim': claim,
                        'error': f'Missing {external_id_field}'
                    })
                    continue
                
                # Perform upsert
                # Try to update first, if not found, create
                try:
                    result = sf.Claims__c.update(
                        f"{external_id_field}/{external_id}",
                        claim
                    )
                    successful += 1
                except Exception as update_error:
                    # If update fails, try to create
                    if '404' in str(update_error) or 'NOT_FOUND' in str(update_error):
                        result = sf.Claims__c.create(claim)
                        successful += 1
                    else:
                        raise update_error
                
            except Exception as e:
                logger.error(f"Failed to upsert claim {claim.get(external_id_field)}: {str(e)}")
                failed += 1
                errors.append({
                    'claim_id': claim.get(external_id_field),
                    'error': str(e)
                })
        
        return {
            'successful': successful,
            'failed': failed,
            'errors': errors
        }
    
    @retry_with_backoff()
    def query_claims(
        self, 
        claim_numbers: Optional[List[str]] = None,
        limit: int = 10000
    ) -> List[Dict[str, Any]]:
        """
        Query existing claims from Salesforce
        
        Args:
            claim_numbers: Optional list of claim numbers to query
            limit: Maximum number of records to return
        
        Returns:
            List of existing claim records
        """
        sf = self.authenticate()
        
        if claim_numbers:
            # Query specific claims
            claim_numbers_str = "','".join(claim_numbers)
            query = (
                f"SELECT Id, Claim_Number__c, Name "
                f"FROM Claims__c "
                f"WHERE Claim_Number__c IN ('{claim_numbers_str}') "
                f"LIMIT {limit}"
            )
        else:
            # Query all claims
            query = (
                f"SELECT Id, Claim_Number__c, Name "
                f"FROM Claims__c "
                f"LIMIT {limit}"
            )
        
        logger.info(f"Querying Salesforce: {query}")
        
        try:
            result = sf.query_all(query)
            records = result.get('records', [])
            logger.info(f"Found {len(records)} existing claims in Salesforce")
            return records
        except Exception as e:
            logger.error(f"Failed to query Salesforce: {str(e)}")
            raise
    
    def get_claim_payor_mapping(self) -> Dict[str, str]:
        """
        Get mapping of Claim Payor names to IDs
        
        Returns:
            Dictionary mapping payor names to IDs
        """
        sf = self.authenticate()
        
        query = "SELECT Id, Name FROM Claim_Payor__c"
        
        try:
            result = sf.query_all(query)
            records = result.get('records', [])
            
            mapping = {}
            mapping_without_ids = {}
            
            for record in records:
                name = record.get('Name', '')
                record_id = record.get('Id', '')
                
                if name and record_id:
                    mapping[name] = record_id
                    
                    # Also create mapping without payor ID suffix for fallback
                    if '(#' in name:
                        name_without_id = name.split('(#')[0].strip()
                        mapping_without_ids[name_without_id] = record_id
            
            logger.info(f"Retrieved {len(mapping)} claim payor mappings")
            
            return {**mapping, **mapping_without_ids}
            
        except Exception as e:
            logger.error(f"Failed to get claim payor mapping: {str(e)}")
            return {}
