from pydantic import BaseModel
from typing import Optional, List, Dict

# Request Schemas
class LessonRequest(BaseModel):
    topic: str
    num_lectures: int
    concepts: Optional[str] = None
    content: Optional[str] = None

class WorksheetRequest(BaseModel):
    topic: str
    difficulty: str
    question_type: str
    num_questions: int
    question_counts: Optional[Dict[str, int]] = None  # e.g. {"MCQ": 5, "One Mark": 5, "Long Answer": 3}
    use_rag: bool = False
    plan_id: Optional[int] = None
    session_context: Optional[str] = None  # extracted session markdown from frontend
    teacher_id: Optional[str] = "teacher_01"
    grade: Optional[str] = ""
    subject: Optional[str] = ""

class EngagementRequest(BaseModel):
    topic: str
    engagement_type: str
    plan_id: Optional[int] = None

class SimplifierRequest(BaseModel):
    topic_or_text: str
    plan_id: Optional[int] = None

class RegenerationRequest(BaseModel):
    feature: str
    original_content: str
    instruction: str
    plan_id: Optional[int] = None

# Response Schemas
class AIResponse(BaseModel):
    success: bool
    content: str
    plan_id: Optional[int] = None
    error: Optional[str] = None
