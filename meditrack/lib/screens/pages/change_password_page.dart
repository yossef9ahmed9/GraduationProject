import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});
  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _currentCtrl = TextEditingController();
  final _newCtrl     = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _showCurrent = false;
  bool _showNew     = false;
  bool _showConfirm = false;
  bool _saving      = false;

  @override
  void dispose() {
    _currentCtrl.dispose(); _newCtrl.dispose(); _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = _currentCtrl.text;
    final newPw   = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPw.isEmpty || confirm.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill in all fields.')));
      return;
    }
    if (newPw != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New passwords do not match.')));
      return;
    }
    if (newPw.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password must be at least 6 characters.')));
      return;
    }

    setState(() => _saving = true);
    final res = await apiService.changePassword(current, newPw);
    if (!mounted) return;
    setState(() => _saving = false);

    if (res.ok) {
      _currentCtrl.clear(); _newCtrl.clear(); _confirmCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password changed successfully.')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to change password.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: Text('Change Password',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _PwField(
              label: 'Current Password',
              ctrl: _currentCtrl,
              visible: _showCurrent,
              isDark: isDark,
              onToggle: () => setState(() => _showCurrent = !_showCurrent),
            ),
            const SizedBox(height: 16),
            _PwField(
              label: 'New Password',
              ctrl: _newCtrl,
              visible: _showNew,
              isDark: isDark,
              onToggle: () => setState(() => _showNew = !_showNew),
            ),
            const SizedBox(height: 16),
            _PwField(
              label: 'Confirm New Password',
              ctrl: _confirmCtrl,
              visible: _showConfirm,
              isDark: isDark,
              onToggle: () => setState(() => _showConfirm = !_showConfirm),
            ),
            const SizedBox(height: 8),
            Text('Minimum 6 characters.',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Text('Change Password',
                        style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _PwField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool visible;
  final bool isDark;
  final VoidCallback onToggle;
  const _PwField({
    required this.label, required this.ctrl,
    required this.visible, required this.isDark, required this.onToggle,
  });

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label.toUpperCase(),
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              letterSpacing: 0.05)),
      const SizedBox(height: 6),
      TextField(
        controller: ctrl,
        obscureText: !visible,
        decoration: InputDecoration(
          hintText: '••••••••',
          suffixIcon: IconButton(
            icon: Icon(visible ? Icons.visibility_off_rounded : Icons.visibility_rounded, size: 20),
            onPressed: onToggle,
          ),
        ),
      ),
    ],
  );
}
