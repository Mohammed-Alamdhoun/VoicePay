import 'package:flutter/material.dart';
import '../auth/login_screen.dart';
import 'final_result_screen.dart';

class FinalResultScreen extends StatelessWidget {
  static const String routeName = '/final-result';

  const FinalResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>? ?? {};

    final transcript = args['transcribed_text']?.toString() ?? 'غير متوفر';
    final dynamic nlpRaw = args['nlp_result'];
    final dynamic actionRaw = args['action_result'];

    final parsedNlp = _parseNlpResult(nlpRaw);
    final parsedAction = _parseActionResult(actionRaw);

    return WillPopScope(
      onWillPop: () async {
        Navigator.pushNamedAndRemoveUntil(
          context,
          LoginScreen.routeName,
          (route) => false,
        );
        return false;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('نتيجة الطلب'),
          automaticallyImplyLeading: false,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  LoginScreen.routeName,
                  (route) => false,
                );
              },
              child: const Text(
                'تسجيل الخروج',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 650),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 18,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green, size: 30),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'تم تنفيذ طلبك بنجاح ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'تم تنفيذ طلبك باستخدام التحقق الصوتي بنجاح.\nلأي عملية جديدة، سيتم طلب التحقق مرة أخرى لحماية حسابك.',
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionTitle(' الطلب الذي تم فهمه'),
                  _infoCard(transcript),

                  const SizedBox(height: 16),

                  _sectionTitle(' تحليل الطلب'),
                  _structuredInfoCard([
                    _infoRow('نوع العملية', parsedNlp.intentArabic),
                    _infoRow('المبلغ', parsedNlp.amountText),
                    _infoRow('المستلم', parsedNlp.recipientText),
                    if (parsedNlp.confidenceText.isNotEmpty)
                      _infoRow('مستوى الثقة', parsedNlp.confidenceText),
                  ]),

                  const SizedBox(height: 16),

                  _sectionTitle('💰 تفاصيل العملية'),
                  _structuredInfoCard([
                    _infoRow('حالة العملية', parsedAction.statusArabic),
                    _infoRow('الرسالة', parsedAction.messageText),
                    if (parsedAction.amountText.isNotEmpty)
                      _infoRow('المبلغ', parsedAction.amountText),
                    if (parsedAction.currencyText.isNotEmpty)
                      _infoRow('العملة', parsedAction.currencyText),
                    if (parsedAction.recipientText.isNotEmpty)
                      _infoRow('المستلم', parsedAction.recipientText),
                  ]),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          LoginScreen.routeName,
                          (route) => false,
                        );
                      },
                      icon: const Icon(Icons.lock_reset),
                      label: const Text('العودة إلى تسجيل الدخول'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  static Widget _infoCard(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 16, height: 1.6),
      ),
    );
  }

  static Widget _structuredInfoCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F8FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: children,
      ),
    );
  }

  static Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$title:',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'غير متوفر' : value,
              style: const TextStyle(
                fontSize: 15,
                height: 1.5,
                color: Color(0xFF374151),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static _ParsedNlpResult _parseNlpResult(dynamic raw) {
    if (raw is Map) {
      final intent = raw['intent']?.toString() ?? '';
      final confidence = raw['confidence']?.toString() ?? '';
      final entities = raw['entities'];

      String amount = '';
      String currency = '';
      String recipient = '';

      if (entities is Map) {
        amount = entities['amount']?.toString() ?? '';
        currency = entities['currency']?.toString() ?? '';
        recipient = entities['recipient']?.toString() ?? '';
      }

      return _ParsedNlpResult(
        intentArabic: _mapIntentToArabic(intent),
        amountText: _combineAmountAndCurrency(amount, currency),
        recipientText: recipient,
        confidenceText: confidence,
      );
    }

    final text = raw?.toString() ?? '';

    final intent = _extractValue(text, 'intent:');
    final confidence = _extractValue(text, 'confidence:');
    final amount = _extractValue(text, 'amount:');
    final currency = _extractValue(text, 'currency:');
    final recipient = _extractValue(text, 'recipient:');

    return _ParsedNlpResult(
      intentArabic: _mapIntentToArabic(intent),
      amountText: _combineAmountAndCurrency(amount, currency),
      recipientText: recipient,
      confidenceText: confidence,
    );
  }

  static _ParsedActionResult _parseActionResult(dynamic raw) {
    if (raw is Map) {
      final status = raw['action_status']?.toString() ?? '';
      final message = raw['message']?.toString() ?? '';
      final data = raw['data'];

      String amount = '';
      String currency = '';
      String recipient = '';

      if (data is Map) {
        amount = data['amount']?.toString() ?? '';
        currency = data['currency']?.toString() ?? '';
        recipient = data['recipient']?.toString() ?? '';
      }

      return _ParsedActionResult(
        statusArabic: _mapStatusToArabic(status),
        messageText: message,
        amountText: amount,
        currencyText: currency,
        recipientText: recipient,
      );
    }

    final text = raw?.toString() ?? '';

    final status = _extractValue(text, 'action_status:');
    final message = _extractValue(text, 'message:');
    final amount = _extractValue(text, 'amount:');
    final currency = _extractValue(text, 'currency:');
    final recipient = _extractValue(text, 'recipient:');

    return _ParsedActionResult(
      statusArabic: _mapStatusToArabic(status),
      messageText: message,
      amountText: amount,
      currencyText: currency,
      recipientText: recipient,
    );
  }

  static String _extractValue(String source, String key) {
    final start = source.indexOf(key);
    if (start == -1) return '';

    final afterKey = source.substring(start + key.length).trim();

    final separators = [',', '}', '\n'];
    int endIndex = afterKey.length;

    for (final sep in separators) {
      final idx = afterKey.indexOf(sep);
      if (idx != -1 && idx < endIndex) {
        endIndex = idx;
      }
    }

    return afterKey.substring(0, endIndex).trim();
  }

  static String _mapIntentToArabic(String intent) {
    switch (intent.trim().toLowerCase()) {
      case 'p2p_transfer':
        return 'تحويل أموال';
      case 'bill_payment':
        return 'دفع فاتورة';
      default:
        return intent.isEmpty ? 'غير محدد' : intent;
    }
  }

  static String _mapStatusToArabic(String status) {
    switch (status.trim().toLowerCase()) {
      case 'success':
        return 'ناجحة';
      case 'failed':
        return 'فاشلة';
      default:
        return status.isEmpty ? 'غير محددة' : status;
    }
  }

  static String _combineAmountAndCurrency(String amount, String currency) {
    if (amount.isEmpty && currency.isEmpty) return '';
    if (amount.isNotEmpty && currency.isNotEmpty) return '$amount $currency';
    return amount.isNotEmpty ? amount : currency;
  }
}

class _ParsedNlpResult {
  final String intentArabic;
  final String amountText;
  final String recipientText;
  final String confidenceText;

  _ParsedNlpResult({
    required this.intentArabic,
    required this.amountText,
    required this.recipientText,
    required this.confidenceText,
  });
}

class _ParsedActionResult {
  final String statusArabic;
  final String messageText;
  final String amountText;
  final String currencyText;
  final String recipientText;

  _ParsedActionResult({
    required this.statusArabic,
    required this.messageText,
    required this.amountText,
    required this.currencyText,
    required this.recipientText,
  });
}