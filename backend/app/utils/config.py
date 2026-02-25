from pydantic_settings import BaseSettings
import os
from dotenv import load_dotenv

load_dotenv()

class Settings(BaseSettings):
    PROJECT_NAME: str = "AI Teacher Assistant"
    PORT: int = 8000
    DEBUG: bool = True
    DATABASE_URL: str = os.getenv("DATABASE_URL", "postgresql://postgres:postgres@localhost:5432/teacher_ai")
    GOOGLE_API_KEY: str = os.getenv("GOOGLE_API_KEY", "")
    LLM_MODEL: str = os.getenv("LLM_MODEL", "gemini-1.5-flash")
    EMBEDDING_MODEL: str = os.getenv("EMBEDDING_MODEL", "models/embedding-001")
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "./uploads")
    VECTOR_DB_DIR: str = os.getenv("VECTOR_DB_DIR", "./chroma_db")
    
    class Config:
        env_file = ".env"

settings = Settings()
