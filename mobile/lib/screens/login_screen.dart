import 'package:flutter/material.dart';
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

  // Error states for inline display
  String? _emailError;
  String? _passwordError;
  String? _generalError;

  void _handleLogin() async {
    // Reset errors
    setState(() {
      _emailError = null;
      _passwordError = null;
      _generalError = null;
      _isLoading = true;
    });

    // Local validation
    bool hasError = false;
    if (_emailController.text.isEmpty) {
      _emailError = 'يرجى إدخال البريد الإلكتروني';
      hasError = true;
    }
    if (_passwordController.text.isEmpty) {
      _passwordError = 'يرجى إدخال كلمة المرور';
      hasError = true;
    }

    if (hasError) {
      setState(() => _isLoading = false);
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
      if (errorMessage.contains('needs_enrollment')) {
        return;
      }
      
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
        body: SingleChildScrollView(
          child: Container(
            height: MediaQuery.of(context).size.height,
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_balance_wallet, size: 100, color: Colors.blue),
                const SizedBox(height: 16),
                const Text('VoicePay', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 48),
                
                if (_generalError != null) ...[
                  VoicePayUI.buildErrorContainer(_generalError!),
                  const SizedBox(height: 16),
                ],

                // Email Field with error above
                Align(
                  alignment: Alignment.centerLeft,
                  child: _emailError != null 
                    ? Text(_emailError!, textAlign: TextAlign.left, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))
                    : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _emailController,
                    onChanged: (_) => setState(() => _emailError = null),
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني', 
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _emailError != null ? Colors.red : Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _emailError != null ? Colors.red : Colors.grey.shade400),
                      ),
                      prefixIcon: Icon(Icons.email_outlined, color: _emailError != null ? Colors.red : null),
                    ),
                    keyboardType: TextInputType.emailAddress,
                  ),
                ),
                
                const SizedBox(height: 20),

                // Password Field with error above
                Align(
                  alignment: Alignment.centerLeft,
                  child: _passwordError != null 
                    ? Text(_passwordError!, textAlign: TextAlign.left, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold))
                    : const SizedBox.shrink(),
                ),
                const SizedBox(height: 4),
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: TextField(
                    controller: _passwordController,
                    onChanged: (_) => setState(() => _passwordError = null),
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة المرور', 
                      border: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _passwordError != null ? Colors.red : Colors.grey),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: const BorderRadius.all(Radius.circular(12)),
                        borderSide: BorderSide(color: _passwordError != null ? Colors.red : Colors.grey.shade400),
                      ),
                      prefixIcon: Icon(Icons.lock_outline, color: _passwordError != null ? Colors.red : null),
                    ),
                  ),
                ),
                
                const SizedBox(height: 32),
                _isLoading 
                  ? const CircularProgressIndicator()
                  : Column(
                      children: [
                        ElevatedButton(
                          onPressed: _handleLogin,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('تسجيل الدخول', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () => Navigator.pushNamed(context, '/register'),
                          child: const Text('ليس لديك حساب؟ أنشئ حساباً جديداً', style: TextStyle(fontSize: 16)),
                        ),
                      ],
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
