from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
from app.routers import lesson, common_features
from app.utils.config import settings
from app.utils.logger import logger
from app.database.models import init_db

init_db()

app = FastAPI(title=settings.PROJECT_NAME)

# ── CORS ──────────────────────────────────────────────────────────────────────
# Allow all origins for local development with Flutter Web (which uses random ports).
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── API Key Security ───────────────────────────────────────────────────────────
# All /api/* routes require the X-API-Key header to match this value.
# In production, store this in an environment variable / secrets manager.
API_KEY = "sprout-ai-secret-key-2025"

@app.middleware("http")
async def validate_api_key(request: Request, call_next):
    # Skip OPTIONS preflight requests — CORS middleware handles those.
    # Only protect /api/* routes; let the root health-check through.
    if request.method != "OPTIONS" and request.url.path.startswith("/api"):
        key = request.headers.get("X-API-Key")
        if key != API_KEY:
            logger.warning(f"Unauthorized request to {request.url.path} — invalid or missing API key")
            return JSONResponse(
                status_code=401,
                content={"detail": "Unauthorized: invalid or missing API key"},
            )
    return await call_next(request)

# ── Routers ───────────────────────────────────────────────────────────────────
app.include_router(lesson.router, prefix="/api", tags=["Lesson Planner"])
app.include_router(common_features.common_router, prefix="/api", tags=["Common Features"])

@app.get("/")
async def root():
    return {"message": f"Welcome to {settings.PROJECT_NAME} API"}

if __name__ == "__main__":
    import uvicorn
    logger.info("Starting Backend Server...")
    uvicorn.run(app, host="0.0.0.0", port=8000)
