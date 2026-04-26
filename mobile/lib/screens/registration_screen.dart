import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/api_service.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({super.key});

  @override
  _RegistrationScreenState createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bankController = TextEditingController();
  
  bool _isLoading = false;
  final ApiService _apiService = ApiService();

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final result = await _apiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
        _phoneController.text,
        _bankController.text,
      );

      if (mounted) {
        Navigator.pushReplacementNamed(
          context, 
          '/voice-enrollment', 
          arguments: {'user_id': result['user_id']}
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: ${e.toString().replaceAll('Exception: ', '')}')),
        );
      }
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
  
            // Back Button
            Positioned(
              top: 20,
              right: 20,
              child: SafeArea(
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_forward_ios_rounded, color: Color(0xFF2A140A)),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.5),
                    padding: const EdgeInsets.all(12),
                  ),
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
                      border: Border.all(color: const Color(0xFFFFB26B).withOpacity(0.18)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFFB26B).withOpacity(0.14),
                          blurRadius: 30,
                          spreadRadius: 1,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'انضم إلى VoicePay',
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2A140A),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'قم بإنشاء حساب صوتي آمن',
                            style: TextStyle(
                              fontSize: 14,
                              color: const Color(0xFF2A140A).withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 32),
                          
                          _buildField(_nameController, 'الاسم الكامل', Icons.person),
                          const SizedBox(height: 16),
                          _buildField(_emailController, 'البريد الإلكتروني', Icons.email, keyboardType: TextInputType.emailAddress),
                          const SizedBox(height: 16),
                          _buildField(_passwordController, 'كلمة المرور', Icons.lock, obscure: true),
                          const SizedBox(height: 16),
                          _buildField(_phoneController, 'رقم الهاتف', Icons.phone, keyboardType: TextInputType.phone),
                          const SizedBox(height: 16),
                          _buildField(_bankController, 'اسم البنك', Icons.account_balance),
                          
                          const SizedBox(height: 32),
                          
                          if (_isLoading)
                            const CircularProgressIndicator(color: Color(0xFFFFB26B))
                          else
                            SizedBox(
                              width: double.infinity,
                              height: 58,
                              child: ElevatedButton(
                                onPressed: _register,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFFFB26B),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                                  elevation: 8,
                                ),
                                child: const Text(
                                  'المتابعة لإعداد الصوت',
                                  style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ).animate().fade(duration: 500.ms).slideY(begin: 0.1),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {bool obscure = false, TextInputType? keyboardType}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      textAlign: TextAlign.right,
      style: const TextStyle(color: Colors.black, fontSize: 15),
      cursorColor: Colors.black,
      decoration: InputDecoration(
        hintText: label,
        hintStyle: TextStyle(color: Colors.black.withOpacity(0.5)),
        prefixIcon: Icon(icon, color: const Color(0xFF8EDBFF)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.65),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
      validator: (v) => v!.isEmpty ? 'يرجى ملء الحقل' : null,
    );
  }
}
