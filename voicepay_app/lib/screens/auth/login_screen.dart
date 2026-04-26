// login_screen.dart

import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import 'package:flutter_animate/flutter_animate.dart';

class LoginScreen extends StatefulWidget {
  static const String routeName = '/login';

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen> {

  final TextEditingController userIdController =
      TextEditingController();

  bool isLoading = false;

  // ================= LOGIN =================

  Future<void> loginFlow() async {

    final userId =
    userIdController.text.trim();

    if (userId.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('الرجاء إدخال User ID'),
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    try {

      final exists =
      await ApiService.checkUserExists(
        userId,
      );

      if (!mounted) return;

      if (!exists) {

        showDialog(
          context: context,

          builder: (_) => const AlertDialog(
            title: Text('غير مسجل'),

            content: Text(
              'هذا المستخدم غير موجود، قم بالتسجيل أولاً',
            ),
          ),
        );

      } else {

        Navigator.pushNamed(
          context,
          '/challenge',
          arguments: userId,
        );
      }

    } catch (e) {

      showDialog(
        context: context,

        builder: (_) => AlertDialog(
          title: const Text('خطأ'),
          content: Text(e.toString()),
        ),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // ================= ENROLLMENT =================

  Future<void> enrollmentFlow() async {

    final userId =
    userIdController.text.trim();

    if (userId.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content:
          Text('الرجاء إدخال User ID'),
        ),
      );

      return;
    }

    setState(() => isLoading = true);

    try {

      final exists =
      await ApiService.checkUserExists(
        userId,
      );

      if (!mounted) return;

      if (exists) {

        showDialog(
          context: context,

          builder: (_) => const AlertDialog(
            title: Text('موجود مسبقاً'),

            content: Text(
              'هذا المستخدم مسجل بالفعل',
            ),
          ),
        );

      } else {

        Navigator.pushNamed(
          context,
          '/enrollment',
          arguments: userId,
        );
      }

    } catch (e) {

      showDialog(
        context: context,

        builder: (_) => AlertDialog(
          title: const Text('خطأ'),
          content: Text(e.toString()),
        ),
      );
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  // ================= UI =================

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor:
      const Color(0xFFF7F1EA),

      body: Stack(
        children: [

          // 🔥 top orange glow
          Positioned(
            top: -170,
            left: -120,

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

          // 🔥 bottom blue glow
          Positioned(
            bottom: -220,
            right: -140,

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

          Center(
            child: Padding(
              padding:
              const EdgeInsets.all(24),

              child: ConstrainedBox(
                constraints:
                const BoxConstraints(
                  maxWidth: 500,
                ),

                child: Container(
                  padding:
                  const EdgeInsets.symmetric(
                    horizontal: 30,
                    vertical: 36,
                  ),

                  decoration: BoxDecoration(
                    borderRadius:
                    BorderRadius.circular(
                        34),

                    color:
                    Colors.white.withOpacity(0.82),

                    border: Border.all(
                      color:
                      const Color(0xFFFFB26B)
                          .withOpacity(0.18),
                    ),

                    boxShadow: [

                      BoxShadow(
                        color:
                        const Color(0xFFFFB26B)
                            .withOpacity(0.14),

                        blurRadius: 30,
                        spreadRadius: 1,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),

                  child: Column(
                    mainAxisSize:
                    MainAxisSize.min,

                    children: [

                      // 🔥 logo
                      Container(
                        width: 110,
                        height: 110,

                        decoration: BoxDecoration(
                          shape:
                          BoxShape.circle,

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
                          Icons.graphic_eq_rounded,

                          color: Colors.white,
                          size: 48,
                        ),
                      )
                          .animate()
                          .fade(duration: 700.ms)
                          .scale(
                        begin:
                        const Offset(
                            0.85,
                            0.85),
                      ),

                      const SizedBox(height: 28),

                      // 🔥 title
                      const Text(
                        'VoicePay',

                        style: TextStyle(
                          fontSize: 36,
                          fontWeight:
                          FontWeight.bold,

                          color:
                          Color(0xFF2A140A),

                          letterSpacing: 1.1,
                        ),
                      ),

                      const SizedBox(height: 10),

                      Text(
                        'Secure AI Voice Authentication',

                        style: TextStyle(
                          fontSize: 14,

                          color:
                          const Color(0xFF2A140A)
                              .withOpacity(0.65),
                        ),
                      ),

                      const SizedBox(height: 34),

                      // 🔥 textfield
                      TextField(
                        controller:
                        userIdController,

                        style: const TextStyle(
                          color:
                          Color(0xFF2A140A),

                          fontSize: 15,
                        ),

                        decoration:
                        InputDecoration(
                          hintText:
                          'Enter User ID',

                          hintStyle:
                          TextStyle(
                            color:
                            const Color(0xFF2A140A)
                                .withOpacity(
                                0.35),
                          ),

                          prefixIcon:
                          const Icon(
                            Icons
                                .person_outline,

                            color:
                            Color(
                                0xFF8EDBFF),
                          ),

                          filled: true,

                          fillColor:
                          Colors.white
                              .withOpacity(
                              0.65),

                          border:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                                22),

                            borderSide:
                            BorderSide(
                              color:
                              Colors.grey
                                  .withOpacity(
                                  0.08),
                            ),
                          ),

                          enabledBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                                22),

                            borderSide:
                            BorderSide(
                              color:
                              Colors.grey
                                  .withOpacity(
                                  0.08),
                            ),
                          ),

                          focusedBorder:
                          OutlineInputBorder(
                            borderRadius:
                            BorderRadius
                                .circular(
                                22),

                            borderSide:
                            const BorderSide(
                              color: Color(
                                  0xFFFFB26B),

                              width: 2,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      if (isLoading)

                        const CircularProgressIndicator(
                          color:
                          Color(0xFFFFB26B),
                        ),

                      const SizedBox(height: 22),

                      // 🔥 login button
                      SizedBox(
                        width: double.infinity,
                        height: 58,

                        child: ElevatedButton(
                          onPressed:
                          isLoading
                              ? null
                              : loginFlow,

                          style:
                          ElevatedButton
                              .styleFrom(
                            backgroundColor:
                            const Color(
                                0xFFFFB26B),

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  22),
                            ),

                            elevation: 12,
                          ),

                          child: const Text(
                            'VERIFY IDENTITY',

                            style: TextStyle(
                              fontSize: 16,

                              fontWeight:
                              FontWeight
                                  .bold,

                              letterSpacing:
                              1,

                              color:
                              Colors.white,
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

                      const SizedBox(height: 14),

                      // 🔥 enrollment button
                      SizedBox(
                        width: double.infinity,
                        height: 58,

                        child: OutlinedButton(
                          onPressed:
                          isLoading
                              ? null
                              : enrollmentFlow,

                          style:
                          OutlinedButton
                              .styleFrom(
                            side: BorderSide(
                              color:
                              const Color(
                                  0xFF8EDBFF)
                                  .withOpacity(
                                  0.70),
                            ),

                            shape:
                            RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius
                                  .circular(
                                  22),
                            ),
                          ),

                          child: const Text(
                            'CREATE VOICE IDENTITY',

                            style: TextStyle(
                              fontSize: 15,

                              fontWeight:
                              FontWeight
                                  .bold,

                              color:
                              Color(
                                  0xFF2A140A),

                              letterSpacing:
                              1,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 22),

                      Text(
                        'AI-powered secure banking authentication',

                        textAlign:
                        TextAlign.center,

                        style: TextStyle(
                          color:
                          const Color(0xFF2A140A)
                              .withOpacity(0.40),

                          fontSize: 12,
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