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
  // Step 1: enter email
  // Step 2: enter token + new password
  int _step = 1;

  final _emailCtrl   = TextEditingController();
  final _tokenCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _cpassCtrl   = TextEditingController();

  bool    _loading    = false;
  bool    _obscure    = true;
  String? _error;
  String? _success;

  String get _email => _emailCtrl.text.trim();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _tokenCtrl.dispose();
    _passCtrl.dispose();
    _cpassCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: request reset email ───────────────────────────
  Future<void> _sendLink() async {
    if (_email.isEmpty) return;
    setState(() { _loading = true; _error = null; _success = null; });
    final res = await apiService.forgotPassword(_email);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _step    = 2;
        _success = 'A reset code has been sent to $_email. Check your inbox.';
      } else {
        _error = res.error ?? 'Something went wrong.';
      }
    });
  }

  // ── Step 2: submit token + new password ──────────────────
  Future<void> _resetPassword() async {
    final token = _tokenCtrl.text.trim();
    final pass  = _passCtrl.text;
    final cpass = _cpassCtrl.text;

    if (token.isEmpty) {
      setState(() => _error = 'Please enter the reset code from your email.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    if (pass != cpass) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }

    setState(() { _loading = true; _error = null; _success = null; });
    final res = await apiService.resetPassword({
      'email':            _email,
      'token':            token,
      'newPassword':      pass,
      'confirmNewPassword': cpass,
    });
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (res.ok) {
        _success = 'Password reset successfully. You can now log in.';
        _step    = 3; // done
      } else {
        _error = res.error ?? 'Reset failed. The code may be expired or invalid.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Forgot Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Progress indicator ─────────────────────────
            Row(children: [
              _StepDot(n: 1, active: _step >= 1),
              Expanded(child: Container(height: 2,
                  color: _step >= 2
                      ? (isDark ? AppColors.darkAccent : AppColors.accent)
                      : (isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              _StepDot(n: 2, active: _step >= 2),
              Expanded(child: Container(height: 2,
                  color: _step >= 3
                      ? (isDark ? AppColors.darkAccent : AppColors.accent)
                      : (isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              _StepDot(n: 3, active: _step >= 3),
            ]),
            const SizedBox(height: 28),

            if (_error != null) ...[
              AlertWidget(message: _error!, isError: true),
              const SizedBox(height: 14),
            ],
            if (_success != null) ...[
              AlertWidget(message: _success!),
              const SizedBox(height: 14),
            ],

            // ── Step 1: Email ──────────────────────────────
            if (_step == 1) ...[
              Text('Reset your password',
                  style: GoogleFonts.dmSans(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Enter your email and we\'ll send you a reset code.',
                  style: GoogleFonts.dmSans(fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              const SizedBox(height: 24),
              _Label('EMAIL ADDRESS', isDark),
              const SizedBox(height: 6),
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _sendLink(),
                decoration: const InputDecoration(hintText: 'you@example.com'),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Send reset code',
                isLoading: _loading,
                onPressed: _sendLink,
              ),
            ],

            // ── Step 2: Token + new password ───────────────
            if (_step == 2) ...[
              Text('Enter the reset code',
                  style: GoogleFonts.dmSans(
                      fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Check your email for the reset code and enter it below.',
                  style: GoogleFonts.dmSans(fontSize: 14,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
              const SizedBox(height: 24),
              _Label('RESET CODE', isDark),
              const SizedBox(height: 6),
              TextField(
                controller: _tokenCtrl,
                decoration: const InputDecoration(
                  hintText: 'Paste the code from your email',
                ),
              ),
              const SizedBox(height: 16),
              _Label('NEW PASSWORD', isDark),
              const SizedBox(height: 6),
              TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  hintText: 'At least 6 characters',
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _Label('CONFIRM PASSWORD', isDark),
              const SizedBox(height: 6),
              TextField(
                controller: _cpassCtrl,
                obscureText: _obscure,
                decoration: const InputDecoration(hintText: 'Repeat new password'),
                onSubmitted: (_) => _resetPassword(),
              ),
              const SizedBox(height: 20),
              PrimaryButton(
                label: 'Reset password',
                isLoading: _loading,
                onPressed: _resetPassword,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() {
                  _step = 1; _error = null; _success = null;
                }),
                child: const Text('← Back'),
              ),
            ],

            // ── Step 3: Done ───────────────────────────────
            if (_step == 3) ...[
              const SizedBox(height: 20),
              Center(child: Column(children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.darkBadgeGreenBg
                        : AppColors.badgeGreenBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.check_rounded, size: 36,
                      color: isDark
                          ? AppColors.darkBadgeGreenTxt
                          : AppColors.badgeGreenTxt),
                ),
                const SizedBox(height: 16),
                Text('Password reset!',
                    style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('You can now log in with your new password.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 14,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary)),
                const SizedBox(height: 28),
                PrimaryButton(
                  label: 'Go to Login',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ])),
            ],

          ]),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────
class _Label extends StatelessWidget {
  final String text;
  final bool isDark;
  const _Label(this.text, this.isDark);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          letterSpacing: 0.05));
}

class _StepDot extends StatelessWidget {
  final int n;
  final bool active;
  const _StepDot({required this.n, required this.active});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 28, height: 28,
      decoration: BoxDecoration(
        color: active
            ? (isDark ? AppColors.darkAccent : AppColors.accent)
            : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
        shape: BoxShape.circle,
      ),
      child: Center(child: Text('$n',
          style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w700,
              color: active ? Colors.white
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)))),
    );
  }
}
