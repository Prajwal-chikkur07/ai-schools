from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
from pydantic import BaseModel
from app.schemas.api_schemas import WorksheetRequest, AIResponse, EngagementRequest, SimplifierRequest, RegenerationRequest
from app.services.ai_orchestrator import ai_orchestrator
from app.utils.logger import logger

from app.database.models import LessonPlan, Worksheet, SessionLocal

common_router = APIRouter()

def get_plan_content(plan_id: int):
    if not plan_id:
        return None
    db = SessionLocal()
    try:
        plan = db.query(LessonPlan).filter(LessonPlan.id == plan_id).first()
        return plan.content if plan else None
    finally:
        db.close()


# ── Worksheet output schema ────────────────────────────────────────────────────

class WorksheetOut(BaseModel):
    id: int
    teacher_id: str
    grade: str
    subject: str
    title: Optional[str]
    topic: str
    difficulty: str
    question_type: str
    num_questions: int
    content: str
    plan_id: Optional[int]
    created_at: str

    class Config:
        from_attributes = True


def _ws_to_out(w: Worksheet) -> WorksheetOut:
    return WorksheetOut(
        id=w.id,
        teacher_id=w.teacher_id,
        grade=w.grade or "",
        subject=w.subject or "",
        title=w.title,
        topic=w.topic,
        difficulty=w.difficulty,
        question_type=w.question_type,
        num_questions=w.num_questions,
        content=w.content,
        plan_id=w.plan_id,
        created_at=str(w.created_at),
    )


# ── Generate + auto-save worksheet ────────────────────────────────────────────

@common_router.post("/generate-worksheet", response_model=AIResponse)
async def generate_worksheet(req: WorksheetRequest):
    try:
        plan_content = get_plan_content(req.plan_id)
        content = await ai_orchestrator.generate_worksheet(
            req.topic, req.difficulty, req.question_type, req.num_questions,
            req.use_rag, plan_content=plan_content,
            session_context=req.session_context,
            question_counts=req.question_counts,
        )

        # Auto-save to DB with grade + subject scope
        teacher_id = req.teacher_id or "teacher_01"
        db = SessionLocal()
        try:
            ws = Worksheet(
                teacher_id=teacher_id,
                grade=req.grade or "",
                subject=req.subject or "",
                topic=req.topic,
                difficulty=req.difficulty,
                question_type=req.question_type,
                num_questions=req.num_questions,
                content=content,
                plan_id=req.plan_id,
            )
            db.add(ws)
            db.commit()
            db.refresh(ws)
            saved_id = ws.id
        finally:
            db.close()

        return AIResponse(success=True, content=content, plan_id=saved_id)
    except Exception as e:
        logger.error(f"Worksheet generation error: {e}")
        return AIResponse(success=False, content="", error=str(e))


# ── List saved worksheets (scoped to grade + subject) ─────────────────────────

@common_router.get("/worksheets", response_model=List[WorksheetOut])
async def get_worksheets(
    teacher_id: str = Query("teacher_01"),
    grade: str = Query(""),
    subject: str = Query(""),
):
    db = SessionLocal()
    try:
        q = db.query(Worksheet).filter(Worksheet.teacher_id == teacher_id)
        if grade:
            q = q.filter(Worksheet.grade == grade)
        if subject:
            q = q.filter(Worksheet.subject == subject)
        rows = q.order_by(Worksheet.created_at.desc()).all()
        return [_ws_to_out(w) for w in rows]
    finally:
        db.close()


# ── Update worksheet content and/or title ─────────────────────────────────────

class UpdateWorksheetRequest(BaseModel):
    content: Optional[str] = None
    title: Optional[str] = None

@common_router.patch("/worksheets/{worksheet_id}")
async def update_worksheet(worksheet_id: int, body: UpdateWorksheetRequest):
    db = SessionLocal()
    try:
        ws = db.query(Worksheet).filter(Worksheet.id == worksheet_id).first()
        if not ws:
            raise HTTPException(status_code=404, detail="Worksheet not found")
        if body.content is not None:
            ws.content = body.content
        if body.title is not None:
            ws.title = body.title
        db.commit()
        db.refresh(ws)
        return {"success": True, "id": ws.id}
    finally:
        db.close()


# ── Delete a saved worksheet ───────────────────────────────────────────────────

@common_router.delete("/worksheets/{worksheet_id}")
async def delete_worksheet(worksheet_id: int):
    db = SessionLocal()
    try:
        ws = db.query(Worksheet).filter(Worksheet.id == worksheet_id).first()
        if not ws:
            raise HTTPException(status_code=404, detail="Worksheet not found")
        db.delete(ws)
        db.commit()
        return {"success": True}
    finally:
        db.close()


# ── Other feature endpoints ────────────────────────────────────────────────────

@common_router.post("/generate-engagement", response_model=AIResponse)
async def generate_engagement(req: EngagementRequest):
    try:
        plan_content = get_plan_content(req.plan_id)
        content = await ai_orchestrator.generate_engagement(req.topic, req.engagement_type, plan_content=plan_content)
        return AIResponse(success=True, content=content, plan_id=req.plan_id)
    except Exception as e:
        return AIResponse(success=False, content="", error=str(e))

@common_router.post("/simplify-concept", response_model=AIResponse)
async def simplify_concept(req: SimplifierRequest):
    try:
        plan_content = get_plan_content(req.plan_id)
        content = await ai_orchestrator.simplify_concept(req.topic_or_text, plan_content=plan_content)
        return AIResponse(success=True, content=content, plan_id=req.plan_id)
    except Exception as e:
        return AIResponse(success=False, content="", error=str(e))

@common_router.post("/regenerate", response_model=AIResponse)
async def regenerate(req: RegenerationRequest):
    try:
        plan_content = get_plan_content(req.plan_id)
        content = await ai_orchestrator.regenerate_with_instruction(
            req.feature, req.original_content, req.instruction, plan_content=plan_content
        )
        return AIResponse(success=True, content=content, plan_id=req.plan_id)
    except Exception as e:
        return AIResponse(success=False, content="", error=str(e))
