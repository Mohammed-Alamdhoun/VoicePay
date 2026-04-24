import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io' show File;
import 'dart:async';
import '../services/api_service.dart';

class VoiceEnrollmentScreen extends StatefulWidget {
  const VoiceEnrollmentScreen({super.key});

  @override
  _VoiceEnrollmentScreenState createState() => _VoiceEnrollmentScreenState();
}

class _VoiceEnrollmentScreenState extends State<VoiceEnrollmentScreen> {
  final AudioRecorder _audioRecorder = AudioRecorder();
  final ApiService _apiService = ApiService();
  
  List<dynamic> _challenges = [];
  int _currentStep = 0;
  List<String> _recordedPaths = [];
  bool _isRecording = false;
  bool _isLoading = true;
  int _userId = 0;
  
  Timer? _recordTimer;
  int _recordMilliseconds = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        _userId = args['user_id'] ?? 0;
        _loadChallenges();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('خطأ: لم يتم العثور على بيانات المستخدم')),
        );
      }
    });
  }

  Future<void> _loadChallenges() async {
    try {
      final challenges = await _apiService.getEnrollmentChallenges();
      setState(() {
        _challenges = challenges;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في تحميل التحديات: $e')),
      );
    }
  }

  Future<void> _startRecording() async {
    try {
      if (await _audioRecorder.hasPermission()) {
        String? path;
        if (!kIsWeb) {
          final directory = await getApplicationDocumentsDirectory();
          path = '${directory.path}/enrollment_sample_${_currentStep}.wav';
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
        if (path != null) {
          if (_recordedPaths.length > _currentStep) {
            _recordedPaths[_currentStep] = path;
          } else {
            _recordedPaths.add(path);
          }
        }
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
    
    if (_currentStep < 5) {
      setState(() {
        _currentStep++;
      });
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
          builder: (context) => AlertDialog(
            title: const Text('تم بنجاح'),
            content: const Text('تم تسجيل بصمة الصوت بنجاح. يمكنك الآن تسجيل الدخول.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false),
                child: const Text('حسناً'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التسجيل: $e')),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final currentChallenge = _challenges[_currentStep];
    final progress = (_currentStep + 1) / 6;

    return Scaffold(
      appBar: AppBar(title: const Text('تسجيل بصمة الصوت')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            LinearProgressIndicator(value: progress, minHeight: 10),
            const SizedBox(height: 20),
            Text(
              'خطوة ${_currentStep + 1} من 6',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const Spacer(),
            const Text(
              'يرجى قراءة النص التالي بوضوح:',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: Colors.blue),
              ),
              child: Text(
                currentChallenge['text'],
                style: const TextStyle(fontSize: 24, color: Colors.blue, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
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
            if (_recordedPaths.length > _currentStep && !_isRecording)
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
                  size: 50,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _isRecording ? 'اترك الزر عند الانتهاء' : 'اضغط مطولاً للتحدث',
              style: TextStyle(color: _isRecording ? Colors.red : Colors.blue),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recordedPaths.length > _currentStep && !_isRecording ? _nextStep : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(_currentStep < 5 ? 'التالي' : 'إكمال التسجيل'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
