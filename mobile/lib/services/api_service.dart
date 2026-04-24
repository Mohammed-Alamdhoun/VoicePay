import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:typed_data';

class ApiService {
  // Automatically switch URL based on platform
  static String get baseUrl {
    if (kIsWeb) {
      return 'http://localhost:5000/api/v1';
    } else {
      // 10.0.2.2 is the alias for 127.0.0.1 for Android Emulator
      return 'http://10.0.2.2:5000/api/v1';
    }
  }

  // Add a timeout to all requests to prevent infinite loading
  static const Duration timeoutDuration = Duration(seconds: 10);

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(timeoutDuration);
      
      final data = jsonDecode(response.body);
      if (response.statusCode == 200) return data;
      throw Exception(data['detail'] ?? 'Failed to login');
    } catch (e) {
      if (e is Exception && e.toString().contains('needs_enrollment')) {
        rethrow;
      }
      throw Exception('لا يمكن الاتصال بالخادم. تأكد من تشغيل الـ Backend. ($e)');
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String phone, String bank) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'full_name': name,
        'email': email,
        'password': password,
        'phone_number': phone,
        'bank_name': bank,
      }),
    );
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? 'Registration failed');
  }

  Future<List<dynamic>> getEnrollmentChallenges() async {
    final response = await http.get(Uri.parse('$baseUrl/enrollment-challenges'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load challenges');
  }

  Future<Map<String, dynamic>> enrollVoice(int userPid, List<String> audioPaths) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/enroll-voice?user_id=$userPid'));
    
    for (int i = 0; i < audioPaths.length; i++) {
      if (kIsWeb) {
        final response = await http.get(Uri.parse(audioPaths[i]));
        request.files.add(http.MultipartFile.fromBytes(
          'files',
          response.bodyBytes,
          filename: 'sample_$i.m4a',
        ));
      } else {
        request.files.add(await http.MultipartFile.fromPath('files', audioPaths[i]));
      }
    }
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? 'Voice enrollment failed');
  }

  Future<Map<String, dynamic>> processCommand(String text, int userPid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/process'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'text': text, 'user_pid': userPid}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to process command');
  }

  Future<Map<String, dynamic>> confirmAction(String actionType, Map<String, dynamic> data, int userPid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/confirm'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action_type': actionType,
        'data': data,
        'user_pid': userPid
      }),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to confirm action');
  }

  Future<Map<String, dynamic>> sendResetCode(int userPid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/send-reset-code?user_pid=$userPid'),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to send reset code');
  }

  Future<Map<String, dynamic>> verifyResetCode(int userPid, String code) async {
    final response = await http.post(
      Uri.parse('$baseUrl/verify-reset-code'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_pid': userPid, 'code': code}),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to verify reset code');
  }

  Future<Uint8List> textToSpeech(String text) async {
    final response = await http.get(
      Uri.parse('$baseUrl/text-to-speech?text=${Uri.encodeComponent(text)}'),
    );
    if (response.statusCode == 200) return response.bodyBytes;
    throw Exception('Failed to generate speech');
  }

  Future<String> voiceToText(String path) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/voice-to-text'));
    
    if (kIsWeb) {
      final response = await http.get(Uri.parse(path));
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        response.bodyBytes,
        filename: 'voice_record.m4a',
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', path));
    }
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['text'] ?? '';
    }
    throw Exception('Failed to transcribe voice');
  }

  Future<Map<String, dynamic>> generateChallenge() async {
    final response = await http.get(Uri.parse('$baseUrl/generate-challenge'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to generate new challenge');
  }

  Future<Map<String, dynamic>> verifyLoginChallenge(int userPid, String challengeCode, String audioPath) async {
    var request = http.MultipartRequest('POST', Uri.parse('$baseUrl/verify-login-challenge?user_pid=$userPid&challenge_code=$challengeCode'));
    
    if (kIsWeb) {
      final response = await http.get(Uri.parse(audioPath));
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        response.bodyBytes,
        filename: 'challenge_record.m4a',
      ));
    } else {
      request.files.add(await http.MultipartFile.fromPath('file', audioPath));
    }
    
    var streamedResponse = await request.send();
    var response = await http.Response.fromStream(streamedResponse);
    final data = jsonDecode(response.body);
    if (response.statusCode == 200) return data;
    throw Exception(data['detail'] ?? 'Challenge verification failed');
  }

  Future<Map<String, dynamic>> updateReferenceNumber(int userPid) async {
    final response = await http.post(
      Uri.parse('$baseUrl/user/update-reference?user_pid=$userPid'),
    );
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to update reference number');
  }

  Future<List<dynamic>> getRecipients(int userPid) async {
    final response = await http.get(Uri.parse('$baseUrl/recipients/$userPid'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load recipients');
  }

  Future<List<dynamic>> getBills(int userPid) async {
    final response = await http.get(Uri.parse('$baseUrl/bills/$userPid'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load bills');
  }

  Future<Map<String, dynamic>> getUserDetails(int userPid) async {
    final response = await http.get(Uri.parse('$baseUrl/user/$userPid'));
    if (response.statusCode == 200) return jsonDecode(response.body);
    throw Exception('Failed to load user details');
  }

  Future<Map<String, dynamic>> addRecipient(int userPid, String nickname, String bankName, String ref, String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipients/add'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_pid': userPid,
        'nickname': nickname,
        'bank_name': bankName,
        'reference_number': ref,
        'phone_number': phone
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> updateRecipient(int id, String nickname, String bankName, String ref, String phone) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipients/update'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'id': id,
        'nickname': nickname,
        'bank_name': bankName,
        'reference_number': ref,
        'phone_number': phone
      }),
    );
    return jsonDecode(response.body);
  }

  Future<Map<String, dynamic>> removeRecipient(int userPid, int recipientId) async {
    final response = await http.post(
      Uri.parse('$baseUrl/recipients/remove'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_pid': userPid, 'recipient_pid': recipientId}),
    );
    return jsonDecode(response.body);
  }
}
