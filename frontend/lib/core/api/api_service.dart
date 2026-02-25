import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ApiService {
  static const String baseUrl = "http://127.0.0.1:8000/api";

  // Hardcoded until auth is added; every request uses this teacher identity.
  static const String teacherId = "teacher_01";

  // Shared API key validated by backend middleware.
  static const String _apiKey = "sprout-ai-secret-key-2025";

  // Default timeout for all HTTP requests.
  static const Duration _timeout = Duration(seconds: 60);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-API-Key': _apiKey,
      };

  /// Fetch lesson plans scoped to a specific grade and subject.
  /// Never returns plans from other grades or subjects.
  Future<List<Map<String, dynamic>>> fetchPlans({
    required String grade,
    required String subject,
  }) async {
    final uri = Uri.parse('$baseUrl/lesson-plans').replace(queryParameters: {
      'teacher_id': teacherId,
      'grade': grade,
      'subject': subject,
    });
    final response = await http.get(uri, headers: {'X-API-Key': _apiKey}).timeout(_timeout);
    final List<dynamic> data = json.decode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  Future<bool> updatePlan(int planId, String content) async {
    final response = await http.patch(
      Uri.parse('$baseUrl/lesson-plans/$planId'),
      headers: _headers,
      body: json.encode({'content': content}),
    ).timeout(_timeout);
    final data = json.decode(response.body);
    return data['success'] == true;
  }

  Future<bool> deletePlan(int planId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/lesson-plans/$planId'),
      headers: {'X-API-Key': _apiKey},
    ).timeout(_timeout);
    final data = json.decode(response.body);
    return data['success'] == true;
  }

  Future<Map<String, dynamic>> generateLesson({
    required String grade,
    required String subject,
    required String topic,
    required int lectures,
    String? concepts,
    Uint8List? fileBytes,
    String? fileName,
  }) async {
    final request =
        http.MultipartRequest('POST', Uri.parse('$baseUrl/generate-lesson'));
    request.headers['X-API-Key'] = _apiKey;
    request.fields['teacher_id'] = teacherId;
    request.fields['grade'] = grade;
    request.fields['subject'] = subject;
    request.fields['topic'] = topic;
    request.fields['num_lectures'] = lectures.toString();
    if (concepts != null && concepts.isNotEmpty) {
      request.fields['concepts'] = concepts;
    }
    if (fileBytes != null && fileName != null) {
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        fileBytes,
        filename: fileName,
        contentType: MediaType('application', 'pdf'),
      ));
    }

    final response = await request.send().timeout(_timeout);
    final responseData = await response.stream.bytesToString();
    return json.decode(responseData);
  }

  Future<Map<String, dynamic>> generateWorksheet({
    required String topic,
    required String difficulty,
    required String questionType,
    required int count,
    Map<String, int>? questionCounts,
    bool useRag = false,
    int? planId,
    String? sessionContext,
    String grade = '',
    String subject = '',
  }) async {
    final body = <String, dynamic>{
      'topic': topic,
      'difficulty': difficulty,
      'question_type': questionType,
      'num_questions': count,
      'use_rag': useRag,
      'plan_id': planId,
      'grade': grade,
      'subject': subject,
    };
    if (questionCounts != null && questionCounts.isNotEmpty) {
      body['question_counts'] = questionCounts;
    }
    if (sessionContext != null) body['session_context'] = sessionContext;
    final response = await http.post(
      Uri.parse('$baseUrl/generate-worksheet'),
      headers: _headers,
      body: json.encode(body),
    ).timeout(_timeout);
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> generateEngagement({
    required String topic,
    required String type,
    int? planId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/generate-engagement'),
      headers: _headers,
      body: json.encode(
          {'topic': topic, 'engagement_type': type, 'plan_id': planId}),
    ).timeout(_timeout);
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> simplifyConcept(String text,
      {int? planId}) async {
    final response = await http.post(
      Uri.parse('$baseUrl/simplify-concept'),
      headers: _headers,
      body: json.encode({'topic_or_text': text, 'plan_id': planId}),
    ).timeout(_timeout);
    return json.decode(response.body);
  }

  Future<Map<String, dynamic>> regenerate({
    required String feature,
    required String originalContent,
    required String instruction,
    int? planId,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/regenerate'),
      headers: _headers,
      body: json.encode({
        'feature': feature,
        'original_content': originalContent,
        'instruction': instruction,
        'plan_id': planId,
      }),
    ).timeout(_timeout);
    return json.decode(response.body);
  }

  /// Fetch worksheets scoped to the current grade + subject.
  Future<List<Map<String, dynamic>>> fetchWorksheets({
    String grade = '',
    String subject = '',
  }) async {
    final uri = Uri.parse('$baseUrl/worksheets').replace(
      queryParameters: {
        'teacher_id': teacherId,
        'grade': grade,
        'subject': subject,
      },
    );
    final response =
        await http.get(uri, headers: {'X-API-Key': _apiKey}).timeout(_timeout);
    final List<dynamic> data = json.decode(response.body);
    return data.cast<Map<String, dynamic>>();
  }

  /// Update content and/or title of a saved worksheet.
  Future<bool> updateWorksheet(int worksheetId,
      {String? content, String? title}) async {
    final body = <String, dynamic>{};
    if (content != null) body['content'] = content;
    if (title != null) body['title'] = title;
    final response = await http.patch(
      Uri.parse('$baseUrl/worksheets/$worksheetId'),
      headers: _headers,
      body: json.encode(body),
    ).timeout(_timeout);
    final data = json.decode(response.body);
    return data['success'] == true;
  }

  /// Delete a saved worksheet by id.
  Future<bool> deleteWorksheet(int worksheetId) async {
    final response = await http.delete(
      Uri.parse('$baseUrl/worksheets/$worksheetId'),
      headers: {'X-API-Key': _apiKey},
    ).timeout(_timeout);
    final data = json.decode(response.body);
    return data['success'] == true;
  }
}
