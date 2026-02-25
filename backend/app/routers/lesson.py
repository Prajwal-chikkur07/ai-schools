from fastapi import APIRouter, HTTPException, UploadFile, File, Form, Query
from app.schemas.api_schemas import AIResponse
from app.services.ai_orchestrator import ai_orchestrator
from app.ai_engine.rag.vector_store import vector_store
from app.utils.logger import logger
import PyPDF2
import io
from typing import List, Optional
from pydantic import BaseModel

from app.database.models import LessonPlan, SessionLocal

router = APIRouter()


class LessonPlanOut(BaseModel):
    id: int
    teacher_id: str
    grade: str
    subject: str
    topic: str
    num_lectures: int
    content: str
    created_at: str

    class Config:
        from_attributes = True


class UpdatePlanRequest(BaseModel):
    content: str


@router.get("/lesson-plans", response_model=List[LessonPlanOut])
async def get_lesson_plans(
    teacher_id: str = Query(..., description="Teacher identifier"),
    grade: str = Query(..., description="Grade to filter by"),
    subject: str = Query(..., description="Subject to filter by"),
):
    """Return only the lesson plans that belong to the given teacher, grade, and subject."""
    db = SessionLocal()
    try:
        plans = (
            db.query(LessonPlan)
            .filter(
                LessonPlan.teacher_id == teacher_id,
                LessonPlan.grade == grade,
                LessonPlan.subject == subject,
            )
            .order_by(LessonPlan.created_at.desc())
            .all()
        )
        return [
            LessonPlanOut(
                id=p.id,
                teacher_id=p.teacher_id,
                grade=p.grade,
                subject=p.subject,
                topic=p.topic,
                num_lectures=p.num_lectures,
                content=p.content,
                created_at=str(p.created_at),
            )
            for p in plans
        ]
    finally:
        db.close()


@router.patch("/lesson-plans/{plan_id}")
async def update_lesson_plan(plan_id: int, body: UpdatePlanRequest):
    db = SessionLocal()
    try:
        plan = db.query(LessonPlan).filter(LessonPlan.id == plan_id).first()
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")
        plan.content = body.content
        db.commit()
        db.refresh(plan)
        return {"success": True, "id": plan.id}
    finally:
        db.close()


@router.delete("/lesson-plans/{plan_id}")
async def delete_lesson_plan(plan_id: int):
    db = SessionLocal()
    try:
        plan = db.query(LessonPlan).filter(LessonPlan.id == plan_id).first()
        if not plan:
            raise HTTPException(status_code=404, detail="Plan not found")
        db.delete(plan)
        db.commit()
        return {"success": True}
    finally:
        db.close()


@router.post("/generate-lesson", response_model=AIResponse)
async def generate_lesson(
    teacher_id: str = Form(...),
    grade: str = Form(...),
    subject: str = Form(...),
    topic: str = Form(...),
    num_lectures: int = Form(...),
    concepts: str = Form(None),
    file: UploadFile = File(None),
):
    db = SessionLocal()
    try:
        if file:
            pdf_reader = PyPDF2.PdfReader(io.BytesIO(await file.read()))
            content_text = ""
            for page in pdf_reader.pages:
                extracted = page.extract_text()
                if extracted:
                    content_text += extracted + "\n"

            # Use 800-char chunks with 100-char overlap for better context continuity
            chunk_size = 800
            overlap = 100
            chunks = []
            for i in range(0, len(content_text), chunk_size - overlap):
                chunk = content_text[i:i + chunk_size].strip()
                if chunk:
                    chunks.append(chunk)

            ids = [f"{teacher_id}_{grade}_{subject}_{file.filename}_{i}" for i in range(len(chunks))]
            metadatas = [{"source": file.filename, "teacher_id": teacher_id, "grade": grade, "subject": subject} for _ in chunks]
            # Stored in teacher+grade+subject-scoped collection — no cross-subject pollution
            vector_store.add_documents(chunks, metadatas, ids, teacher_id=teacher_id, grade=grade, subject=subject)

        content = await ai_orchestrator.generate_lesson_plan(
            topic, num_lectures,
            concepts=concepts,
            context_query=topic if file else None,
            teacher_id=teacher_id,
            grade=grade,
            subject=subject,
        )

        db_plan = LessonPlan(
            teacher_id=teacher_id,
            grade=grade,
            subject=subject,
            topic=topic,
            num_lectures=num_lectures,
            content=content,
        )
        db.add(db_plan)
        db.commit()
        db.refresh(db_plan)

        return AIResponse(success=True, content=content, plan_id=db_plan.id)
    except Exception as e:
        logger.error(f"Error in lesson generation: {str(e)}")
        return AIResponse(success=False, content="", error=str(e))
    finally:
        db.close()
