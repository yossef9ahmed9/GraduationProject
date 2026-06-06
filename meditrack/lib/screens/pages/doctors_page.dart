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
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _selectedSpec;
  bool _booking = false;

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  List<DoctorResponse> _filtered(List<DoctorResponse> all) {
    final q = _query.trim().toLowerCase();
    return all.where((d) {
      final matchesQuery = q.isEmpty ||
          d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q);
      final matchesSpec = _selectedSpec == null || d.specialization == _selectedSpec;
      return matchesQuery && matchesSpec;
    }).toList();
  }

  List<String> _specs(List<DoctorResponse> all) =>
      all.map((d) => d.specialization).where((s) => s.isNotEmpty).toSet().toList()..sort();

  Future<void> _bookWithDoctor(DoctorResponse doctor) async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final patientId = app.patientByEmail(auth.user?.email ?? '')?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Could not identify patient.', style: GoogleFonts.dmSans()),
      ));
      return;
    }

    final data = await showModalBottomSheet<_BookingData>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookDoctorSheet(doctor: doctor),
    );
    if (data == null) return;

    setState(() => _booking = true);
    final res = await apiService.addFollowUp(FollowUpRequest(
      diagnosis: data.reason,
      treatmentPlan: data.treatmentPlan.isNotEmpty ? data.treatmentPlan : 'To be determined',
      notes: data.notes.isNotEmpty
          ? data.notes
          : 'Appointment: ${data.date.day}/${data.date.month}/${data.date.year} ${data.time}',
      patientId: patientId,
      doctorId: doctor.id,
    ));
    if (!mounted) return;
    if (res.ok) await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
    if (!mounted) return;
    setState(() => _booking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        res.ok ? 'Follow-up booked with Dr. ${doctor.name}' : (res.error ?? 'Failed to book.'),
        style: GoogleFonts.dmSans(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app     = context.watch<AppProvider>();
    final auth    = context.watch<AuthProvider>();
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final canBook = auth.role == UserRole.patient;
    final specs   = _specs(app.doctors);
    final filtered = _filtered(app.doctors);

    return RefreshIndicator(
      onRefresh: () => app.refreshDoctors(),
      child: Stack(
        children: [
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              // ── Search ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: 'Search by name or specialization…',
                      prefixIcon: const Icon(Icons.search_rounded, size: 18),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () { _searchCtrl.clear(); setState(() => _query = ''); },
                      )
                          : null,
                    ),
                  ),
                ),
              ),

              // ── Specialization chips ──────────────────────────
              if (specs.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      children: [
                        _SpecChip(label: 'All', selected: _selectedSpec == null,
                            onTap: () => setState(() => _selectedSpec = null)),
                        ...specs.map((s) => _SpecChip(
                          label: s,
                          selected: _selectedSpec == s,
                          onTap: () => setState(
                                  () => _selectedSpec = _selectedSpec == s ? null : s),
                        )),
                      ],
                    ),
                  ),
                ),

              // ── Count ─────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                  child: Text(
                    '${filtered.length} doctor${filtered.length != 1 ? 's' : ''}',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  ),
                ),
              ),

              // ── List ──────────────────────────────────────────
              if (app.isLoading)
                const SliverToBoxAdapter(child: LoadingRows(count: 5))
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    message: _query.isNotEmpty || _selectedSpec != null
                        ? 'No doctors match your search'
                        : 'No doctors found',
                    icon: Icons.medical_services_outlined,
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (_, i) => _DoctorCard(
                        doctor: filtered[i],
                        canBook: canBook,
                        onBook: () => _bookWithDoctor(filtered[i]),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          ),
          if (_booking)
            const IgnorePointer(child: SizedBox.expand(child: ColoredBox(color: Colors.black12))),
        ],
      ),
    );
  }
}

// ── Spec chip ─────────────────────────────────────────────────

class _SpecChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _SpecChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkAccent : AppColors.accent)
              : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.transparent : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500,
                color: selected ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
      ),
    );
  }
}

// ── Doctor card ───────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final DoctorResponse doctor; final bool canBook; final VoidCallback onBook;
  const _DoctorCard({required this.doctor, required this.canBook, required this.onBook});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        AvatarWidget(initials: doctor.initials, size: 40, fontSize: 14),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(doctor.name, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(doctor.specialization, style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkAccent : AppColors.accent, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(doctor.email, style: GoogleFonts.dmSans(fontSize: 11.5,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
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
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}

// ── Booking data ──────────────────────────────────────────────

class _BookingData {
  final DateTime date; final String time; final String reason;
  final String treatmentPlan; final String notes;
  const _BookingData({required this.date, required this.time, required this.reason,
    required this.treatmentPlan, required this.notes});
}

// ── Bottom sheet ──────────────────────────────────────────────

class _BookDoctorSheet extends StatefulWidget {
  final DoctorResponse doctor;
  const _BookDoctorSheet({required this.doctor});
  @override
  State<_BookDoctorSheet> createState() => _BookDoctorSheetState();
}

class _BookDoctorSheetState extends State<_BookDoctorSheet> {
  final DateTime _date = DateTime.now();
  String _time = '09:00';
  String _reason = 'Routine checkup';
  final _treatmentCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  static const _timeSlots = ['09:00','10:00','11:00','12:00','14:00','15:00','16:00'];
  static const _reasons   = ['Routine checkup','Medication review','New symptoms',
    'Test result discussion','Post-procedure follow-up','Chronic disease management','Other'];

  @override
  void dispose() { _treatmentCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final bottom  = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          // drag handle
          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2)))),

          Text('Book Dr. ${widget.doctor.name}',
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(widget.doctor.specialization,
              style: GoogleFonts.dmSans(fontSize: 13,
                  color: isDark ? AppColors.darkAccent : AppColors.accent)),
          const SizedBox(height: 16),

          Text('TIME', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
              children: _timeSlots.map((t) => ChoiceChip(
                label: Text(t, style: GoogleFonts.dmSans(fontSize: 12)),
                selected: _time == t,
                onSelected: (_) => setState(() => _time = t),
              )).toList()),
          const SizedBox(height: 14),

          DropdownButtonFormField<String>(
            value: _reason,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _treatmentCtrl,
            decoration: const InputDecoration(labelText: 'Treatment plan (optional)'),
          ),
          const SizedBox(height: 10),

          TextFormField(
            controller: _notesCtrl,
            minLines: 2, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),

          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(_BookingData(
                date: _date, time: _time, reason: _reason,
                treatmentPlan: _treatmentCtrl.text.trim(),
                notes: _notesCtrl.text.trim(),
              )),
              child: const Text('Confirm'),
            )),
          ]),
        ]),
      ),
    );
  }
}
