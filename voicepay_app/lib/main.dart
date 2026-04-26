import 'package:flutter/material.dart';
import 'screens/auth/login_screen.dart';
import 'screens/voice/challenge_screen.dart';
import 'screens/voice/request_screen.dart';
import 'screens/voice/enrollment_screen.dart';
import 'screens/splash/splash_screen.dart';

void main() {
  runApp(const VoicePayApp());
}

class VoicePayApp extends StatelessWidget {
  const VoicePayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VoicePay',

      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Roboto',

        scaffoldBackgroundColor: const Color(0xFF1B120B),

        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFB26B),
          secondary: Color(0xFF8EDBFF),
          surface: Color(0xFF24160D),
        ),

        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFFB26B),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
            ),
          ),
        ),
      ),

      initialRoute: SplashScreen.routeName,

      routes: {
        SplashScreen.routeName: (_) => const SplashScreen(),
        LoginScreen.routeName: (_) => const LoginScreen(),
        ChallengeScreen.routeName: (_) => const ChallengeScreen(),
        RequestScreen.routeName: (_) => const RequestScreen(),
        EnrollmentScreen.routeName: (_) => const EnrollmentScreen(),
      },
    );
  }
}