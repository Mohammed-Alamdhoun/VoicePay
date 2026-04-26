import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

enum RequestState {
  idle,
  recording,
  uploading,
}

class RequestScreen extends StatefulWidget {
  static const String routeName = '/request';

  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() =>
      _RequestScreenState();
}

class _RequestScreenState
    extends State<RequestScreen> {

  final AudioRecorder _audioRecorder =
      AudioRecorder();

  RequestState currentState =
      RequestState.idle;

  String statusMessage = '';
  String? recordedAudioPath;
  String? errorMessage;

  Timer? recordTimer;
  String currentUserId = '';

  // ================= SMART REJECTION =================

  String getSmartMessage(String? reason) {

    switch (reason) {

      case 'NO_INTENT_DETECTED':
        return 'لم يتم فهم طلبك، حاول التحدث بوضوح';

      case 'LOW_AUDIO_QUALITY':
        return 'الصوت غير واضح، حاول في مكان هادئ';

      case 'EMPTY_SPEECH':
        return 'لم يتم اكتشاف أي كلام';

      case 'UNSUPPORTED_REQUEST':
        return 'هذا الطلب غير مدعوم حالياً';

      default:
        return 'حدث خطأ أثناء معالجة الطلب';
    }
  }

  @override
  Widget build(BuildContext context) {

    currentUserId =
        (ModalRoute.of(context)
        ?.settings
        .arguments as String?) ??
            '';

    return Scaffold(
      backgroundColor:
      const Color(0xFF1B120B),

      body: Stack(
        children: [

          // 🔥 orange glow
          Positioned(
            top: -140,
            left: -90,

            child: Container(
              width: 320,
              height: 320,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color:
                const Color(0xFFFFB26B)
                    .withOpacity(0.28),
              ),
            ),
          ),

          // 🔥 blue glow
          Positioned(
            bottom: -150,
            right: -100,

            child: Container(
              width: 340,
              height: 340,

              decoration: BoxDecoration(
                shape: BoxShape.circle,

                color:
                const Color(0xFF8EDBFF)
                    .withOpacity(0.20),
              ),
            ),
          ),

          SafeArea(
            child: Padding(
              padding:
              const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 18,
              ),

              child: Column(
                children: [

                  // 🔥 top bar
                  Row(
                    mainAxisAlignment:
                    MainAxisAlignment
                        .spaceBetween,

                    children: [

                      Column(
                        crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                        children: [

                          const Text(
                            'VoicePay AI',

                            style: TextStyle(
                              color: Colors.white,

                              fontSize: 30,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 4),

                          Text(
                            'Secure Banking Assistant',

                            style: TextStyle(
                              color: Colors.white
                                  .withOpacity(0.60),

                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),

                      TextButton.icon(
                        onPressed: () {

                          Navigator
                              .pushNamedAndRemoveUntil(
                            context,
                            LoginScreen.routeName,
                                (route) => false,
                          );
                        },

                        icon: const Icon(
                          Icons.logout_rounded,
                          color: Colors.redAccent,
                        ),

                        label: const Text(
                          'Logout',

                          style: TextStyle(
                            color:
                            Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 34),

                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints:
                        const BoxConstraints(
                          maxWidth: 560,
                        ),

                        child: Column(
                          mainAxisAlignment:
                          MainAxisAlignment
                              .center,

                          children: [

                            // 🔥 AI orb
                            Container(
                              width: 135,
                              height: 135,

                              decoration:
                              BoxDecoration(
                                shape:
                                BoxShape.circle,

                                gradient:
                                const LinearGradient(
                                  colors: [
                                    Color(
                                        0xFFFFB26B),
                                    Color(
                                        0xFF8EDBFF),
                                  ],
                                ),

                                boxShadow: [

                                  BoxShadow(
                                    color:
                                    const Color(
                                        0xFFFFB26B)
                                        .withOpacity(
                                        0.45),

                                    blurRadius: 50,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),

                              child: const Icon(
                                Icons
                                    .graphic_eq_rounded,

                                color: Colors.white,
                                size: 62,
                              ),
                            ),

                            const SizedBox(height: 30),

                            // 🔥 title
                            const Text(
                              'AI Banking Assistant',

                              style: TextStyle(
                                fontSize: 32,

                                fontWeight:
                                FontWeight.bold,

                                color: Colors.white,

                                letterSpacing: 1,
                              ),
                            ),

                            const SizedBox(height: 12),

                            Text(
                              'Voice identity verified successfully',

                              textAlign:
                              TextAlign.center,

                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.72),

                                fontSize: 15,
                              ),
                            ),

                            const SizedBox(height: 14),

                            Text(
                              'Welcome, $currentUserId',

                              style: TextStyle(
                                color: Colors.white
                                    .withOpacity(0.5),

                                fontSize: 14,
                              ),
                            ),

                            const SizedBox(height: 38),

                            // 🔥 assistant card
                            Container(
                              width: double.infinity,

                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 26,
                                vertical: 30,
                              ),

                              decoration:
                              BoxDecoration(
                                borderRadius:
                                BorderRadius
                                    .circular(32),

                                color:
                                const Color(
                                    0xFF24160D)
                                    .withOpacity(
                                    0.88),

                                border: Border.all(
                                  color: Colors
                                      .white
                                      .withOpacity(
                                      0.08),
                                ),

                                boxShadow: [

                                  BoxShadow(
                                    color:
                                    const Color(
                                        0xFFFFB26B)
                                        .withOpacity(
                                        0.18),

                                    blurRadius: 40,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),

                              child: Column(
                                children: [

                                  const Row(
                                    children: [

                                      Icon(
                                        Icons
                                            .security_rounded,

                                        color:
                                        Color(
                                            0xFFFFB26B),
                                      ),

                                      SizedBox(width: 10),

                                      Text(
                                        'Smart Banking Request',

                                        style: TextStyle(
                                          color:
                                          Colors
                                              .white,

                                          fontSize:
                                          16,

                                          fontWeight:
                                          FontWeight
                                              .bold,
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(
                                      height: 24),

                                  Text(
                                    'اضغط على الزر واذكر طلبك البنكي بوضوح\n'
                                        'مثل: تحويل 20 دينار إلى أحمد',

                                    textAlign:
                                    TextAlign.center,

                                    style: TextStyle(
                                      color: Colors
                                          .white
                                          .withOpacity(
                                          0.75),

                                      fontSize: 15,

                                      height: 1.8,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 30),

                            // 🔥 status
                            if (statusMessage
                                .isNotEmpty)

                              Text(
                                statusMessage,

                                textAlign:
                                TextAlign.center,

                                style: TextStyle(
                                  fontSize: 15,

                                  fontWeight:
                                  FontWeight
                                      .w600,

                                  color:
                                  currentState ==
                                      RequestState
                                          .recording

                                      ? const Color(
                                      0xFFFFB26B)

                                      : currentState ==
                                      RequestState
                                          .uploading

                                      ? const Color(
                                      0xFF8EDBFF)

                                      : const Color(
                                      0xFF4ADE80),
                                ),
                              ),

                            if (currentState ==
                                RequestState
                                    .uploading) ...[

                              const SizedBox(
                                  height: 22),

                              const CircularProgressIndicator(
                                color:
                                Color(0xFFFFB26B),
                              ),
                            ],

                            if (errorMessage !=
                                null) ...[

                              const SizedBox(
                                  height: 18),

                              Text(
                                errorMessage!,

                                textAlign:
                                TextAlign.center,

                                style:
                                const TextStyle(
                                  color:
                                  Colors.redAccent,

                                  fontSize: 14,
                                ),
                              ),
                            ],

                            const SizedBox(height: 38),

                            // 🔥 button
                            SizedBox(
                              width: double.infinity,
                              height: 64,

                              child:
                              ElevatedButton(
                                onPressed:
                                (currentState ==
                                    RequestState
                                        .uploading)

                                    ? null
                                    : startRecordingFlow,

                                style:
                                ElevatedButton
                                    .styleFrom(
                                  backgroundColor:
                                  const Color(
                                      0xFFFFB26B),

                                  disabledBackgroundColor:
                                  Colors.grey
                                      .shade800,

                                  shape:
                                  RoundedRectangleBorder(
                                    borderRadius:
                                    BorderRadius.circular(
                                        24),
                                  ),

                                  elevation: 14,
                                ),

                                child: Text(
                                  currentState ==
                                      RequestState
                                          .recording

                                      ? 'LISTENING...'

                                      : 'START VOICE REQUEST',

                                  style:
                                  const TextStyle(
                                    fontSize: 15,

                                    fontWeight:
                                    FontWeight
                                        .bold,

                                    letterSpacing:
                                    1.1,

                                    color:
                                    Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ================= RECORD =================

  Future<void> startRecordingFlow() async {

    if (currentState == RequestState.recording) {
      stopAndSend();
      return;
    }

    final hasPermission =
    await _audioRecorder.hasPermission();

    if (!hasPermission) return;

    final dir =
    await getTemporaryDirectory();

    final path =
        '${dir.path}/request_${DateTime.now().millisecondsSinceEpoch}.wav';

    await _audioRecorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );

    setState(() {

      currentState =
          RequestState.recording;

      statusMessage =
      '🎙️ Listening to your banking request...';

      recordedAudioPath = path;
    });
  }

  // ================= STOP + SEND =================

  Future<void> stopAndSend() async {

    await _audioRecorder.stop();

    setState(() {

      currentState =
          RequestState.uploading;

      statusMessage =
      '⏳ AI is analyzing your request...';
    });

    try {

      final result =
      await ApiService.processRequest(
        audioFilePath:
        recordedAudioPath!,

        userId: currentUserId,
      );

      final success =
          result['status'] == 'SUCCESS';

      final reason =
      result['reason'];

      final message = success

          ? result['message']

          : getSmartMessage(reason);

      if (!mounted) return;

      showDialog(
        context: context,

        builder: (_) => AlertDialog(
          backgroundColor:
          const Color(0xFF24160D),

          shape: RoundedRectangleBorder(
            borderRadius:
            BorderRadius.circular(24),
          ),

          title: Text(
            success
                ? 'تم بنجاح'
                : 'فشل الطلب',

            style: const TextStyle(
              color: Colors.white,
            ),
          ),

          content: Text(
            message ?? '',

            style: TextStyle(
              color:
              Colors.white.withOpacity(0.8),

              height: 1.7,
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.pop(context);

                setState(() {

                  currentState =
                      RequestState.idle;

                  statusMessage = '';
                });
              },

              child: const Text(
                'موافق',

                style: TextStyle(
                  color:
                  Color(0xFFFFB26B),
                ),
              ),
            )
          ],
        ),
      );

    } catch (e) {

      setState(() {
        errorMessage = 'خطأ: $e';
      });
    }
  }

  @override
  void dispose() {

    recordTimer?.cancel();

    _audioRecorder.dispose();

    super.dispose();
  }
}