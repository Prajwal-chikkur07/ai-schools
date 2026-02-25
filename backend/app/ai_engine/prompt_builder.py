"""
prompt_builder.py
-----------------
Centralised, parameterised prompt-template registry.

How to add or modify a prompt
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
1. Add / edit an entry in PROMPT_TEMPLATES or SYSTEM_PROMPTS below.
2. Use {placeholder} syntax for runtime substitution.
3. Call PromptBuilder.build(template_key, **kwargs) — it validates that all
   required placeholders are supplied and raises ValueError otherwise.

No Python code changes are needed to tune prompt wording; only the template
strings at the top of this file need to be updated.
"""

from typing import List, Optional, Dict

# ── System prompts ────────────────────────────────────────────────────────────
SYSTEM_PROMPTS: dict[str, str] = {
    "base": "You are an expert AI Teacher Assistant.",
    "lesson": (
        "You are a world-class curriculum designer and master teacher with 20+ years of classroom experience across all grade levels. "
        "You create exceptionally detailed, pedagogically sound, and age-appropriate lesson plans that are immediately ready to use in a real classroom. "
        "Your plans are praised for their clarity, engagement, real-world connections, and alignment with learning science. "
        "You ALWAYS calibrate language complexity, activity types, examples, and depth of explanation strictly to the grade level and subject provided. "
        "You NEVER produce generic content — every plan is specifically crafted for the exact grade and subject given. "
        "Output clean, well-structured Markdown."
    ),
    "worksheet": (
        "You are an expert educational assessment designer with 15+ years of experience creating classroom worksheets. "
        "You produce beautifully structured, print-ready worksheets with clear formatting, properly labelled options, and answer keys. "
        "Every question is unambiguous, age-appropriate, and directly tied to the specified topic. "
        "Output clean, well-structured Markdown that renders clearly on screen and in print."
    ),
    "engagement": (
        "You are an expert AI Teacher Assistant. "
        "Create fun, interactive classroom activities."
    ),
    "simplifier": (
        "You are an expert AI Teacher Assistant. "
        "Explain complex topics simply for children."
    ),
}

# ── User-turn prompt templates ─────────────────────────────────────────────────
# All placeholders use {name} syntax; optional blocks are handled in code.
PROMPT_TEMPLATES: dict[str, str] = {

    "lesson_plan": """
GRADE: {grade}
SUBJECT: {subject}
TOPIC: {teacher_input}
NUMBER OF SESSIONS: {lectures}
{concepts_block}
{context_block}

You are designing a lesson plan for REAL classroom use. Follow every instruction below precisely.

━━━ GRADE & SUBJECT CALIBRATION ━━━
- Vocabulary, sentence complexity, and examples MUST match what is appropriate for {grade} students studying {subject}.
- For lower grades (K–4): use simple sentences, concrete hands-on activities, relatable everyday analogies, colourful descriptions.
- For middle grades (5–8): introduce subject-specific terminology with clear definitions, include inquiry-based activities and group discussions.
- For high school (9–12): use precise academic language, include critical thinking tasks, primary source connections, and exam-style questions.
- NEVER use vocabulary or concepts above the stated grade level without first explaining them.
- ALL examples, analogies, and activities MUST be drawn from the real world and relevant to the {subject} domain.

━━━ OUTPUT FORMAT ━━━
Start with a single H1 heading:
# {teacher_input}: {grade} {subject} Lesson Plan

Then for EACH of the {lectures} sessions write an H2 heading:
## Session N: [Descriptive Title that reflects the session content]

Under each session, include ALL of the following H3 sections IN ORDER:

### Learning Objectives
Exactly 3 specific, measurable objectives using action verbs (e.g. "Students will be able to...").
Each objective must be directly achievable within a single 45-minute session.

### Topic Explanation
Write 3 full paragraphs (not bullet points):
1. Core concept explanation using grade-appropriate language.
2. Real-world connection — a concrete example from everyday life or the {subject} field that {grade} students can relate to.
3. Why this matters — relevance of this topic to the student's life or future learning.

### 45-Minute Lesson Breakdown
A detailed, time-stamped plan:
- **Introduction (5 min):** Hook activity or warm-up question to activate prior knowledge.
- **Core Instruction (20 min):** Step-by-step explanation of the main concept with teacher actions and student interactions.
- **Guided Activity (12 min):** A hands-on, collaborative, or inquiry-based activity appropriate for {grade} — describe it in enough detail for a teacher to run it without extra prep.
- **Class Discussion (5 min):** 2 discussion questions to consolidate understanding.
- **Recap & Exit Ticket (3 min):** Summary of key points + one exit ticket question students answer on paper before leaving.

### Key Terms
List 4–6 subject-specific terms as: **term** — one clear, grade-appropriate definition.

### Assessment Questions
3 questions at different cognitive levels:
1. Knowledge/Recall — a factual question any student should answer after the session.
2. Understanding/Application — requires applying the concept to a new situation.
3. Analysis/Critical Thinking — challenges the student to evaluate, compare, or create.

━━━ QUALITY RULES ━━━
- Write in full sentences everywhere except bullet lists.
- Be specific — no vague phrases like "discuss the topic" or "do an activity". Describe exactly what happens.
- Do NOT repeat the same activity or example across sessions.
- Each session must build logically on the previous one.
- Total output must be comprehensive and immediately usable by a teacher with no additional preparation.
""",

    "lesson_plan_concepts_block": """
━━━ KEY CONCEPTS (Teacher-specified — MANDATORY) ━━━
The following concepts MUST ALL be explicitly addressed across the {lectures} sessions.
Do not skip or merge any of them:
{concepts}
""",

    "worksheet": """
TOPIC: {topic}
DIFFICULTY: {difficulty}
QUESTION TYPE(S): {question_type}

━━━ MANDATORY QUESTION COUNT REQUIREMENT ━━━
{counts_instruction}
YOU MUST GENERATE EXACTLY THESE COUNTS. DO NOT ADD OR REMOVE QUESTIONS FROM ANY SECTION.
This is a hard requirement — deviating from these counts is an error.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CONTEXT: {context}

Generate a classroom worksheet following EVERY rule below precisely.

━━━ DOCUMENT STRUCTURE ━━━
Output the worksheet in this exact order:

# [Topic] — Worksheet
**Subject:** [infer from topic] | **Difficulty:** {difficulty} | **Total Questions:** {num_questions}

---

**Student Name:** _________________________ &nbsp;&nbsp; **Date:** _____________ &nbsp;&nbsp; **Score:** _____ / {num_questions}

---

**Instructions:** Read each question carefully and answer to the best of your ability.

---

━━━ QUESTION FORMATTING RULES ━━━

**If question type includes MCQ (Multiple Choice):**
Format each MCQ exactly like this:

**Q[N].** [Question stem ending with a question mark or blank to fill in]

- A) [Option A]
- B) [Option B]
- C) [Option C]
- D) [Option D]

**If question type includes One Mark / Short Answer:**
Format each short-answer question exactly like this:

**Q[N].** [Clear, direct question]

_Answer:_ ________________________________________________________________

**If question type includes Long Answer:**
Format each long-answer question exactly like this:

**Q[N].** [Higher-order thinking question that requires explanation, analysis, or evaluation]

_Answer:_

___________________________________________________________________________

___________________________________________________________________________

___________________________________________________________________________

___________________________________________________________________________

━━━ NUMBERING & SECTION COUNTS (CRITICAL) ━━━
- Number questions sequentially from Q1 to Q{num_questions}.
- Group questions by type with a bold section heading:
  **Section A: Multiple Choice Questions** / **Section B: Short Answer** / **Section C: Long Answer**
- Each section heading must show the marks: e.g. *(1 mark each)*
- ⚠ CRITICAL: Each section MUST contain EXACTLY the number of questions from the MANDATORY QUESTION COUNT REQUIREMENT above.
  {counts_instruction}
  Do NOT add extra questions. Do NOT skip any questions. Count carefully before finalising.

━━━ ANSWER KEY ━━━
After all questions, add a horizontal rule and an answer key section:

---

## Answer Key *(For Teacher Use Only)*

For MCQ: list Q[N] → [Correct option letter] — [One-line explanation]
For Short Answer: list Q[N] → [Model answer in 1–2 sentences]
For Long Answer: list Q[N] → [Key points the answer should cover, as bullet points]

━━━ QUALITY RULES ━━━
- Every question must be directly about the specified TOPIC — no off-topic filler.
- MCQ distractors must be plausible (wrong answers that a student might reasonably choose).
- Difficulty {difficulty}: Easy = recall/recognition, Medium = application/understanding, Hard = analysis/evaluation.
- Do NOT number options with numbers (1,2,3,4) — always use A), B), C), D).
- Do NOT repeat the same concept across multiple questions.
- Write every question in full, grammatically correct sentences.
""",

    "engagement": """
TOPIC: {topic}
ENGAGEMENT TYPE: {engagement_type}

Provide 5 creative and interactive engagement suggestions for this topic.
Each suggestion must include:
- A catchy activity name
- A brief description (2-3 sentences)
- Materials needed (if any)
- Estimated duration
""",

    "simplifier": """
CONCEPT/TOPIC: {concept}

Simplify this concept for a student. Use analogies and clear language.
Structure your response as:
1. Simple Explanation (2-3 sentences a 10-year-old could understand)
2. Real-world analogy
3. Key takeaway (one sentence)
""",
}


class PromptBuilder:
    """
    Builds prompts by looking up a named template and substituting
    runtime values.  Raises ValueError for unknown templates or
    missing placeholders so errors are caught early during development.
    """

    # ── Public builder helpers ─────────────────────────────────────────────

    @staticmethod
    def build_lesson_plan_prompt(
        context_chunks: List[str],
        teacher_input: str,
        lectures: int,
        concepts: Optional[str] = None,
        grade: str = "",
        subject: str = "",
    ) -> str:
        if context_chunks:
            context_block = (
                "━━━ REFERENCE MATERIAL (from uploaded document — use this as your primary source) ━━━\n"
                + "\n\n".join(context_chunks)
                + "\n\nIMPORTANT: Ground the lesson content in the above reference material wherever possible. "
                "If the material covers the topic, prioritise it over general knowledge."
            )
        else:
            context_block = ""

        concepts_block = ""
        if concepts:
            concepts_block = PromptBuilder._render(
                "lesson_plan_concepts_block",
                concepts=concepts,
                lectures=lectures,
            )

        return PromptBuilder._render(
            "lesson_plan",
            grade=grade or "the appropriate grade",
            subject=subject or "the subject",
            context_block=context_block,
            teacher_input=teacher_input,
            lectures=lectures,
            concepts_block=concepts_block,
        )

    @staticmethod
    def build_worksheet_prompt(
        topic: str,
        difficulty: str,
        question_type: str,
        num_questions: int,
        context_chunks: Optional[List[str]] = None,
        question_counts: Optional[Dict[str, int]] = None,
    ) -> str:
        context_str = "\n".join(context_chunks) if context_chunks else "General knowledge"

        # Build a detailed per-type breakdown instruction when counts are provided
        if question_counts and len(question_counts) > 0:
            breakdown_lines = [f"  - {qtype}: {count} question(s)" for qtype, count in question_counts.items()]
            counts_instruction = (
                f"QUESTION BREAKDOWN (generate EXACTLY these counts per type):\n"
                + "\n".join(breakdown_lines)
                + f"\nTOTAL: {num_questions} questions"
            )
        else:
            counts_instruction = f"NUMBER OF QUESTIONS: {num_questions}"

        return PromptBuilder._render(
            "worksheet",
            topic=topic,
            difficulty=difficulty,
            question_type=question_type,
            num_questions=num_questions,
            context=context_str,
            counts_instruction=counts_instruction,
        )

    @staticmethod
    def build_engagement_prompt(topic: str, engagement_type: str) -> str:
        return PromptBuilder._render(
            "engagement",
            topic=topic,
            engagement_type=engagement_type,
        )

    @staticmethod
    def build_simplifier_prompt(concept: str) -> str:
        return PromptBuilder._render("simplifier", concept=concept)

    @staticmethod
    def get_system_prompt(feature: str) -> str:
        return SYSTEM_PROMPTS.get(feature, SYSTEM_PROMPTS["base"])

    # ── Internal rendering ─────────────────────────────────────────────────

    @staticmethod
    def _render(template_key: str, **kwargs) -> str:
        if template_key not in PROMPT_TEMPLATES:
            raise ValueError(
                f"Unknown prompt template '{template_key}'. "
                f"Available: {list(PROMPT_TEMPLATES.keys())}"
            )
        template = PROMPT_TEMPLATES[template_key]
        try:
            return template.format(**kwargs)
        except KeyError as exc:
            raise ValueError(
                f"Template '{template_key}' requires placeholder {exc} "
                f"but it was not supplied."
            ) from exc


prompt_builder = PromptBuilder()
