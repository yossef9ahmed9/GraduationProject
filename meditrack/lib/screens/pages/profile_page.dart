
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/login_screen.dart';
import 'package:meditrack/models/models.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _savingBloodType = false;

  Future<void> _updateBloodType(PatientResponse patient, String bloodType) async {
    setState(() => _savingBloodType = true);
    final auth = context.read<AuthProvider>();
    final app = context.read<AppProvider>();
    final res = await apiService.updateBloodType(patient.id, bloodType);
    if (res.ok) await app.refreshPatients(auth.role);
    if (!mounted) return;
    setState(() => _savingBloodType = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok ? 'Blood type updated' : (res.error ?? 'Failed to update blood type')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = auth.user;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          AppCard(child: Column(children: [
            Container(padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(border: Border(bottom: BorderSide(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              child: Row(children: [
                Container(width: 60, height: 60, decoration: BoxDecoration(shape: BoxShape.circle,
                  gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient),
                  child: Center(child: Text(user?.initials ?? 'U',
                    style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)))),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user?.name ?? '—', style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user?.email ?? '—', style: GoogleFonts.dmSans(fontSize: 13,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  BadgeWidget(label: auth.role.label, type: BadgeType.blue),
                ])),
              ])),
            Padding(padding: const EdgeInsets.all(16), child: Column(children: [
              _InfoRow('Role', auth.role.label),
              _InfoRow('Email', user?.email ?? '—'),
              _InfoRow('User ID', user?.id ?? '—'),
            ])),
          ])),
          const SizedBox(height: 16),
          AppCard(child: Column(children: [
            const CardHeader(title: 'Session'),
            InkWell(
              onTap: () async {
                final app = context.read<AppProvider>();
                await auth.logout(); app.clear();
                if (!context.mounted) return;
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
              },
              child: Padding(padding: const EdgeInsets.all(16), child: Row(children: [
                Icon(Icons.logout_rounded, size: 18,
                    color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
                const SizedBox(width: 10),
                Text('Sign out', style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)),
              ])),
            ),
          ])),
        ]),
      )),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Row(children: [
      SizedBox(width: 90, child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
      Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 13,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
    ]));
  }
}
