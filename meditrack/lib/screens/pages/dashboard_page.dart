
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/home_screen.dart';

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
      _WelcomeBanner(icon: Icons.group_outlined, text: 'Family dashboard — Monitoring health status for your linked patient.'),
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
    final alerts = app.vitals.where((v) => v.emergencyStatus).length;
    final activeD = app.activeDispatches.length;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _WelcomeBanner(icon: Icons.emergency_outlined, text: 'Ambulance dashboard — Monitor and manage dispatch requests.'),
      const SizedBox(height: 16),
      if (app.hasEmergency) ...[
        EmergencyBanner(
          text: app.emergencyVitals.isNotEmpty ? '${app.emergencyVitals.first.patientName} — Emergency alert' : 'Emergency alert active',
          onViewVitals: () => HomeNavigator.go(context, 'vitals')),
        const SizedBox(height: 12),
      ],
      Row(children: [
        Expanded(child: StatCard(label: 'Active Dispatches', value: '$activeD', subtitle: 'In progress',
          valueColor: activeD > 0 ? AppColors.badgeRedTxt : null)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Vitals Alerts', value: '$alerts', subtitle: 'From vitals API',
          valueColor: alerts > 0 ? AppColors.badgeRedTxt : null)),
        const SizedBox(width: 12),
        Expanded(child: StatCard(label: 'Patients', value: '${app.patients.length}')),
      ]),
    ]);
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
        AvatarWidget(initials: patient.initials),
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
