import chromadb
from app.utils.config import settings
from app.utils.logger import logger
import os
import re
import google.generativeai as genai

class GeminiEmbeddingFunction:
    def __init__(self, api_key, model_name):
        genai.configure(api_key=api_key)
        self.model_name = model_name

    def __call__(self, input: list):
        response = genai.embed_content(
            model=self.model_name,
            content=input,
            task_type="retrieval_document"
        )
        return response['embedding']

class VectorStore:
    def __init__(self):
        os.makedirs(settings.VECTOR_DB_DIR, exist_ok=True)
        self.client = chromadb.PersistentClient(path=settings.VECTOR_DB_DIR)
        self.embedding_fn = GeminiEmbeddingFunction(
            api_key=settings.GOOGLE_API_KEY,
            model_name=settings.EMBEDDING_MODEL
        )

    def _safe_name(self, teacher_id: str, grade: str = "", subject: str = "") -> str:
        """Convert teacher_id+grade+subject to a valid ChromaDB collection name (alphanumeric + underscore, max 63 chars)."""
        raw = f"{teacher_id}_{grade}_{subject}" if (grade or subject) else teacher_id
        safe = re.sub(r'[^a-zA-Z0-9_]', '_', raw)
        # ChromaDB requires names to start with a letter
        if safe and not safe[0].isalpha():
            safe = 't_' + safe
        return safe[:63] or 'teacher_default'

    def _get_collection(self, teacher_id: str, grade: str = "", subject: str = ""):
        """Get or create an isolated collection for this teacher+grade+subject."""
        name = self._safe_name(teacher_id, grade, subject)
        return self.client.get_or_create_collection(
            name=name,
            embedding_function=self.embedding_fn,
        )

    def add_documents(self, texts: list, metadatas: list, ids: list, teacher_id: str = "default", grade: str = "", subject: str = ""):
        collection = self._get_collection(teacher_id, grade, subject)
        try:
            # Clear all existing chunks before upserting new PDF so stale content from
            # a previous upload never pollutes the new generation.
            existing = collection.get()
            if existing and existing.get('ids'):
                collection.delete(ids=existing['ids'])
                logger.info(f"Cleared {len(existing['ids'])} old chunks from collection '{self._safe_name(teacher_id, grade, subject)}'")
            collection.upsert(
                documents=texts,
                metadatas=metadatas,
                ids=ids,
            )
            logger.info(f"Upserted {len(texts)} chunks into collection '{self._safe_name(teacher_id, grade, subject)}'")
        except Exception as e:
            logger.error(f"Error adding to vector store: {str(e)}")
            raise e

    def query(self, query_text: str, teacher_id: str = "default", grade: str = "", subject: str = "", n_results: int = 10):
        collection = self._get_collection(teacher_id, grade, subject)
        try:
            count = collection.count()
            if count == 0:
                return []
            # Don't ask for more results than documents exist
            actual_n = min(n_results, count)
            results = collection.query(
                query_texts=[query_text],
                n_results=actual_n,
            )
            return results['documents'][0] if results['documents'] else []
        except Exception as e:
            logger.error(f"Error querying vector store: {str(e)}")
            return []

vector_store = VectorStore()
