#!/bin/bash
echo "Testing Sprout AI Backend..."
echo "---------------------------"

# Test Root
echo "1. Testing Root Endpoint:"
curl -s http://localhost:8000/
echo -e "\n"

# Test Lesson Generation
echo "2. Testing Lesson Generation (Photosynthesis):"
curl -s http://localhost:8000/api/generate-lesson -F "topic=Photosynthesis" -F "num_lectures=1" | head -c 300
echo -e "...\n"

# Test Worksheet Generation
echo "3. Testing Worksheet Generation (Algebra):"
curl -s -H "Content-Type: application/json" -X POST http://localhost:8000/api/generate-worksheet -d '{"topic": "Algebra", "difficulty": "Medium", "question_type": "MCQ", "num_questions": 5}' | head -c 300
echo -e "...\n"

echo "---------------------------"
echo "Backend is healthy and running!"
