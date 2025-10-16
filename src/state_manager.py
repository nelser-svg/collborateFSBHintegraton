
"""State management using DynamoDB for tracking sync progress"""
import boto3
from datetime import datetime
from typing import Optional, Dict, Any
from botocore.exceptions import ClientError
from src.config import Config
from src.logger import setup_logger

logger = setup_logger(__name__)


class StateManager:
    """Manage sync state using DynamoDB"""
    
    def __init__(self):
        self.table_name = Config.DYNAMODB_TABLE_NAME
        self.region = Config.DYNAMODB_REGION
        self.dynamodb = boto3.resource('dynamodb', region_name=self.region)
        self.table = None
        
    def _get_table(self):
        """Get or create DynamoDB table"""
        if self.table:
            return self.table
        
        try:
            self.table = self.dynamodb.Table(self.table_name)
            # Verify table exists
            self.table.load()
            logger.info(f"Connected to DynamoDB table: {self.table_name}")
            return self.table
        except ClientError as e:
            if e.response['Error']['Code'] == 'ResourceNotFoundException':
                logger.warning(f"Table {self.table_name} not found, will create it")
                self._create_table()
                return self.table
            else:
                logger.error(f"Error accessing DynamoDB table: {str(e)}")
                raise
    
    def _create_table(self):
        """Create DynamoDB table for state management"""
        try:
            logger.info(f"Creating DynamoDB table: {self.table_name}")
            
            self.table = self.dynamodb.create_table(
                TableName=self.table_name,
                KeySchema=[
                    {
                        'AttributeName': 'sync_id',
                        'KeyType': 'HASH'
                    }
                ],
                AttributeDefinitions=[
                    {
                        'AttributeName': 'sync_id',
                        'AttributeType': 'S'
                    }
                ],
                BillingMode='PAY_PER_REQUEST'
            )
            
            # Wait for table to be created
            self.table.wait_until_exists()
            logger.info(f"DynamoDB table created: {self.table_name}")
            
        except Exception as e:
            logger.error(f"Failed to create DynamoDB table: {str(e)}")
            raise
    
    def get_last_sync_timestamp(self, sync_id: str = 'default') -> Optional[datetime]:
        """
        Get timestamp of last successful sync
        
        Args:
            sync_id: Identifier for this sync configuration
        
        Returns:
            Datetime of last sync or None
        """
        try:
            table = self._get_table()
            
            response = table.get_item(
                Key={'sync_id': sync_id}
            )
            
            if 'Item' in response:
                timestamp_str = response['Item'].get('last_sync_timestamp')
                if timestamp_str:
                    timestamp = datetime.fromisoformat(timestamp_str)
                    logger.info(f"Last sync timestamp: {timestamp}")
                    return timestamp
            
            logger.info("No previous sync found")
            return None
            
        except ClientError as e:
            logger.error(f"Error getting last sync timestamp: {str(e)}")
            return None
        except Exception as e:
            logger.error(f"Unexpected error getting last sync timestamp: {str(e)}")
            return None
    
    def update_sync_timestamp(
        self, 
        sync_id: str = 'default',
        timestamp: Optional[datetime] = None,
        records_processed: int = 0,
        records_successful: int = 0,
        records_failed: int = 0
    ) -> bool:
        """
        Update last sync timestamp and statistics
        
        Args:
            sync_id: Identifier for this sync configuration
            timestamp: Timestamp to store (defaults to now)
            records_processed: Number of records processed
            records_successful: Number of successful records
            records_failed: Number of failed records
        
        Returns:
            True if successful
        """
        try:
            table = self._get_table()
            
            timestamp = timestamp or datetime.utcnow()
            
            item = {
                'sync_id': sync_id,
                'last_sync_timestamp': timestamp.isoformat(),
                'last_sync_date': timestamp.strftime('%Y-%m-%d'),
                'records_processed': records_processed,
                'records_successful': records_successful,
                'records_failed': records_failed,
                'updated_at': datetime.utcnow().isoformat()
            }
            
            table.put_item(Item=item)
            
            logger.info(
                f"Updated sync state: {records_successful}/{records_processed} successful"
            )
            return True
            
        except Exception as e:
            logger.error(f"Failed to update sync timestamp: {str(e)}")
            return False
    
    def get_sync_stats(self, sync_id: str = 'default') -> Dict[str, Any]:
        """
        Get sync statistics
        
        Args:
            sync_id: Identifier for this sync configuration
        
        Returns:
            Dictionary with sync statistics
        """
        try:
            table = self._get_table()
            
            response = table.get_item(
                Key={'sync_id': sync_id}
            )
            
            if 'Item' in response:
                return {
                    'last_sync_timestamp': response['Item'].get('last_sync_timestamp'),
                    'last_sync_date': response['Item'].get('last_sync_date'),
                    'records_processed': response['Item'].get('records_processed', 0),
                    'records_successful': response['Item'].get('records_successful', 0),
                    'records_failed': response['Item'].get('records_failed', 0),
                    'updated_at': response['Item'].get('updated_at')
                }
            
            return {}
            
        except Exception as e:
            logger.error(f"Error getting sync stats: {str(e)}")
            return {}
