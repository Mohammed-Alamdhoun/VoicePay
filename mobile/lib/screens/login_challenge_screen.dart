import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:async';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

class LoginChallengeScreen extends StatefulWidget {
  const LoginChallengeScreen({super.key});

  @override
  _LoginChallengeScreenState createState() => _LoginChallengeScreenState();
}

class _LoginChallengeScreenState extends State<LoginChallengeScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  
  Map<String, dynamic> _challenge = {};
  int _userId = 0;
  String? _recordedPath;
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isInitialized = false;

  Timer? _recordTimer;
  int _recordMilliseconds = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _userId = args['user_pid'] ?? 0;
        _challenge = Map<String, dynamic>.from(args['challenge'] ?? {});
      }
      _isInitialized = true;
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/login_challenge.wav';
        }
        
        const config = RecordConfig(
          encoder: AudioEncoder.wav, 
          sampleRate: 16000, 
          numChannels: 1
        );

        await _audioRecorder.start(config, path: path ?? '');
        
        _recordMilliseconds = 0;
        _recordTimer?.cancel();
        _recordTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
          setState(() {
            _recordMilliseconds += 100;
          });
        });

        setState(() => _isRecording = true);
      }
    } catch (e) {
      print('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRecorder.stop();
      _recordTimer?.cancel();
      setState(() {
        _isRecording = false;
        _recordedPath = path;
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _refreshChallenge() async {
    setState(() => _isLoading = true);
    try {
      final newChallenge = await _apiService.generateChallenge();
      setState(() {
        _challenge = newChallenge;
        _recordedPath = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في تحديث الرمز: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleEmailReset() async {
    setState(() => _isLoading = true);
    try {
      final res = await _apiService.sendResetCode(_userId);
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message'])),
      );

      final codeController = TextEditingController();
      Timer? resendTimer;
      int resendSeconds = 60;
      
      showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              void startCountdown() {
              resendTimer?.cancel();
              resendSeconds = 60;
              resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
                if (resendSeconds > 0) {
                  setDialogState(() => resendSeconds--);
                } else {
                  timer.cancel();
                }
              });
            }

            if (resendTimer == null) {
              startCountdown();
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: const Text('تحقق من البريد الإلكتروني', style: TextStyle(color: Color(0xFF2A140A), fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('أدخل الرمز المكون من 6 أرقام المرسل إلى بريدك:', style: TextStyle(color: Color(0xFF5A463A))),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8, color: Colors.black),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFFF7F1EA),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                        counterText: "",
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (resendSeconds > 0)
                      Text(
                        'يمكنك إعادة إرسال الرمز بعد: $resendSeconds ثانية',
                        style: const TextStyle(fontSize: 14, color: Colors.grey),
                      )
                    else
                      TextButton(
                        onPressed: () async {
                          try {
                            await _apiService.sendResetCode(_userId);
                            startCountdown();
                          } catch (e) {}
                        },
                        child: const Text('إعادة إرسال الرمز', style: TextStyle(color: Color(0xFFFFB26B))),
                      ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء', style: TextStyle(color: Color(0xFF8EDBFF)))),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final verifyRes = await _apiService.verifyResetCode(_userId, codeController.text);
                        if (verifyRes['status'] == 'needs_enrollment') {
                          Navigator.pop(context);
                          Navigator.pushReplacementNamed(
                            context, 
                            '/voice-enrollment', 
                            arguments: {'user_id': _userId}
                          );
                        }
                      } catch (e) {}
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFFFB26B), foregroundColor: Colors.white),
                    child: const Text('تحقق'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
        resendTimer?.cancel();
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _verifyChallenge() async {
    if (_recordedPath == null) return;
    
    setState(() => _isLoading = true);
    try {
      final result = await _apiService.verifyLoginChallenge(
        _userId, 
        _challenge['code'], 
        _recordedPath!
      );
      
      if (mounted) {
        if (result['status'] == 'success') {
          Navigator.pushReplacement(
            context, 
            MaterialPageRoute(builder: (context) => DashboardScreen(userData: result['user']))
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message'] ?? 'فشل التحقق'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التحقق: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _audioRecorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F1EA),
        body: Stack(
          children: [
            // 🔥 Background Glows
            _buildGlow(top: -170, left: -120, color: const Color(0xFFFFD6AE)),
            _buildGlow(bottom: -220, right: -140, color: const Color(0xFFD7EEF7)),

            // Back Button
            Positioned(
              top: 20, right: 20,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2A140A)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.5),
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
            ),

            SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        _buildLogo(),
                        const SizedBox(height: 24),
                        const Text('التحقق من الهوية', style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF2A140A))),
                        const SizedBox(height: 8),
                        Text('يرجى تأكيد هويتك من خلال بصمتك الصوتية', style: TextStyle(fontSize: 15, color: const Color(0xFF2A140A).withOpacity(0.6))),
                        const SizedBox(height: 32),

                        _buildCard(
                          child: Column(
                            children: [
                              const Text('تحدي الأمان الصوتي', style: TextStyle(fontSize: 18, color: Color(0xFF8EDBFF), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              const Text('يرجى قراءة الأرقام التالية بوضوح:', style: TextStyle(color: Color(0xFF2A140A), fontSize: 14)),
                              const SizedBox(height: 16),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    '${_challenge['code'] ?? ''}',
                                    style: const TextStyle(fontSize: 36, letterSpacing: 4, fontWeight: FontWeight.bold, color: Color(0xFFFFB26B)),
                                  ),
                                  Text(
                                    '(${_challenge['spoken'] ?? ''})',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF2A140A)),
                                  ),
                                  IconButton(
                                    onPressed: _isLoading ? null : _refreshChallenge,
                                    icon: const Icon(Icons.refresh, color: Color(0xFF8EDBFF)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),
                        
                        if (_isRecording)
                          Text(
                            'مدة التسجيل: ${(_recordMilliseconds / 1000.0).toStringAsFixed(1)} ثانية',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.redAccent),
                          ),
                        if (_recordedPath != null && !_isRecording)
                          const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green),
                              SizedBox(width: 8),
                              Text('تم التسجيل بنجاح', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                            ],
                          ),

                        const SizedBox(height: 24),

                        // Recording Button
                        GestureDetector(
                          onTap: () => _isRecording ? _stopRecording() : _startRecording(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: _isRecording ? Colors.redAccent : const Color(0xFFFFB26B),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: (_isRecording ? Colors.redAccent : const Color(0xFFFFB26B)).withOpacity(0.3), blurRadius: 20, spreadRadius: 5),
                              ],
                            ),
                            child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 60, color: Colors.white),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        Text(_isRecording ? 'اضغط للإيقاف' : 'اضغط للتحدث', style: TextStyle(color: _isRecording ? Colors.redAccent : const Color(0xFFFFB26B), fontWeight: FontWeight.bold)),

                        const SizedBox(height: 48),

                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: _isLoading 
                            ? const Center(child: CircularProgressIndicator(color: Color(0xFFFFB26B)))
                            : ElevatedButton(
                                onPressed: _recordedPath != null && !_isRecording ? _verifyChallenge : null,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB26B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                  elevation: 8,
                                ),
                                child: const Text('تأكيد الدخول', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              ),
                        ),

                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading ? null : _handleEmailReset,
                          child: const Text(
                            'أعد ضبط بصمة الصوت عبر البريد',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Color(0xFF5A463A), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlow({double? top, double? bottom, double? left, double? right, required Color color}) {
    return Positioned(
      top: top, bottom: bottom, left: left, right: right,
      child: Container(
        width: 400, height: 400,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.75)),
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 100, height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(colors: [Color(0xFFFFB26B), Color(0xFF8EDBFF)]),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB26B).withOpacity(0.35), blurRadius: 35, spreadRadius: 3)],
      ),
      child: const Icon(Icons.security, color: Colors.white, size: 48),
    );
  }

  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: Colors.white.withOpacity(0.82),
        border: Border.all(color: const Color(0xFFFFB26B).withOpacity(0.1)),
        boxShadow: [BoxShadow(color: const Color(0xFFFFB26B).withOpacity(0.1), blurRadius: 30, spreadRadius: 1)],
      ),
      child: child,
    );
  }
}
