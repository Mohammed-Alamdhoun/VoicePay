import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:async';
import 'dart:math';
import '../services/api_service.dart';

class VoiceEnrollmentScreen extends StatefulWidget {
  const VoiceEnrollmentScreen({super.key});

  @override
  _VoiceEnrollmentScreenState createState() => _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends State<VoiceEnrollmentScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  
  int _currentStep = 0;
  final int _totalSteps = 6;
  List<String> _recordedPaths = [];
  bool _isRecording = false;
  bool _isLoading = true;
  int _userId = 0;
  
  Timer? _recordTimer;
  int _recordMilliseconds = 0;
  String _currentChallenge = '';
  String _status = '';

  @override
  void initState() {
    super.initState();
    _generateChallenge();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        _userId = args['user_id'] ?? 0;
        setState(() => _isLoading = false);
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ: لم يتم العثور على بيانات المستخدم')),
        );
      }
    });
  }

  void _generateChallenge() {
    final random = Random();
    List<int> digits = List.generate(6, (_) => random.nextInt(10));
    setState(() {
      _currentChallenge = digits.join(' ');
    });
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/enrollment_sample_${_currentStep}.wav';
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

        setState(() {
          _isRecording = true;
          _status = '🎙 جاري تسجيل العينة...';
        });
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
        if (path != null) {
          if (_recordedPaths.length > _currentStep) {
            _recordedPaths[_currentStep] = path;
          } else {
            _recordedPaths.add(path);
          }
        }
        _status = '✅ تم حفظ العينة ${_currentStep + 1}';
      });
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _nextStep() async {
    if (_recordedPaths.length <= _currentStep) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى تسجيل العينة أولاً')),
      );
      return;
    }
    
    if (_currentStep < _totalSteps - 1) {
      setState(() {
        _currentStep++;
        _status = '';
      });
      _generateChallenge();
    } else {
      _finishEnrollment();
    }
  }

  Future<void> _finishEnrollment() async {
    setState(() => _isLoading = true);
    try {
      await _apiService.enrollVoice(_userId, _recordedPaths);
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('تم بنجاح', style: TextStyle(color: Color(0xFF2A140A), fontWeight: FontWeight.bold)),
              content: const Text('تم تسجيل بصمتك الصوتية بنجاح. يمكنك الآن تسجيل الدخول.', style: TextStyle(color: Color(0xFF5A463A))),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                  child: const Text('حسناً', style: TextStyle(color: Color(0xFFFFB26B), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التسجيل: ${e.toString().replaceAll('Exception: ', '')}')),
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
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB26B))));
    }

    final progress = (_currentStep + 1) / _totalSteps;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F1EA),
        body: Stack(
          children: [
            // 🔥 Background Glows
            Positioned(top: -170, left: -120, child: _buildGlow(360, const Color(0xFFFFD6AE))),
            Positioned(bottom: -220, right: -140, child: _buildGlow(420, const Color(0xFFD7EEF7))),
  
            // Back Button
            Positioned(
              top: 20, right: 20,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2A140A)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.55),
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
                        const Text('تسجيل البصمة الصوتية', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF2A140A))),
                        const SizedBox(height: 8),
                        Text('إنشاء هويتك الصوتية المدعومة بالذكاء الاصطناعي', style: TextStyle(fontSize: 14, color: const Color(0xFF2A140A).withOpacity(0.6))),
                        const SizedBox(height: 32),
  
                        // Progress Card
                        _buildCard(
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('تقدم التسجيل', style: TextStyle(color: Color(0xFF2A140A), fontWeight: FontWeight.bold, fontSize: 16)),
                                  Text('${_currentStep + 1} / $_totalSteps', style: const TextStyle(color: Color(0xFFFFB26B), fontWeight: FontWeight.bold, fontSize: 18)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor: Colors.grey.withOpacity(0.15),
                                  valueColor: const AlwaysStoppedAnimation(Color(0xFFFFB26B)),
                                ),
                              ),
                            ],
                          ),
                        ),
  
                        const SizedBox(height: 24),
  
                        // Challenge Card
                        _buildCard(
                          child: Column(
                            children: [
                              const Text('تحدي الأمان الصوتي', style: TextStyle(fontSize: 18, color: Color(0xFF8EDBFF), fontWeight: FontWeight.bold)),
                              const SizedBox(height: 20),
                              const Text('يرجى قراءة الأرقام التالية بوضوح:', style: TextStyle(color: Color(0xFF2A140A), fontSize: 14)),
                              const SizedBox(height: 16),
                              Text(
                                _currentChallenge,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 32, letterSpacing: 8, fontWeight: FontWeight.bold, color: Color(0xFF2A140A)),
                              ),
                            ],
                          ),
                        ),
  
                        const SizedBox(height: 32),
                        
                        if (_status.isNotEmpty)
                          Text(_status, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _isRecording ? const Color(0xFFFFB26B) : const Color(0xFF4ADE80))),
  
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
                            child: Icon(_isRecording ? Icons.mic : Icons.mic_none, size: 50, color: Colors.white),
                          ),
                        ),
                        
                        const SizedBox(height: 12),
                        Text(_isRecording ? 'اضغط للإيقاف' : 'اضغط للتحدث', style: TextStyle(color: _isRecording ? Colors.redAccent : const Color(0xFFFFB26B), fontWeight: FontWeight.bold)),
  
                        const SizedBox(height: 40),
  
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: ElevatedButton(
                            onPressed: _recordedPaths.length > _currentStep && !_isRecording ? _nextStep : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFFB26B),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                              elevation: 8,
                            ),
                            child: Text(_currentStep < _totalSteps - 1 ? 'التالي' : 'إكمال التسجيل', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.75)),
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
      child: const Icon(Icons.mic_rounded, color: Colors.white, size: 48),
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
