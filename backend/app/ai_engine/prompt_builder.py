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
        "You are a master classroom engagement specialist with 20+ years of experience designing activities that energise students. "
        "You create highly specific, ready-to-run classroom experiences — not vague ideas. "
        "Every suggestion must include step-by-step instructions a teacher can follow immediately, exact timing, grouping, and any materials. "
        "Calibrate complexity, language, and energy level to the topic provided. "
        "CRITICAL FORMATTING RULES — YOU MUST FOLLOW THESE WITHOUT EXCEPTION:\n"
        "1. Output ONLY well-structured Markdown. NO preamble, NO intro sentences, NO closing remarks.\n"
        "2. Do NOT start with phrases like 'Okay', 'Sure', 'Here are', 'Certainly', 'Of course', 'I've created', or any similar opener.\n"
        "3. Begin your response DIRECTLY with the H1 title (e.g. '# Quiz: Photosynthesis') or the first H2 heading.\n"
        "4. Use consistent heading hierarchy: # for document title, ## for sections, ### for sub-sections.\n"
        "5. Every section must be complete — never leave placeholders like '[Question text]' unfilled."
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
{extra_instructions}
⚠ OUTPUT RULES (MANDATORY):
- Start your response DIRECTLY with the content — NO preamble, NO intro sentence.
- Use well-structured Markdown headings (# ## ###). Every section must be fully written out.
- Do NOT include phrases like "Here are", "Certainly", "Okay", "Sure", or any conversational opener.

{type_instructions}
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
    def build_engagement_prompt(
        topic: str,
        engagement_type: str,
        num_questions: Optional[int] = None,
        activity_format: Optional[str] = None,
        discussion_format: Optional[str] = None,
    ) -> str:
        etype = engagement_type.lower()
        extra_instructions = ""

        if etype == "icebreaker":
            type_instructions = (
                f"# Icebreaker Activities — {topic}\n\n"
                f"Generate 4 ready-to-run icebreaker activities for the topic above.\n"
                f"Each icebreaker must start class with energy, be completable in 5–8 minutes, and require no special materials.\n\n"
                f"For EACH icebreaker, use this exact structure:\n\n"
                f"## [Activity Name]\n"
                f"**Type:** [Pair / Small group / Whole class]  \n"
                f"**Duration:** [X minutes]\n\n"
                f"**How it works:**\n"
                f"1. [Step one — what teacher says/does]\n"
                f"2. [Step two — what students do]\n"
                f"3. [Continue for 3–5 steps]\n\n"
                f"**Teacher tip:** [One sentence on facilitating it well]\n\n"
                f"---\n"
            )

        elif etype == "quiz":
            n = num_questions or 5
            extra_instructions = f"NUMBER OF QUESTIONS: {n}\n"
            type_instructions = (
                f"# Quiz: {topic}\n\n"
                f"Generate exactly {n} in-class quiz questions on the topic above.\n"
                f"Mix question types: Multiple Choice (A/B/C/D), True/False, and Short Answer.\n\n"
                f"**Total Questions:** {n}\n\n"
                f"---\n\n"
                f"Format each question like this:\n\n"
                f"**Q1.** [Question text]\n\n"
                f"*(For MCQ)*\n"
                f"- A) [Option A]\n"
                f"- B) [Option B]\n"
                f"- C) [Option C]\n"
                f"- D) [Option D]\n\n"
                f"*(For True/False)*\n"
                f"☐ True &nbsp;&nbsp; ☐ False\n\n"
                f"*(For Short Answer)*\n"
                f"_Answer:_ _______________________________________________\n\n"
                f"---\n\n"
                f"## Answer Key *(Teacher Use Only)*\n\n"
                f"| Q# | Answer | Explanation |\n"
                f"|---|---|---|\n"
                f"| Q1 | [Answer] | [One-line explanation] |\n"
                f"| ... | ... | ... |\n"
            )

        elif etype == "activities":
            fmt_line = f"ACTIVITY FORMAT: {activity_format}\n" if activity_format else ""
            extra_instructions = fmt_line
            type_instructions = (
                f"# Classroom Activities — {topic}\n\n"
                f"Generate 3 detailed, hands-on classroom activities for the topic above.\n"
                f"Each must be a complete, immediately usable lesson segment.\n\n"
                f"For EACH activity, use this exact structure:\n\n"
                f"## Activity [N]: [Activity Name]\n"
                f"**Format:** [Individual / Pairs / Small groups / Whole class]  \n"
                f"**Duration:** [X minutes]  \n"
                f"**Materials:** [List items, or 'None required']\n\n"
                f"**Learning Objective:** [One clear sentence — what students will achieve]\n\n"
                f"**Instructions:**\n"
                f"1. [Step 1 — teacher setup]\n"
                f"2. [Step 2 — student action]\n"
                f"3. [Continue for 5–8 steps]\n\n"
                f"**Assessment:** [How to check understanding at the end of this activity]\n\n"
                f"**Differentiation Tip:** [One adaptation for struggling or advanced students]\n\n"
                f"---\n"
            )

        elif etype == "discussion":
            fmt_line = f"DISCUSSION FORMAT: {discussion_format}\n" if discussion_format else ""
            extra_instructions = fmt_line
            type_instructions = (
                f"# Discussion Plan — {topic}\n\n"
                f"Generate a fully structured classroom discussion plan for the topic above.\n\n"
                f"## Discussion Overview\n"
                f"**Format:** [Socratic seminar / Think-Pair-Share / Fishbowl / Debate / Jigsaw / Four Corners]  \n"
                f"**Total Duration:** [X minutes]  \n"
                f"**Group Size:** [Individual / Pairs / Small groups / Whole class]\n\n"
                f"---\n\n"
                f"## Warm-Up Prompt *(2 min)*\n\n"
                f"[Write one sentence question to get students thinking individually before the discussion begins]\n\n"
                f"---\n\n"
                f"## Core Discussion Questions\n\n"
                f"Five open-ended questions ordered from surface to deep:\n\n"
                f"1. **Opening** *(recall/observation)*: [Question]\n"
                f"2. **Exploring** *(understanding)*: [Question]\n"
                f"3. **Connecting** *(applying to real life)*: [Question]\n"
                f"4. **Challenging** *(evaluation/debate)*: [Question]\n"
                f"5. **Synthesis** *(big picture)*: [Question]\n\n"
                f"---\n\n"
                f"## Teacher Facilitation Notes\n\n"
                f"- **Opening:** [How to introduce and frame the discussion]\n"
                f"- **Handling disagreement:** [Strategy to manage conflicting views productively]\n"
                f"- **Quiet students:** [Technique to include reluctant participants]\n"
                f"- **Wrap-up:** [How to summarise and assess understanding at the end]\n\n"
                f"---\n\n"
                f"## Extension Prompt\n\n"
                f"[One thought-provoking question for early finishers or as homework]\n"
            )

        else:
            type_instructions = (
                f"# Engagement Activities — {topic}\n\n"
                f"Generate 4 creative classroom engagement ideas for this topic.\n\n"
                f"For EACH idea use this structure:\n\n"
                f"## [Activity Name]\n"
                f"**Duration:** [X minutes]  \n"
                f"**Materials:** [List or 'None']\n\n"
                f"**Description:** [2-3 sentences]\n\n"
                f"**Instructions:**\n"
                f"1. [Step 1]\n"
                f"2. [Step 2]\n"
                f"3. [Continue...]\n\n"
                f"---\n"
            )

        return PromptBuilder._render(
            "engagement",
            topic=topic,
            engagement_type=engagement_type,
            extra_instructions=extra_instructions,
            type_instructions=type_instructions,
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
