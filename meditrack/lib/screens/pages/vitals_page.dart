
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class VitalsPage extends StatefulWidget {
  const VitalsPage({super.key});
  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  int? _selectedPatientId;
  List<VitalSignsResponse> _history = [];
  bool _loading = false;
  String? _error;

  @override
  void initState() { super.initState(); WidgetsBinding.instance.addPostFrameCallback((_) => _init()); }

  void _init() {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final role = auth.role;
    int? id;
    if (role == UserRole.patient) {
      id = app.patientByEmail(auth.user?.email ?? '')?.id ?? (app.patients.isNotEmpty ? app.patients.first.id : null);
    } else {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    }
    if (id != null) _loadVitals(id);
  }

  Future<void> _loadVitals(int patientId) async {
    setState(() { _loading = true; _error = null; _selectedPatientId = patientId; });
    try {
      final res = await apiService.getVitalsByPatient(patientId);
      await apiService.getPatientProgress(patientId, limit: 100);
      if (res.ok) {
        setState(() {
          _history = res.data ?? [];
          _loading = false;
        });
      } else {
        setState(() { _error = res.error ?? 'Failed to load vitals.'; _loading = false; });
      }
    } catch (e) { setState(() { _error = e.toString(); _loading = false; }); }
  }

  String _alertText(VitalSignsResponse v) {
    if (v.heartRate > 100) return 'Heart rate ${v.heartRate} bpm — elevated';
    if (v.heartRate < 60) return 'Heart rate ${v.heartRate} bpm — low';
    if ((v.oxygenSaturation ?? 100) < 95) return 'SpO₂ ${v.oxygenSaturation?.toStringAsFixed(1)}% — low';
    return 'Emergency status active';
  }

  @override
  Widget build(BuildContext context) {
    final app  = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role = auth.role;
    final latest = _history.isNotEmpty ? _history.first : null;
    final hrHigh = (latest?.heartRate ?? 0) > 100;
    final hrLow  = (latest?.heartRate ?? 0) < 60 && latest != null;
    final o2Low  = (latest?.oxygenSaturation ?? 100) < 95 && latest != null;
    final isAlert = latest?.isAlert ?? false;
    final selectorPatients = (role == UserRole.patient || role == UserRole.relative)
        ? (app.patients.isNotEmpty ? [app.patients.first] : <PatientResponse>[])
        : app.patients;

    return RefreshIndicator(
      onRefresh: () async { if (_selectedPatientId != null) await _loadVitals(_selectedPatientId!); },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (selectorPatients.isNotEmpty) ...[
              const Icon(Icons.person_outline, size: 15),
              const SizedBox(width: 6),
              Expanded(child: role == UserRole.patient || role == UserRole.relative
                ? Text(selectorPatients.first.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500))
                : DropdownButton<int>(
                    value: _selectedPatientId, isDense: true, underline: const SizedBox(),
                    style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    items: selectorPatients.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} — #${p.id}'))).toList(),
                    onChanged: (id) { if (id != null) _loadVitals(id); })),
            ] else Text('No patients', style: GoogleFonts.dmSans(fontSize: 13, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _selectedPatientId != null ? () => _loadVitals(_selectedPatientId!) : null,
              icon: const Icon(Icons.refresh_rounded, size: 18), tooltip: 'Refresh',
              style: IconButton.styleFrom(padding: const EdgeInsets.all(6), minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
          ]),
          const SizedBox(height: 14),
          if (_error != null) ...[AlertWidget(message: _error!, isError: true), const SizedBox(height: 12)],
          if (isAlert && latest != null) ...[EmergencyBanner(text: _alertText(latest)), const SizedBox(height: 12)],
          if (_loading) const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 40), child: CircularProgressIndicator()))
          else if (latest == null) const EmptyState(message: 'No vitals data for this patient', icon: Icons.monitor_heart_outlined)
          else ...[
            GridView.count(crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
              children: [
                VitalCard(label: 'Heart rate', value: '${latest.heartRate}', unit: 'bpm',
                  valueColor: hrHigh || hrLow ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null),
                VitalCard(label: 'Oxygen saturation', value: latest.oxygenSaturation?.toStringAsFixed(1) ?? '—', unit: '% SpO₂',
                  valueColor: o2Low ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null),
                VitalCard(label: 'Temperature', value: latest.temperature?.toStringAsFixed(1) ?? '—', unit: '°C'),
                VitalCard(label: 'Blood pressure', value: latest.bpDisplay, unit: 'mmHg'),
                VitalCard(label: 'Respiratory rate', value: latest.respiratoryRate?.toString() ?? '—', unit: 'breaths/min'),
                VitalCard(label: 'Blood glucose', value: latest.bloodGlucose?.toStringAsFixed(1) ?? '—', unit: 'mg/dL'),
              ]),
            const SizedBox(height: 16),
            AppCard(child: Column(children: [
              const CardHeader(title: 'Vitals history'),
              if (_history.isEmpty) const EmptyState(message: 'No history')
              else SingleChildScrollView(scrollDirection: Axis.horizontal, child: DataTable(
                headingRowHeight: 36, dataRowMinHeight: 40, dataRowMaxHeight: 48, columnSpacing: 20,
                headingTextStyle: GoogleFonts.dmSans(fontSize: 10.5, fontWeight: FontWeight.w700,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05),
                dataTextStyle: GoogleFonts.dmSans(fontSize: 12.5, color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                columns: const [
                  DataColumn(label: Text('TIME')), DataColumn(label: Text('HR')),
                  DataColumn(label: Text('SPO₂')), DataColumn(label: Text('TEMP')),
                  DataColumn(label: Text('BP')), DataColumn(label: Text('STATUS')),
                ],
                rows: _history.take(20).map((v) {
                  final ts = DateTime.tryParse(v.timeStamp)?.toLocal();
                  final timeStr = ts != null ? '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')} ${ts.day}/${ts.month}' : '—';
                  return DataRow(cells: [
                    DataCell(Text(timeStr, style: GoogleFonts.dmMono(fontSize: 11.5))),
                    DataCell(Text('${v.heartRate}', style: GoogleFonts.dmMono(fontSize: 12,
                      color: v.heartRate > 100 || v.heartRate < 60 ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null))),
                    DataCell(Text(v.oxygenSaturation?.toStringAsFixed(1) ?? '—', style: GoogleFonts.dmMono(fontSize: 12,
                      color: (v.oxygenSaturation ?? 100) < 95 ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null))),
                    DataCell(Text(v.temperature?.toStringAsFixed(1) ?? '—', style: GoogleFonts.dmMono(fontSize: 12))),
                    DataCell(Text(v.bpDisplay, style: GoogleFonts.dmMono(fontSize: 12))),
                    DataCell(BadgeWidget(label: v.emergencyStatus ? 'Alert' : 'Normal',
                      type: v.emergencyStatus ? BadgeType.red : BadgeType.green)),
                  ]);
                }).toList(),
              )),
            ])),
          ],
        ]),
      ),
    );
  }
}
