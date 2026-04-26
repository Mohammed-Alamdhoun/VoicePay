import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';
import '../services/ui_utils.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _apiService = ApiService();
  bool _isLoading = false;

  String? _emailError;
  String? _passwordError;
  String? _generalError;

  void _handleLogin() async {
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _isLoading = true;
    });

    if (_emailController.text.isEmpty) {
      setState(() {
        _emailError = 'يرجى إدخال البريد الإلكتروني';
        _isLoading = false;
      });
      return;
    }
    if (_passwordController.text.isEmpty) {
      setState(() {
        _passwordError = 'يرجى إدخال كلمة المرور';
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await _apiService.login(
        _emailController.text,
        _passwordController.text,
      );
      
      if (!mounted) return;

      if (response['status'] == 'needs_enrollment') {
        Navigator.pushNamed(
          context, 
          '/voice-enrollment', 
          arguments: {'user_id': response['user']['pid']}
        );
        return;
      }

      if (response['status'] == 'needs_challenge') {
        Navigator.pushNamed(
          context, 
          '/login-challenge', 
          arguments: {
            'user_pid': response['user_pid'],
            'challenge': response['challenge']
          }
        );
        return;
      }

      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (context) => DashboardScreen(userData: response['user']))
      );
    } catch (e) {
      String errorMessage = e.toString().replaceAll('Exception: ', '');
      if (!mounted) return;
      
      setState(() {
        if (errorMessage.toLowerCase().contains('email') || errorMessage.contains('البريد')) {
          _emailError = 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
        } else if (errorMessage.toLowerCase().contains('password') || errorMessage.contains('كلمة')) {
          _passwordError = 'كلمة المرور غير صحيحة';
        } else {
          _generalError = errorMessage;
        }
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F1EA),
        body: Stack(
          children: [
            // 🔥 Top orange glow
            Positioned(
              top: -170,
              left: -120,
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD6AE).withOpacity(0.75),
                ),
              ),
            ),
  
            // 🔥 Bottom blue glow
            Positioned(
              bottom: -220,
              right: -140,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD7EEF7).withOpacity(0.75),
                ),
              ),
            ),
  
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 500),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 36),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(34),
                      color: Colors.white.withOpacity(0.82),
                      border: Border.all(
                        color: const Color(0xFFFFB26B).withOpacity(0.18),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB26B).withOpacity(0.14),
                          blurRadius: 30,
                          spreadRadius: 1,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 🔥 Logo
                        Container(
                          width: 100,
                          height: 100,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB26B), Color(0xFF8EDBFF)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFFFB26B).withOpacity(0.35),
                                blurRadius: 35,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.graphic_eq_rounded,
                            color: Colors.white,
                            size: 44,
                          ),
                        )
                            .animate()
                            .fade(duration: 700.ms)
                            .scale(begin: const Offset(0.85, 0.85)),
  
                        const SizedBox(height: 24),
  
                        const Text(
                          'VoicePay',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF2A140A),
                            letterSpacing: 1.1,
                          ),
                        ),
  
                        const SizedBox(height: 8),
  
                        Text(
                          'مصادقة صوتية آمنة بالذكاء الاصطناعي',
                          style: TextStyle(
                            fontSize: 13,
                            color: const Color(0xFF2A140A).withOpacity(0.65),
                          ),
                        ),
  
                        const SizedBox(height: 32),
                        
                        if (_generalError != null) ...[
                          VoicePayUI.buildErrorContainer(_generalError!),
                          const SizedBox(height: 16),
                        ],
  
                        // Email Field
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: _emailController,
                            style: const TextStyle(color: Colors.black, fontSize: 15),
                            cursorColor: Colors.black,
                            onChanged: (_) => setState(() => _emailError = null),
                            decoration: InputDecoration(
                              hintText: 'البريد الإلكتروني',
                              hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                              errorText: _emailError,
                              prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF8EDBFF)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.65),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(color: Color(0xFFFFB26B), width: 2),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
  
                        // Password Field
                        Directionality(
                          textDirection: TextDirection.ltr,
                          child: TextField(
                            controller: _passwordController,
                            obscureText: true,
                            style: const TextStyle(color: Colors.black, fontSize: 15),
                            cursorColor: Colors.black,
                            onChanged: (_) => setState(() => _passwordError = null),
                            decoration: InputDecoration(
                              hintText: 'كلمة المرور',
                              hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
                              errorText: _passwordError,
                              prefixIcon: const Icon(Icons.lock_outline, color: Color(0xFF8EDBFF)),
                              filled: true,
                              fillColor: Colors.white.withOpacity(0.65),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.08)),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: BorderSide(color: Colors.grey.withOpacity(0.08)),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(22),
                                borderSide: const BorderSide(color: Color(0xFFFFB26B), width: 2),
                              ),
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 32),
  
                        if (_isLoading)
                          const CircularProgressIndicator(color: Color(0xFFFFB26B))
                        else ...[
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _handleLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFFFB26B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                elevation: 8,
                              ),
                              child: const Text(
                                'التحقق من الهوية',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1),
                              ),
                            ).animate(onPlay: (c) => c.repeat(reverse: true)).shimmer(duration: 3.seconds),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: OutlinedButton(
                              onPressed: () => Navigator.pushNamed(context, '/register'),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: const Color(0xFF8EDBFF).withOpacity(0.7)),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(22),
                                ),
                              ),
                              child: const Text(
                                'إنشاء هوية صوتية',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF2A140A)),
                              ),
                            ),
                          ),
                        ],
  
                        const SizedBox(height: 24),
  
                        Text(
                          'مصادقة بنكية آمنة مدعومة بالذكاء الاصطناعي',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xFF2A140A).withOpacity(0.40),
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
      ),
    );
  }
}
