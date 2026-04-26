import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';
import 'package:flutter_tts/flutter_tts.dart';

// 🔥 animations
import 'package:flutter_animate/flutter_animate.dart';
import 'package:animate_do/animate_do.dart';
import 'package:avatar_glow/avatar_glow.dart';

enum ChallengeState {
  waitingToStart,
  recording,
  uploading,
}

class ChallengeScreen extends StatefulWidget {
  static const String routeName = '/challenge';

  const ChallengeScreen({super.key});

  @override
  State<ChallengeScreen> createState() =>
      _ChallengeScreenState();
}

class _ChallengeScreenState
    extends State<ChallengeScreen> {

  final AudioRecorder _audioRecorder =
      AudioRecorder();

  final FlutterTts tts = FlutterTts();

  ChallengeState currentState =
      ChallengeState.waitingToStart;

  String challengeText =
      'جاري تحميل رمز التحقق...';

  String statusMessage =
      'اضغط على "Start" خلال الوقت المحدد لبدء التحقق';

  String? sessionId;
  String? recordedAudioPath;
  String? errorMessage;

  Timer? preStartTimer;
  Timer? recordTimer;

  int preStartSeconds = 5;

  String currentUserId = '';

  bool hasStarted = false;
  bool isPreparing = true;

  @override
  void didChangeDependencies() {

    super.didChangeDependencies();

    if (currentUserId.isEmpty) {

      currentUserId =
          (ModalRoute.of(context)
          ?.settings
          .arguments as String?) ??
              '';

      _prepareChallenge();
    }
  }

  Future<void> _prepareChallenge() async {

    try {

      final result =
      await ApiService.startVerification(
        userId: currentUserId,
      );

      if (!mounted) return;

      setState(() {

        sessionId = result['session_id'];

        challengeText =
            result['challenge'] ??
                'يرجى قول رمز التحقق الظاهر أمامك';

        isPreparing = false;
      });

      startPreStartTimer();

    } catch (e) {

      if (!mounted) return;

      setState(() {

        isPreparing = false;

        errorMessage =
        'تعذر تحميل التحدي: $e';
      });
    }
  }

  void startPreStartTimer() {

    preStartTimer?.cancel();

    preStartSeconds = 5;

    preStartTimer = Timer.periodic(
      const Duration(seconds: 1),

          (timer) {

        if (!mounted) return;

        if (preStartSeconds > 1) {

          setState(() {
            preStartSeconds--;
          });

        } else {

          timer.cancel();

          if (!hasStarted) {

            Navigator.pushNamedAndRemoveUntil(
              context,
              LoginScreen.routeName,
                  (route) => false,
            );
          }
        }
      },
    );
  }

  Future<void> onStartPressed() async {

    if (currentState == ChallengeState.recording) {
      stopAndSend();
      return;
    }

    hasStarted = true;

    preStartTimer?.cancel();

    setState(() {

      currentState =
          ChallengeState.recording;

      statusMessage =
      '🎙️ يتم التسجيل الآن... تحدث بوضوح';

      errorMessage = null;
    });

    try {

      final hasPermission =
      await _audioRecorder.hasPermission();

      if (!hasPermission) {

        setState(() {

          currentState =
              ChallengeState.waitingToStart;

          errorMessage =
          'لم يتم منح إذن استخدام الميكروفون';
        });

        return;
      }

      final dir =
      await getTemporaryDirectory();

      final path =
          '${dir.path}/challenge_${DateTime.now().millisecondsSinceEpoch}.wav';

      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: path,
      );

      recordedAudioPath = path;

    } catch (e) {
      debugPrint('Error starting recording: $e');
      setState(() {
        currentState = ChallengeState.waitingToStart;
        errorMessage = 'حدث خطأ أثناء بدء التسجيل';
      });
    }
  }

  Future<void> speakArabic(String text) async {

    await tts.setLanguage("ar-SA");

    await tts.setSpeechRate(0.4);

    await tts.setVolume(1.0);

    await tts.setPitch(1.0);

    await tts.speak(text);
  }

  Future<void> stopAndSend() async {

    try {

      await _audioRecorder.stop();

      if (!mounted) return;

      setState(() {

        currentState =
            ChallengeState.uploading;

        statusMessage =
        '⏳ جاري تحليل البصمة الصوتية...';
      });

      final result =
      await ApiService.completeVerification(
        sessionId: sessionId!,
        audioFilePath: recordedAudioPath!,
        speakerLabel: currentUserId,
      );

      if (!mounted) return;

      final status =
      result['verification_status'];

      final bool contentOk =
          result['content_ok'] ?? false;

      final bool speakerOk =
          result['speaker_ok'] ?? false;

      String smartMessage = '';

      if (!contentOk && !speakerOk) {

        smartMessage =
        '❌ الصوت غير مطابق + رمز التحقق غير صحيح';

      } else if (!contentOk) {

        smartMessage =
        '🔢 لم يتم نطق رمز التحقق بشكل صحيح';

      } else if (!speakerOk) {

        smartMessage =
        '🎤 الصوت غير مطابق للحساب';

      } else {

        smartMessage = '❌ فشل التحقق';
      }

      if (status == 'ACCEPT') {

        Navigator.pushNamedAndRemoveUntil(
          context,
          '/request',
              (route) => false,
          arguments: currentUserId,
        );

      } else {

        showDialog(
          context: context,

          builder: (_) => AlertDialog(
            backgroundColor:
            const Color(0xFFFFFFFF),

            title: const Text(
              'فشل التحقق',

              style: TextStyle(
                color: Color(0xFF2A1A12),
              ),
            ),

            content: Text(
              smartMessage,

              style: const TextStyle(
                color: Color(0xFF5E4A3E),
              ),
            ),

            actions: [

              TextButton(
                onPressed: () {

                  Navigator.pop(context);

                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    LoginScreen.routeName,
                        (route) => false,
                  );
                },

                child: const Text(
                  'رجوع',

                  style: TextStyle(
                    color:
                    Color(0xFFFFB26B),
                  ),
                ),
              )
            ],
          ),
        );
      }

    } catch (e) {

      if (!mounted) return;

      setState(() {

        currentState =
            ChallengeState.waitingToStart;

        errorMessage =
        'خطأ أثناء الإرسال: $e';
      });
    }
  }

  @override
  void dispose() {

    preStartTimer?.cancel();

    recordTimer?.cancel();

    _audioRecorder.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    final bool startDisabled =
        isPreparing ||
            currentState ==
                ChallengeState.uploading;

    return Scaffold(
      backgroundColor:
      const Color(0xFFF6EFE7),

      body: Stack(
        children: [

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
                    .withOpacity(0.22),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
              duration:
              5.seconds,

              begin:
              const Offset(1, 1),

              end:
              const Offset(1.2, 1.2),
            ),
          ),

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
                    .withOpacity(0.18),
              ),
            )
                .animate(onPlay: (c) => c.repeat())
                .scale(
              duration:
              6.seconds,

              begin:
              const Offset(1, 1),

              end:
              const Offset(1.15, 1.15),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(

                padding:
                const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),

                child: ConstrainedBox(
                  constraints:
                  const BoxConstraints(
                    maxWidth: 520,
                  ),

                  child: Column(
                    mainAxisAlignment:
                    MainAxisAlignment.center,

                    children: [

                      ZoomIn(
                        duration:
                        const Duration(
                            milliseconds: 900),

                        child: AvatarGlow(
                          glowColor:
                          const Color(0xFFFFB26B),

                          animate:
                          currentState ==
                              ChallengeState
                                  .recording,

                          child: Container(
                            width: 100,
                            height: 100,

                            decoration:
                            const BoxDecoration(
                              shape:
                              BoxShape.circle,

                              gradient:
                              LinearGradient(
                                colors: [
                                  Color(
                                      0xFFFFB26B),
                                  Color(
                                      0xFF8EDBFF),
                                ],
                              ),
                            ),

                            child: const Icon(
                              Icons.mic_rounded,
                              size: 50,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      FadeInDown(
                        child: const Text(
                          'Voice Verification',

                          style: TextStyle(
                            fontSize: 22,

                            fontWeight:
                            FontWeight.bold,

                            color:
                            Color(0xFF2A1A12),

                            letterSpacing: 1,
                          ),
                        ),
                      ),

                      const SizedBox(height: 10),

                      FadeIn(
                        delay:
                        const Duration(
                            milliseconds: 250),

                        child: const Text(
                          'Secure AI Voice Authentication',

                          style: TextStyle(
                            fontSize: 13,

                            color:
                            Color(0xFF6E5A4F),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'User ID: $currentUserId',

                        style: const TextStyle(
                          color:
                          Color(0xFF8B776B),

                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 36),

                      FadeInUp(
                        duration:
                        const Duration(
                            milliseconds: 700),

                        child: Container(
                          width: double.infinity,

                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 30,
                          ),

                          decoration:
                          BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(
                                32),

                            color:
                            Colors.white.withOpacity(0.82),

                            border: Border.all(
                              color:
                              const Color(0xFFFFB26B)
                                  .withOpacity(0.20),
                            ),

                            boxShadow: [

                              BoxShadow(
                                color:
                                const Color(
                                    0xFFFFB26B)
                                    .withOpacity(
                                    0.12),

                                blurRadius: 30,
                                spreadRadius: 1,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),

                          child: Column(
                            children: [

                              const Text(
                                'Security Challenge',

                                style: TextStyle(
                                  fontSize: 14,

                                  color:
                                  Color(
                                      0xFF8EDBFF),

                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),

                              const SizedBox(
                                  height: 22),

                              Text(
                                challengeText,

                                textAlign:
                                TextAlign.center,

                                style:
                                const TextStyle(
                                  fontSize: 22,

                                  height: 1.7,

                                  letterSpacing: 4,

                                  fontWeight:
                                  FontWeight
                                      .bold,

                                  color:
                                  Color(0xFF2A1A12),
                                ),
                              )
                                  .animate(
                                onPlay:
                                    (controller) =>
                                    controller.repeat(
                                        reverse:
                                        true),
                              )
                                  .shimmer(
                                duration:
                                2.seconds,
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 26),

                      FadeInUp(
                        delay:
                        const Duration(
                            milliseconds: 250),

                        child: Container(
                          width: double.infinity,

                          padding:
                          const EdgeInsets.all(22),

                          decoration:
                          BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(
                                26),

                            color:
                            Colors.white.withOpacity(0.80),

                            border: Border.all(
                              color: const Color(0xFFFFB26B)
                                  .withOpacity(
                                  0.08),
                            ),
                          ),

                          child: Column(
                            crossAxisAlignment:
                            CrossAxisAlignment
                                .start,

                            children: [

                              const Row(
                                children: [

                                  Icon(
                                    Icons.security,
                                    color:
                                    Color(
                                        0xFF8EDBFF),
                                  ),

                                  SizedBox(width: 10),

                                  Text(
                                    'AI Security Instructions',

                                    style: TextStyle(
                                      color:
                                      Color(0xFF2A1A12),

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
                                  height: 18),

                              const Text(
                                '• اضغط على Start خلال 5 ثوانٍ\n'
                                    '• تحدث بوضوح وبصوت طبيعي\n'
                                    '• سيتم إيقاف التسجيل تلقائياً\n'
                                    '• سيتم تحليل البصمة الصوتية باستخدام AI',

                                style: TextStyle(
                                  color:
                                  Color(0xFF5E4A3E),

                                  fontSize: 14,
                                  height: 1.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      if (currentState ==
                          ChallengeState
                              .waitingToStart &&
                          !isPreparing)

                        Container(
                          padding:
                          const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 12,
                          ),

                          decoration: BoxDecoration(
                            borderRadius:
                            BorderRadius.circular(
                                18),

                            color: Colors.red
                                .withOpacity(0.12),
                          ),

                          child: Text(
                            '$preStartSeconds s',

                            style: const TextStyle(
                              color:
                              Colors.redAccent,

                              fontSize: 20,

                              fontWeight:
                              FontWeight.bold,
                            ),
                          ),
                        )
                            .animate(
                          onPlay:
                              (controller) =>
                              controller.repeat(),
                        )
                            .scale(
                          duration:
                          900.ms,

                          begin:
                          const Offset(1, 1),

                          end:
                          const Offset(1.1, 1.1),
                        ),

                      if (statusMessage
                          .isNotEmpty) ...[

                        const SizedBox(height: 20),

                        FadeIn(
                          child: Text(
                            statusMessage,

                            textAlign:
                            TextAlign.center,

                            style: TextStyle(
                              fontSize: 12,

                              fontWeight:
                              FontWeight.w600,

                              color: currentState ==
                                  ChallengeState
                                      .recording

                                  ? const Color(
                                  0xFFFFB26B)

                                  : currentState ==
                                  ChallengeState
                                      .uploading

                                  ? const Color(
                                  0xFF8EDBFF)

                                  : const Color(
                                  0xFF4ADE80),
                            ),
                          ),
                        ),
                      ],

                      if (currentState ==
                          ChallengeState
                              .uploading) ...[

                        const SizedBox(height: 22),

                        const CircularProgressIndicator(
                          color:
                          Color(0xFFFFB26B),
                        ),
                      ],

                      if (errorMessage != null) ...[

                        const SizedBox(height: 18),

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

                      const SizedBox(height: 36),

                      FadeInUp(
                        delay:
                        const Duration(
                            milliseconds: 350),

                        child: SizedBox(
                          width: double.infinity,
                          height: 64,

                          child: ElevatedButton(
                            onPressed:
                            startDisabled
                                ? null
                                : onStartPressed,

                            style:
                            ElevatedButton
                                .styleFrom(
                              backgroundColor:
                              const Color(
                                  0xFFFFB26B),

                              disabledBackgroundColor:
                              Colors.grey
                                  .shade300,

                              shape:
                              RoundedRectangleBorder(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    24),
                              ),

                              elevation: 14,
                            ),

                            child: Text(
                              isPreparing
                                  ? 'Loading...'
                                  : currentState ==
                                  ChallengeState
                                      .recording
                                  ? 'RECORDING...'
                                  : 'START VERIFICATION',

                              style:
                              const TextStyle(
                                fontSize: 16,

                                fontWeight:
                                FontWeight
                                    .bold,

                                letterSpacing:
                                1,

                                color:
                                Color(0xFF2A1A12),
                              ),
                            ),
                          )
                              .animate(
                            onPlay:
                                (controller) =>
                                controller.repeat(
                                    reverse:
                                    true),
                          )
                              .shimmer(
                            duration:
                            3.seconds,
                          ),
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
    );
  }
}