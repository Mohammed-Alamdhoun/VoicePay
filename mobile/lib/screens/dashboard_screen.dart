import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/api_service.dart';
import '../services/ui_utils.dart';
import '../core/app_colors.dart';

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
      if (args is Map) {
        setState(() {
          _user = Map<String, dynamic>.from(args);
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
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        title: Text(existing == null ? 'إضافة مستلم' : 'تعديل مستلم', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDark)),
        content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
          _buildDialogField(_nicknameController, 'الاسم الحركي', Icons.person_outline),
          const SizedBox(height: 16),
          _buildDialogField(_phoneController, 'رقم الهاتف', Icons.phone_android_outlined),
          const SizedBox(height: 16),
          _buildDialogField(_bankController, 'اسم البنك', Icons.account_balance_outlined),
          const SizedBox(height: 16),
          _buildDialogField(_refController, 'رقم المرجع (Ref Number)', Icons.tag),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text('إلغاء', style: TextStyle(color: AppColors.textDark.withOpacity(0.7)))),
          ElevatedButton(
            onPressed: () => _saveRecipient(id: existing?['id']), 
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text('حفظ', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ));
  }

  Widget _buildDialogField(TextEditingController controller, String label, IconData icon) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: AppColors.textDark),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: AppColors.textDark.withOpacity(0.6)),
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        prefixIcon: Icon(icon, color: AppColors.secondary),
        filled: true,
        fillColor: Colors.black.withOpacity(0.04),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
      ),
    );
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
        Color color = _isRecording ? Colors.redAccent : const Color(0xFF4ADE80);
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
    if (_user.isEmpty) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Color(0xFFFFB26B))));
    final List<Widget> pages = [_buildVoicePayTab(), _buildBillsTab(), _buildRecipientsTab()];
    
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F1EA),
        extendBody: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: const Text('VoicePay', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 24)),
          centerTitle: false,
          actions: [
            IconButton(
              onPressed: () => Navigator.pop(context), 
              icon: const Icon(Icons.logout_rounded, color: Colors.black)
            )
          ],
        ),
        body: Stack(
          children: [
            // 🔥 Background Glows
            Positioned(top: -170, left: -120, child: _buildGlow(360, const Color(0xFFFFD6AE))),
            Positioned(bottom: -220, right: -140, child: _buildGlow(420, const Color(0xFFD7EEF7))),
            
            Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: IndexedStack(index: _tabIndex, children: pages),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }

  Widget _buildGlow(double size, Color color) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.7)),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      margin: const EdgeInsets.all(20),
      height: 70,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, spreadRadius: 1),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.mic_none_rounded, Icons.mic_rounded, 'دفع صوتي', 0),
          _buildNavItem(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'فواتير', 1),
          _buildNavItem(Icons.people_outline_rounded, Icons.people_rounded, 'جهات الاتصال', 2),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, IconData activeIcon, String label, int index) {
    bool isSelected = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(isSelected ? activeIcon : icon, color: isSelected ? const Color(0xFFFFB26B) : Colors.black54, size: 28),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(fontSize: 10, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFFFFB26B) : Colors.black54)),
        ],
      ),
    );
  }

  Widget _buildVoicePayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0), 
      child: Column(children: [
        // 🔥 Glassmorphic Balance Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(34),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF2A140A), Color(0xFF5A463A)],
            ),
            boxShadow: [
              BoxShadow(color: const Color(0xFF2A140A).withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('الرصيد المتوفر', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFFFB26B), size: 20),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '${double.parse((_user['balance'] ?? 0).toString()).toStringAsFixed(2)} د.أ',
                style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
              ).animate().fade().slideY(begin: 0.1),
              const SizedBox(height: 20),
              const Divider(color: Colors.white24, height: 1),
              const SizedBox(height: 16),
              Text(_user['full_name'] ?? '', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500)),
              Text(_user['reference_number'] ?? '', style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12)),
            ],
          ),
        ),
        
        const SizedBox(height: 40),
        
        const Text('بماذا يمكنني مساعدتك؟', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black)),
        const SizedBox(height: 8),
        const Text('تحدث لتنفيذ المعاملات بسرعة', style: TextStyle(fontSize: 14, color: Colors.black87)),
        
        const SizedBox(height: 40),
        
        _buildVoiceButton(),
        
        const SizedBox(height: 40),
        
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
        
        // Manual Input Section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFB26B).withOpacity(0.2)),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Icon(Icons.keyboard_outlined, color: Color(0xFFFFB26B), size: 18),
                  SizedBox(width: 8),
                  Text('إدخال نصي يدوياً', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.black)),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _commandController, 
                style: const TextStyle(color: Colors.black),
                decoration: InputDecoration(
                  hintText: 'مثلاً: حول 50 دينار لزيد',
                  hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                  filled: true,
                  fillColor: Colors.grey.withOpacity(0.05),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide.none),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Color(0xFFFFB26B)),
                    onPressed: _isProcessing ? null : () { 
                      final text = _commandController.text; 
                      if (_pendingTransaction != null) _processConfirmation(text); 
                      else _processVoice(text); 
                    },
                  ),
                )
              ),
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildBillsTab() {
    if (_bills.isEmpty) return const Center(child: Text('لا توجد فواتير.'));
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), 
      itemCount: _bills.length, 
      itemBuilder: (context, index) {
        final b = _bills[index]; 
        final isPaid = b['status'] == 'Paid';
        final color = _getBillColor(b['name']);
        
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFFFB26B).withOpacity(0.1)),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(_getBillIcon(b['name']), color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black)),
                    Text(b['serves'], style: const TextStyle(fontSize: 12, color: Colors.black54)),
                    const SizedBox(height: 4),
                    Text('تاريخ الاستحقاق: ${b['due_date']}', style: const TextStyle(fontSize: 11, color: Colors.black45)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${double.parse(b['cost'].toString()).toStringAsFixed(2)}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black)
                  ),
                  const Text('د.أ', style: TextStyle(fontSize: 10, color: Colors.black54)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: (isPaid ? Colors.green : Colors.orange).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isPaid ? 'مدفوعة' : 'مستحقة', 
                      style: TextStyle(color: isPaid ? Colors.green : Colors.orange, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                  ),
                ],
              ),
            ],
          ),
        ).animate().fade(delay: (index * 100).ms).slideX(begin: 0.1);
      }
    );
  }

  Widget _buildRecipientsTab() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(24.0), 
        child: SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: () => _showRecipientDialog(), 
            icon: const Icon(Icons.person_add_rounded, color: Colors.white), 
            label: const Text('إضافة مستلم جديد', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              elevation: 4,
            ),
          ),
        ),
      ),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24), 
        itemCount: _recipients.length, 
        itemBuilder: (context, index) {
          final r = _recipients[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.primary.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 25,
                  backgroundColor: AppColors.secondary.withOpacity(0.15), 
                  child: const Icon(Icons.person_rounded, color: AppColors.secondary, size: 30)
                ), 
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r['nickname'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDark)), 
                      Text(r['bank_name'] ?? 'بدون بنك', style: TextStyle(fontSize: 12, color: AppColors.textDark.withOpacity(0.6))), 
                      Text(r['reference_number'] ?? '', style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)), 
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, color: AppColors.secondary), 
                  onPressed: () => _showRecipientDialog(existing: r)
                ), 
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent), 
                  onPressed: () => _removeRecipient(r['id'])
                ),
              ],
            ),
          ).animate().fade(delay: (index * 100).ms).slideY(begin: 0.1);
        }
      )),
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
              Color buttonColor = const Color(0xFFFFB26B); 
              IconData buttonIcon = Icons.mic_rounded;
              
              if (_isRecording) { buttonColor = Colors.redAccent; buttonIcon = Icons.stop_rounded; }
              else if (_isProcessing) { buttonColor = Colors.grey; buttonIcon = Icons.hourglass_empty_rounded; }
              else if (_isSpeaking) { buttonColor = const Color(0xFF4ADE80); buttonIcon = Icons.volume_up_rounded; }
              else if (_pendingTransaction != null) { buttonColor = const Color(0xFF8EDBFF); buttonIcon = Icons.help_outline_rounded; }
              
              return Container(
                width: 100, height: 100, 
                decoration: BoxDecoration(
                  shape: BoxShape.circle, 
                  gradient: !_isRecording && !_isSpeaking && !_isProcessing ? const LinearGradient(colors: [Color(0xFFFFB26B), Color(0xFFFFD6AE)]) : null,
                  color: (_isRecording || _isSpeaking || _isProcessing) ? buttonColor : null,
                  boxShadow: [
                    BoxShadow(
                      color: buttonColor.withOpacity(0.35), 
                      blurRadius: 30 + (_isRecording || _isSpeaking ? _pulseController!.value * 20 : 0), 
                      spreadRadius: 2 + (_isRecording || _isSpeaking ? _pulseController!.value * 10 : 0)
                    ) 
                  ]
                ), 
                child: _isProcessing 
                  ? const Padding(padding: EdgeInsets.all(28.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)) 
                  : Icon(buttonIcon, color: Colors.white, size: 50)
              );
            }),
          ],
        ),
        const SizedBox(height: 20),
        _buildStatusText(),
      ]),
    );
  }

  Widget _buildStatusText() {
    String text = 'اضغط للتحدث'; Color color = const Color(0xFFFFB26B);
    if (_isRecording) { text = 'أنا أسمعك الآن...'; color = Colors.redAccent; }
    else if (_isProcessing) { text = 'جاري المعالجة...'; color = Colors.grey; }
    else if (_isSpeaking) { text = 'جاري التحدث...'; color = const Color(0xFF4ADE80); }
    else if (_pendingTransaction != null) { text = 'هل أنت متأكد؟ قل نعم أو لا'; color = const Color(0xFF8EDBFF); }
    return Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16));
  }
}
