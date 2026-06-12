import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/location_service.dart';
import 'package:meditrack/services/rating_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';
import 'package:meditrack/screens/user_profile_screen.dart';

enum _SortMode { name, rating, distance }

class DoctorsPage extends StatefulWidget {
  const DoctorsPage({super.key});
  @override
  State<DoctorsPage> createState() => _DoctorsPageState();
}

class _DoctorsPageState extends State<DoctorsPage> {
  final _searchCtrl = TextEditingController();
  String    _query       = '';
  String?   _selectedSpec;
  _SortMode _sortMode    = _SortMode.name;
  bool      _booking     = false;
  Timer?    _autoRefresh;

  @override
  void initState() {
    super.initState();
    _autoRefresh = Timer.periodic(const Duration(seconds: 60), (_) {
      if (mounted) context.read<AppProvider>().refreshDoctors();
    });
    // Load ratings for current patient
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = context.read<AuthProvider>().user?.email ?? '';
      ratingService.load(email);
    });
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  // ── Filtering + sorting ───────────────────────────────────────

  List<DoctorResponse> _process(List<DoctorResponse> all) {
    final q = _query.trim().toLowerCase();
    var list = all.where((d) {
      final matchQ    = q.isEmpty || d.name.toLowerCase().contains(q) ||
          d.specialization.toLowerCase().contains(q);
      final matchSpec = _selectedSpec == null || d.specialization == _selectedSpec;
      return matchQ && matchSpec;
    }).toList();

    switch (_sortMode) {
      case _SortMode.name:
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
      case _SortMode.rating:
        list.sort((a, b) {
          // Prefer backend average rating; fall back to local rating
          final ra = a.averageRating > 0
              ? a.averageRating
              : (ratingService.getDoctorRating(a.id) ?? 0);
          final rb = b.averageRating > 0
              ? b.averageRating
              : (ratingService.getDoctorRating(b.id) ?? 0);
          return rb.compareTo(ra); // highest first
        });
        break;
      case _SortMode.distance:
        final pos = locationService.lastPosition;
        if (pos != null) {
          list.sort((a, b) {
            final da = (a.clinicLatitude != null && a.clinicLongitude != null)
                ? _distKm(pos.latitude, pos.longitude,
                    a.clinicLatitude!, a.clinicLongitude!)
                : double.infinity;
            final db = (b.clinicLatitude != null && b.clinicLongitude != null)
                ? _distKm(pos.latitude, pos.longitude,
                    b.clinicLatitude!, b.clinicLongitude!)
                : double.infinity;
            return da.compareTo(db);
          });
        }
        break;
    }
    return list;
  }

  List<String> _specs(List<DoctorResponse> all) =>
      all.map((d) => d.specialization).where((s) => s.isNotEmpty).toSet().toList()..sort();

  // ── Book follow-up ────────────────────────────────────────────

  Future<void> _bookWithDoctor(DoctorResponse doctor) async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final patientId = app.patientByEmail(auth.user?.email ?? '')?.id;
    if (patientId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not identify patient.',
              style: GoogleFonts.dmSans())));
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
      diagnosis:     data.reason,
      treatmentPlan: data.treatmentPlan.isNotEmpty ? data.treatmentPlan : 'To be determined',
      notes:         data.notes.isNotEmpty
          ? data.notes
          : 'Appointment: ${data.date.day}/${data.date.month}/${data.date.year} ${data.time}',
      patientId: patientId,
      doctorId:  doctor.id,
    ));
    if (!mounted) return;
    if (res.ok) await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
    if (!mounted) return;
    setState(() => _booking = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        res.ok ? 'Follow-up booked with Dr. ${doctor.name}' : (res.error ?? 'Failed.'),
        style: GoogleFonts.dmSans(),
      ),
    ));
  }

  // ── Rate doctor ───────────────────────────────────────────────

  Future<void> _rateDoctor(DoctorResponse doctor) async {
    final email = context.read<AuthProvider>().user?.email ?? '';
    final current = ratingService.getDoctorRating(doctor.id);
    final picked  = await showDialog<double>(
      context: context,
      builder: (_) => _RatingDialog(
        name: 'Dr. ${doctor.name}',
        subtitle: doctor.specialization,
        initial: current,
      ),
    );
    if (picked == null) return;
    await ratingService.rateDoctor(email, doctor.id, picked);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final app     = context.watch<AppProvider>();
    final auth    = context.watch<AuthProvider>();
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final canBook = auth.role == UserRole.patient;
    final specs   = _specs(app.doctors);
    final list    = _process(app.doctors);

    return RefreshIndicator(
      onRefresh: () => app.refreshDoctors(),
      child: Stack(children: [
        CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Search ──
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
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            })
                        : null,
                  ),
                ),
              ),
            ),
            // ── Spec chips ──
            if (specs.isNotEmpty)
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    children: [
                      _FilterChip(
                          label: 'All',
                          selected: _selectedSpec == null,
                          onTap: () => setState(() => _selectedSpec = null)),
                      ...specs.map((s) => _FilterChip(
                            label: s,
                            selected: _selectedSpec == s,
                            onTap: () => setState(() =>
                                _selectedSpec = _selectedSpec == s ? null : s),
                          )),
                    ],
                  ),
                ),
              ),
            // ── Sort bar + count ──
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Row(children: [
                  Text('${list.length} doctor${list.length != 1 ? 's' : ''}',
                      style: GoogleFonts.dmSans(fontSize: 13,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary)),
                  const Spacer(),
                  _SortBar(
                    current: _sortMode,
                    onChange: (m) => setState(() => _sortMode = m),
                  ),
                ]),
              ),
            ),
            // ── List ──
            if (app.isLoading)
              const SliverToBoxAdapter(child: LoadingRows(count: 5))
            else if (list.isEmpty)
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
                      doctor:    list[i],
                      canBook:   canBook,
                      canRate:   auth.role == UserRole.patient,
                      myRating:  ratingService.getDoctorRating(list[i].id),
                      sortMode:  _sortMode,
                      onBook:    () => _bookWithDoctor(list[i]),
                      onRate:    () => _rateDoctor(list[i]),
                      onChat:    () => Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => ChatScreen(
                            otherEmail: list[i].email,
                            otherName:  list[i].name,
                          ))),
                    ),
                    childCount: list.length,
                  ),
                ),
              ),
          ],
        ),
        if (_booking)
          const IgnorePointer(
              child: SizedBox.expand(child: ColoredBox(color: Colors.black12))),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Doctor Card
// ─────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final DoctorResponse doctor;
  final bool canBook, canRate;
  final double? myRating;
  final _SortMode sortMode;
  final VoidCallback onBook, onRate, onChat;

  const _DoctorCard({
    required this.doctor,   required this.canBook,  required this.canRate,
    required this.myRating, required this.sortMode, required this.onBook,
    required this.onRate,   required this.onChat,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pos    = locationService.lastPosition;
    final hasDist = pos != null &&
        doctor.clinicLatitude != null && doctor.clinicLongitude != null;
    final dist = hasDist
        ? _distKm(pos!.latitude, pos.longitude,
            doctor.clinicLatitude!, doctor.clinicLongitude!)
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Top row ──
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            AvatarWidget(
                initials: doctor.initials, size: 40, fontSize: 14,
                photoUrl: doctor.profilePictureUrl),
            const SizedBox(width: 12),
            Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(doctor.name,
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(doctor.specialization,
                  style: GoogleFonts.dmSans(fontSize: 12,
                      color: isDark ? AppColors.darkAccent : AppColors.accent,
                      fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              // Rating row — shows backend average + my personal rating
              Row(children: [
                _StarRow(rating: doctor.averageRating > 0 ? doctor.averageRating : myRating, size: 13),
                const SizedBox(width: 6),
                if (doctor.averageRating > 0) ...[
                  Text(
                    '${doctor.averageRating.toStringAsFixed(1)} (${doctor.ratingCount})',
                    style: GoogleFonts.dmSans(fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary),
                  ),
                ] else ...[
                  Text(
                    myRating != null
                        ? myRating!.toStringAsFixed(1)
                        : 'Not rated',
                    style: GoogleFonts.dmSans(fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary),
                  ),
                ],
              ]),
            ])),
            // Distance badge (shown when sorting by distance or location available)
            if (dist != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkAccentMuted
                      : AppColors.accentMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  dist < 1
                      ? '${(dist * 1000).round()} m'
                      : '${dist.toStringAsFixed(1)} km',
                  style: GoogleFonts.dmSans(fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.darkAccent
                          : AppColors.accent),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          // ── Action buttons ──
          Row(children: [
            Expanded(child: _ActionBtn(
              icon: Icons.person_outline,
              label: 'Profile',
              onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => UserProfileScreen.doctor(doctor))),
            )),
            const SizedBox(width: 6),
            Expanded(child: _ActionBtn(
              icon: Icons.chat_bubble_outline_rounded,
              label: 'Chat',
              onTap: onChat,
            )),
            if (canBook) ...[
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(
                icon: Icons.calendar_month_outlined,
                label: 'Book',
                onTap: onBook,
              )),
            ],
            if (canRate) ...[
              const SizedBox(width: 6),
              Expanded(child: _ActionBtn(
                icon: myRating != null
                    ? Icons.star_rounded
                    : Icons.star_border_rounded,
                label: myRating != null ? 'Rated' : 'Rate',
                onTap: onRate,
                highlight: myRating != null,
              )),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Labs Page  (imported from labs_page.dart — rating + sort added)
// ─────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────
// Sort bar
// ─────────────────────────────────────────────────────────────

class _SortBar extends StatelessWidget {
  final _SortMode current;
  final void Function(_SortMode) onChange;
  const _SortBar({required this.current, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('Sort:', style: GoogleFonts.dmSans(fontSize: 12,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      const SizedBox(width: 6),
      _SortChip(
          label: 'Name',
          icon: Icons.sort_by_alpha_rounded,
          selected: current == _SortMode.name,
          onTap: () => onChange(_SortMode.name)),
      const SizedBox(width: 4),
      _SortChip(
          label: 'Rating',
          icon: Icons.star_rounded,
          selected: current == _SortMode.rating,
          onTap: () => onChange(_SortMode.rating)),
      const SizedBox(width: 4),
      _SortChip(
          label: 'Near',
          icon: Icons.near_me_rounded,
          selected: current == _SortMode.distance,
          onTap: () => onChange(_SortMode.distance)),
    ]);
  }
}

class _SortChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _SortChip(
      {required this.label, required this.icon,
       required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? AppColors.darkAccent : AppColors.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? accent.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: selected
                ? accent
                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 12,
              color: selected ? accent
                  : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          const SizedBox(width: 3),
          Text(label,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? accent
                      : (isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary))),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Rating dialog
// ─────────────────────────────────────────────────────────────

class _RatingDialog extends StatefulWidget {
  final String name, subtitle;
  final double? initial;
  const _RatingDialog(
      {required this.name, required this.subtitle, this.initial});

  @override
  State<_RatingDialog> createState() => _RatingDialogState();
}

class _RatingDialogState extends State<_RatingDialog> {
  late double _stars;

  @override
  void initState() {
    super.initState();
    _stars = widget.initial ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      backgroundColor: isDark ? AppColors.darkBgCard : AppColors.bgCard,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Rate', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              letterSpacing: 0.8)),
          const SizedBox(height: 4),
          Text(widget.name, style: GoogleFonts.dmSans(
              fontSize: 17, fontWeight: FontWeight.w700), textAlign: TextAlign.center),
          if (widget.subtitle.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(widget.subtitle, style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkAccent : AppColors.accent)),
          ],
          const SizedBox(height: 20),
          // Star row — tap to select
          Row(mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
            final filled = i < _stars;
            return GestureDetector(
              onTap: () => setState(() => _stars = (i + 1).toDouble()),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Icon(
                  filled ? Icons.star_rounded : Icons.star_border_rounded,
                  size: 36,
                  color: filled
                      ? const Color(0xFFFFC107)
                      : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
                ),
              ),
            );
          })),
          const SizedBox(height: 8),
          Text(
            _stars == 0 ? 'Tap a star to rate'
                : _stars <= 1 ? 'Poor'
                : _stars <= 2 ? 'Fair'
                : _stars <= 3 ? 'Good'
                : _stars <= 4 ? 'Very Good'
                : 'Excellent',
            style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            )),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _stars == 0 ? null : () => Navigator.of(context).pop(_stars),
              child: const Text('Submit'),
            )),
          ]),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _FilterChip(
      {required this.label, required this.selected, required this.onTap});

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
            color: selected
                ? Colors.transparent
                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          ),
        ),
        child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500,
                color: selected ? Colors.white
                    : (isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary))),
      ),
    );
  }
}

/// Read-only star row — shows filled stars up to [rating].
class _StarRow extends StatelessWidget {
  final double? rating;
  final double size;
  const _StarRow({this.rating, required this.size});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (i) {
        final filled = rating != null && i < rating!;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          size: size,
          color: filled
              ? const Color(0xFFFFC107)
              : Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkBorderColor
                  : AppColors.borderColor,
        );
      }),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool highlight;
  const _ActionBtn(
      {required this.icon, required this.label,
       required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color  = highlight
        ? const Color(0xFFFFC107)
        : null;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 14, color: color),
      label: Text(label,
          style: GoogleFonts.dmSans(fontSize: 12, color: color)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: highlight
            ? const BorderSide(color: Color(0xFFFFC107))
            : null,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Haversine distance helper
// ─────────────────────────────────────────────────────────────

double _distKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = _rad(lat2 - lat1);
  final dLon = _rad(lon2 - lon1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_rad(lat1)) * cos(_rad(lat2)) *
          sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

double _rad(double deg) => deg * pi / 180;

// ─────────────────────────────────────────────────────────────
// Booking sheet (unchanged)
// ─────────────────────────────────────────────────────────────

class _BookingData {
  final DateTime date;
  final String time, reason, treatmentPlan, notes;
  const _BookingData(
      {required this.date, required this.time, required this.reason,
       required this.treatmentPlan, required this.notes});
}

class _BookDoctorSheet extends StatefulWidget {
  final DoctorResponse doctor;
  const _BookDoctorSheet({required this.doctor});
  @override
  State<_BookDoctorSheet> createState() => _BookDoctorSheetState();
}

class _BookDoctorSheetState extends State<_BookDoctorSheet> {
  final DateTime _date = DateTime.now();
  String _time   = '09:00';
  String _reason = 'Routine checkup';
  final _treatmentCtrl = TextEditingController();
  final _notesCtrl     = TextEditingController();

  static const _timeSlots = [
    '09:00', '10:00', '11:00', '12:00', '14:00', '15:00', '16:00'
  ];
  static const _reasons = [
    'Routine checkup', 'Medication review', 'New symptoms',
    'Test result discussion', 'Post-procedure follow-up',
    'Chronic disease management', 'Other',
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(child: Container(
              width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2)),
            )),
            Text('Book Dr. ${widget.doctor.name}',
                style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(widget.doctor.specialization,
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkAccent : AppColors.accent)),
            const SizedBox(height: 16),
            Text('TIME', style: GoogleFonts.dmSans(fontSize: 11,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                letterSpacing: 0.05)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8, runSpacing: 8,
              children: _timeSlots.map((t) => ChoiceChip(
                label: Text(t, style: GoogleFonts.dmSans(fontSize: 12)),
                selected: _time == t,
                onSelected: (_) => setState(() => _time = t),
              )).toList(),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _reason, isExpanded: true,
              decoration: const InputDecoration(labelText: 'Reason'),
              items: _reasons.map((r) =>
                  DropdownMenuItem(value: r, child: Text(r))).toList(),
              onChanged: (v) => setState(() => _reason = v ?? _reason),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _treatmentCtrl,
              decoration: const InputDecoration(
                  labelText: 'Treatment plan (optional)'),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _notesCtrl, minLines: 2, maxLines: 3,
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
          ],
        ),
      ),
    );
  }
}
