import asyncio
from app.ai_engine.llm_service import llm_service
from app.ai_engine.prompt_builder import prompt_builder
from app.ai_engine.rag.vector_store import vector_store
from app.ai_engine.validators.output_validator import output_validator
from app.utils.logger import logger
from typing import Optional, List

# Maximum seconds to wait for a single LLM response attempt
GENERATION_TIMEOUT_SECONDS = 90

class AIOrchestrator:
    async def generate_with_retry(self, system_prompt: str, user_prompt: str, feature: str, max_retries: int = 1):
        current_prompt = user_prompt
        for attempt in range(max_retries + 1):
            logger.info(f"Generating content for {feature}, Attempt {attempt + 1}")
            try:
                response = await asyncio.wait_for(
                    llm_service.generate_response(system_prompt, current_prompt),
                    timeout=GENERATION_TIMEOUT_SECONDS,
                )
            except asyncio.TimeoutError:
                logger.error(f"LLM timeout on attempt {attempt + 1} for feature '{feature}'")
                if attempt < max_retries:
                    continue  # retry
                raise TimeoutError(f"AI generation exceeded {GENERATION_TIMEOUT_SECONDS}s timeout after {max_retries + 1} attempts.")

            is_valid, error_msg = output_validator.validate_content(response, feature)
            if is_valid:
                return response
            
            

            logger.warning(f"Validation failed on attempt {attempt + 1}: {error_msg}")
            if attempt < max_retries:
                current_prompt = output_validator.build_retry_prompt(current_prompt, error_msg)
            else:
                return response # Return even if invalid on last attempt, or raise error

    async def generate_lesson_plan(self, teacher_input: str, num_lectures: int, concepts: Optional[str] = None, context_query: Optional[str] = None, teacher_id: str = "default", grade: str = "", subject: str = ""):
        chunks = []
        if context_query:
            chunks = vector_store.query(teacher_input, teacher_id=teacher_id, grade=grade, subject=subject)

        system_prompt = prompt_builder.get_system_prompt("lesson")
        user_prompt = prompt_builder.build_lesson_plan_prompt(chunks, teacher_input, num_lectures, concepts=concepts, grade=grade, subject=subject)

        return await self.generate_with_retry(system_prompt, user_prompt, "lesson")

    async def generate_worksheet(self, topic: str, difficulty: str, q_type: str, count: int, use_rag: bool = False, plan_content: Optional[str] = None, session_context: Optional[str] = None, question_counts: Optional[dict] = None):
        chunks = []
        if use_rag:
            chunks = vector_store.query(topic)

        system_prompt = prompt_builder.get_system_prompt("worksheet")
        user_prompt = prompt_builder.build_worksheet_prompt(topic, difficulty, q_type, count, chunks, question_counts=question_counts)

        if session_context:
            # Specific sessions selected — scope questions to only those sessions
            user_prompt = f"GENERATE QUESTIONS ONLY FROM THESE SELECTED SESSIONS:\n{session_context}\n\n---\n\n{user_prompt}"
        elif plan_content:
            # No specific sessions — use the full plan as context
            user_prompt = f"BASED ON THIS LESSON PLAN:\n{plan_content}\n\n---\n\n{user_prompt}"

        return await self.generate_with_retry(system_prompt, user_prompt, "worksheet")

    async def generate_engagement(self, topic: str, e_type: str, plan_content: Optional[str] = None, num_questions: Optional[int] = None, activity_format: Optional[str] = None, discussion_format: Optional[str] = None):
        system_prompt = prompt_builder.get_system_prompt("engagement")
        user_prompt = prompt_builder.build_engagement_prompt(topic, e_type, num_questions=num_questions, activity_format=activity_format, discussion_format=discussion_format)
        if plan_content:
            user_prompt = f"BASED ON THIS LESSON PLAN/SESSION CONTENT:\n{plan_content}\n\n---\n\n{user_prompt}"
        result = await self.generate_with_retry(system_prompt, user_prompt, "engagement")
        return self._strip_preamble(result)

    @staticmethod
    def _strip_preamble(text: str) -> str:
        """Remove conversational opener lines before the first Markdown heading."""
        _PREAMBLE_STARTERS = (
            "okay", "sure", "here are", "here is", "certainly", "of course",
            "i've created", "i have created", "absolutely", "great", "below is",
            "below are", "let me", "i'll", "i will",
        )
        lines = text.splitlines()
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped.startswith("#"):
                return "\n".join(lines[i:]).strip()
            if stripped and not any(stripped.lower().startswith(p) for p in _PREAMBLE_STARTERS):
                # Non-preamble line reached before a heading — keep from here
                return "\n".join(lines[i:]).strip()
        return text.strip()

    async def simplify_concept(self, topic_or_text: str, plan_content: Optional[str] = None):
        system_prompt = prompt_builder.get_system_prompt("simplifier")
        user_prompt = prompt_builder.build_simplifier_prompt(topic_or_text)
        if plan_content:
            user_prompt = f"BASED ON THIS LESSON PLAN:\n{plan_content}\n\n---\n\n{user_prompt}"
        return await self.generate_with_retry(system_prompt, user_prompt, "simplifier")

    async def regenerate_with_instruction(self, feature: str, original_content: str, instruction: str, plan_content: Optional[str] = None):
        """Implements 'Add New Prompt Instruction' flow from diagram"""
        system_prompt = prompt_builder.get_system_prompt(feature)
        user_prompt = f"Original Content: {original_content}\n\nUpdate Instructions: {instruction}\n\nPlease regenerate the content based on these new instructions."
        if plan_content:
            user_prompt = f"BASED ON THIS LESSON PLAN:\n{plan_content}\n\n---\n\n{user_prompt}"
        return await llm_service.generate_response(system_prompt, user_prompt)

ai_orchestrator = AIOrchestrator()
