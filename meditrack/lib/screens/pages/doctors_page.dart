import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});

  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  bool _booking = false;

  Future<void> _bookWithDoctor(DoctorResponse doctor) async {
    final app = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final patientId = app.patientByEmail(auth.user?.email ?? '')?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not identify patient.', style: GoogleFonts.dmSans()),
      ));
      return;
    }

    final data = await showDialog<_BookingData>(
      context: context,
      builder: (_) => _BookDoctorDialog(doctor: doctor),
    );
    if (data == null) return;

    setState(() => _booking = true);
    final res = await apiService.addFollowUp(FollowUpRequest(
      diagnosis: data.reason,
      treatmentPlan:
          data.treatmentPlan.isNotEmpty ? data.treatmentPlan : 'To be determined',
      notes: data.notes.isNotEmpty
          ? data.notes
          : 'Appointment: ${data.date.day}/${data.date.month}/${data.date.year} ${data.time}',
      patientId: patientId,
      doctorId: doctor.id,
    ));

    if (!mounted) return;
    if (res.ok) {
      await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
    }
    if (!mounted) return;
    setState(() => _booking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        res.ok
            ? 'Follow-up booked with Dr. ${doctor.name}'
            : (res.error ?? 'Failed to book.'),
        style: GoogleFonts.dmSans(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final canBook = auth.role == UserRole.patient;

    return RefreshIndicator(
      onRefresh: () => app.refreshDoctors(),
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
                  child: Text(
                    '${app.doctors.length} doctor${app.doctors.length != 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
              if (app.isLoading)
                const SliverToBoxAdapter(child: LoadingRows(count: 5))
              else if (app.doctors.isEmpty)
                const SliverToBoxAdapter(
                  child: EmptyState(
                    message: 'No doctors found',
                    icon: Icons.medical_services_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _DoctorCard(
                        doctor: app.doctors[i],
                        canBook: canBook,
                        onBook: () => _bookWithDoctor(app.doctors[i]),
                      ),
                      childCount: app.doctors.length,
                    ),
                  ),
                ),
            ],
          ),
          if (_booking)
            const IgnorePointer(
              child: SizedBox.expand(child: ColoredBox(color: Colors.black12)),
            ),
        ],
      ),
    );
  }
}

class _DoctorCard extends StatelessWidget {
  final DoctorResponse doctor;
  final bool canBook;
  final VoidCallback onBook;

  const _DoctorCard({
    required this.doctor,
    required this.canBook,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AvatarWidget(initials: doctor.initials, size: 40, fontSize: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.specialization,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.email,
                  style: GoogleFonts.dmSans(
                    fontSize: 11.5,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (doctor.isAvailable != null)
                BadgeWidget(
                  label: doctor.isAvailable! ? 'Available' : 'Busy',
                  type: doctor.isAvailable! ? BadgeType.green : BadgeType.amber,
                ),
              if (canBook) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: doctor.isAvailable == false ? null : onBook,
                  icon: const Icon(Icons.calendar_month_outlined, size: 14),
                  label: Text('Book', style: GoogleFonts.dmSans(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _BookingData {
  final DateTime date;
  final String time;
  final String reason;
  final String treatmentPlan;
  final String notes;

  const _BookingData({
    required this.date,
    required this.time,
    required this.reason,
    required this.treatmentPlan,
    required this.notes,
  });
}

class _BookDoctorDialog extends StatefulWidget {
  final DoctorResponse doctor;
  const _BookDoctorDialog({required this.doctor});

  @override
  State<_BookDoctorDialog> createState() => _BookDoctorDialogState();
}

class _BookDoctorDialogState extends State<_BookDoctorDialog> {
  final DateTime _date = DateTime.now();
  String _time = '09:00';
  String _reason = 'Routine checkup';
  final _treatmentCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  static const _timeSlots = [
    '09:00',
    '10:00',
    '11:00',
    '12:00',
    '14:00',
    '15:00',
    '16:00',
  ];

  static const _reasons = [
    'Routine checkup',
    'Medication review',
    'New symptoms',
    'Test result discussion',
    'Post-procedure follow-up',
    'Chronic disease management',
    'Other',
  ];

  @override
  void dispose() {
    _treatmentCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AlertDialog(
      title: Text(
        'Book Dr. ${widget.doctor.name}',
        style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TIME',
              style: GoogleFonts.dmSans(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _timeSlots.map((t) {
                return ChoiceChip(
                  label: Text(t, style: GoogleFonts.dmSans(fontSize: 12)),
                  selected: _time == t,
                  onSelected: (_) => setState(() => _time = t),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _reason,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reasons.map((r) {
                return DropdownMenuItem(value: r, child: Text(r));
              }).toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _treatmentCtrl,
              decoration: const InputDecoration(labelText: 'Treatment plan'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl,
              minLines: 2,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(_BookingData(
            date: _date,
            time: _time,
            reason: _reason,
            treatmentPlan: _treatmentCtrl.text.trim(),
            notes: _notesCtrl.text.trim(),
          )),
          child: const Text('Confirm'),
        ),
      ],
    );
  }
}
