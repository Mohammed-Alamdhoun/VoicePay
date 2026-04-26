// enrollment_screen.dart

import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../../services/api_service.dart';
import '../auth/login_screen.dart';

class EnrollmentScreen extends StatefulWidget {

  static const String routeName = '/enrollment';

  const EnrollmentScreen({super.key});

  @override
  State<EnrollmentScreen> createState() =>
      _EnrollmentScreenState();
}

class _EnrollmentScreenState
    extends State<EnrollmentScreen> {

  final AudioRecorder recorder =
      AudioRecorder();

  int currentStep = 1;
  final int totalSteps = 8;

  bool isRecording = false;
  String status = '';

  Timer? timer;

  String? userId;

  List<String> recordedPaths = [];

  String currentChallenge = '';
  String currentInstruction = '';

  final List<String> instructions = [

    'تحدث بصوت طبيعي',
    'اقترب من الميكروفون',
    'تحدث ببطء',
    'تحدث بسرعة معتدلة',
    'تحدث بصوت أوضح',
    'حافظ على نبرة طبيعية',
    'تحدث وكأنك في مكان مزدحم',
    'تحدث بثقة ووضوح',
  ];

  @override
  void didChangeDependencies() {

    super.didChangeDependencies();

    userId =
        ModalRoute.of(context)
            ?.settings
            .arguments as String?;

    if (currentChallenge.isEmpty) {
      generateChallenge();
    }
  }

  void generateChallenge() {

    final random = Random();

    List<int> digits =
    List.generate(
      6,
          (_) => random.nextInt(10),
    );

    currentChallenge =
        digits.join(' ');

    currentInstruction =
        instructions[
        random.nextInt(
            instructions.length)
        ];
  }

  Future<void> sendToBackend() async {

    try {

      final result =
      await ApiService.enrollUserUpload(
        userId: userId!,
        filePaths: recordedPaths,
      );

      setState(() {

        status =
        '🎉 تم حفظ البصمة الصوتية بنجاح';
      });

      print(result);

      if (!mounted) return;

      showDialog(
        context: context,

        builder: (_) => AlertDialog(
          backgroundColor:
          Colors.white,

          title: const Text(
            'تم بنجاح',
            style: TextStyle(
              color: Color(0xFF2A140A),
              fontWeight: FontWeight.bold,
            ),
          ),

          content: const Text(
            'تم تسجيل بصمتك الصوتية، يمكنك تسجيل الدخول الآن',

            style: TextStyle(
              color: Color(0xFF5A463A),
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {

                Navigator.of(context).pushAndRemoveUntil(

                  MaterialPageRoute(
                    builder: (_) =>
                    const LoginScreen(),
                  ),

                      (route) => false,
                );
              },

              child: const Text(
                'حسناً',

                style: TextStyle(
                  color:
                  Color(0xFFFFB26B),
                ),
              ),
            ),
          ],
        ),
      );

    } catch (e) {

      setState(() {

        status =
        '❌ فشل في الإرسال';
      });

      print(e);
    }
  }

  Future<void> startRecording() async {

    final hasPermission =
    await recorder.hasPermission();

    if (!hasPermission) return;

    final dir =
    await getTemporaryDirectory();

    final path =
        '${dir.path}/${userId}_enroll_$currentStep.wav';

    await recorder.start(

      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),

      path: path,
    );

    setState(() {
      isRecording = true;
      status = '🎙 يتم إنشاء البصمة الصوتية الآن...';
    });
  }

  Future<void> stopRecording() async {

    try {

      final path = await recorder.stop();

      if (path != null) {

        recordedPaths.add(path);
      }

      // ✅ خلصنا كل التسجيلات
      if (recordedPaths.length >= totalSteps) {

        setState(() {

          currentStep = totalSteps;

          isRecording = false;

          status = '✔ تم الانتهاء من جميع العينات';
        });

        // 🔥 إرسال للباك
        await sendToBackend();

        return;
      }

      // ✅ تحديث المرحلة
      setState(() {

        currentStep++;

        isRecording = false;

        status = '✔ تم حفظ العينة بنجاح';
      });

      // 🔥 challenge جديد
      generateChallenge();

    } catch (e) {

        print('❌ REAL ERROR: $e');

        setState(() {

          status =
          '❌ $e';
        });
      }
  }

  @override
  void dispose() {

    timer?.cancel();

    recorder.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F1EA),

      body: Stack(
        children: [

          // top orange shape
          Positioned(
            top: -170,
            left: -120,

            child: IgnorePointer(
              child: Container(
                width: 360,
                height: 360,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                  const Color(0xFFFFD6AE)
                      .withOpacity(0.75),
                ),
              ),
            ),
          ),

          // bottom blue shape
          Positioned(
            bottom: -220,
            right: -140,

            child: IgnorePointer(
              child: Container(
                width: 420,
                height: 420,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color:
                  const Color(0xFFD7EEF7)
                      .withOpacity(0.75),
                ),
              ),
            ),
          ),

          // back button
          Positioned(
            top: 20,
            left: 20,

            child: SafeArea(
              child: Material(
                color: Colors.transparent,

                child: InkWell(

                  borderRadius:
                  BorderRadius.circular(18),

                  onTap: () {
                    Navigator.pop(context);
                  },

                  child: Container(
                    padding:
                    const EdgeInsets.all(14),

                    decoration: BoxDecoration(
                      color: Colors.white
                          .withOpacity(0.55),

                      borderRadius:
                      BorderRadius.circular(
                          18),
                    ),

                    child: const Icon(
                      Icons
                          .arrow_back_ios_new_rounded,

                      color:
                      Color(0xFF2A140A),

                      size: 22,
                    ),
                  ),
                ),
              ),
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

                      // logo
                      Container(
                        width: 110,
                        height: 110,

                        decoration: BoxDecoration(
                          shape: BoxShape.circle,

                          gradient:
                          const LinearGradient(
                            colors: [
                              Color(0xFFFFB26B),
                              Color(0xFF8EDBFF),
                            ],
                          ),

                          boxShadow: [

                            BoxShadow(
                              color:
                              const Color(
                                  0xFFFFB26B)
                                  .withOpacity(
                                  0.35),

                              blurRadius: 35,
                              spreadRadius: 3,
                            ),
                          ],
                        ),

                        child: const Icon(
                          Icons.mic_rounded,

                          color: Colors.white,
                          size: 52,
                        ),
                      ),

                      const SizedBox(height: 28),

                      const Text(
                        'Voice Enrollment',

                        style: TextStyle(
                          fontSize: 38,

                          fontWeight:
                          FontWeight.bold,

                          color:
                          Color(0xFF2A140A),

                          letterSpacing: 1,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Creating Your AI Voice Identity',

                        style: TextStyle(
                          fontSize: 16,

                          color:
                          const Color(0xFF2A140A)
                              .withOpacity(0.60),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Text(
                        'User ID: $userId',

                        style: TextStyle(
                          color:
                          const Color(0xFF2A140A)
                              .withOpacity(0.45),

                          fontSize: 14,
                        ),
                      ),

                      const SizedBox(height: 34),

                      // progress card
                      Container(
                        width: double.infinity,

                        padding:
                        const EdgeInsets.all(
                            24),

                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(
                              30),

                          color:
                          Colors.white
                              .withOpacity(0.82),

                          boxShadow: [

                            BoxShadow(
                              color:
                              const Color(
                                  0xFFFFB26B)
                                  .withOpacity(
                                  0.10),

                              blurRadius: 30,
                              spreadRadius: 1,
                            ),
                          ],
                        ),

                        child: Column(
                          children: [

                            Row(
                              mainAxisAlignment:
                              MainAxisAlignment
                                  .spaceBetween,

                              children: [

                                const Text(
                                  'Enrollment Progress',

                                  style: TextStyle(
                                    color:
                                    Color(0xFF2A140A),

                                    fontSize: 16,

                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),

                                Text(
                                  '$currentStep / $totalSteps',

                                  style:
                                  const TextStyle(
                                    color:
                                    Color(
                                        0xFFFFB26B),

                                    fontSize: 18,

                                    fontWeight:
                                    FontWeight
                                        .bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(
                                height: 18),

                            ClipRRect(

                              borderRadius:
                              BorderRadius.circular(
                                  20),

                              child:
                              LinearProgressIndicator(
                                value:
                                currentStep /
                                    totalSteps,

                                minHeight: 10,

                                backgroundColor:
                                Colors.grey
                                    .withOpacity(
                                    0.15),

                                valueColor:
                                const AlwaysStoppedAnimation(
                                  Color(
                                      0xFFFFB26B),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      // challenge card
                      Container(
                        width: double.infinity,

                        padding:
                        const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 34,
                        ),

                        decoration: BoxDecoration(
                          borderRadius:
                          BorderRadius.circular(
                              32),

                          color:
                          Colors.white
                              .withOpacity(0.82),

                          boxShadow: [

                            BoxShadow(
                              color:
                              const Color(
                                  0xFFFFB26B)
                                  .withOpacity(
                                  0.12),

                              blurRadius: 35,
                              spreadRadius: 1,
                            ),
                          ],
                        ),

                        child: Column(
                          children: [

                            const Text(
                              'Voice Security Challenge',

                              style: TextStyle(
                                fontSize: 18,

                                color:
                                Color(
                                    0xFF8EDBFF),

                                fontWeight:
                                FontWeight
                                    .bold,
                              ),
                            ),

                            const SizedBox(
                                height: 24),

                            Text(
                              currentChallenge,

                              textAlign:
                              TextAlign.center,

                              style:
                              const TextStyle(
                                fontSize: 32,

                                letterSpacing:
                                10,

                                fontWeight:
                                FontWeight
                                    .bold,

                                color:
                                Color(0xFF2A140A),
                              ),
                            ),

                            const SizedBox(
                                height: 26),

                            Container(

                              padding:
                              const EdgeInsets.symmetric(
                                horizontal: 22,
                                vertical: 14,
                              ),

                              decoration:
                              BoxDecoration(
                                borderRadius:
                                BorderRadius
                                    .circular(
                                    20),

                                color:
                                const Color(
                                    0xFFFFB26B)
                                    .withOpacity(
                                    0.18),
                              ),

                              child: Text(
                                currentInstruction,

                                textAlign:
                                TextAlign.center,

                                style:
                                const TextStyle(
                                  color:
                                  Color(0xFF2A140A),

                                  fontSize: 16,

                                  fontWeight:
                                  FontWeight
                                      .w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 28),

                      if (status.isNotEmpty)

                        Text(
                          status,

                          textAlign:
                          TextAlign.center,

                          style: TextStyle(
                            fontSize: 15,

                            fontWeight:
                            FontWeight.w600,

                            color: isRecording

                                ? const Color(
                                0xFFFFB26B)

                                : const Color(
                                0xFF4ADE80),
                          ),
                        ),

                      const SizedBox(height: 32),

                      SizedBox(
                        width: double.infinity,
                        height: 62,

                        child: ElevatedButton(
                          onPressed: (recordedPaths.length >= totalSteps)
                              ? null
                              : (isRecording ? stopRecording : startRecording),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFB26B),
                            disabledBackgroundColor: Colors.grey.shade400,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 10,
                          ),
                          child: Text(
                            recordedPaths.length >= totalSteps
                                ? 'COMPLETED'
                                : isRecording
                                    ? 'STOP RECORDING'
                                    : 'START ENROLLMENT',
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1,
                              color: Colors.white,
                            ),
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