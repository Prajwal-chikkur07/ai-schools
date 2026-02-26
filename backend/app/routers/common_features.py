from fastapi import APIRouter, Query, HTTPException
from typing import List, Optional
from pydantic import BaseModel
from app.schemas.api_schemas import WorksheetRequest, AIResponse, EngagementRequest, SimplifierRequest, RegenerationRequest
from app.services.ai_orchestrator import ai_orchestrator
from app.utils.logger import logger

from app.database.models import LessonPlan, Worksheet, Engagement, SimplifierResult, SessionLocal

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

# ── Engagement output schema ───────────────────────────────────────────────────

class EngagementOut(BaseModel):
    id: int
    teacher_id: str
    grade: str
    subject: str
    title: Optional[str]
    topic: str
    engagement_type: str
    content: str
    plan_id: Optional[int]
    created_at: str

    class Config:
        from_attributes = True


def _eng_to_out(e: Engagement) -> EngagementOut:
    return EngagementOut(
        id=e.id,
        teacher_id=e.teacher_id,
        grade=e.grade or "",
        subject=e.subject or "",
        title=e.title,
        topic=e.topic,
        engagement_type=e.engagement_type,
        content=e.content,
        plan_id=e.plan_id,
        created_at=str(e.created_at),
    )


class EngagementRequestFull(BaseModel):
    topic: str
    engagement_type: str
    plan_id: Optional[int] = None
    teacher_id: Optional[str] = "teacher_01"
    grade: Optional[str] = ""
    subject: Optional[str] = ""
    session_context: Optional[str] = None
    num_questions: Optional[int] = None
    activity_format: Optional[str] = None
    discussion_format: Optional[str] = None


@common_router.post("/generate-engagement", response_model=AIResponse)
async def generate_engagement(req: EngagementRequestFull):
    try:
        # Use explicit session_context if provided, otherwise fall back to full plan content
        plan_content = req.session_context or get_plan_content(req.plan_id)
        content = await ai_orchestrator.generate_engagement(req.topic, req.engagement_type, plan_content=plan_content, num_questions=req.num_questions, activity_format=req.activity_format, discussion_format=req.discussion_format)

        teacher_id = req.teacher_id or "teacher_01"
        db = SessionLocal()
        try:
            eng = Engagement(
                teacher_id=teacher_id,
                grade=req.grade or "",
                subject=req.subject or "",
                topic=req.topic,
                engagement_type=req.engagement_type,
                content=content,
                plan_id=req.plan_id,
            )
            db.add(eng)
            db.commit()
            db.refresh(eng)
            saved_id = eng.id
        finally:
            db.close()

        return AIResponse(success=True, content=content, plan_id=saved_id)
    except Exception as e:
        return AIResponse(success=False, content="", error=str(e))


@common_router.get("/engagements", response_model=List[EngagementOut])
async def get_engagements(
    teacher_id: str = Query("teacher_01"),
    grade: str = Query(""),
    subject: str = Query(""),
):
    db = SessionLocal()
    try:
        q = db.query(Engagement).filter(Engagement.teacher_id == teacher_id)
        if grade:
            q = q.filter(Engagement.grade == grade)
        if subject:
            q = q.filter(Engagement.subject == subject)
        rows = q.order_by(Engagement.created_at.desc()).all()
        return [_eng_to_out(e) for e in rows]
    finally:
        db.close()


class UpdateEngagementRequest(BaseModel):
    content: Optional[str] = None
    title: Optional[str] = None


@common_router.patch("/engagements/{engagement_id}")
async def update_engagement(engagement_id: int, body: UpdateEngagementRequest):
    db = SessionLocal()
    try:
        eng = db.query(Engagement).filter(Engagement.id == engagement_id).first()
        if not eng:
            raise HTTPException(status_code=404, detail="Engagement not found")
        if body.content is not None:
            eng.content = body.content
        if body.title is not None:
            eng.title = body.title
        db.commit()
        db.refresh(eng)
        return {"success": True, "id": eng.id}
    finally:
        db.close()


@common_router.delete("/engagements/{engagement_id}")
async def delete_engagement(engagement_id: int):
    db = SessionLocal()
    try:
        eng = db.query(Engagement).filter(Engagement.id == engagement_id).first()
        if not eng:
            raise HTTPException(status_code=404, detail="Engagement not found")
        db.delete(eng)
        db.commit()
        return {"success": True}
    finally:
        db.close()

class SimplifierOut(BaseModel):
    id: int
    teacher_id: str
    grade: str
    subject: str
    title: Optional[str]
    topic: str
    content: str
    plan_id: Optional[int]
    created_at: str

    class Config:
        from_attributes = True


def _simp_to_out(s: SimplifierResult) -> SimplifierOut:
    return SimplifierOut(
        id=s.id,
        teacher_id=s.teacher_id,
        grade=s.grade or "",
        subject=s.subject or "",
        title=s.title,
        topic=s.topic,
        content=s.content,
        plan_id=s.plan_id,
        created_at=str(s.created_at),
    )


class SimplifierRequestFull(BaseModel):
    topic_or_text: str
    plan_id: Optional[int] = None
    teacher_id: Optional[str] = "teacher_01"
    grade: Optional[str] = ""
    subject: Optional[str] = ""


@common_router.post("/simplify-concept", response_model=AIResponse)
async def simplify_concept(req: SimplifierRequestFull):
    try:
        plan_content = get_plan_content(req.plan_id)
        content = await ai_orchestrator.simplify_concept(req.topic_or_text, plan_content=plan_content)

        teacher_id = req.teacher_id or "teacher_01"
        db = SessionLocal()
        try:
            sr = SimplifierResult(
                teacher_id=teacher_id,
                grade=req.grade or "",
                subject=req.subject or "",
                topic=req.topic_or_text[:200],
                content=content,
                plan_id=req.plan_id,
            )
            db.add(sr)
            db.commit()
            db.refresh(sr)
            saved_id = sr.id
        finally:
            db.close()

        return AIResponse(success=True, content=content, plan_id=saved_id)
    except Exception as e:
        return AIResponse(success=False, content="", error=str(e))


@common_router.get("/simplifier-results", response_model=List[SimplifierOut])
async def get_simplifier_results(
    teacher_id: str = Query("teacher_01"),
    grade: str = Query(""),
    subject: str = Query(""),
):
    db = SessionLocal()
    try:
        q = db.query(SimplifierResult).filter(SimplifierResult.teacher_id == teacher_id)
        if grade:
            q = q.filter(SimplifierResult.grade == grade)
        if subject:
            q = q.filter(SimplifierResult.subject == subject)
        rows = q.order_by(SimplifierResult.created_at.desc()).all()
        return [_simp_to_out(r) for r in rows]
    finally:
        db.close()


class UpdateSimplifierRequest(BaseModel):
    content: Optional[str] = None
    title: Optional[str] = None


@common_router.patch("/simplifier-results/{result_id}")
async def update_simplifier_result(result_id: int, body: UpdateSimplifierRequest):
    db = SessionLocal()
    try:
        sr = db.query(SimplifierResult).filter(SimplifierResult.id == result_id).first()
        if not sr:
            raise HTTPException(status_code=404, detail="Simplifier result not found")
        if body.content is not None:
            sr.content = body.content
        if body.title is not None:
            sr.title = body.title
        db.commit()
        db.refresh(sr)
        return {"success": True, "id": sr.id}
    finally:
        db.close()


@common_router.delete("/simplifier-results/{result_id}")
async def delete_simplifier_result(result_id: int):
    db = SessionLocal()
    try:
        sr = db.query(SimplifierResult).filter(SimplifierResult.id == result_id).first()
        if not sr:
            raise HTTPException(status_code=404, detail="Simplifier result not found")
        db.delete(sr)
        db.commit()
        return {"success": True}
    finally:
        db.close()

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
