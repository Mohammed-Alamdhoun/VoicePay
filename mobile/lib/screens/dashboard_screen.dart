import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io' show File;
import '../services/api_service.dart';
import '../services/ui_utils.dart';

class DashboardScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const DashboardScreen({super.key, this.userData});

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
  AnimationController? _pulseController;
  
  String _result = '';
  bool _isError = false;
  bool _isCriticalError = false;
  bool _isProcessing = false;
  bool _isRecording = false;
  bool _isSpeaking = false;
  List<dynamic> _recipients = [];
  List<dynamic> _bills = [];
  late Map<String, dynamic> _user;
  int _tabIndex = 0;

  Map<String, dynamic>? _pendingTransaction;
  Timer? _recordingTimer;
  StreamSubscription<Amplitude>? _amplitudeSubscription;

  @override
  void initState() { 
    super.initState(); 
    _user = widget.userData ?? {};
    
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _recorder.onStateChanged().listen((state) {
      if (state == RecordState.stop && _isRecording && mounted) {
        setState(() => _isRecording = false);
        _pulseController?.stop();
        _pulseController?.reset();
        _recordingTimer?.cancel();
      }
    });

    _audioPlayer.onPlayerComplete.listen((event) {
      if (mounted) {
        setState(() => _isSpeaking = false);
        if (_pendingTransaction != null) {
          _toggleRecording();
        }
      }
    });

    if (_user.isNotEmpty) {
      _fetchData();
    }
  }

  bool _initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized && _user.isEmpty) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map<String, dynamic>) {
        setState(() {
          _user = Map.from(args);
          _fetchData();
        });
      }
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    _audioPlayer.dispose();
    _pulseController?.dispose();
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _commandController.dispose();
    _nicknameController.dispose();
    _bankController.dispose();
    _refController.dispose();
    _phoneController.dispose();
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
    HapticFeedback.mediumImpact();
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
      const config = kIsWeb ? RecordConfig(encoder: AudioEncoder.opus) : RecordConfig();
      await _recorder.start(config, path: path ?? '');
      _pulseController?.repeat(reverse: true);
      setState(() {
        _isRecording = true;
        _isError = false;
      });
      _recordingTimer = Timer(const Duration(seconds: 6), () {
        if (_isRecording) _stopRecording();
      });
      int silenceCount = 0;
      const silenceThreshold = -40.0;
      const silenceDuration = 1500;
      const checkInterval = 200;
      _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: checkInterval)).listen((amp) {
        if (amp.current < silenceThreshold) silenceCount += checkInterval;
        else silenceCount = 0;
        if (silenceCount >= silenceDuration && _isRecording) _stopRecording();
      });
    }
  }

  void _stopRecording() async {
    _recordingTimer?.cancel();
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    final path = await _recorder.stop();
    _pulseController?.stop();
    _pulseController?.reset();
    setState(() => _isRecording = false);
    if (path != null) _handleVoiceInput(path);
  }

  void _handleVoiceInput(String path) async {
    try {
      final text = await _apiService.voiceToText(path);
      _commandController.text = text;
      if (_pendingTransaction != null) _processConfirmation(text);
      else _processVoice(text);
    } catch (e) {
      setState(() { 
        _result = '$e'.replaceAll('Exception: ', ''); 
        _isError = true;
        _isProcessing = false; 
      });
    }
  }

  void _processVoice(String text) async {
    setState(() { 
      _isProcessing = true; 
      _result = 'جاري المعالجة...'; 
      _isError = false;
      _isCriticalError = false;
    });
    try {
      final response = await _apiService.processCommand(text, _user['pid']);
      if (response['status'] == 'needs_confirmation') {
        setState(() { _pendingTransaction = response; _result = response['prompt']; });
      } else if (response['status'] == 'success') {
        setState(() => _result = response['message']);
        _fetchData();
      } else {
        setState(() {
          _result = response['message'] ?? response['reason'] ?? 'خطأ غير معروف';
          _isError = true;
        });
      }
      if (response['voice_response'] != null) await _playTTS(response['voice_response']);
    } catch (e) { 
      setState(() { 
        _result = '$e'.replaceAll('Exception: ', ''); 
        _isError = true;
      });
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  String _normalizeArabic(String text) {
    return text.replaceAll(RegExp(r'[\u064B-\u065F]'), '').replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا').replaceAll('ة', 'ه').replaceAll('ى', 'ي').trim();
  }

  void _processConfirmation(String voiceText) async {
    setState(() { 
      _isProcessing = true; 
      _result = 'جاري المعالجة...'; 
      _isError = false;
    });
    final lowerText = voiceText.toLowerCase().trim();
    if (lowerText.isEmpty) {
      setState(() { 
        _result = 'لم أسمع شيئاً. يرجى المحاولة مرة أخرى.'; 
        _isError = true;
        _isProcessing = false; 
      });
      return;
    }
    final normalizedText = _normalizeArabic(lowerText);
    final confirmationWords = ['نعم', 'موافق', 'اه', 'ماشي', 'ايوه', 'اكيد', 'اكد', 'طبعا', 'تمام', 'طيب', 'صح', 'اوكي', 'بالضبط', 'يلا', 'نفذ', 'حول', 'ادفع', 'اسوي', 'yes', 'ok', 'sure', 'confirm', 'yep', 'yeah', 'do it', 'go'];
    final rejectionWords = ['لا', 'رفض', 'الغاء', 'بطلت', 'خلص', 'لا لا', 'مش موافق', 'no', 'cancel', 'reject', 'stop', 'dont'];
    bool isConfirmed = false;
    for (var word in confirmationWords) {
      if (normalizedText == word || normalizedText.contains(' $word ') || normalizedText.startsWith('$word ') || normalizedText.endsWith(' $word')) {
        isConfirmed = true; break;
      }
    }
    if (!isConfirmed) isConfirmed = confirmationWords.any((word) => normalizedText.contains(word));
    bool isRejected = rejectionWords.any((word) => normalizedText.contains(word));
    if (isConfirmed && _pendingTransaction != null) {
      setState(() => _result = 'جاري تنفيذ العملية...');
      try {
        final res = await _apiService.confirmAction(_pendingTransaction!['action_type'], _pendingTransaction!['data'], _user['pid']);
        if (res['status'] == 'failed') {
          setState(() {
            _result = res['message'] ?? 'بصمة الصوت غير متطابقة';
            _isError = true;
            _isCriticalError = true;
          });
        } else {
          setState(() { _result = res['message']; _pendingTransaction = null; });
          if (res['voice_response'] != null) await _playTTS(res['voice_response']);
          _fetchData();
        }
      } catch (e) { 
        setState(() {
          _result = 'خطأ في التأكيد: $e'.replaceAll('Exception: ', '');
          _isError = true;
        }); 
      }
    } else if (isRejected) {
      setState(() { _result = 'تم إلغاء العملية.'; _pendingTransaction = null; });
      await _playTTS('تم إلغاء العملية بناءً على طلبك');
    } else {
      setState(() { 
        _result = 'لم يتم التعرف على الرد ($normalizedText). يرجى قول نعم أو لا.'; 
        _isError = true;
      });
      await _playTTS('لم أفهم ردك، هل يمكنك قول نعم للتأكيد أو لا للإلغاء؟');
    }
    setState(() => _isProcessing = false);
  }

  void _fetchRecipients() async {
    if (_user.isEmpty) return;
    try {
      final list = await _apiService.getRecipients(_user['pid']);
      setState(() => _recipients = list);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _fetchBills() async {
    if (_user.isEmpty) return;
    try {
      final list = await _apiService.getBills(_user['pid']);
      setState(() => _bills = list);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _refreshBalance() async {
    if (_user.isEmpty) return;
    try {
      final updatedUser = await _apiService.getUserDetails(_user['pid']);
      setState(() => _user = updatedUser);
    } catch (e) { debugPrint(e.toString()); }
  }

  void _saveRecipient({int? id}) async {
    try {
      Map res;
      if (id == null) {
        res = await _apiService.addRecipient(_user['pid'], _nicknameController.text, _bankController.text, _refController.text, _phoneController.text);
      } else {
        res = await _apiService.updateRecipient(id, _nicknameController.text, _bankController.text, _refController.text, _phoneController.text);
      }
      if (!mounted) return;
      
      if (res['status'] == 'success') {
        VoicePayUI.showSuccessSnackBar(context, res['message']);
        _clearForm();
        Navigator.pop(context);
        _fetchRecipients();
      } else {
        VoicePayUI.showErrorSnackBar(context, res['message']);
      }
    } catch (e) {
      if (!mounted) return;
      VoicePayUI.showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _clearForm() { _nicknameController.clear(); _bankController.clear(); _refController.clear(); _phoneController.clear(); }

  void _removeRecipient(int id) async {
    try {
      final res = await _apiService.removeRecipient(_user['pid'], id);
      if (!mounted) return;
      VoicePayUI.showSuccessSnackBar(context, res['message']);
      _fetchRecipients();
    } catch (e) {
      if (!mounted) return;
      VoicePayUI.showErrorSnackBar(context, e.toString().replaceAll('Exception: ', ''));
    }
  }

  void _showRecipientDialog({Map? existing}) {
    if (existing != null) {
      _nicknameController.text = existing['nickname'];
      _bankController.text = existing['bank_name'] ?? '';
      _refController.text = existing['reference_number'] ?? '';
      _phoneController.text = existing['phone_number'] ?? '';
    } else _clearForm();
    showDialog(context: context, builder: (context) => Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(existing == null ? 'إضافة مستلم' : 'تعديل مستلم', style: const TextStyle(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: _nicknameController, decoration: const InputDecoration(labelText: 'الاسم الحركي', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'رقم الهاتف', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _bankController, decoration: const InputDecoration(labelText: 'اسم البنك', border: OutlineInputBorder())),
          const SizedBox(height: 12),
          TextField(controller: _refController, decoration: const InputDecoration(labelText: 'رقم المرجع (Ref Number)', border: OutlineInputBorder())),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => _saveRecipient(id: existing?['id']), 
            style: ElevatedButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('حفظ'),
          ),
        ],
      ),
    ));
  }

  void _updateRef() async {
    setState(() => _isProcessing = true);
    try {
      final res = await _apiService.updateReferenceNumber(_user['pid']);
      setState(() {
        _user['reference_number'] = res['reference_number'];
        _result = res['message'];
      });
      VoicePayUI.showSuccessSnackBar(context, res['message']);
    } catch (e) {
      VoicePayUI.showErrorSnackBar(context, e.toString());
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  IconData _getBillIcon(String name) {
    final n = name.toLowerCase();
    if (n.contains('كهرباء')) return Icons.electric_bolt;
    if (n.contains('مياه')) return Icons.water_drop;
    if (n.contains('إنترنت') || n.contains('نت')) return Icons.wifi;
    if (n.contains('هاتف') || n.contains('خلوي')) return Icons.phone_android;
    if (n.contains('جامعة')) return Icons.school;
    if (n.contains('غاز')) return Icons.gas_meter;
    if (n.contains('سيارة') || n.contains('قسط')) return Icons.directions_car;
    return Icons.receipt_long;
  }

  Color _getBillColor(String name) {
    final n = name.toLowerCase();
    if (n.contains('كهرباء')) return Colors.amber;
    if (n.contains('مياه')) return Colors.blue;
    if (n.contains('إنترنت') || n.contains('نت')) return Colors.purple;
    if (n.contains('هاتف') || n.contains('خلوي')) return Colors.orange;
    if (n.contains('جامعة')) return Colors.indigo;
    if (n.contains('غاز')) return Colors.deepOrange;
    if (n.contains('سيارة') || n.contains('قسط')) return Colors.blueGrey;
    return Colors.grey;
  }

  Widget _buildPulseRing(double scale, double opacity) {
    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        Color color = _isRecording ? Colors.red : Colors.green;
        return Transform.scale(
          scale: 1.0 + (_pulseController!.value * scale),
          child: Container(
            width: 100, height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(opacity * (1 - _pulseController!.value)),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_user.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final List<Widget> pages = [_buildVoicePayTab(), _buildBillsTab(), _buildRecipientsTab()];
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(title: const Text('VoicePay', style: TextStyle(fontWeight: FontWeight.bold)), actions: [IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.logout))], elevation: 2),
        body: IndexedStack(index: _tabIndex, children: pages),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tabIndex,
          onDestinationSelected: (index) => setState(() => _tabIndex = index),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.mic_none), selectedIcon: Icon(Icons.mic), label: 'دفع صوتي'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined), selectedIcon: Icon(Icons.receipt_long), label: 'فواتير'),
            NavigationDestination(icon: Icon(Icons.contacts_outlined), selectedIcon: Icon(Icons.contacts), label: 'جهات الاتصال'),
          ],
        ),
      ),
    );
  }

  Widget _buildVoicePayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0), 
      child: Column(children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('الرصيد المتوفر', style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 8),
              Text(
                '${double.parse((_user['balance'] ?? 0).toString()).toStringAsFixed(2)} د.أ',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_user['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 16)),
                  const Icon(Icons.account_balance_wallet, color: Colors.white54),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        const Text('بماذا يمكنني مساعدتك؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildVoiceButton(),
        const SizedBox(height: 32),
        if (_result.isNotEmpty) 
          _isCriticalError
            ? VoicePayUI.buildCriticalErrorBubble(
                _result, 
                onRetry: () => setState(() { _isCriticalError = false; _isError = false; _result = 'يرجى المحاولة مرة أخرى'; })
              )
            : _isError 
              ? VoicePayUI.buildErrorBubble(_result)
              : VoicePayUI.buildAssistantBubble(
                  _result, 
                  _pendingTransaction != null,
                  onConfirm: () => _processConfirmation('نعم'),
                  onCancel: () => setState(() { _pendingTransaction = null; _result = 'تم إلغاء العملية.'; }),
                ),
        const SizedBox(height: 48),
        ExpansionTile(
          title: const Text('إدخال نصي يدوياً', style: TextStyle(fontSize: 14)),
          children: [
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), child: Column(children: [
              TextField(controller: _commandController, decoration: const InputDecoration(hintText: 'مثلاً: حول 50 دينار لزيد', border: OutlineInputBorder())),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _isProcessing ? null : () { final text = _commandController.text; if (_pendingTransaction != null) _processConfirmation(text); else _processVoice(text); }, child: const Text('تنفيذ'))),
            ])),
          ],
        ),
      ]),
    );
  }

  Widget _buildBillsTab() {
    if (_bills.isEmpty) return const Center(child: Text('لا توجد فواتير.'));
    return ListView.builder(
      padding: const EdgeInsets.all(16), 
      itemCount: _bills.length, 
      itemBuilder: (context, index) {
        final b = _bills[index]; 
        final isPaid = b['status'] == 'Paid';
        final color = _getBillColor(b['name']);
        
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(_getBillIcon(b['name']), color: color),
            ),
            title: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('${b['serves']}\nتاريخ الاستحقاق: ${b['due_date']}'),
            isThreeLine: true,
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${double.parse(b['cost'].toString()).toStringAsFixed(2)} د.أ', 
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? 'مدفوعة' : 'غير مدفوعة', 
                    style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildRecipientsTab() {
    return Column(children: [
      Padding(padding: const EdgeInsets.all(16.0), child: ElevatedButton.icon(onPressed: () => _showRecipientDialog(), icon: const Icon(Icons.person_add), label: const Text('إضافة مستلم'), style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)))),
      Expanded(child: ListView.builder(padding: const EdgeInsets.symmetric(horizontal: 16), itemCount: _recipients.length, itemBuilder: (context, index) {
        final r = _recipients[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12), 
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person_outline)), 
            title: Text(r['nickname'], style: const TextStyle(fontWeight: FontWeight.bold)), 
            subtitle: Text('${r['bank_name'] ?? 'بدون بنك'}\n${r['reference_number'] ?? ''}'), 
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min, 
              children: [
                IconButton(icon: const Icon(Icons.edit, color: Colors.blue), onPressed: () => _showRecipientDialog(existing: r)), 
                IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _removeRecipient(r['id']))
              ]
            )
          )
        );
      })),
    ]);
  }

  Widget _buildVoiceButton() {
    return GestureDetector(
      onTap: (_isProcessing || _isSpeaking) ? null : _toggleRecording,
      behavior: HitTestBehavior.opaque,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Stack(
          alignment: Alignment.center,
          children: [
            if (_isRecording || _isSpeaking) ...[
              _buildPulseRing(1.2, 0.2),
              _buildPulseRing(1.5, 0.1),
            ],
            AnimatedBuilder(animation: _pulseController!, builder: (context, child) {
              Color buttonColor = Colors.blue; IconData buttonIcon = Icons.mic;
              if (_isRecording) { buttonColor = Colors.red; buttonIcon = Icons.stop; }
              else if (_isProcessing) { buttonColor = Colors.grey; buttonIcon = Icons.hourglass_empty; }
              else if (_isSpeaking) { buttonColor = Colors.green; buttonIcon = Icons.volume_up; }
              else if (_pendingTransaction != null) { buttonColor = Colors.orange; buttonIcon = Icons.help_outline; }
              return Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: buttonColor, boxShadow: [if (_isRecording || _isSpeaking) BoxShadow(color: buttonColor.withOpacity(0.4), blurRadius: 15 + _pulseController!.value * 20, spreadRadius: _pulseController!.value * 12) else const BoxShadow(color: Colors.black12, blurRadius: 6, spreadRadius: 2)]), child: _isProcessing ? const Padding(padding: EdgeInsets.all(25.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 4)) : Icon(buttonIcon, color: Colors.white, size: 50));
            }),
          ],
        ),
        const SizedBox(height: 16),
        _buildStatusText(),
      ]),
    );
  }

  Widget _buildStatusText() {
    String text = 'اضغط للتحدث'; Color color = Colors.blue;
    if (_isRecording) { text = 'أنا أسمعك الآن...'; color = Colors.red; }
    else if (_isProcessing) { text = 'جاري معالجة طلبك...'; color = Colors.grey; }
    else if (_isSpeaking) { text = 'جاري التحدث...'; color = Colors.green; }
    else if (_pendingTransaction != null) { text = 'هل أنت متأكد؟ قل نعم أو لا'; color = Colors.orange; }
    return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16));
  }
}
