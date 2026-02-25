from typing import Tuple
from app.utils.logger import logger

class OutputValidator:
    @staticmethod
    def validate_content(content: str, source_type: str) -> Tuple[bool, str]:
        """
        Validates the generated content based on specific rules for each feature.
        Returns (is_valid, error_message)
        """
        if not content or len(content) < 50:
            return False, "Content too short or empty."

        # Simple validation logic for production
        # In a real system, you might check for specific sections or keywords
        if source_type == "lesson" and "Objectives" not in content:
            return False, "Lesson plan missing 'Objectives' section."
            
        if source_type == "worksheet" and "?" not in content:
            return False, "Worksheet does not seem to contain questions."

        return True, ""

    @staticmethod
    def build_retry_prompt(original_prompt: str, error_msg: str) -> str:
        return f"""
        The previous response was invalid for the following reason: {error_msg}
        Please regenerate the content, making sure to fix this issue.
        Original requirements: {original_prompt}
        """

output_validator = OutputValidator()
