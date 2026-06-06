
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class PatientsPage extends StatelessWidget {
  const PatientsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    return RefreshIndicator(
      onRefresh: () => app.refreshPatients(role),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
              child: Text('${app.patients.length} patient${app.patients.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            ),
          ),
          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 6))
          else if (app.patients.isEmpty)
            const SliverToBoxAdapter(child: EmptyState(message: 'No patients found', icon: Icons.people_outline))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PatientCard(patient: app.patients[i]),
                  childCount: app.patients.length),
              ),
            ),
        ],
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final PatientResponse patient;
  const _PatientCard({required this.patient});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          AvatarWidget(initials: patient.initials, size: 40, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(patient.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(patient.email, style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              if (patient.phone.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(patient.phone, style: GoogleFonts.dmSans(fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
              ],
              if (patient.isInEmergency) ...[
                const SizedBox(height: 4),
                BadgeWidget(label: 'EMERGENCY', type: BadgeType.red),
              ],
            ]),
          ),
          BadgeWidget(
            label: patient.gender.isNotEmpty ? patient.gender[0].toUpperCase() + patient.gender.substring(1) : '—',
            type: patient.gender.toLowerCase() == 'female' ? BadgeType.blue : BadgeType.green,
          ),
        ],
      ),
    );
  }
}
