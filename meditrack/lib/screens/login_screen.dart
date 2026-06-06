
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/register_screen.dart';
import 'package:meditrack/screens/forgot_password_screen.dart';
import 'package:meditrack/screens/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure = true;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut));
    _animCtrl.forward();
  }

  @override
  void dispose() { _animCtrl.dispose(); _emailCtrl.dispose(); _passCtrl.dispose(); super.dispose(); }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) return;
    final auth = context.read<AuthProvider>();
    final app  = context.read<AppProvider>();
    auth.clearError();
    final ok = await auth.login(email, pass);
    if (ok && mounted) {
      await app.loadAll(auth.role);
      if (mounted) Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: FadeTransition(opacity: _fadeAnim, child: SlideTransition(position: _slideAnim, child: Column(children: [
                Container(width: 56, height: 56,
                  decoration: BoxDecoration(gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [BoxShadow(color: AppColors.accent.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))]),
                  child: const Icon(Icons.monitor_heart_outlined, color: Colors.white, size: 28)),
                const SizedBox(height: 20),
                Text('MediTrack', style: GoogleFonts.dmSans(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
                const SizedBox(height: 4),
                Text('Healthcare Management System', style: GoogleFonts.dmSans(fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 32),
                if (auth.error != null) ...[AlertWidget(message: auth.error!, isError: true), const SizedBox(height: 14)],
                Align(alignment: Alignment.centerLeft, child: Text('EMAIL ADDRESS', style: GoogleFonts.dmSans(fontSize: 11,
                    fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05))),
                const SizedBox(height: 5),
                TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(hintText: 'ahmed@example.com')),
                const SizedBox(height: 13),
                Align(alignment: Alignment.centerLeft, child: Text('PASSWORD', style: GoogleFonts.dmSans(fontSize: 11,
                    fontWeight: FontWeight.w600, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05))),
                const SizedBox(height: 5),
                TextField(controller: _passCtrl, obscureText: _obscure, textInputAction: TextInputAction.done,
                    decoration: InputDecoration(hintText: 'Enter your password',
                      suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
                        onPressed: () => setState(() => _obscure = !_obscure))),
                    onSubmitted: (_) => _login()),
                const SizedBox(height: 14),
                PrimaryButton(label: 'Sign in', onPressed: _login, isLoading: auth.isLoading),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: Divider(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
                  Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text('or',
                    style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
                  Expanded(child: Divider(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
                ]),
                const SizedBox(height: 16),
                GestureDetector(onTap: () { auth.clearError(); Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RegisterScreen())); },
                  child: RichText(text: TextSpan(style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                    children: [const TextSpan(text: "Don't have an account? "),
                      TextSpan(text: 'Create one', style: GoogleFonts.dmSans(color: isDark ? AppColors.darkAccent : AppColors.accent, fontWeight: FontWeight.w500))]))),
                const SizedBox(height: 8),
                GestureDetector(onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ForgotPasswordScreen())),
                  child: Text('Forgot password?', style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkAccent : AppColors.accent, fontWeight: FontWeight.w500))),
              ]))),
            ),
          ),
        ),
      ),
    );
  }
}
