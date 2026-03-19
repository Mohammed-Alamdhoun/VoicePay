import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show File; // Use show File to avoid conflicts on web
import '../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const DashboardScreen({super.key, required this.userData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  final _commandController = TextEditingController();
  final _nicknameController = TextEditingController();
  final _bankController = TextEditingController();
  final _refController = TextEditingController();
  final _phoneController = TextEditingController();
  
  final _apiService = ApiService();
  final _recorder = AudioRecorder();
  final _audioPlayer = AudioPlayer();
  late AnimationController _pulseController;
  
  String _result = '';
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _isSpeaking = false;
  List<dynamic> _recipients = [];
  List<dynamic> _bills = [];
  late Map<String, dynamic> _user;

  Map<String, dynamic>? _pendingTransaction;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  @override
  void initState() { 
    super.initState(); 
    _user = Map.from(widget.userData);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fetchData(); 

    // Listen for recorder state changes (to detect unexpected stops)
    _recorder.onStateChanged().listen((state) {
      if (state == RecordState.stop && _isRecording && mounted) {
        setState(() => _isRecording = false);
        _pulseController.stop();
        _pulseController.reset();
        _recordingTimer?.cancel();
      }
    });

    // Listen for audio player completion to trigger next step
    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        // If we just played a confirmation prompt, start recording the user's response automatically
        if (_pendingTransaction != null) {
          _toggleRecording();
        }
      }
    });
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    super.dispose();
  }

  void _fetchData() {
    _fetchRecipients();
    _fetchBills();
    _refreshBalance();
  }

  Future<void> _playTTS(String text) async {
    try {
      setState(() => _isSpeaking = true);
      final audioBytes = await _apiService.textToSpeech(text);
      await _audioPlayer.play(BytesSource(audioBytes));
    } catch (e) {
      setState(() => _isSpeaking = false);
      debugPrint('TTS Error: $e');
    }
  }

  void _toggleRecording() async {
    if (_isProcessing || _isSpeaking) return; 

    if (_isRecording) {
      _stopRecording();
    } else {
      _startRecording();
    }
  }

  void _startRecording() async {
    if (await _recorder.hasPermission()) {
      String? path;
      if (!kIsWeb) {
        final directory = await getTemporaryDirectory();
        path = '${directory.path}/voice_record.m4a';
      }
      
      if (await _recorder.isRecording()) return;

      const config = kIsWeb 
          ? RecordConfig(encoder: AudioEncoder.opus) 
          : RecordConfig();

      await _recorder.start(config, path: path ?? '');
      _pulseController.repeat(reverse: true);
      setState(() => _isRecording = true);

      // 1. Global Safety Timeout (Stop after 6 seconds anyway)
      _recordingTimer = Timer(const Duration(seconds: 6), () {
        if (_isRecording) _stopRecording();
      });

      // 2. Silence Detection (Auto-stop when user stops talking)
      int silenceCount = 0;
      const silenceThreshold = -40.0; // dB
      const silenceDuration = 1500; // milliseconds
      const checkInterval = 200; // milliseconds

      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: checkInterval))
          .listen((amp) {
        if (amp.current < silenceThreshold) {
          silenceCount += checkInterval;
        } else {
          silenceCount = 0; // Reset if sound detected
        }

        if (silenceCount >= silenceDuration && _isRecording) {
          _stopRecording();
        }
      });
    }
  }

  void _stopRecording() async {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    
    final path = await _recorder.stop();
    _pulseController.stop();
    _pulseController.reset();
    setState(() => _isRecording = false);
    if (path != null) {
      _handleVoiceInput(path);
    }
  }

  void _handleVoiceInput(String path) async {
    try {
      final text = await _apiService.voiceToText(path);
      _commandController.text = text;
      
      // If we are waiting for a confirmation
      if (_pendingTransaction != null) {
        _processConfirmation(text);
      } else {
        _processVoice(text);
      }
    } catch (e) {
      setState(() {
        _result = 'خطأ: $e';
        _isProcessing = false;
      });
    }
  }

  void _processVoice(String text) async {
    setState(() {
      _isProcessing = true;
      _result = 'جاري المعالجة...';
    });
    try {
      final response = await _apiService.processCommand(text, _user['pid']);
      debugPrint('BACKEND RESPONSE: ${jsonEncode(response)}');
      
      // Update result message
      if (response['status'] == 'needs_confirmation') {
        setState(() {
          _pendingTransaction = response;
          _result = response['prompt'];
        });
      } else if (response['status'] == 'success') {
        setState(() => _result = response['message']);
        _fetchData();
      } else {
        setState(() => _result = response['message'] ?? response['reason'] ?? 'خطأ غير معروف');
      }

      // Play voice response if provided by backend
      if (response['voice_response'] != null) {
        await _playTTS(response['voice_response']);
      }
    } catch (e) { 
      setState(() {
        _result = 'خطأ: $e';
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _normalizeArabic(String text) {
    return text
        .replaceAll(RegExp(r'[\u064B-\u065F]'), '') // Remove diacritics
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ة', 'ه')
        .replaceAll('ى', 'ي')
        .trim();
  }

  void _processConfirmation(String voiceText) async {
    setState(() {
      _isProcessing = true;
      _result = 'جاري المعالجة...';
    });
    
    final lowerText = voiceText.toLowerCase().trim();
    if (lowerText.isEmpty) {
      setState(() {
        _result = 'لم أسمع شيئاً. يرجى المحاولة مرة أخرى.';
        _isProcessing = false;
      });
      return;
    }

    final normalizedText = _normalizeArabic(lowerText);
    
    final confirmationWords = [
      'نعم', 'موافق', 'اه', 'ماشي', 'ايوه', 'اكيد', 'اكد', 'طبعا', 'تمام', 'طيب', 
      'صح', 'اوكي', 'بالضبط', 'يلا', 'نفذ', 'حول', 'ادفع', 'اسوي', 'yes', 'ok', 
      'sure', 'confirm', 'yep', 'yeah', 'do it', 'go'
    ];

    final rejectionWords = [
      'لا', 'رفض', 'الغاء', 'بطلت', 'خلص', 'لا لا', 'مش موافق', 'no', 'cancel', 
      'reject', 'stop', 'dont'
    ];

    bool isConfirmed = false;
    for (var word in confirmationWords) {
      if (normalizedText == word || normalizedText.contains(' $word ') || 
          normalizedText.startsWith('$word ') || normalizedText.endsWith(' $word')) {
        isConfirmed = true;
        break;
      }
    }

    // fallback to simple contains if it's a short word
    if (!isConfirmed) {
      isConfirmed = confirmationWords.any((word) => normalizedText.contains(word));
    }

    bool isRejected = rejectionWords.any((word) => normalizedText.contains(word));

    if (isConfirmed && _pendingTransaction != null) {
      setState(() => _result = 'جاري تنفيذ العملية...');
      try {
        final res = await _apiService.confirmAction(
          _pendingTransaction!['action_type'],
          _pendingTransaction!['data'],
          _user['pid']
        );
        setState(() {
          _result = res['message'];
          _pendingTransaction = null;
        });
        
        if (res['voice_response'] != null) {
          await _playTTS(res['voice_response']);
        }
        _fetchData();
      } catch (e) {
        setState(() => _result = 'خطأ في التأكيد: $e');
      }
    } else if (isRejected) {
      setState(() {
        _result = 'تم إلغاء العملية.';
        _pendingTransaction = null;
      });
      await _playTTS('تم إلغاء العملية بناءً على طلبك');
    } else {
      // Default fallback if neither clear yes nor clear no
      setState(() {
        _result = 'لم يتم التعرف على الرد ($normalizedText). يرجى قول نعم أو لا.';
        // Keep _pendingTransaction so we can try again
      });
      await _playTTS('لم أفهم ردك، هل يمكنك قول نعم للتأكيد أو لا للإلغاء؟');
    }
    setState(() => _isProcessing = false);
  }

  void _fetchRecipients() async {
    try {
      final list = await _apiService.getRecipients(_user['pid']);
      setState(() => _recipients = list);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _fetchBills() async {
    try {
      final list = await _apiService.getBills(_user['pid']);
      setState(() => _bills = list);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _refreshBalance() async {
    try {
      final updatedUser = await _apiService.getUserDetails(_user['pid']);
      setState(() => _user = updatedUser);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _saveRecipient({int? id}) async {
    Map res;
    if (id == null) {
      res = await _apiService.addRecipient(_user['pid'], _nicknameController.text, _bankController.text, _refController.text, _phoneController.text);
    } else {
      res = await _apiService.updateRecipient(id, _nicknameController.text, _bankController.text, _refController.text, _phoneController.text);
    }
    
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
    _clearForm();
    Navigator.pop(context);
    _fetchRecipients();
  }

  void _clearForm() {
    _nicknameController.clear(); _bankController.clear(); _refController.clear(); _phoneController.clear();
  }

  void _removeRecipient(int id) async {
    final res = await _apiService.removeRecipient(_user['pid'], id);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message'])));
    _fetchRecipients();
  }

  void _showRecipientDialog({Map? existing}) {
    if (existing != null) {
      _nicknameController.text = existing['nickname'];
      _bankController.text = existing['bank_name'] ?? '';
      _refController.text = existing['reference_number'] ?? '';
      _phoneController.text = existing['phone_number'] ?? '';
    } else {
      _clearForm();
    }

    showDialog(context: context, builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(existing == null ? 'إضافة مستلم' : 'تعديل مستلم'),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: 'الاسم الحركي')),
          TextField(controller: _refController, decoration: const InputDecoration(labelText: 'رقم المرجع')),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف')),
          TextField(controller: _bankController, decoration: const InputDecoration(labelText: 'اسم البنك')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(onPressed: () => _saveRecipient(id: existing?['id']), child: const Text('حفظ')),
        ],
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: DefaultTabController(
        length: 3, child: Scaffold(
          appBar: AppBar(
            title: const Text('VoicePay'), 
            bottom: const TabBar(tabs: [
              Tab(text: 'دفع', icon: Icon(Icons.mic)), 
              Tab(text: 'فواتير', icon: Icon(Icons.receipt_long)),
              Tab(text: 'جهات الاتصال', icon: Icon(Icons.contacts)), 
            ]), 
            actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.logout))]
          ),
          body: TabBarView(children: [
            // VOICE PAY TAB
            Padding(padding: const EdgeInsets.all(20.0), child: Column(children: [
              Card(elevation: 4, child: ListTile(leading: const CircleAvatar(child: Icon(Icons.person)), title: Text(_user['full_name']), subtitle: Text('الرصيد: ${double.parse(_user['balance'].toString()).toStringAsFixed(2)} دينار', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)))),
              const SizedBox(height: 24),
              TextField(
                controller: _commandController, 
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'مثلاً: حول 50 دينار لأبو عمر', 
                  border: OutlineInputBorder(), 
                  prefixIcon: Icon(Icons.keyboard_voice),
                )
              ),
              const SizedBox(height: 24),
              _buildVoiceButton(),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isProcessing 
                    ? null 
                    : () {
                        final text = _commandController.text;
                        if (_pendingTransaction != null) {
                          _processConfirmation(text);
                        } else {
                          _processVoice(text);
                        }
                      },
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)), 
                child: const Text('تنفيذ الأمر')
              ),
              const SizedBox(height: 24), const Text('النتيجة:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Expanded(child: Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(8)), child: SingleChildScrollView(child: Text(_result, style: TextStyle(color: _pendingTransaction != null ? Colors.blue[800] : Colors.black, fontWeight: _pendingTransaction != null ? FontWeight.bold : FontWeight.normal))))),
            ])),
            
            // BILLS TAB
            Padding(padding: const EdgeInsets.all(16.0), child: _bills.isEmpty 
              ? const Center(child: Text('لا توجد فواتير.'))
              : ListView.builder(itemCount: _bills.length, itemBuilder: (context, i) {
                  final b = _bills[i];
                  final isPaid = b['status'] == 'Paid';
                  return Card(child: ListTile(
                    leading: Icon(Icons.receipt, color: isPaid ? Colors.green : Colors.orange),
                    title: Text(b['name']),
                    subtitle: Text('تاريخ الاستحقاق: ${b['due_date']} - ${b['serves']}'),
                    trailing: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Text('${double.parse(b['cost'].toString()).toStringAsFixed(2)} دينار', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(color: isPaid ? Colors.green.withOpacity(0.1) : Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Text(isPaid ? 'مدفوعة' : 'غير مدفوعة', style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 12, fontWeight: FontWeight.bold)),
                      )
                    ]),
                  ));
                })
            ),

            // RECIPIENTS TAB
            Padding(padding: const EdgeInsets.all(16.0), child: Column(children: [
              ElevatedButton.icon(onPressed: () => _showRecipientDialog(), icon: const Icon(Icons.person_add), label: const Text('إضافة مستلم')),
              const SizedBox(height: 16),
              Expanded(child: ListView.builder(itemCount: _recipients.length, itemBuilder: (context, i) {
                final r = _recipients[i];
                return Card(child: ListTile(
                  title: Text(r['nickname']),
                  subtitle: Text('${r['bank_name'] ?? 'بدون بنك'} - ${r['reference_number']}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showRecipientDialog(existing: r)),
                    IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeRecipient(r['id'])),
                  ]),
                ));
              }))
            ]))
          ]),
        ),
      ),
    );
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: (_isProcessing || _isSpeaking) ? null : _toggleRecording,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              Color buttonColor = Colors.blue;
              IconData buttonIcon = Icons.mic;

              if (_isRecording) {
                buttonColor = Colors.red;
                buttonIcon = Icons.stop;
              } else if (_isProcessing) {
                buttonColor = Colors.grey;
                buttonIcon = Icons.hourglass_empty;
              } else if (_isSpeaking) {
                buttonColor = Colors.green;
                buttonIcon = Icons.volume_up;
              } else if (_pendingTransaction != null) {
                buttonColor = Colors.orange;
                buttonIcon = Icons.help_outline;
              }

              return Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: buttonColor,
                  boxShadow: [
                    if (_isRecording || _isSpeaking)
                      BoxShadow(
                        color: buttonColor.withOpacity(0.4),
                        blurRadius: 15 + _pulseController.value * 20,
                        spreadRadius: _pulseController.value * 12,
                      )
                    else
                      const BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        spreadRadius: 2,
                      )
                  ],
                ),
                child: _isProcessing 
                    ? const Padding(
                        padding: EdgeInsets.all(25.0),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 4,
                        ),
                      )
                    : Icon(
                        buttonIcon,
                        color: Colors.white,
                        size: 50,
                      ),
              );
            },
          ),
          const SizedBox(height: 16),
          _buildStatusText(),
        ],
      ),
    );
  }

  Widget _buildStatusText() {
    String text = 'اضغط للتحدث';
    Color color = Colors.blue;

    if (_isRecording) { text = 'أنا أسمعك الآن...'; color = Colors.red; }
    else if (_isProcessing) { text = 'جاري معالجة طلبك...'; color = Colors.grey; }
    else if (_isSpeaking) { text = 'جاري التحدث...'; color = Colors.green; }
    else if (_pendingTransaction != null) { text = 'هل أنت متأكد؟ قل نعم أو لا'; color = Colors.orange; }

    return Text(
      text,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 16,
      ),
    );
  }
}
