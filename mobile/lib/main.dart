import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'screens/login_screen.dart';
import 'screens/registration_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/login_challenge_screen.dart';
import 'screens/voice_enrollment_screen.dart';

void main() {
  runApp(const VoicePayApp());
}

class VoicePayApp extends StatelessWidget {
  const VoicePayApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoicePay',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      initialRoute: '/login',
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegistrationScreen(),
        '/dashboard': (context) => const DashboardScreen(),
        '/login-challenge': (context) => const LoginChallengeScreen(),
        '/voice-enrollment': (context) => const VoiceEnrollmentScreen(),
      },
    );
  }
}
