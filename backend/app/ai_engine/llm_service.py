import asyncio
import google.generativeai as genai
from app.utils.config import settings
from app.utils.logger import logger

class LLMService:
    def __init__(self):
        genai.configure(api_key=settings.GOOGLE_API_KEY)
        # Reuse a single model instance — avoids re-initialising on every call.
        # Use gemini-1.5-flash for fastest response times.
        self._model = genai.GenerativeModel(
            model_name=settings.LLM_MODEL,
            generation_config={
                "temperature": 0.5,          # lower = faster, more focused
                "max_output_tokens": 4096,   # cap output to avoid runaway responses
            },
        )

    async def generate_response(self, system_prompt: str, user_prompt: str, temperature: float = 0.5):
        try:
            full_prompt = f"{system_prompt}\n\n{user_prompt}"
            # Run the blocking SDK call in a thread pool so it doesn't block the event loop.
            loop = asyncio.get_event_loop()
            response = await loop.run_in_executor(
                None,
                lambda: self._model.generate_content(full_prompt),
            )
            return response.text
        except Exception as e:
            logger.error(f"Error in Gemini Call: {str(e)}")
            raise e

llm_service = LLMService()
