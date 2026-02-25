# AI Teacher Assistant

A production-ready AI Teacher Assistant system with 4 main features: Lesson Planner (RAG-based), Worksheet Generator, Engagement Suggestion, and Concept Simplifier.

## 🛠 Tech Stack
- **Frontend**: Flutter (Clean Architecture, Riverpod)
- **Backend**: FastAPI (Python)
- **AI Logic**: OpenAI GPT-4, RAG (ChromaDB), JSON Validation, Retry Loops
- **Database**: PostgreSQL (Metadata), ChromaDB (Vector Search)

---

## 🚀 Setup Instructions

### Backend Setup
1. Navigate to the backend directory: `cd backend`
2. Create a virtual environment: `python -m venv venv`
3. Activate it: `source venv/bin/activate` (Mac/Linux) or `venv\Scripts\activate` (Windows)
4. Install dependencies: `pip install -r requirements.txt`
5. Create `.env` from `.env.example` and add your `OPENAI_API_KEY`.
6. Start the server: `python -m app.main`

### Frontend Setup
1. Navigate to the frontend directory: `cd frontend`
2. Install dependencies: `flutter pub get`
3. Run the app: `flutter run`

---

## 🧪 API Testing Examples

### 1. Generate Lesson Plan (with PDF upload)
```bash
curl -X POST "http://localhost:8000/api/generate-lesson" \
     -F "topic=Photosynthesis" \
     -F "num_lectures=2" \
     -F "file=@/path/to/textbook.pdf"
```

### 2. Generate Worksheet
```bash
curl -X POST "http://localhost:8000/api/generate-worksheet" \
     -H "Content-Type: application/json" \
     -d '{
       "topic": "Algebraic Equations",
       "difficulty": "Intermediate",
       "question_type": "Multiple Choice",
       "num_questions": 10,
       "use_rag": false
     }'
```

### 3. Simplify Concept
```bash
curl -X POST "http://localhost:8000/api/simplify-concept" \
     -H "Content-Type: application/json" \
     -d '{
       "topic_or_text": "Quantum Superposition"
     }'
```

---

## 🔷 System Architecture Flow
1. **Frontend**: Collects inputs (Grade, Subject, Feature specific params).
2. **Backend**: 
   - Feature check -> Optional RAG context retrieval.
   - Dynamic prompt construction.
   - LLM generation.
   - **Quality Check**: Validator checks output logic. If failed, it automatically retries with a refined prompt.
3. **Refinement**: "Regenerate" flow allows teachers to edit content by providing natural language instructions that update the existing output.
