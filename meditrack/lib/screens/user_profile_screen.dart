import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/rating_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';
import 'package:meditrack/screens/pages/provider_shared_widgets.dart';

const String _picBase = 'http://192.168.1.6:5098';

// ════════════════════════════════════════════════════════════════
// UserProfileScreen — shows another user's public profile.
// Supports DoctorResponse, LabResponse, PatientResponse.
// Doctor viewing a patient also gets an editable medical record.
// ════════════════════════════════════════════════════════════════

class UserProfileScreen extends StatefulWidget {
  final DoctorResponse?  doctor;
  final LabResponse?     lab;
  final PatientResponse? patient;

  const UserProfileScreen.doctor(DoctorResponse d, {super.key})
      : doctor = d, lab = null, patient = null;

  const UserProfileScreen.lab(LabResponse l, {super.key})
      : lab = l, doctor = null, patient = null;

  const UserProfileScreen.patient(PatientResponse p, {super.key})
      : patient = p, doctor = null, lab = null;

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _medCtrl     = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final _allergyCtrl = TextEditingController();
  bool _savingMed = false;
  bool _medLoaded = false;

  @override
  void initState() {
    super.initState();
    // Pre-load ratings cache so star display is instant
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final email = context.read<AuthProvider>().user?.email ?? '';
      ratingService.load(email);
    });
  }

  // ── Rate doctor / lab ─────────────────────────────────────────

  Future<void> _rateDoctor(DoctorResponse d) async {
    final email   = context.read<AuthProvider>().user?.email ?? '';
    final current = ratingService.getDoctorRating(d.id) ?? d.myRating;
    final picked  = await showDialog<double>(
      context: context,
      builder: (_) => ProviderRatingDialog(
        name:     'Dr. ${d.name}',
        subtitle: d.specialization,
        initial:  current,
      ),
    );
    if (picked == null) return;
    await ratingService.rateDoctor(email, d.id, picked);
    if (mounted) setState(() {});
  }

  Future<void> _rateLab(LabResponse l) async {
    final email   = context.read<AuthProvider>().user?.email ?? '';
    final current = ratingService.getLabRating(l.id) ?? l.myRating;
    final picked  = await showDialog<double>(
      context: context,
      builder: (_) => ProviderRatingDialog(
        name:     l.name,
        subtitle: l.location,
        initial:  current,
      ),
    );
    if (picked == null) return;
    await ratingService.rateLab(email, l.id, picked);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _medCtrl.dispose();
    _chronicCtrl.dispose();
    _allergyCtrl.dispose();
    super.dispose();
  }

  void _loadMedFields(PatientResponse p) {
    if (_medLoaded) return;
    _medCtrl.text     = p.medicalRecord;
    _chronicCtrl.text = p.chronicDiseases ?? '';
    _allergyCtrl.text = p.allergies       ?? '';
    _medLoaded = true;
  }

  Future<void> _saveMedRecord(PatientResponse p) async {
    setState(() => _savingMed = true);
    final res = await apiService.updateMedicalRecord(
      p.id,
      medicalRecord:   _medCtrl.text.trim().isNotEmpty    ? _medCtrl.text.trim()     : null,
      chronicDiseases: _chronicCtrl.text.trim().isNotEmpty ? _chronicCtrl.text.trim() : null,
      allergies:       _allergyCtrl.text.trim().isNotEmpty  ? _allergyCtrl.text.trim() : null,
    );
    if (res.ok && mounted) {
      _medLoaded = false; // allow fields to reload from the refreshed patient
      context.read<AppProvider>().refreshPatients(context.read<AuthProvider>().role);
    }
    if (!mounted) return;
    setState(() => _savingMed = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok ? 'Medical record updated.' : (res.error ?? 'Failed.')),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final app  = context.watch<AppProvider>(); // watch so we rebuild on refreshPatients
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    if (widget.doctor  != null) return _buildDoctorProfile(widget.doctor!, isDark, role);
    if (widget.lab     != null) return _buildLabProfile(widget.lab!, isDark, role);
    if (widget.patient != null) {
      // Always use the freshest copy from AppProvider so medical-record edits
      // are immediately visible after the doctor saves them.
      final fresh = app.patients.where((p) => p.id == widget.patient!.id).firstOrNull
          ?? widget.patient!;
      return _buildPatientProfile(fresh, isDark, role);
    }
    return const SizedBox.shrink();
  }

  // ── Doctor ────────────────────────────────────────────────────

  Widget _buildDoctorProfile(DoctorResponse d, bool isDark, UserRole role) {
    final fullPic = d.profilePictureUrl != null && d.profilePictureUrl!.isNotEmpty
        ? '$_picBase${d.profilePictureUrl}' : null;

    return Scaffold(
      appBar: AppBar(title: Text(d.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _BigAvatar(fullPicUrl: fullPic, initials: d.initials),
          const SizedBox(height: 12),
          Text(d.name,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(d.specialization,
              style: GoogleFonts.dmSans(fontSize: 15,
                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 12),
          // ── Rating summary ──
          _RatingSummaryWidget(
            averageRating: d.averageRating,
            ratingCount:   d.ratingCount,
            myRating:      ratingService.getDoctorRating(d.id),
            isDark:        isDark,
            canRate:       role == UserRole.patient,
            onRate: role == UserRole.patient
                ? () => _rateDoctor(d)
                : null,
          ),
          const SizedBox(height: 16),
          AppCard(child: Column(children: [
            if (d.clinicName != null && d.clinicName!.isNotEmpty)
              _InfoRow(icon: Icons.local_hospital_outlined, label: d.clinicName!)
            else
              _InfoRow(icon: Icons.local_hospital_outlined, label: 'Clinic name not specified'),
            if (d.clinicAddress != null && d.clinicAddress!.isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined, label: d.clinicAddress!)
            else
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address not specified'),
            _InfoRow(icon: Icons.email_outlined, label: d.email),
            if (d.phone.isNotEmpty)
              _InfoRow(icon: Icons.phone_outlined, label: d.phone),
          ])),
          // Map preview — only when coordinates are available
          if (d.clinicLatitude != null && d.clinicLongitude != null) ...[
            const SizedBox(height: 16),
            _MapPreview(
              lat: d.clinicLatitude!,
              lng: d.clinicLongitude!,
              label: d.clinicName ?? 'Clinic Location',
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(otherEmail: d.email, otherName: d.name),
              )),
              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
              label: Text('Chat with Dr. ${d.name.split(' ').first}',
                  style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
            ),
          ),
          // Book appointment — patients only
          if (role == UserRole.patient) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final data = await showModalBottomSheet<_BookingData>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _BookDoctorSheet(doctor: d),
                  );
                  if (data == null || !context.mounted) return;
                  final app       = context.read<AppProvider>();
                  final auth      = context.read<AuthProvider>();
                  final patientId = app.patientByEmail(auth.user?.email ?? '')?.id;
                  if (patientId == null) return;
                  final res = await apiService.addFollowUp(FollowUpRequest(
                    diagnosis:     data.reason,
                    treatmentPlan: data.treatmentPlan.isNotEmpty
                        ? data.treatmentPlan : 'To be determined',
                    notes: data.notes.isNotEmpty
                        ? data.notes
                        : 'Appointment: ${data.date.day}/${data.date.month}/${data.date.year} ${data.time}',
                    patientId: patientId,
                    doctorId:  d.id,
                  ));
                  if (!context.mounted) return;
                  await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.ok
                        ? 'Follow-up booked with Dr. ${d.name.split(' ').first}'
                        : (res.error ?? 'Failed.')),
                  ));
                },
                icon: const Icon(Icons.calendar_month_outlined, size: 18),
                label: Text('Book Appointment',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Lab ───────────────────────────────────────────────────────

  Widget _buildLabProfile(LabResponse l, bool isDark, UserRole role) {
    final fullPic = l.profilePictureUrl != null && l.profilePictureUrl!.isNotEmpty
        ? '$_picBase${l.profilePictureUrl}' : null;
    final initials = l.name.isNotEmpty ? l.name[0].toUpperCase() : 'L';

    return Scaffold(
      appBar: AppBar(title: Text(l.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _BigAvatar(fullPicUrl: fullPic, initials: initials),
          const SizedBox(height: 12),
          Text(l.name,
              style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Medical Laboratory',
              style: GoogleFonts.dmSans(fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 12),
          // ── Rating summary ──
          _RatingSummaryWidget(
            averageRating: l.averageRating,
            ratingCount:   l.ratingCount,
            myRating:      ratingService.getLabRating(l.id),
            isDark:        isDark,
            canRate:       role == UserRole.patient,
            onRate: role == UserRole.patient
                ? () => _rateLab(l)
                : null,
          ),
          const SizedBox(height: 16),
          AppCard(child: Column(children: [
            _InfoRow(icon: Icons.science_outlined, label: l.name.isNotEmpty ? l.name : 'Lab name not specified'),
            if (l.location.isNotEmpty)
              _InfoRow(icon: Icons.location_on_outlined, label: l.location)
            else
              _InfoRow(icon: Icons.location_on_outlined, label: 'Address not specified'),
            _InfoRow(icon: Icons.email_outlined, label: l.email),
            if (l.phone.isNotEmpty)
              _InfoRow(icon: Icons.phone_outlined, label: l.phone),
          ])),
          // Map preview — only when coordinates are available
          if (l.latitude != null && l.longitude != null) ...[
            const SizedBox(height: 16),
            _MapPreview(
              lat: l.latitude!,
              lng: l.longitude!,
              label: l.name,
            ),
          ],
          const SizedBox(height: 16),
          if (l.email.isNotEmpty)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ChatScreen(otherEmail: l.email, otherName: l.name),
                )),
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                label: Text('Chat with ${l.name}',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          // Book lab test — patients only
          if (role == UserRole.patient) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final result = await showModalBottomSheet<_LabBookingData>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => _BookLabSheet(lab: l),
                  );
                  if (result == null || !context.mounted) return;
                  final app     = context.read<AppProvider>();
                  final auth    = context.read<AuthProvider>();
                  final patient = app.patientByEmail(auth.user?.email ?? '');
                  if (patient == null) return;
                  final res = await apiService.createLabAppointment(
                    LabAppointmentRequest(
                      patientId:       patient.id,
                      labId:           l.id,
                      testNames:       result.tests,
                      appointmentDate: result.date,
                      notes:           result.notes.isNotEmpty ? result.notes : null,
                    ),
                  );
                  if (!context.mounted) return;
                  await app.refreshLabAppointments();
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text(res.ok
                        ? 'Appointment booked at ${l.name}'
                        : (res.error ?? 'Failed.')),
                  ));
                },
                icon: const Icon(Icons.science_outlined, size: 18),
                label: Text('Book Lab Test',
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  // ── Patient ───────────────────────────────────────────────────

  Widget _buildPatientProfile(PatientResponse p, bool isDark, UserRole role) {
    _loadMedFields(p);
    final fullPic = p.profilePictureUrl != null && p.profilePictureUrl!.isNotEmpty
        ? '$_picBase${p.profilePictureUrl}' : null;
    final canEditMedRecord = role == UserRole.doctor || role == UserRole.admin;

    return Scaffold(
      appBar: AppBar(title: Text(p.name)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          _BigAvatar(fullPicUrl: fullPic, initials: p.initials),
          const SizedBox(height: 12),
          // Name + inline chat icon
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(p.name,
                style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(otherEmail: p.email, otherName: p.name),
              )),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.chat_bubble_outline_rounded, size: 16,
                    color: isDark ? AppColors.darkAccent : AppColors.accent),
              ),
            ),
          ]),
          if (p.isInEmergency) ...[
            const SizedBox(height: 8),
            BadgeWidget(label: '🚨 EMERGENCY', type: BadgeType.red),
          ],
          const SizedBox(height: 16),
          AppCard(child: Column(children: [
            _InfoRow(icon: Icons.email_outlined, label: p.email),
            if (p.phone.isNotEmpty)
              _InfoRow(icon: Icons.phone_outlined, label: p.phone),
            if (p.gender.isNotEmpty)
              _InfoRow(icon: Icons.person_outline, label: p.gender),
            if (p.bloodType.isNotEmpty && p.bloodType != 'Unknown')
              _InfoRow(icon: Icons.water_drop_outlined,
                  label: 'Blood type: ${p.bloodType}'),
          ])),
          const SizedBox(height: 16),

          // Editable medical record — Doctor / Admin
          if (canEditMedRecord)
            AppCard(child: Column(children: [
              const CardHeader(title: 'Medical Record'),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(children: [
                  TextField(
                    controller: _medCtrl,
                    minLines: 2, maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'Medical Record',
                      hintText: 'Current conditions, history, notes…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _chronicCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Chronic Diseases',
                      hintText: 'Diabetes, hypertension…',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _allergyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      hintText: 'Penicillin, shellfish…',
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _savingMed ? null : () => _saveMedRecord(p),
                      child: _savingMed
                          ? const SizedBox(width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Save Medical Record'),
                    ),
                  ),
                ]),
              ),
            ]))

          // Read-only medical info — Patient / Relative
          else if (p.medicalRecord.isNotEmpty || p.chronicDiseases != null)
            AppCard(child: Column(children: [
              const CardHeader(title: 'Medical Info'),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (p.medicalRecord.isNotEmpty)
                        _InfoRow(icon: Icons.description_outlined,
                            label: p.medicalRecord),
                      if (p.chronicDiseases != null && p.chronicDiseases!.isNotEmpty)
                        _InfoRow(icon: Icons.medical_services_outlined,
                            label: p.chronicDiseases!),
                      if (p.allergies != null && p.allergies!.isNotEmpty)
                        _InfoRow(icon: Icons.warning_amber_outlined,
                            label: 'Allergies: ${p.allergies}'),
                    ]),
              ),
            ])),
        ]),
      ),
    );
  }
}

// ── Rating summary widget ─────────────────────────────────────

class _RatingSummaryWidget extends StatelessWidget {
  final double  averageRating;
  final int     ratingCount;
  final double? myRating;
  final bool    isDark;
  final bool    canRate;
  final VoidCallback? onRate;

  const _RatingSummaryWidget({
    required this.averageRating,
    required this.ratingCount,
    required this.isDark,
    required this.canRate,
    this.myRating,
    this.onRate,
  });

  @override
  Widget build(BuildContext context) {
    final hasRating  = averageRating > 0;
    final accentColor = isDark ? AppColors.darkAccent : AppColors.accent;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        // Stars + numeric
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              ProviderStarRow(
                rating: hasRating ? averageRating : null,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                hasRating
                    ? averageRating.toStringAsFixed(1)
                    : '—',
                style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: hasRating
                        ? const Color(0xFFFFC107)
                        : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(
              hasRating
                  ? '$ratingCount rating${ratingCount != 1 ? 's' : ''}'
                  : 'No ratings yet',
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
            ),
            // Show the patient's own rating if they've rated
            if (myRating != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.person_outline, size: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                const SizedBox(width: 4),
                Text(
                  'Your rating: ${myRating!.toStringAsFixed(1)} ★',
                  style: GoogleFonts.dmSans(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                ),
              ]),
            ],
          ]),
        ),
        // Rate button for patients
        if (canRate && onRate != null)
          ElevatedButton.icon(
            onPressed: onRate,
            icon: Icon(
              myRating != null ? Icons.star_rounded : Icons.star_border_rounded,
              size: 16,
              color: myRating != null ? const Color(0xFFFFC107) : null,
            ),
            label: Text(
              myRating != null ? 'Update' : 'Rate',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              backgroundColor: myRating != null
                  ? const Color(0xFFFFC107).withValues(alpha: 0.15)
                  : accentColor,
              foregroundColor: myRating != null
                  ? const Color(0xFFFFC107)
                  : Colors.white,
              elevation: 0,
              side: myRating != null
                  ? const BorderSide(color: Color(0xFFFFC107))
                  : BorderSide.none,
            ),
          ),
      ]),
    );
  }
}

// ── Big avatar ────────────────────────────────────────────────

class _BigAvatar extends StatelessWidget {
  final String? fullPicUrl;
  final String  initials;
  const _BigAvatar({this.fullPicUrl, required this.initials});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (fullPicUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl:  fullPicUrl!,
          cacheKey:  fullPicUrl!,
          width: 90, height: 90, fit: BoxFit.cover,
          placeholder:  (_, __) => _circle(isDark),
          errorWidget:  (_, __, ___) => _circle(isDark),
        ),
      );
    }
    return _circle(isDark);
  }

  Widget _circle(bool isDark) => Container(
    width: 90, height: 90,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient,
    ),
    child: Center(child: Text(initials,
        style: const TextStyle(
            fontSize: 28, fontWeight: FontWeight.w700, color: Colors.white))),
  );
}

// ── Info row ──────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _InfoRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(children: [
        Icon(icon, size: 16,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
      ]),
    );
  }
}

// ── Map preview (read-only) ───────────────────────────────────
// Shows a small embedded OSM tile with a pin. Tapping it opens
// a full-screen bottom sheet with the interactive map so the
// user can see the exact location or get directions.

class _MapPreview extends StatelessWidget {
  final double lat, lng;
  final String label;
  const _MapPreview({required this.lat, required this.lng, required this.label});

  void _openFullMap(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        height: MediaQuery.of(context).size.height * 0.88,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgBase : AppColors.bgBase,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Drag handle + title
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 8, bottom: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, size: 18, color: Colors.red),
              const SizedBox(width: 8),
              Expanded(child: Text(label,
                  style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700))),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          // Full map
          Expanded(child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(lat, lng),
              initialZoom: 16,
              interactionOptions: const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.meditrack',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: LatLng(lat, lng),
                  width: 44, height: 44,
                  child: const Icon(Icons.location_pin,
                      color: Colors.red, size: 44),
                ),
              ]),
            ],
          )),
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, 12, 16, MediaQuery.of(context).viewPadding.bottom + 16),
            child: Text(
              '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmMono(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _openFullMap(context),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(children: [
            // Thumbnail map (non-interactive)
            SizedBox(
              height: 160,
              child: IgnorePointer(
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(lat, lng),
                    initialZoom: 15,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.meditrack',
                    ),
                    MarkerLayer(markers: [
                      Marker(
                        point: LatLng(lat, lng),
                        width: 40, height: 40,
                        child: const Icon(Icons.location_pin,
                            color: Colors.red, size: 40),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
            // Tap overlay label
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(children: [
                  const Icon(Icons.open_in_full_rounded,
                      size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text('Tap to view full map',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: Colors.white,
                          fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ── Doctor booking ────────────────────────────────────────────

class _BookingData {
  final DateTime date;
  final String   time;
  final String   reason;
  final String   treatmentPlan;
  final String   notes;
  const _BookingData({
    required this.date, required this.time, required this.reason,
    required this.treatmentPlan, required this.notes,
  });
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
    '09:00','10:00','11:00','12:00','14:00','15:00','16:00',
  ];
  static const _reasons = [
    'Routine checkup', 'Medication review', 'New symptoms',
    'Test result discussion', 'Post-procedure follow-up',
    'Chronic disease management', 'Other',
  ];

  @override
  void dispose() { _treatmentCtrl.dispose(); _notesCtrl.dispose(); super.dispose(); }

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
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
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              letterSpacing: 0.05)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
              children: _timeSlots.map((t) => ChoiceChip(
                label: Text(t, style: GoogleFonts.dmSans(fontSize: 12)),
                selected: _time == t,
                onSelected: (_) => setState(() => _time = t),
              )).toList()),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            value: _reason, isExpanded: true,
            decoration: const InputDecoration(labelText: 'Reason'),
            items: _reasons.map((r) =>
                DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (v) => setState(() => _reason = v ?? _reason),
          ),
          const SizedBox(height: 10),
          TextFormField(controller: _treatmentCtrl,
              decoration: const InputDecoration(
                  labelText: 'Treatment plan (optional)')),
          const SizedBox(height: 10),
          TextFormField(controller: _notesCtrl, minLines: 2, maxLines: 3,
              decoration: const InputDecoration(labelText: 'Notes (optional)')),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'))),
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

// ── Lab booking ───────────────────────────────────────────────

class _LabBookingData {
  final List<String> tests;
  final DateTime     date;
  final String       notes;
  const _LabBookingData({
    required this.tests, required this.date, required this.notes,
  });
}

class _BookLabSheet extends StatefulWidget {
  final LabResponse lab;
  const _BookLabSheet({required this.lab});
  @override
  State<_BookLabSheet> createState() => _BookLabSheetState();
}

class _BookLabSheetState extends State<_BookLabSheet> {
  final Set<String> _checked  = {'CBC'};
  final _notesCtrl = TextEditingController();
  DateTime _date   = DateTime.now().add(const Duration(days: 1));

  static const _tests = [
    'CBC', 'Blood Glucose', 'HbA1c', 'Lipid Panel',
    'Kidney Function', 'Liver Function', 'Thyroid (TSH)',
    'Vitamin D', 'Iron Studies', 'Urine Analysis',
  ];

  @override
  void dispose() { _notesCtrl.dispose(); super.dispose(); }

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
        child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 36, height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                  borderRadius: BorderRadius.circular(2)))),
          Text('Book at ${widget.lab.name}',
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text('SELECT TESTS', style: GoogleFonts.dmSans(fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              letterSpacing: 0.05)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, runSpacing: 8,
            children: _tests.map((t) {
              final selected = _checked.contains(t);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) _checked.remove(t); else _checked.add(t);
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
                        : (isDark ? AppColors.darkBgBase : AppColors.bgBase),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: selected
                          ? (isDark ? AppColors.darkAccent : AppColors.accent)
                          : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
                    ),
                  ),
                  child: Text(t, style: GoogleFonts.dmSans(fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? (isDark ? AppColors.darkAccent : AppColors.accent)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
              );
              if (picked != null) setState(() => _date = picked);
            },
            icon: const Icon(Icons.calendar_month_outlined, size: 16),
            label: Text('Date: ${_date.day}/${_date.month}/${_date.year}',
                style: GoogleFonts.dmSans(fontSize: 13)),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _notesCtrl, minLines: 1, maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)'),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'))),
            const SizedBox(width: 12),
            Expanded(child: ElevatedButton(
              onPressed: _checked.isEmpty
                  ? null
                  : () => Navigator.of(context).pop(_LabBookingData(
                        tests: _checked.toList(),
                        date:  _date,
                        notes: _notesCtrl.text.trim(),
                      )),
              child: const Text('Book'),
            )),
          ]),
        ]),
      ),
    );
  }
}
