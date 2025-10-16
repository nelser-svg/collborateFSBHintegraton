
"""Configuration management for the middleware"""
import os
from typing import Optional


class Config:
    """Configuration class for environment variables"""
    
    # CollaborateMD Configuration
    COLLABORATE_MD_BASE_URL: str = os.getenv(
        'COLLABORATE_MD_BASE_URL', 
        'https://webapi.collaboratemd.com'
    )
    COLLABORATE_MD_USERNAME: str = os.getenv('COLLABORATE_MD_USERNAME', '')
    COLLABORATE_MD_PASSWORD: str = os.getenv('COLLABORATE_MD_PASSWORD', '')
    COLLABORATE_MD_CUSTOMER: str = os.getenv('COLLABORATE_MD_CUSTOMER', '')
    COLLABORATE_MD_REPORT_SEQ: str = os.getenv('COLLABORATE_MD_REPORT_SEQ', '')
    COLLABORATE_MD_FILTER_SEQ: str = os.getenv('COLLABORATE_MD_FILTER_SEQ', '')
    
    # Salesforce Configuration
    SALESFORCE_INSTANCE_URL: str = os.getenv('SALESFORCE_INSTANCE_URL', '')
    SALESFORCE_USERNAME: str = os.getenv('SALESFORCE_USERNAME', '')
    SALESFORCE_PASSWORD: str = os.getenv('SALESFORCE_PASSWORD', '')
    SALESFORCE_SECURITY_TOKEN: str = os.getenv('SALESFORCE_SECURITY_TOKEN', '')
    SALESFORCE_CONSUMER_KEY: str = os.getenv('SALESFORCE_CONSUMER_KEY', '')
    SALESFORCE_CONSUMER_SECRET: str = os.getenv('SALESFORCE_CONSUMER_SECRET', '')
    
    # Processing Configuration
    BATCH_SIZE: int = int(os.getenv('BATCH_SIZE', '200'))
    MAX_RETRIES: int = int(os.getenv('MAX_RETRIES', '3'))
    RETRY_BACKOFF_FACTOR: float = float(os.getenv('RETRY_BACKOFF_FACTOR', '2.0'))
    INITIAL_RETRY_DELAY: float = float(os.getenv('INITIAL_RETRY_DELAY', '1.0'))
    
    # DynamoDB Configuration (for state management)
    DYNAMODB_TABLE_NAME: str = os.getenv('DYNAMODB_TABLE_NAME', 'collaboratemd-sync-state')
    DYNAMODB_REGION: str = os.getenv('AWS_REGION', 'us-east-1')
    
    # Logging Configuration
    LOG_LEVEL: str = os.getenv('LOG_LEVEL', 'INFO')
    
    @classmethod
    def validate(cls) -> None:
        """Validate that all required configuration is present"""
        required_vars = [
            ('COLLABORATE_MD_USERNAME', cls.COLLABORATE_MD_USERNAME),
            ('COLLABORATE_MD_PASSWORD', cls.COLLABORATE_MD_PASSWORD),
            ('COLLABORATE_MD_CUSTOMER', cls.COLLABORATE_MD_CUSTOMER),
            ('COLLABORATE_MD_REPORT_SEQ', cls.COLLABORATE_MD_REPORT_SEQ),
            ('COLLABORATE_MD_FILTER_SEQ', cls.COLLABORATE_MD_FILTER_SEQ),
            ('SALESFORCE_INSTANCE_URL', cls.SALESFORCE_INSTANCE_URL),
            ('SALESFORCE_USERNAME', cls.SALESFORCE_USERNAME),
            ('SALESFORCE_PASSWORD', cls.SALESFORCE_PASSWORD),
            ('SALESFORCE_SECURITY_TOKEN', cls.SALESFORCE_SECURITY_TOKEN),
        ]
        
        missing_vars = [var_name for var_name, var_value in required_vars if not var_value]
        
        if missing_vars:
            raise ValueError(
                f"Missing required environment variables: {', '.join(missing_vars)}"
            )
    
    @classmethod
    def get_collaborate_md_auth_header(cls) -> str:
        """Generate Basic Auth header for CollaborateMD API"""
        import base64
        credentials = f"{cls.COLLABORATE_MD_USERNAME}:{cls.COLLABORATE_MD_PASSWORD}"
        encoded = base64.b64encode(credentials.encode('utf-8')).decode('utf-8')
        return f"Basic {encoded}"
