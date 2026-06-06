
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _success;
  String? _error;

  @override
  void dispose() { _emailCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });
    final res = await apiService.forgotPassword(email);
    setState(() {
      _loading = false;
      if (res.ok) {
        _success = 'If that email is registered, a reset link has been sent.';
      } else {
        _error = res.error ?? 'Something went wrong.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Enter your email address and we\'ll send you a password reset link.',
            style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        const SizedBox(height: 20),
        if (_success != null) ...[AlertWidget(message: _success!), const SizedBox(height: 14)],
        if (_error != null) ...[AlertWidget(message: _error!, isError: true), const SizedBox(height: 14)],
        Text('EMAIL ADDRESS', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
        const SizedBox(height: 6),
        TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(hintText: 'you@example.com')),
        const SizedBox(height: 16),
        PrimaryButton(label: 'Send reset link', onPressed: _submit, isLoading: _loading),
      ])),
    );
  }
}
