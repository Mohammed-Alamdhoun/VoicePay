import 'package:flutter/material.dart';
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
      if (args is Map<String, dynamic>) {
        _userId = args['user_pid'] ?? 0;
        _challenge = args['challenge'] ?? {};
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
        
        final config = kIsWeb 
            ? const RecordConfig(encoder: AudioEncoder.opus) 
            : const RecordConfig(encoder: AudioEncoder.wav);

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
          String? dialogError;
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

            // Start timer if it's the first time
            if (resendTimer == null) {
              startCountdown();
            }

            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                title: const Text('تحقق من البريد الإلكتروني'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('أدخل الرمز المكون من 6 أرقام المرسل إلى بريدك:'),
                    const SizedBox(height: 16),
                    TextField(
                      controller: codeController,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      maxLength: 6,
                      style: const TextStyle(fontSize: 24, letterSpacing: 8),
                      decoration: InputDecoration(
                        border: const OutlineInputBorder(),
                        errorText: dialogError,
                        counterText: "", // Hide character counter
                      ),
                      onChanged: (_) {
                        if (dialogError != null) {
                          setDialogState(() => dialogError = null);
                        }
                      },
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
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم إعادة إرسال الرمز')),
                              );
                              startCountdown();
                            }
                          } catch (e) {
                            if (context.mounted) {
                              setDialogState(() => dialogError = 'فشل الإرسال: $e');
                            }
                          }
                        },
                        child: const Text('إعادة إرسال الرمز'),
                      ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
                  ElevatedButton(
                    onPressed: () async {
                      try {
                        final verifyRes = await _apiService.verifyResetCode(_userId, codeController.text);
                        if (verifyRes['status'] == 'needs_enrollment') {
                          if (context.mounted) {
                            Navigator.pop(context); // Close dialog
                            Navigator.pushReplacementNamed(
                              context, 
                              '/voice-enrollment', 
                              arguments: {'user_id': _userId}
                            );
                          }
                        } else {
                          if (context.mounted) {
                            setDialogState(() => dialogError = verifyRes['message'] ?? 'رمز غير صحيح');
                          }
                        }
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => dialogError = 'خطأ في التحقق: ${e.toString().replaceAll('Exception: ', '')}');
                        }
                      }
                    },
                    child: const Text('تحقق'),
                  ),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
        // Cancel timer when dialog is closed (dismissed or popped)
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
          // Allow retrying with same challenge or maybe get a new one?
          // For now just allow retry.
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
        appBar: AppBar(title: const Text('التحقق من الهوية')),
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.security, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'يرجى تأكيد هويتك من خلال قراءة الأرقام التالية بوضوح:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.blue.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const SizedBox(width: 40), // Placeholder for balance
                        Text(
                          _challenge['code'] ?? '',
                          style: const TextStyle(
                            fontSize: 48, 
                            letterSpacing: 8,
                            fontWeight: FontWeight.bold, 
                            color: Colors.blue
                          ),
                        ),
                        IconButton(
                          onPressed: _isLoading ? null : _refreshChallenge,
                          icon: const Icon(Icons.refresh, color: Colors.blue),
                          tooltip: 'تغيير الرمز',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _challenge['spoken'] ?? '',
                      style: TextStyle(fontSize: 18, color: Colors.blue.shade700),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              if (_isRecording)
                Text(
                  'مدة التسجيل: ${(_recordMilliseconds / 1000.0).toStringAsFixed(1)} ثانية',
                  style: const TextStyle(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    color: Colors.red
                  ),
                ),
              if (_recordedPath != null && !_isRecording)
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle, color: Colors.green),
                    SizedBox(width: 8),
                    Text('تم التسجيل بنجاح', style: TextStyle(color: Colors.green)),
                  ],
                ),
              const SizedBox(height: 20),
              GestureDetector(
                onLongPressStart: (_) => _startRecording(),
                onLongPressEnd: (_) => _stopRecording(),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _isRecording ? Colors.red : Colors.blue,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: (_isRecording ? Colors.red : Colors.blue).withOpacity(0.3),
                        blurRadius: 15,
                        spreadRadius: 5,
                      )
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.mic : Icons.mic_none,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                _isRecording ? 'اترك الزر عند الانتهاء' : 'اضغط مطولاً للتحدث',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: _isRecording ? Colors.red : Colors.blue
                ),
              ),
              const SizedBox(height: 48),
              SizedBox(
                width: double.infinity,
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _recordedPath != null && !_isRecording ? _verifyChallenge : null,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: const Text('تأكيد الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _isLoading ? null : _handleEmailReset,
                child: const Text(
                  'تواجه مشكلة في التحقق الصوتي؟ أعد ضبط بصمة الصوت عبر البريد',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.blueGrey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
