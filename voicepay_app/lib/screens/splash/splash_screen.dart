// splash_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import '../auth/login_screen.dart';

class SplashScreen extends StatefulWidget {
  static const String routeName = '/';

  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() =>
      _SplashScreenState();
}

class _SplashScreenState
    extends State<SplashScreen>
    with SingleTickerProviderStateMixin {

  late AnimationController controller;

  @override
  void initState() {
    super.initState();

    controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    Timer(const Duration(seconds: 4), () {

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        LoginScreen.routeName,
      );
    });
  }

  @override
  void dispose() {

    controller.dispose();

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

          // bottom blue shape
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
            child: Column(
              mainAxisAlignment:
              MainAxisAlignment.center,

              children: [

                ScaleTransition(

                  scale: Tween<double>(
                    begin: 0.92,
                    end: 1.05,
                  ).animate(
                    CurvedAnimation(
                      parent: controller,
                      curve: Curves.easeInOut,
                    ),
                  ),

                  child: Container(
                    width: 135,
                    height: 135,

                    decoration:
                    BoxDecoration(
                      shape: BoxShape.circle,

                      gradient:
                      const LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,

                        colors: [
                          Color(0xFFFFB26B),
                          Color(0xFF8EDBFF),
                        ],
                      ),

                      boxShadow: [
                        BoxShadow(
                          color:
                          const Color(0xFFFFB26B)
                              .withOpacity(0.35),

                          blurRadius: 35,
                          spreadRadius: 3,
                        ),
                      ],
                    ),

                    child: const Icon(
                      Icons.graphic_eq_rounded,

                      size: 65,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'VoicePay',

                  style: TextStyle(
                    fontSize: 42,
                    fontWeight:
                    FontWeight.w800,

                    letterSpacing: 1,

                    color:
                    Color(0xFF2A140A),
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  'AI-Powered Secure Voice Authentication',

                  style: TextStyle(
                    color:
                    const Color(0xFF2A140A)
                        .withOpacity(0.65),

                    fontSize: 17,
                    fontWeight:
                    FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}