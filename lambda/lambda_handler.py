
"""AWS Lambda handler for CollaborateMD to Salesforce sync"""
import json
from datetime import datetime
from typing import Dict, Any
from src.config import Config
from src.logger import setup_logger
from src.collaboratemd_client import CollaborateMDClient
from src.salesforce_client import SalesforceClient
from src.data_transformer import DataTransformer
from src.state_manager import StateManager

logger = setup_logger(__name__)


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Main Lambda handler function
    
    Args:
        event: Lambda event object
        context: Lambda context object
    
    Returns:
        Dictionary with execution results
    """
    logger.info("=" * 80)
    logger.info("Starting CollaborateMD to Salesforce sync")
    logger.info("=" * 80)
    
    try:
        # Validate configuration
        Config.validate()
        logger.info("Configuration validated successfully")
        
        # Initialize components
        state_manager = StateManager()
        collab_client = CollaborateMDClient()
        sf_client = SalesforceClient()
        
        # Check if this is an incremental or full sync
        force_full_sync = event.get('full_sync', False)
        
        if force_full_sync:
            logger.info("Force full sync requested")
            last_sync_timestamp = None
        else:
            last_sync_timestamp = state_manager.get_last_sync_timestamp()
        
        # Step 1: Fetch claims from CollaborateMD
        logger.info("Step 1: Fetching claims from CollaborateMD")
        claims = collab_client.fetch_claims(last_sync_timestamp)
        
        if not claims:
            logger.info("No claims to process")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No claims to process',
                    'records_processed': 0
                })
            }
        
        logger.info(f"Fetched {len(claims)} claims from CollaborateMD")
        
        # Step 2: Get Claim Payor mapping from Salesforce
        logger.info("Step 2: Fetching Claim Payor mapping from Salesforce")
        claim_payor_mapping = sf_client.get_claim_payor_mapping()
        
        # Step 3: Transform data
        logger.info("Step 3: Transforming data")
        transformer = DataTransformer(claim_payor_mapping)
        transformed_claims = transformer.transform_claims(claims)
        
        if not transformed_claims:
            logger.warning("No claims successfully transformed")
            return {
                'statusCode': 200,
                'body': json.dumps({
                    'message': 'No claims successfully transformed',
                    'records_processed': 0
                })
            }
        
        logger.info(f"Transformed {len(transformed_claims)} claims")
        
        # Step 4: Upsert to Salesforce
        logger.info("Step 4: Upserting claims to Salesforce")
        result = sf_client.upsert_claims(transformed_claims)
        
        # Step 5: Update sync state
        logger.info("Step 5: Updating sync state")
        state_manager.update_sync_timestamp(
            timestamp=datetime.utcnow(),
            records_processed=result['total'],
            records_successful=result['successful'],
            records_failed=result['failed']
        )
        
        # Prepare response
        success_rate = (result['successful'] / result['total'] * 100) if result['total'] > 0 else 0
        
        response = {
            'statusCode': 200 if result['failed'] == 0 else 207,  # 207 = Multi-Status
            'body': json.dumps({
                'message': 'Sync completed',
                'timestamp': datetime.utcnow().isoformat(),
                'statistics': {
                    'claims_fetched': len(claims),
                    'claims_transformed': len(transformed_claims),
                    'records_processed': result['total'],
                    'records_successful': result['successful'],
                    'records_failed': result['failed'],
                    'success_rate': f"{success_rate:.2f}%"
                },
                'errors': result['errors'][:10] if result['errors'] else []  # Limit error details
            }, default=str)
        }
        
        logger.info("=" * 80)
        logger.info(f"Sync completed: {result['successful']}/{result['total']} successful")
        logger.info("=" * 80)
        
        return response
        
    except Exception as e:
        logger.error(f"Fatal error in Lambda handler: {str(e)}", exc_info=True)
        
        return {
            'statusCode': 500,
            'body': json.dumps({
                'message': 'Sync failed',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }, default=str)
        }


def local_test():
    """
    Function for local testing (not used in Lambda)
    """
    print("Running local test...")
    
    # Mock event and context
    event = {
        'full_sync': False
    }
    
    class MockContext:
        def __init__(self):
            self.function_name = 'local-test'
            self.memory_limit_in_mb = 512
            self.invoked_function_arn = 'arn:aws:lambda:local'
            self.aws_request_id = 'local-test-id'
    
    context = MockContext()
    
    # Run handler
    result = lambda_handler(event, context)
    
    print("\n" + "=" * 80)
    print("RESULT:")
    print(json.dumps(result, indent=2, default=str))
    print("=" * 80)


if __name__ == '__main__':
    local_test()
