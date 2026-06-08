import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/relative_link_screen.dart';
import 'package:meditrack/screens/ambulance_tracking_screen.dart';

class RelativePatientsPage extends StatefulWidget {
  const RelativePatientsPage({super.key});

  @override
  State<RelativePatientsPage> createState() => _RelativePatientsPageState();
}

class _RelativePatientsPageState extends State<RelativePatientsPage> {
  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: () => app.refreshPatients(auth.role),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header + Add Patient button
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(children: [
                Expanded(child: Text('My Patients',
                    style: GoogleFonts.dmSans(
                        fontSize: 18, fontWeight: FontWeight.w700))),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const RelativeLinkScreen()),
                  ),
                  icon: const Icon(Icons.person_add_outlined, size: 16),
                  label: Text('Add Patient',
                      style: GoogleFonts.dmSans(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ]),
            ),
          ),

          // Empty state
          if (app.patients.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(children: [
                  Icon(Icons.people_outline, size: 48,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary),
                  const SizedBox(height: 12),
                  Text('No linked patients yet',
                      style: GoogleFonts.dmSans(
                          fontSize: 15, fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Text(
                    'Tap "Add Patient" to search and link to a patient.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary),
                  ),
                ]),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _PatientCard(
                    patient:        app.patients[i],
                    activeDispatch: app.dispatches
                        .where((d) =>
                            d.patientId == app.patients[i].id && d.isActive)
                        .firstOrNull,
                  ),
                  childCount: app.patients.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Patient card ──────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final PatientResponse patient;
  final EmergencyDispatchResponse? activeDispatch;
  const _PatientCard({required this.patient, this.activeDispatch});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          AvatarWidget(
            initials: patient.initials,
            size:     42,
            fontSize: 15,
            photoUrl: patient.profilePictureUrl,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name,
                      style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(patient.email,
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary)),
                  const SizedBox(height: 2),
                  Row(children: [
                    if (patient.bloodType.isNotEmpty &&
                        patient.bloodType != 'Unknown')
                      BadgeWidget(
                          label: patient.bloodType, type: BadgeType.blue),
                    if (patient.isInEmergency) ...[
                      const SizedBox(width: 6),
                      BadgeWidget(label: 'EMERGENCY', type: BadgeType.red),
                    ],
                  ]),
                ]),
          ),
        ]),

        // Track button — only shown when there's an active dispatch
        if (activeDispatch != null) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AmbulanceTrackingScreen(
                  patientId:   patient.id,
                  patientName: patient.name,
                  dispatchId:  activeDispatch!.id,
                ),
              )),
              icon: const Icon(Icons.emergency_rounded, size: 16),
              label: Text('Track Ambulance',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}
