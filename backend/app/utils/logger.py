import logging
import sys

def setup_logger():
    logger = logging.getLogger("teacher_ai")
    logger.setLevel(logging.INFO)
    
    formatter = logging.Formatter(
        "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
    )
    
    handler = sys.stdout
    stream_handler = logging.StreamHandler(handler)
    stream_handler.setFormatter(formatter)
    
    if not logger.handlers:
        logger.addHandler(stream_handler)
    
    return logger

logger = setup_logger()
