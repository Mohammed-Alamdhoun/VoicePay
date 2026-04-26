import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  //static const String baseUrl = 'http://127.0.0.1:8000';
  static const String baseUrl = 'https://modalmadhoun-voicepay-backend.hf.space/api/v1';
  // ================= START VERIFICATION =================

  static Future<Map<String, dynamic>> startVerification({
    required String userId,
  }) async {
    final url = Uri.parse('$baseUrl/start-verification');

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('❌ start-verification failed: ${response.body}');
    }
  }

  // ================= COMPLETE VERIFICATION =================

  static Future<Map<String, dynamic>> completeVerification({
    required String sessionId,
    required String audioFilePath,
    String? speakerLabel,
  }) async {
    final uri = Uri.parse('$baseUrl/complete-verification').replace(
      queryParameters: {
        'session_id': sessionId,
        if (speakerLabel != null && speakerLabel.trim().isNotEmpty)
          'speaker_label': speakerLabel.trim(),
      },
    );

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('audio_file', audioFilePath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('🔍 Verification Response: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('❌ complete-verification failed: ${response.body}');
    }
  }

  // ================= COMPLETE VERIFICATION AI SECURE =================

  static Future<Map<String, dynamic>> completeVerificationAiSecure({
    required String sessionId,
    required String audioFilePath,
    String? speakerLabel,
  }) async {
    final uri = Uri.parse('$baseUrl/complete-verification-ai-secure').replace(
      queryParameters: {
        'session_id': sessionId,
        if (speakerLabel != null && speakerLabel.trim().isNotEmpty)
          'speaker_label': speakerLabel.trim(),
      },
    );

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('audio_file', audioFilePath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('🤖 AI SECURE Verification Response: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception(
        '❌ complete-verification-ai-secure failed: ${response.body}',
      );
    }
  }

  //==================enrollment check====================

  static Future<bool> checkUserExists(String userId) async {
    final url = Uri.parse('$baseUrl/check-user/$userId');

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['exists'];
    } else {
      throw Exception('Error checking user');
    }
  }

  static Future<dynamic> enrollUserUpload({
    required String userId,
    required List<String> filePaths,
  }) async {

    try {

      var uri = Uri.parse(
        '$baseUrl/enroll-user-upload',
      );

      var request =
      http.MultipartRequest(
        'POST',
        uri,
      );

      // fields
      request.fields['user_id'] =
          userId;

      request.fields['profile'] =
      'mobile';

      // files
      for (String path in filePaths) {

        request.files.add(

          await http.MultipartFile
              .fromPath(
            'audio_files',
            path,
          ),
        );
      }

      print(
          '🚀 Sending enrollment request...');

      var streamedResponse =
      await request.send();

      var response =
      await http.Response.fromStream(
        streamedResponse,
      );

      print(
          '📥 Enrollment Status: ${response.statusCode}');
      print(
          '📥 Enrollment Body: ${response.body}');

      if (response.statusCode == 200) {

        return jsonDecode(response.body);

      } else {

        throw Exception(
          'Enrollment failed: ${response.body}',
        );
      }

    } catch (e) {

      print(
          '❌ Enrollment Exception: $e');

      rethrow;
    }
  }

  // ================= PROCESS REQUEST (🔥 FIXED NAME) =================

  static Future<Map<String, dynamic>> processRequest({
    required String userId,
    required String audioFilePath,
    String? speakerLabel,
  }) async {
    final uri = Uri.parse('$baseUrl/process-audio-request').replace(
      queryParameters: {
        'user_id': userId,
        if (speakerLabel != null && speakerLabel.trim().isNotEmpty)
          'speaker_label': speakerLabel.trim(),
      },
    );

    print('🚀 Sending request to: $uri');
    print('🎤 Audio path: $audioFilePath');

    final request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('audio_file', audioFilePath),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    print('📥 Status Code: ${response.statusCode}');
    print('📥 Response Body: ${response.body}');

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('❌ process-audio-request failed: ${response.body}');
    }
  }
}
