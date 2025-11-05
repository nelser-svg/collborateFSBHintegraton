
"""CollaborateMD API Client"""
import requests
import json
import time
import zipfile
import io
from typing import Dict, List, Any, Optional
from datetime import datetime
from src.config import Config
from src.logger import setup_logger
from src.utils import retry_with_backoff

logger = setup_logger(__name__)


class CollaborateMDClient:
    """Client for interacting with CollaborateMD Web API"""
    
    def __init__(self):
        self.base_url = Config.COLLABORATE_MD_BASE_URL
        self.customer = Config.COLLABORATE_MD_CUSTOMER
        self.report_seq = Config.COLLABORATE_MD_REPORT_SEQ
        self.filter_seq = Config.COLLABORATE_MD_FILTER_SEQ
        self.auth_header = Config.get_collaborate_md_auth_header()
        
    def _get_headers(self, accept_type: str = 'application/json') -> Dict[str, str]:
        """Get request headers with authentication"""
        return {
            'Authorization': self.auth_header,
            'Accept': accept_type,
            'Content-Type': 'application/json'
        }
    
    @retry_with_backoff()
    def run_report(self) -> str:
        """
        Trigger a report run in CollaborateMD
        
        Returns:
            Request identifier for retrieving results
        
        Raises:
            Exception: If report run fails
        """
        endpoint = (
            f"{self.base_url}/v1/customer/{self.customer}/"
            f"reports/{self.report_seq}/filter/{self.filter_seq}/run"
        )
        
        logger.info(f"Triggering report run: {endpoint}")
        
        response = requests.post(
            endpoint,
            headers=self._get_headers(),
            timeout=120
        )
        
        if response.status_code != 200:
            raise Exception(
                f"Failed to run report. Status: {response.status_code}, "
                f"Response: {response.text}"
            )
        
        data = response.json()
        status = data.get('Status', '')
        
        if status == 'REPORT RUNNING':
            logger.warning("Previous report still running, will poll for results")
            # Return the identifier from the response if available
            return data.get('Identifier', '')
        elif status != 'SUCCESS':
            status_message = data.get('StatusMessage', 'Unknown error')
            raise Exception(f"Report run failed: {status} - {status_message}")
        
        request_seq = data.get('Identifier', '')
        if not request_seq:
            raise Exception("No request identifier returned from report run")
        
        logger.info(f"Report run initiated successfully. Request ID: {request_seq}")
        return request_seq
    
    @retry_with_backoff(max_retries=10, initial_delay=5.0)
    def get_report_results(self, request_seq: str) -> List[Dict[str, Any]]:
        """
        Retrieve report results from CollaborateMD
        
        Args:
            request_seq: Request identifier from run_report
        
        Returns:
            List of claim records
        
        Raises:
            Exception: If results retrieval fails
        """
        endpoint = (
            f"{self.base_url}/v1/customer/{self.customer}/"
            f"reports/results/{request_seq}"
        )
        
        logger.info(f"Fetching report results for request: {request_seq}")
        
        response = requests.post(
            endpoint,
            headers=self._get_headers(),
            timeout=120
        )
        
        if response.status_code != 200:
            raise Exception(
                f"Failed to get report results. Status: {response.status_code}, "
                f"Response: {response.text}"
            )
        
        data = response.json()
        status = data.get('Status', '')
        
        if status == 'REPORT RUNNING':
            logger.info("Report still running, will retry...")
            raise Exception("Report still running")  # Will trigger retry
        elif status == 'REPORT TIMED OUT':
            raise Exception("Report execution timed out. Consider narrowing the filter criteria.")
        elif status != 'SUCCESS':
            status_message = data.get('StatusMessage', 'Unknown error')
            raise Exception(f"Failed to get report results: {status} - {status_message}")
        
        # Extract and decode the report data
        encoded_data = data.get('Data', '')
        if not encoded_data:
            logger.warning("No data returned from report")
            return []
        
        # Decode base64 and unzip
        import base64
        zip_data = base64.b64decode(encoded_data)
        
        logger.info(f"Retrieved {len(zip_data)} bytes of zipped data")
        
        # Extract JSON from zip file
        claims_data = self._extract_json_from_zip(zip_data)
        
        logger.info(f"Successfully extracted {len(claims_data)} claim records")
        return claims_data
    
    def _extract_json_from_zip(self, zip_data: bytes) -> List[Dict[str, Any]]:
        """
        Extract JSON data from zip file
        
        Args:
            zip_data: Zip file bytes
        
        Returns:
            List of claim records
        """
        claims = []
        
        with zipfile.ZipFile(io.BytesIO(zip_data), 'r') as zip_file:
            # List all files in the zip
            file_list = zip_file.namelist()
            logger.info(f"Files in zip: {file_list}")
            
            # Process each file in the zip
            for filename in file_list:
                if filename.endswith('.json'):
                    with zip_file.open(filename) as json_file:
                        content = json_file.read().decode('utf-8')
                        json_data = json.loads(content)
                        
                        # Handle different JSON structures
                        if isinstance(json_data, list):
                            claims.extend(json_data)
                        elif isinstance(json_data, dict):
                            # Check if it has a 'data' field (paginated response)
                            if 'data' in json_data:
                                data_field = json_data['data']
                                if isinstance(data_field, list):
                                    claims.extend(data_field)
                                else:
                                    claims.append(data_field)
                            else:
                                claims.append(json_data)
                        
                        logger.info(f"Processed {filename}: {len(claims)} total claims so far")
                elif filename.endswith('.csv'):
                    # Handle CSV files if needed
                    logger.info(f"Found CSV file: {filename}, skipping for now")
                else:
                    logger.info(f"Skipping non-JSON file: {filename}")
        
        return claims
    
    def fetch_claims(self, last_sync_timestamp: Optional[datetime] = None) -> List[Dict[str, Any]]:
        """
        Main method to fetch claims data from CollaborateMD
        
        Args:
            last_sync_timestamp: Timestamp of last sync for incremental updates
        
        Returns:
            List of claim records
        """
        logger.info("Starting CollaborateMD claims fetch")
        
        if last_sync_timestamp:
            logger.info(f"Fetching claims modified since: {last_sync_timestamp}")
        else:
            logger.info("Fetching all claims (full sync)")
        
        # Step 1: Run the report
        request_seq = self.run_report()
        
        # Step 2: Wait a bit before polling for results
        time.sleep(5)
        
        # Step 3: Get the results (with retry logic built in)
        claims = self.get_report_results(request_seq)
        
        # Step 4: Filter by last sync timestamp if provided
        if last_sync_timestamp:
            claims = self._filter_by_timestamp(claims, last_sync_timestamp)
        
        logger.info(f"Fetched {len(claims)} claims from CollaborateMD")
        return claims
    
    def _filter_by_timestamp(
        self, 
        claims: List[Dict[str, Any]], 
        last_sync_timestamp: datetime
    ) -> List[Dict[str, Any]]:
        """
        Filter claims by last modified timestamp
        
        Args:
            claims: List of claim records
            last_sync_timestamp: Timestamp to filter by
        
        Returns:
            Filtered list of claims
        """
        filtered_claims = []
        
        for claim in claims:
            # Check various date fields that might indicate modification
            date_fields = ['updatedAt', 'ClaimDateEntered', 'createdAt']
            
            for field in date_fields:
                if field in claim and claim[field]:
                    try:
                        claim_date_str = claim[field]
                        # Handle ISO format dates
                        if 'T' in claim_date_str:
                            claim_date = datetime.fromisoformat(claim_date_str.replace('Z', '+00:00'))
                        else:
                            claim_date = datetime.strptime(claim_date_str, '%m/%d/%Y')
                        
                        if claim_date >= last_sync_timestamp:
                            filtered_claims.append(claim)
                            break
                    except (ValueError, TypeError) as e:
                        logger.warning(f"Could not parse date field {field}: {e}")
                        continue
        
        logger.info(
            f"Filtered {len(filtered_claims)} claims modified since {last_sync_timestamp}"
        )
        return filtered_claims
