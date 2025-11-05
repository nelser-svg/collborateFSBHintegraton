
"""Utility functions for the middleware"""
import time
from typing import Callable, Any, TypeVar, Optional
from functools import wraps
from src.logger import setup_logger
from src.config import Config

logger = setup_logger(__name__)

T = TypeVar('T')


def retry_with_backoff(
    max_retries: Optional[int] = None,
    backoff_factor: Optional[float] = None,
    initial_delay: Optional[float] = None,
    exceptions: tuple = (Exception,)
):
    """
    Decorator to retry a function with exponential backoff
    
    Args:
        max_retries: Maximum number of retries (uses Config.MAX_RETRIES if None)
        backoff_factor: Multiplier for delay between retries (uses Config.RETRY_BACKOFF_FACTOR if None)
        initial_delay: Initial delay in seconds (uses Config.INITIAL_RETRY_DELAY if None)
        exceptions: Tuple of exceptions to catch and retry
    
    Returns:
        Decorated function with retry logic
    """
    max_retries = max_retries or Config.MAX_RETRIES
    backoff_factor = backoff_factor or Config.RETRY_BACKOFF_FACTOR
    initial_delay = initial_delay or Config.INITIAL_RETRY_DELAY
    
    def decorator(func: Callable[..., T]) -> Callable[..., T]:
        @wraps(func)
        def wrapper(*args, **kwargs) -> T:
            delay = initial_delay
            last_exception = None
            
            for attempt in range(max_retries + 1):
                try:
                    return func(*args, **kwargs)
                except exceptions as e:
                    last_exception = e
                    if attempt < max_retries:
                        logger.warning(
                            f"Attempt {attempt + 1}/{max_retries + 1} failed for {func.__name__}: {str(e)}. "
                            f"Retrying in {delay:.2f} seconds..."
                        )
                        time.sleep(delay)
                        delay *= backoff_factor
                    else:
                        logger.error(
                            f"All {max_retries + 1} attempts failed for {func.__name__}. "
                            f"Last error: {str(e)}"
                        )
            
            # If we get here, all retries failed
            raise last_exception
        
        return wrapper
    
    return decorator


def chunk_list(data: list, chunk_size: int) -> list:
    """
    Split a list into chunks of specified size
    
    Args:
        data: List to split
        chunk_size: Size of each chunk
    
    Returns:
        List of chunks
    """
    return [data[i:i + chunk_size] for i in range(0, len(data), chunk_size)]


def safe_get(dictionary: dict, *keys, default=None) -> Any:
    """
    Safely get nested dictionary values
    
    Args:
        dictionary: Dictionary to search
        *keys: Keys to traverse
        default: Default value if key not found
    
    Returns:
        Value or default
    """
    result = dictionary
    for key in keys:
        if isinstance(result, dict):
            result = result.get(key, default)
        else:
            return default
    return result if result is not None else default
