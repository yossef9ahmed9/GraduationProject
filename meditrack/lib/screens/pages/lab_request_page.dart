
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class LabRequestPage extends StatefulWidget {
  const LabRequestPage({super.key});
  @override
  State<LabRequestPage> createState() => _LabRequestPageState();
}

class _LabRequestPageState extends State<LabRequestPage> {
  LabResponse? _selectedLab;
  final Set<String> _checkedTests = {'CBC'};
  final _notesCtrl = TextEditingController();
  DateTime _appointmentDate = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;
  String? _success;
  String? _error;

  static const _availableTests = [
    'Complete Blood Count (CBC)', 'Blood Glucose', 'HbA1c', 'Lipid Panel',
    'Kidney Function', 'Liver Function', 'Thyroid (TSH)', 'Vitamin D', 'Iron Studies', 'Urine Analysis',
  ];

  static String _testKey(String label) {
    const map = {'Complete Blood Count (CBC)': 'CBC', 'Blood Glucose': 'Glucose'};
    return map[label] ?? label;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final app = context.read<AppProvider>();
      if (app.labs.isNotEmpty && _selectedLab == null) {
        setState(() => _selectedLab = app.labs.first);
      }
    });
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_checkedTests.isEmpty) {
      setState(() => _error = 'Please select at least one test.');
      return;
    }
    if (_selectedLab == null) {
      setState(() => _error = 'Please select a lab.');
      return;
    }
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    int? patientId = auth.role == UserRole.patient
        ? app.patientByEmail(auth.user?.email ?? '')?.id
        : null;
    patientId ??= app.patients.isNotEmpty ? app.patients.first.id : null;
    if (patientId == null) {
      setState(() => _error = 'Could not determine patient.');
      return;
    }
    setState(() { _submitting = true; _error = null; _success = null; });
    final res = await apiService.createLabAppointment(LabAppointmentRequest(
      patientId:       patientId,
      labId:           _selectedLab!.id,
      testNames:       _checkedTests.toList(),
      appointmentDate: _appointmentDate,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
    await app.refreshLabAppointments();
    setState(() {
      _submitting = false;
      if (res.ok) {
        _success = 'Appointment booked with ${_selectedLab!.name}!';
        _checkedTests.clear();
      } else {
        _error = res.error ?? 'Failed to book appointment.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (_selectedLab == null && app.labs.isNotEmpty) _selectedLab = app.labs.first;

    return RefreshIndicator(
      onRefresh: () => context.read<AppProvider>().refreshLabs(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Request a Lab Test',
                    style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w700, letterSpacing: -0.3)),
                const SizedBox(height: 4),
                Text('Choose a lab and the tests you need',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 20),
                if (_success != null) ...[AlertWidget(message: _success!), const SizedBox(height: 14)],
                if (_error   != null) ...[AlertWidget(message: _error!, isError: true), const SizedBox(height: 14)],

                // ── Lab selector ──────────────────────────────────
                Text('SELECT LAB',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        letterSpacing: 0.05)),
                const SizedBox(height: 8),
                if (app.labs.isEmpty)
                  const EmptyState(message: 'No labs available', icon: Icons.science_outlined)
                else
                  Wrap(
                    spacing: 8, runSpacing: 8,
                    children: app.labs.map((l) => GestureDetector(
                      onTap: () => setState(() => _selectedLab = l),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: _selectedLab?.id == l.id
                              ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
                              : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _selectedLab?.id == l.id
                                ? (isDark ? AppColors.darkAccent : AppColors.accent)
                                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
                          ),
                        ),
                        child: Text(l.name,
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                                color: _selectedLab?.id == l.id
                                    ? (isDark ? AppColors.darkAccent : AppColors.accent)
                                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
                      ),
                    )).toList(),
                  ),

                // ── Test selector ─────────────────────────────────
                const SizedBox(height: 20),
                Text('SELECT TESTS',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        letterSpacing: 0.05)),
                const SizedBox(height: 8),
                AppCard(
                  child: Column(
                    children: _availableTests.map((t) => CheckboxListTile(
                      dense: true,
                      title: Text(_testKey(t), style: GoogleFonts.dmSans(fontSize: 13)),
                      subtitle: Text(t != _testKey(t) ? t : '',
                          style: GoogleFonts.dmSans(fontSize: 11,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
                      value: _checkedTests.contains(_testKey(t)),
                      onChanged: (v) => setState(() {
                        if (v == true) _checkedTests.add(_testKey(t));
                        else _checkedTests.remove(_testKey(t));
                      }),
                    )).toList(),
                  ),
                ),

                // ── Date ─────────────────────────────────────────
                const SizedBox(height: 16),
                Text('APPOINTMENT DATE',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        letterSpacing: 0.05)),
                const SizedBox(height: 8),
                AppCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(Icons.calendar_month_outlined, size: 18,
                        color: isDark ? AppColors.darkAccent : AppColors.accent),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      '${_appointmentDate.day}/${_appointmentDate.month}/${_appointmentDate.year}',
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                    )),
                    TextButton(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _appointmentDate,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) setState(() => _appointmentDate = picked);
                      },
                      child: const Text('Change'),
                    ),
                  ]),
                ),

                // ── Notes ─────────────────────────────────────────
                const SizedBox(height: 16),
                Text('NOTES (OPTIONAL)',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        letterSpacing: 0.05)),
                const SizedBox(height: 5),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(hintText: 'Any additional notes for the lab...'),
                ),
                const SizedBox(height: 16),
                PrimaryButton(
                  label: 'Submit Request',
                  isLoading: _submitting,
                  onPressed: _submit,
                ),

                // ── Past appointments ─────────────────────────────
                if (app.labAppointments.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text('Lab Appointments',
                      style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 10),
                  ...app.labAppointments.take(10).map((a) => AppCard(
                    padding: const EdgeInsets.all(12),
                    child: Row(children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(a.testNames.join(', '),
                            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                        Text(
                          a.labName.isNotEmpty ? a.labName : 'Lab #${a.labId}',
                          style: GoogleFonts.dmSans(fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                      ])),
                      BadgeWidget(
                        label: a.status,
                        type: a.status == 'Completed' ? BadgeType.green
                            : a.status == 'Cancelled'  ? BadgeType.red
                            : BadgeType.amber,
                      ),
                    ]),
                  )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
