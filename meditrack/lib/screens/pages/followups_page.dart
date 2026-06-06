
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class FollowUpsPage extends StatelessWidget {
  const FollowUpsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return RefreshIndicator(
      onRefresh: () => app.refreshFollowUps(role, auth.user?.email ?? ''),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,16,16,10),
            child: Text('${app.followUps.length} follow-up${app.followUps.length != 1 ? "s" : ""}',
              style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)))),
          if (app.isLoading) const SliverToBoxAdapter(child: LoadingRows(count: 5))
          else if (app.followUps.isEmpty) const SliverToBoxAdapter(child: EmptyState(message: 'No follow-ups found', icon: Icons.assignment_outlined))
          else SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            sliver: SliverList(delegate: SliverChildBuilderDelegate(
              (_, i) => _FollowUpCard(followUp: app.followUps[i], app: app,
                showPatient: role != UserRole.patient, showDoctor: role != UserRole.doctor),
              childCount: app.followUps.length)),
          ),
        ],
      ),
    );
  }
}

class _FollowUpCard extends StatelessWidget {
  final FollowUpResponse followUp;
  final AppProvider app;
  final bool showPatient;
  final bool showDoctor;
  const _FollowUpCard({required this.followUp, required this.app, this.showPatient = true, this.showDoctor = true});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pName = app.patientName(followUp.patientId) ?? 'Patient #${followUp.patientId}';
    final dName = app.doctorName(followUp.doctorId) ?? 'Doctor #${followUp.doctorId}';
    final lu = followUp.lastUpdate != null
        ? DateTime.tryParse(followUp.lastUpdate!)?.toLocal().toString().split(' ').first ?? '—' : '—';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (showPatient) Expanded(child: Text(pName, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600))),
          if (!showPatient && showDoctor) Expanded(child: Text(dName, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(lu, style: GoogleFonts.dmSans(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ]),
        if (showPatient && showDoctor) ...[
          const SizedBox(height: 2),
          Text(dName, style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ],
        const SizedBox(height: 6),
        Text(followUp.diagnosis.isNotEmpty ? followUp.diagnosis : '—',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
        if (followUp.treatmentPlan.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('Plan: ${followUp.treatmentPlan}', style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ],
      ]),
    );
  }
}
