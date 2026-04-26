import 'dart:async';
import '../models/app_models.dart';

class MockService {
  static Future<VerificationResultModel> verifyVoice({
    required String userId,
  }) async {
    await Future.delayed(const Duration(seconds: 2));

    return VerificationResultModel(
      status: 'ACCEPT',
      message: 'Identity verified successfully',
      sessionId: 'session_123456',
      challenge: 'Please say: 5 7 8 4 1 9',
    );
  }

  static Future<ServiceResultModel> processVoiceRequest() async {
    await Future.delayed(const Duration(seconds: 2));

    return ServiceResultModel(
      transcript: 'Transfer 50 JOD to Ahmad Al-Ghrair',
      intent: 'Transfer Money',
      entities: {
        'Amount': '50 JOD',
        'Recipient': 'Ahmad Al-Ghrair',
        'Bank': 'Arabic Bank',
      },
      finalMessage: 'Your transfer request has been processed successfully (Dummy).',
    );
  }

  static List<ContactModel> getContacts() {
    return [
      ContactModel(
        name: 'Ahmed Al-Ghrair',
        bank: 'Arabic Bank',
        maskedAccount: '**** 1234',
      ),
      ContactModel(
        name: 'Ahmed Hassan',
        bank: 'Islamic Bank',
        maskedAccount: '**** 5678',
      ),
      ContactModel(
        name: 'Layan Khadash',
        bank: 'Arabic Bank',
        maskedAccount: '**** 9012',
      ),
    ];
  }
}