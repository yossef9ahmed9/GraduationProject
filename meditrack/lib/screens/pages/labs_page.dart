import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';
import 'package:meditrack/screens/user_profile_screen.dart';

class LabsPage extends StatefulWidget {
  const LabsPage({super.key});
  @override
  State<LabsPage> createState() => _LabsPageState();
}

class _LabsPageState extends State<LabsPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        final app  = context.read<AppProvider>();
        final auth = context.read<AuthProvider>();
        Future.wait([app.refreshLabs(), app.refreshLabAppointments(),
          app.refreshTests()]);
      }
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  List<LabResponse> _filtered(List<LabResponse> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((l) =>
        l.name.toLowerCase().contains(q) ||
        l.location.toLowerCase().contains(q)).toList();
  }

  void _showBookSheet(LabResponse lab) {
    final auth = context.read<AuthProvider>();
    // Only patients can book tests
    if (auth.role != UserRole.patient) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BookTestSheet(lab: lab),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app      = context.watch<AppProvider>();
    final auth     = context.watch<AuthProvider>();
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final filtered = _filtered(app.labs);
    final canBook  = auth.role == UserRole.patient;

    return RefreshIndicator(
      onRefresh: () => app.refreshLabs(),
      child: Stack(
        children: [
          CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Search
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search labs by name or location…',
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
          // Count
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${filtered.length} lab${filtered.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ),
          ),
          // List
          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 4))
          else if (filtered.isEmpty)
            SliverToBoxAdapter(
              child: EmptyState(
                message: _query.isNotEmpty ? 'No labs match your search' : 'No labs found',
                icon: Icons.science_outlined,
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _LabCard(
                    lab: filtered[i],
                    onChat: () => Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherEmail: filtered[i].email,
                          otherName:  filtered[i].name,
                        ))),
                    onBook: canBook ? () => _showBookSheet(filtered[i]) : null,
                  ),
                  childCount: filtered.length,
                ),
              ),
            ),
        ],
      ),
          Positioned(
            bottom: 16,
            right: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                final app  = context.read<AppProvider>();
                final auth = context.read<AuthProvider>();
                Future.wait([app.refreshLabs(), app.refreshLabAppointments(),
                  app.refreshTests()]);
              },
              tooltip: 'Refresh',
              child: const Icon(Icons.refresh_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Lab Card ─────────────────────────────────────────────────

class _LabCard extends StatelessWidget {
  final LabResponse lab;
  final VoidCallback? onChat;
  final VoidCallback? onBook;
  const _LabCard({required this.lab, this.onChat, this.onBook});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        lab.profilePictureUrl != null && lab.profilePictureUrl!.isNotEmpty
            ? AvatarWidget(
                initials: lab.name.isNotEmpty ? lab.name[0].toUpperCase() : 'L',
                size: 40, fontSize: 14,
                photoUrl: lab.profilePictureUrl,
              )
            : Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.science_outlined, size: 20,
                    color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
              ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(lab.name,
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Row(children: [
              Icon(Icons.location_on_outlined, size: 12,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
              const SizedBox(width: 3),
              Expanded(
                child: Text(lab.location,
                    style: GoogleFonts.dmSans(fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ),
            ]),
            const SizedBox(height: 2),
            Text(lab.phone,
                style: GoogleFonts.dmSans(fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
            const SizedBox(height: 10),
            // Action buttons — full width row, no overflow
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => UserProfileScreen.lab(lab),
                )),
                icon: const Icon(Icons.info_outline_rounded, size: 14),
                label: Text('Profile', style: GoogleFonts.dmSans(fontSize: 12)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              if (onChat != null) ...[
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: onChat,
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                  label: Text('Chat', style: GoogleFonts.dmSans(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              ],
              if (onBook != null) ...[
                const SizedBox(width: 6),
                Expanded(child: OutlinedButton.icon(
                  onPressed: onBook,
                  icon: const Icon(Icons.calendar_month_outlined, size: 14),
                  label: Text('Book', style: GoogleFonts.dmSans(fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                )),
              ],
            ]),
          ]),
        ),
      ]),
    );
  }
}

// ── Book Test Bottom Sheet ────────────────────────────────────

class _BookTestSheet extends StatefulWidget {
  final LabResponse lab;
  const _BookTestSheet({required this.lab});
  @override
  State<_BookTestSheet> createState() => _BookTestSheetState();
}

class _BookTestSheetState extends State<_BookTestSheet> {
  final Set<String> _checked = {'CBC'};
  final _notesCtrl = TextEditingController();
  DateTime _date = DateTime.now().add(const Duration(days: 1));
  bool _submitting = false;
  String? _error;

  static const _availableTests = [
    'Complete Blood Count (CBC)', 'Blood Glucose', 'HbA1c', 'Lipid Panel',
    'Kidney Function', 'Liver Function', 'Thyroid (TSH)', 'Vitamin D',
    'Iron Studies', 'Urine Analysis',
  ];

  static String _key(String label) {
    const map = {'Complete Blood Count (CBC)': 'CBC', 'Blood Glucose': 'Glucose'};
    return map[label] ?? label;
  }

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_checked.isEmpty) { setState(() => _error = 'Select at least one test.'); return; }
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    int? patientId = auth.role == UserRole.patient
        ? app.patientByEmail(auth.user?.email ?? '')?.id
        : null;
    patientId ??= app.patients.isNotEmpty ? app.patients.first.id : null;
    if (patientId == null) { setState(() => _error = 'Could not determine patient.'); return; }

    setState(() { _submitting = true; _error = null; });
    final res = await apiService.createLabAppointment(LabAppointmentRequest(
      patientId: patientId,
      labId: widget.lab.id,
      testNames: _checked.toList(),
      appointmentDate: _date,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    ));
    await app.refreshLabAppointments();
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.ok) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Appointment booked with ${widget.lab.name}!',
            style: GoogleFonts.dmSans()),
      ));
    } else {
      setState(() => _error = res.error ?? 'Failed to book.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(width: 36, height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                    borderRadius: BorderRadius.circular(2)))),
            Text('Book Test — ${widget.lab.name}',
                style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            if (_error != null) ...[
              AlertWidget(message: _error!, isError: true),
              const SizedBox(height: 12),
            ],
            Text('SELECT TESTS', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                letterSpacing: 0.05)),
            const SizedBox(height: 8),
            AppCard(
              child: Column(
                children: _availableTests.map((t) => CheckboxListTile(
                  dense: true,
                  title: Text(_key(t), style: GoogleFonts.dmSans(fontSize: 13)),
                  subtitle: t != _key(t)
                      ? Text(t, style: GoogleFonts.dmSans(fontSize: 11,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))
                      : null,
                  value: _checked.contains(_key(t)),
                  onChanged: (v) => setState(() {
                    if (v == true) _checked.add(_key(t)); else _checked.remove(_key(t));
                  }),
                )).toList(),
              ),
            ),
            const SizedBox(height: 16),
            Text('APPOINTMENT DATE', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
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
                  '${_date.day}/${_date.month}/${_date.year}',
                  style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
                )),
                TextButton(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setState(() => _date = picked);
                  },
                  child: const Text('Change'),
                ),
              ]),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl, maxLines: 2,
              decoration: const InputDecoration(hintText: 'Notes (optional)…'),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'))),
              const SizedBox(width: 12),
              Expanded(child: PrimaryButton(
                  label: 'Confirm', isLoading: _submitting, onPressed: _submit)),
            ]),
          ],
        ),
      ),
    );
  }
}
