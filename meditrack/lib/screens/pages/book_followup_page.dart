
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class BookFollowUpPage extends StatefulWidget {
  const BookFollowUpPage({super.key});
  @override
  State<BookFollowUpPage> createState() => _BookFollowUpPageState();
}

class _BookFollowUpPageState extends State<BookFollowUpPage> {
  int _step = 1;
  DoctorResponse? _selectedDoc;
  DateTime _date = DateTime.now();
  String _time = '09:00';
  String _reason = '';
  final _treatmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  bool _submitting = false;
  bool _success = false;
  String? _error;

  static const _timeSlots = ['09:00','10:00','11:00','12:00','14:00','15:00','16:00'];
  static const _reasons = ['Routine checkup','Medication review','New symptoms','Test result discussion',
    'Post-procedure follow-up','Chronic disease management','Other'];

  @override
  void dispose() { _treatmentCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  void _goStep(int step) {
    if (step == 2 && _selectedDoc == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a doctor.', style: GoogleFonts.dmSans())));
      return;
    }
    if (step == 3 && _reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please select a reason.', style: GoogleFonts.dmSans())));
      return;
    }
    setState(() { _step = step; _error = null; });
  }

  Future<void> _submit() async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    int? patientId = auth.role == UserRole.patient ? app.patientByEmail(auth.user?.email ?? '')?.id : null;
    patientId ??= app.patients.isNotEmpty ? app.patients.first.id : null;
    if (patientId == null) { setState(() => _error = 'Could not identify patient.'); return; }
    if (_selectedDoc == null) { setState(() => _error = 'No doctor selected.'); return; }
    setState(() { _submitting = true; _error = null; });
    try {
      final res = await apiService.addFollowUp(FollowUpRequest(
        diagnosis: _reason,
        treatmentPlan: _treatmentCtrl.text.trim().isNotEmpty ? _treatmentCtrl.text.trim() : 'To be determined',
        notes: _notesCtrl.text.trim().isNotEmpty ? _notesCtrl.text.trim() : 'Appointment: ${_date.day}/${_date.month}/${_date.year} $_time',
        patientId: patientId!, doctorId: _selectedDoc!.id));
      if (res.ok) {
        await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
        setState(() { _submitting = false; _success = true; });
      } else {
        setState(() { _submitting = false; _error = res.error ?? 'Failed to book.'; });
      }
    } catch (e) { setState(() { _submitting = false; _error = e.toString(); }); }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_success) {
      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.check_circle_outline, size: 56, color: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt),
        const SizedBox(height: 16),
        Text('Follow-up booked!', style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('With Dr. ${_selectedDoc?.name ?? '—'} on ${_date.day}/${_date.month}/${_date.year} at $_time',
          style: GoogleFonts.dmSans(fontSize: 14, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        const SizedBox(height: 20),
        ElevatedButton(onPressed: () => setState(() { _step = 1; _success = false; _selectedDoc = null; _reason = ''; }),
          child: const Text('Book another')),
      ]));
    }

    return SingleChildScrollView(padding: const EdgeInsets.all(16), child: Center(
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 600), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [1,2,3].map((s) => Expanded(child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          height: 4, decoration: BoxDecoration(
            color: s <= _step ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
            borderRadius: BorderRadius.circular(2))))).toList()),
        const SizedBox(height: 20),
        if (_error != null) ...[AlertWidget(message: _error!, isError: true), const SizedBox(height: 12)],

        if (_step == 1) ...[
          Text('Choose a Doctor', style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          if (app.doctors.isEmpty) const EmptyState(message: 'No doctors available', icon: Icons.medical_services_outlined)
          else ...app.doctors.map((d) => GestureDetector(
            onTap: () => setState(() => _selectedDoc = d),
            child: Container(margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _selectedDoc?.id == d.id ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted) : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _selectedDoc?.id == d.id ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              child: Row(children: [
                AvatarWidget(initials: d.initials, size: 38, fontSize: 13),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(d.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(d.specialization, style: GoogleFonts.dmSans(fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ])),
              ])))),
          const SizedBox(height: 16),
          PrimaryButton(label: 'Next →', onPressed: () => _goStep(2)),

        ] else if (_step == 2) ...[
          Text('Pick a Date & Reason', style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Text('TIME', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8, children: _timeSlots.map((t) => GestureDetector(
            onTap: () => setState(() => _time = t),
            child: Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: _time == t ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _time == t ? Colors.transparent : (isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
              child: Text(t, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500,
                color: _time == t ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)))))).toList()),
          const SizedBox(height: 16),
          Text('REASON', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          const SizedBox(height: 8),
          ..._reasons.map((r) => RadioListTile<String>(
            dense: true, title: Text(r, style: GoogleFonts.dmSans(fontSize: 13)),
            value: r, groupValue: _reason, onChanged: (v) => setState(() => _reason = v ?? ''))),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: () => _goStep(1), child: const Text('← Back'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => _goStep(3), child: const Text('Review →'))),
          ]),

        ] else ...[
          Text('Review & Confirm', style: GoogleFonts.dmSans(fontSize: 19, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AppCard(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _ReviewRow('Doctor', _selectedDoc?.name ?? '—'),
            _ReviewRow('Time', '$_time — ${_date.day}/${_date.month}/${_date.year}'),
            _ReviewRow('Reason', _reason),
          ])),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: _submitting ? null : () => _goStep(2), child: const Text('← Back'))),
            const SizedBox(width: 12),
            Expanded(child: PrimaryButton(label: 'Confirm', isLoading: _submitting, onPressed: _submit)),
          ]),
        ],
      ]))));
  }
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  const _ReviewRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
      Expanded(child: Text(value, style: GoogleFonts.dmSans(fontSize: 13))),
    ]));
  }
}
