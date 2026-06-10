
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/home_screen.dart';
import 'package:meditrack/screens/pages/ambulance_navigation_page.dart';
import 'package:meditrack/services/api_service.dart';

class DashboardPage extends StatelessWidget {
  final UserRole role;
  const DashboardPage({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    if (app.isLoading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(
      onRefresh: () => app.loadAll(role),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: switch (role) {
          UserRole.patient   => _PatientDash(app: app, auth: auth),
          UserRole.doctor    => _DoctorDash(app: app),
          UserRole.lab       => _LabDash(app: app),
          UserRole.relative  => _RelativeDash(app: app),
          UserRole.ambulance => _AmbulanceDash(app: app),
          _                  => _AdminDash(app: app),
        },
      ),
    );
  }
}

// ── Patient ───────────────────────────────────────────────────
class _PatientDash extends StatelessWidget {
  final AppProvider app; final AuthProvider auth;
  const _PatientDash({required this.app, required this.auth});
  @override
  Widget build(BuildContext context) {
    final user   = auth.user;
    final mine   = user != null ? app.patientByEmail(user.email) : null;
    final latest = mine != null ? app.latestVitalForPatient(mine.id) : null;
    final myTests = mine != null ? app.testsForPatient(mine.id) : <MedicalTestResponse>[];
    final myFups  = mine != null ? app.followUpsForPatient(mine.id) : app.followUps;
    final hrHigh  = (latest?.heartRate ?? 0) > 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeBanner(icon: Icons.person_outline, text: 'Welcome back, ${user?.name.split(' ').first ?? ''}! Here\'s a summary of your health status.'),
      const SizedBox(height: 16),
      if (hrHigh) ...[
        EmergencyBanner(text: '${mine?.name ?? 'You'} — Heart rate ${latest!.heartRate} bpm (elevated)',
          onViewVitals: () => HomeNavigator.go(context, 'vitals')),
        const SizedBox(height: 12),
      ],
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.6,
        children: [
          StatCard(label: 'My Follow-ups', value: '${myFups.length}', subtitle: 'Active records'),
          StatCard(label: 'My Tests', value: '${myTests.length}', subtitle: 'Lab results'),
          StatCard(label: 'Heart Rate', value: latest != null ? '${latest.heartRate}' : '—',
            subtitle: latest != null ? 'bpm · latest' : 'No data', valueColor: hrHigh ? AppColors.badgeRedTxt : null),
          StatCard(label: 'SpO₂',
            value: latest?.oxygenSaturation != null ? '${latest!.oxygenSaturation!.toStringAsFixed(1)}' : '—',
            subtitle: latest != null ? '% · latest' : 'No data',
            valueColor: (latest?.oxygenSaturation ?? 100) < 95 ? AppColors.badgeRedTxt : null),
        ]),
      const SizedBox(height: 16),
      AppCard(child: Column(children: [
        CardHeader(title: 'Recent Follow-ups',
          trailing: TextButton(onPressed: () => HomeNavigator.go(context, 'followups'),
            child: Text('View all', style: GoogleFonts.dmSans(fontSize: 12)))),
        if (myFups.isEmpty) const EmptyState(message: 'No follow-ups yet')
        else ...myFups.take(3).map((f) => _FollowUpRow(followUp: f, showPatient: false, doctorName: app.doctorName(f.doctorId))),
      ])),
    ]);
  }
}

// ── Doctor ────────────────────────────────────────────────────
class _DoctorDash extends StatelessWidget {
  final AppProvider app;
  const _DoctorDash({required this.app});
  @override
  Widget build(BuildContext context) {
    final emergency = app.emergencyVitals.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeBanner(icon: Icons.medical_services_outlined, text: 'Doctor dashboard — Manage your patients and medical records.'),
      const SizedBox(height: 16),
      if (emergency > 0) ...[
        EmergencyBanner(text: '${app.emergencyVitals.first.patientName} — ${_emergencyDesc(app.emergencyVitals.first)}',
          onViewVitals: () => HomeNavigator.go(context, 'vitals')),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: StatCard(label: 'Patients', value: '${app.patients.length}', subtitle: 'Registered')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Follow-ups', value: '${app.followUps.length}', subtitle: 'Active records')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Alerts', value: '$emergency', subtitle: 'Elevated vitals',
          valueColor: emergency > 0 ? AppColors.badgeRedTxt : null)),
      ]),
      const SizedBox(height: 16),
      AppCard(child: Column(children: [
        CardHeader(title: 'Patients', trailing: TextButton(onPressed: () => HomeNavigator.go(context, 'patients'),
          child: Text('View all', style: GoogleFonts.dmSans(fontSize: 12)))),
        if (app.patients.isEmpty) const EmptyState(message: 'No patients')
        else ...app.patients.take(5).map((p) => _PatientRow(patient: p)),
      ])),
      const SizedBox(height: 12),
      AppCard(child: Column(children: [
        CardHeader(title: 'Recent Follow-ups', trailing: TextButton(onPressed: () => HomeNavigator.go(context, 'followups'),
          child: Text('View all', style: GoogleFonts.dmSans(fontSize: 12)))),
        if (app.followUps.isEmpty) const EmptyState(message: 'No follow-ups')
        else ...app.followUps.take(4).map((f) => _FollowUpRow(followUp: f, patientName: app.patientName(f.patientId), showDoctor: false)),
      ])),
    ]);
  }
}

// ── Lab ───────────────────────────────────────────────────────
class _LabDash extends StatelessWidget {
  final AppProvider app;
  const _LabDash({required this.app});
  @override
  Widget build(BuildContext context) {
    final pending = app.tests.where((t) => t.result.isEmpty || t.result == 'Pending').length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeBanner(icon: Icons.science_outlined, text: 'Lab dashboard — Manage test requests and results.'),
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: StatCard(label: 'Total Tests', value: '${app.tests.length}')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Pending', value: '$pending')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Labs', value: '${app.labs.length}')),
      ]),
      const SizedBox(height: 16),
      AppCard(child: Column(children: [
        CardHeader(title: 'Recent Test Requests', trailing: TextButton(onPressed: () => HomeNavigator.go(context, 'tests'),
          child: Text('View all', style: GoogleFonts.dmSans(fontSize: 12)))),
        if (app.tests.isEmpty) const EmptyState(message: 'No tests')
        else ...app.tests.take(5).map((t) => _TestRow(test: t)),
      ])),
    ]);
  }
}

// ── Relative ──────────────────────────────────────────────────
class _RelativeDash extends StatelessWidget {
  final AppProvider app;
  const _RelativeDash({required this.app});
  @override
  Widget build(BuildContext context) {
    final linked = app.patients.isNotEmpty ? app.patients.first : null;
    final latest = linked != null ? app.latestVitalForPatient(linked.id) : null;
    final hrHigh = (latest?.heartRate ?? 0) > 100;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeBanner(icon: Icons.home_outlined, text: 'Home — Monitoring health status for your linked patient.'),
      const SizedBox(height: 16),
      if (hrHigh) ...[
        EmergencyBanner(text: '${linked?.name ?? 'Patient'} — Heart rate ${latest!.heartRate} bpm (elevated)',
          onViewVitals: () => HomeNavigator.go(context, 'vitals')),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: StatCard(label: 'Linked Patient', value: linked?.name ?? '—', subtitle: 'Patient #${linked?.id ?? '—'}')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Heart Rate', value: latest != null ? '${latest.heartRate}' : '—',
          subtitle: 'bpm · latest', valueColor: hrHigh ? AppColors.badgeRedTxt : null)),
      ]),
    ]);
  }
}

// ── Ambulance ─────────────────────────────────────────────────
class _AmbulanceDash extends StatelessWidget {
  final AppProvider app;
  const _AmbulanceDash({required this.app});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final auth    = context.read<AuthProvider>();
    // Watch NotificationProvider so the card rebuilds when patient becomes stable
    context.watch<NotificationProvider>();
    final myEmail = auth.user?.email.toLowerCase() ?? '';
    final myAmb   = app.ambulances
        .where((a) => a.email.toLowerCase() == myEmail)
        .firstOrNull;

    final myDispatches = myAmb != null
        ? app.dispatches.where((d) => d.ambulanceId == myAmb.id).toList()
        : <EmergencyDispatchResponse>[];

    final pending  = myDispatches.where((d) => d.status == 'Pending').toList();
    final active   = myDispatches
        .where((d) => d.status == 'OnTheWay' || d.status == 'Arrived')
        .toList();
    final resolved = myDispatches.where((d) => d.status == 'Resolved').toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── Status card ──────────────────────────────────────────
      if (myAmb != null) _AmbStatusCard(ambulance: myAmb, isDark: isDark),
      const SizedBox(height: 16),

      // ── Pending dispatch — big action card ───────────────────
      if (pending.isNotEmpty) ...[
        ...pending.map((d) => _PendingDispatchCard(
            dispatch: d, app: app, isDark: isDark)),
        const SizedBox(height: 16),
      ],

      // ── Active dispatch — navigate card ──────────────────────
      if (active.isNotEmpty) ...[
        ...active.map((d) => _ActiveDispatchCard(
            dispatch: d, app: app, isDark: isDark, myAmbId: myAmb?.id)),
        const SizedBox(height: 16),
      ],

      // ── Waiting ───────────────────────────────────────────────
      if (pending.isEmpty && active.isEmpty) ...[
        _WaitingForDispatchCard(isDark: isDark),
        const SizedBox(height: 16),
      ],

      // ── Stats ─────────────────────────────────────────────────
      Row(children: [
        Expanded(child: StatCard(
            label: 'Resolved Today', value: '${resolved.length}')),
        const SizedBox(width: 12),
        Expanded(child: StatCard(
            label: 'Total Dispatches', value: '${myDispatches.length}')),
      ]),
    ]);
  }
}

// ── Ambulance status card ─────────────────────────────────────
class _AmbStatusCard extends StatelessWidget {
  final AmbulanceResponse ambulance;
  final bool isDark;
  const _AmbStatusCard({required this.ambulance, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final status = ambulance.availabilityStatus;
    final bt = status == 'Available'
        ? BadgeType.green
        : status == 'Busy'
            ? BadgeType.red
            : BadgeType.amber;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Row(children: [
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.emergency_outlined, size: 22,
              color: isDark ? AppColors.darkAccent : AppColors.accent),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ambulance.driverName,
              style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          Text(ambulance.licensePlate,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
        ])),
        BadgeWidget(label: status, type: bt),
      ]),
    );
  }
}

// ── Pending dispatch card — Accept / Reject ───────────────────
class _PendingDispatchCard extends StatelessWidget {
  final EmergencyDispatchResponse dispatch;
  final AppProvider app;
  final bool isDark;
  const _PendingDispatchCard(
      {required this.dispatch, required this.app, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final patName =
        app.patientName(dispatch.patientId) ?? 'Patient #${dispatch.patientId}';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2D1A1A) : const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                .withValues(alpha: 0.5),
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(Icons.emergency_rounded,
              color:
                  isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
              size: 18),
          const SizedBox(width: 8),
          Text('🚨 Emergency Dispatch',
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isDark
                      ? AppColors.darkBadgeRedTxt
                      : AppColors.badgeRedTxt)),
        ]),
        const SizedBox(height: 8),
        Text(patName,
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w700)),
        if (dispatch.notes != null && dispatch.notes!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(dispatch.notes!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
        ],
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () async {
                final res = await apiService.acceptDispatch(dispatch.id);
                if (context.mounted) {
                  await app.refreshDispatches();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(res.ok
                          ? 'Accepted! Navigate to patient.'
                          : (res.error ?? 'Failed.'))));
                }
              },
              icon: const Icon(Icons.check_rounded, size: 18),
              label: Text('Accept',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.badgeGreenTxt,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () async {
                await apiService.rejectDispatch(dispatch.id);
                if (context.mounted) await app.refreshDispatches();
              },
              icon: const Icon(Icons.close_rounded, size: 18),
              label: Text('Reject',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
                side: BorderSide(
                    color: isDark
                        ? AppColors.darkBadgeRedTxt
                        : AppColors.badgeRedTxt),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Active dispatch card — Navigate + Mark Arrived / Resolve ──
class _ActiveDispatchCard extends StatelessWidget {
  final EmergencyDispatchResponse dispatch;
  final AppProvider app;
  final bool isDark;
  final int? myAmbId;
  const _ActiveDispatchCard(
      {required this.dispatch,
      required this.app,
      required this.isDark,
      this.myAmbId});

  @override
  Widget build(BuildContext context) {
    final patName =
        app.patientName(dispatch.patientId) ?? 'Patient #${dispatch.patientId}';
    final isOnTheWay = dispatch.status == 'OnTheWay';
    final notifPr    = context.watch<NotificationProvider>();

    // Patient is stable if:
    // 1. NotificationProvider received a normal_vitals FCM, OR
    // 2. Patient's isInEmergency flag is false (backend cleared it when vitals normalized)
    final patient = app.patients
        .where((p) => p.id == dispatch.patientId)
        .firstOrNull;
    final isVitalsNormal = patient != null && !patient.isInEmergency;

    final patientStable = notifPr.isPatientStable(dispatch.patientId) || isVitalsNormal;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1E2D) : const Color(0xFFF0F7FF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color:
                (isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt)
                    .withValues(alpha: 0.5),
            width: 1.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
              isOnTheWay
                  ? Icons.directions_car_rounded
                  : Icons.local_hospital_rounded,
              color:
                  isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt,
              size: 18),
          const SizedBox(width: 8),
          Text(
              isOnTheWay ? 'On the way to patient' : 'Arrived at patient',
              style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? AppColors.darkBadgeBlueTxt
                      : AppColors.badgeBlueTxt)),
        ]),
        const SizedBox(height: 8),
        Text(patName,
            style: GoogleFonts.dmSans(
                fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),

        // ── Patient Stable banner ─────────────────────────────
        if (patientStable) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F5E9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF66BB6A)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Patient vitals back to normal',
                    style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32))),
              ),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                context.read<NotificationProvider>()
                    .clearPatientStable(dispatch.patientId);
                await app.updateDispatchStatus(dispatch.id, 'Cancelled');
                if (context.mounted) await app.refreshDispatches();
              },
              icon: const Icon(Icons.cancel_outlined, size: 16),
              label: Text('Cancel Transport — Patient Stable',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2E7D32),
                side: const BorderSide(color: Color(0xFF66BB6A)),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],

        Row(children: [
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AmbulanceNavigationPage(
                  dispatch:    dispatch,
                  patientName: patName,
                  ambulanceId: myAmbId ?? 0,
                ),
              )),
              icon: const Icon(Icons.navigation_rounded, size: 18),
              label: Text('Navigate',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isDark ? AppColors.darkAccent : AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                final newStatus = isOnTheWay ? 'Arrived' : 'Resolved';
                await app.updateDispatchStatus(dispatch.id, newStatus);
                if (context.mounted) await app.refreshDispatches();
              },
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: Text(isOnTheWay ? 'Mark Arrived' : 'Resolve',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
            ),
          ),
        ]),
      ]),
    );
  }
}

// ── Waiting card ──────────────────────────────────────────────
class _WaitingForDispatchCard extends StatelessWidget {
  final bool isDark;
  const _WaitingForDispatchCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Row(children: [
        Icon(Icons.check_circle_outline_rounded,
            color: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt,
            size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text("You're Available",
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text('Waiting for dispatch request…',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ]),
        ),
      ]),
    );
  }
}

// ── Admin ─────────────────────────────────────────────────────
class _AdminDash extends StatelessWidget {
  final AppProvider app;
  const _AdminDash({required this.app});
  @override
  Widget build(BuildContext context) {
    final emergency = app.emergencyVitals.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (emergency > 0) ...[
        EmergencyBanner(text: '${app.emergencyVitals.first.patientName} — ${_emergencyDesc(app.emergencyVitals.first)}',
          onViewVitals: () => HomeNavigator.go(context, 'vitals')),
        const SizedBox(height: 12),
      ],
      GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.7,
        children: [
          StatCard(label: 'Total Patients', value: '${app.patients.length}'),
          StatCard(label: 'Doctors', value: '${app.doctors.length}'),
          StatCard(label: 'Sensors', value: '${app.sensors.length}'),
          StatCard(label: 'Alerts', value: '$emergency',
            valueColor: emergency > 0 ? AppColors.badgeRedTxt : null),
        ]),
    ]);
  }
}

// ── Helpers ───────────────────────────────────────────────────
String _emergencyDesc(VitalSignsResponse v) {
  if (v.heartRate > 100) return 'HR ${v.heartRate} bpm (elevated)';
  if ((v.oxygenSaturation ?? 100) < 95) return 'SpO₂ ${v.oxygenSaturation?.toStringAsFixed(1)}% (low)';
  return 'Emergency status';
}

class _WelcomeBanner extends StatelessWidget {
  final IconData icon; final String text;
  const _WelcomeBanner({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
      child: Row(children: [
        Icon(icon, size: 18, color: isDark ? AppColors.darkAccent : AppColors.accent),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: GoogleFonts.dmSans(fontSize: 13,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
      ]));
  }
}

class _PatientRow extends StatelessWidget {
  final PatientResponse patient;
  const _PatientRow({required this.patient});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        AvatarWidget(initials: patient.initials, photoUrl: patient.profilePictureUrl),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(patient.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(patient.email, style: GoogleFonts.dmSans(fontSize: 11.5,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ])),
        BadgeWidget(label: patient.gender.isNotEmpty ? patient.gender[0].toUpperCase() + patient.gender.substring(1) : '—',
          type: patient.gender == 'female' ? BadgeType.blue : BadgeType.green),
      ]));
  }
}

class _FollowUpRow extends StatelessWidget {
  final FollowUpResponse followUp;
  final String? patientName; final String? doctorName;
  final bool showPatient; final bool showDoctor;
  const _FollowUpRow({required this.followUp, this.patientName, this.doctorName, this.showPatient = true, this.showDoctor = true});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lu = followUp.lastUpdate != null ? DateTime.tryParse(followUp.lastUpdate!)?.toLocal().toString().split(' ').first ?? '—' : '—';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (showPatient && patientName != null) Text(patientName!, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
          if (showDoctor && doctorName != null) Text(doctorName!, style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Text(followUp.diagnosis.isEmpty ? '—' : followUp.diagnosis, style: GoogleFonts.dmSans(fontSize: 12.5, fontWeight: FontWeight.w500)),
        ])),
        Text(lu, style: GoogleFonts.dmSans(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      ]));
  }
}

class _TestRow extends StatelessWidget {
  final MedicalTestResponse test;
  const _TestRow({required this.test});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = test.date != null ? DateTime.tryParse(test.date!)?.toLocal().toString().split(' ').first ?? '—' : '—';
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(test.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
          Text(test.result.isNotEmpty ? test.result.substring(0, test.result.length.clamp(0, 50)) : 'Pending',
            style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ])),
        Text(date, style: GoogleFonts.dmSans(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      ]));
  }
}
