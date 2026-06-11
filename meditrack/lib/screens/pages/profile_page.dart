import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/theme_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/widgets/map_location_picker.dart';
import 'package:meditrack/services/location_service.dart';
import 'package:meditrack/screens/login_screen.dart';
import 'package:meditrack/screens/pages/change_name_page.dart';
import 'package:meditrack/screens/pages/change_password_page.dart';
import 'package:meditrack/screens/pages/sensor_provision_page.dart';
import 'package:meditrack/models/models.dart';

// Base URL for profile pictures served by the backend
const String _picBase = 'http://192.168.0.102:5098';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  bool _savingBloodType  = false;
  bool _loggingOut       = false;
  bool _savingProfile    = false;
  bool _uploadingPic     = false;

  // Doctor clinic controllers
  final _clinicNameCtrl    = TextEditingController();
  final _clinicAddressCtrl = TextEditingController();

  // Doctor clinic location (map picker)
  double? _clinicLat;
  double? _clinicLng;

  // Lab location controllers
  final _labNameCtrl     = TextEditingController();
  final _labLocationCtrl = TextEditingController();
  final _labPhoneCtrl    = TextEditingController();

  // Lab location (map picker)
  double? _labLat;
  double? _labLng;

  bool _doctorFieldsLoaded = false;
  bool _labFieldsLoaded    = false;

  void _loadDoctorFields(DoctorResponse d) {
    if (_doctorFieldsLoaded) return;
    _clinicNameCtrl.text    = d.clinicName    ?? '';
    _clinicAddressCtrl.text = d.clinicAddress ?? '';
    _clinicLat = d.clinicLatitude;
    _clinicLng = d.clinicLongitude;
    _doctorFieldsLoaded = true;
  }

  void _loadLabFields(LabResponse l) {
    if (_labFieldsLoaded) return;
    _labNameCtrl.text     = l.name;
    _labLocationCtrl.text = l.location;
    _labPhoneCtrl.text    = l.phone;
    _labLat = l.latitude;
    _labLng = l.longitude;
    _labFieldsLoaded = true;
  }

  @override
  void dispose() {
    _clinicNameCtrl.dispose(); _clinicAddressCtrl.dispose();
    _labNameCtrl.dispose();    _labLocationCtrl.dispose();
    _labPhoneCtrl.dispose();
    super.dispose();
  }

  // ── Profile picture ──────────────────────────────────────────
  Future<void> _pickProfilePicture() async {
    final hasPic = context.read<AuthProvider>().user?.profilePictureUrl?.isNotEmpty == true;
    final choice = await showModalBottomSheet<dynamic>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PicSourceSheet(hasPicture: hasPic),
    );
    if (choice == null) return;

    // User chose to delete
    if (choice == 'delete') {
      await _deleteProfilePicture();
      return;
    }

    final picker = ImagePicker();
    final picked = await picker.pickImage(source: choice as ImageSource, imageQuality: 85, maxWidth: 800);
    if (picked == null) return;

    setState(() => _uploadingPic = true);
    final bytes = await picked.readAsBytes();

    // Evict OLD image from every possible cache key before uploading
    final auth   = context.read<AuthProvider>();
    final oldPic = auth.user?.profilePictureUrl;
    if (oldPic != null && oldPic.isNotEmpty) {
      final oldFull = '$_picBase$oldPic';
      await CachedNetworkImage.evictFromCache(oldPic);
      await CachedNetworkImage.evictFromCache(oldFull);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final res = await apiService.uploadProfilePicture(bytes, picked.name);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      await context.read<AuthProvider>().refreshProfilePic(res.data!);
      final app = context.read<AppProvider>();
      await app.refreshPatients(auth.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to upload picture.')));
    }
    setState(() => _uploadingPic = false);
  }

  Future<void> _deleteProfilePicture() async {
    setState(() => _uploadingPic = true);
    final auth = context.read<AuthProvider>();
    final oldPic = auth.user?.profilePictureUrl;
    if (oldPic != null && oldPic.isNotEmpty) {
      final oldFull = '$_picBase$oldPic';
      await CachedNetworkImage.evictFromCache(oldPic);
      await CachedNetworkImage.evictFromCache(oldFull);
    }
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();

    final res = await apiService.deleteProfilePicture();
    if (!mounted) return;
    if (res.ok) {
      await auth.refreshProfilePic(''); // clears picture from auth state
      final app = context.read<AppProvider>();
      await app.refreshPatients(auth.role);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to remove picture.')));
    }
    setState(() => _uploadingPic = false);
  }

  // ── Role-specific saves ──────────────────────────────────────
  Future<void> _saveDoctor(DoctorResponse doc) async {
    setState(() => _savingProfile = true);
    final body = {
      'name':           doc.name,
      'phone':          doc.phone,
      'email':          doc.email,
      'specialization': doc.specialization,
      if (_clinicNameCtrl.text.trim().isNotEmpty)
        'clinicName':    _clinicNameCtrl.text.trim(),
      if (_clinicAddressCtrl.text.trim().isNotEmpty)
        'clinicAddress': _clinicAddressCtrl.text.trim(),
      if (_clinicLat != null) 'clinicLatitude':  _clinicLat,
      if (_clinicLng != null) 'clinicLongitude': _clinicLng,
    };
    final res = await apiService.updateDoctor(doc.id, body);
    if (res.ok && mounted) {
      context.read<AppProvider>().refreshDoctors();
      _doctorFieldsLoaded = false;
    }
    if (!mounted) return;
    setState(() => _savingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok ? 'Clinic info updated.' : (res.error ?? 'Failed.')),
    ));
  }

  Future<void> _saveLab(LabResponse lab) async {
    setState(() => _savingProfile = true);
    final body = {
      'name':     _labNameCtrl.text.trim().isNotEmpty ? _labNameCtrl.text.trim() : lab.name,
      'location': _labLocationCtrl.text.trim().isNotEmpty ? _labLocationCtrl.text.trim() : lab.location,
      'phone':    _labPhoneCtrl.text.trim().isNotEmpty ? _labPhoneCtrl.text.trim() : lab.phone,
      if (_labLat != null) 'latitude':  _labLat,
      if (_labLng != null) 'longitude': _labLng,
    };
    final res = await apiService.updateLab(lab.id, body);
    if (res.ok && mounted) {
      context.read<AppProvider>().refreshLabs();
      _labFieldsLoaded = false;
    }
    if (!mounted) return;
    setState(() => _savingProfile = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok ? 'Lab info updated.' : (res.error ?? 'Failed.')),
    ));
  }

  Future<void> _updateBloodType(PatientResponse patient, String bloodType) async {
    setState(() => _savingBloodType = true);
    final auth = context.read<AuthProvider>();
    final app  = context.read<AppProvider>();
    final res  = await apiService.updateBloodType(patient.id, bloodType);
    if (res.ok) await app.refreshPatients(auth.role);
    if (!mounted) return;
    setState(() => _savingBloodType = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(res.ok ? 'Blood type updated' : (res.error ?? 'Failed')),
    ));
  }

  Future<void> _logout() async {
    final auth    = context.read<AuthProvider>();
    final appProv = context.read<AppProvider>();
    setState(() => _loggingOut = true);
    if (auth.role == UserRole.ambulance) {
      await apiService.ambulanceSignOut();
    }
    locationService.stopPatientTracking();
    locationService.stopAmbulanceTracking();
    await auth.logout();
    appProv.clear();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final app       = context.watch<AppProvider>();
    final theme     = context.watch<ThemeProvider>();
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final user      = auth.user;
    final isPatient = auth.role == UserRole.patient;
    final isDoctor  = auth.role == UserRole.doctor;
    final isLab     = auth.role == UserRole.lab;
    final patient   = isPatient ? app.patientByEmail(user?.email ?? '') : null;
    final doctor    = isDoctor  ? app.doctorByEmail(user?.email ?? '')  : null;
    final lab       = isLab     ? app.labByEmail(user?.email ?? '')     : null;

    if (doctor != null) _loadDoctorFields(doctor);
    if (lab    != null) _loadLabFields(lab);

    return RefreshIndicator(
      onRefresh: () async {
        final auth = context.read<AuthProvider>();
        final app  = context.read<AppProvider>();
        await Future.wait([
          app.refreshPatients(auth.role),
          app.refreshDoctors(),
          app.refreshLabs(),
        ]);
        // reset field-loaded flags so editable fields reload fresh values
        _doctorFieldsLoaded = false;
        _labFieldsLoaded    = false;
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // ── Profile card ──────────────────────────────────────
            AppCard(child: Column(children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(border: Border(bottom: BorderSide(
                    color: isDark ? AppColors.darkBorderColor : AppColors.borderColor))),
                child: Row(children: [
                  // ── Avatar with camera overlay ────────────────
                  GestureDetector(
                    onTap: _pickProfilePicture,
                    child: Stack(children: [
                      // Circle avatar
                      _buildAvatar(user, isDark),
                      // Camera icon overlay
                      Positioned(
                        right: 0, bottom: 0,
                        child: Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkAccent : AppColors.accent,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
                                width: 2),
                          ),
                          child: _uploadingPic
                              ? const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: CircularProgressIndicator(
                                      strokeWidth: 1.5, color: Colors.white))
                              : const Icon(Icons.camera_alt_rounded,
                                  size: 12, color: Colors.white),
                        ),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user?.name ?? '—',
                          style: GoogleFonts.dmSans(
                              fontSize: 16, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(user?.email ?? '—',
                          style: GoogleFonts.dmSans(fontSize: 13,
                              color: isDark
                                  ? AppColors.darkTextSecondary
                                  : AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      BadgeWidget(label: auth.role.label, type: BadgeType.blue),
                    ],
                  )),
                ]),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  _InfoRow('Role',    auth.role.label),
                  _InfoRow('Email',   user?.email ?? '—'),
                  _InfoRow('User ID', user?.id     ?? '—'),
                  // ── Connect Sensor button (patient only) ──────
                  if (isPatient && patient != null) ...[
                    const SizedBox(height: 12),
                    _ConnectSensorButton(patientId: patient.id),
                  ],
                ]),
              ),
            ])),
            const SizedBox(height: 16),

            // ── Account (name + password) ─────────────────────────
            AppCard(child: Column(children: [
              const CardHeader(title: 'Account'),
              // Change name
              _AccountRow(
                icon: Icons.badge_outlined,
                label: 'Change Display Name',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangeNamePage())),
              ),
              Divider(height: 1,
                  indent: 16, endIndent: 16,
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
              // Change password
              _AccountRow(
                icon: Icons.lock_outline_rounded,
                label: 'Change Password',
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ChangePasswordPage())),
              ),
            ])),
            const SizedBox(height: 16),

            // ── Blood type (patient only) ─────────────────────────
            if (isPatient && patient != null) ...[
              AppCard(child: Column(children: [
                const CardHeader(title: 'Medical Info'),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('BLOOD TYPE',
                        style: GoogleFonts.dmSans(fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.darkTextTertiary
                                : AppColors.textTertiary,
                            letterSpacing: 0.05)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: patient.bloodType.isNotEmpty
                              ? patient.bloodType : 'Unknown',
                          isExpanded: true,
                          decoration: const InputDecoration(isDense: true),
                          items: ['Unknown','A+','A-','B+','B-','AB+','AB-','O+','O-']
                              .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                              .toList(),
                          onChanged: _savingBloodType
                              ? null
                              : (v) { if (v != null) _updateBloodType(patient, v); },
                        ),
                      ),
                      if (_savingBloodType) ...[
                        const SizedBox(width: 12),
                        const SizedBox(width: 18, height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ]),
                    if (patient.chronicDiseases != null &&
                        patient.chronicDiseases!.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoRow('Chronic', patient.chronicDiseases!),
                    ],
                    if (patient.allergies != null &&
                        patient.allergies!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _InfoRow('Allergies', patient.allergies!),
                    ],
                    if (patient.medicalRecord.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _InfoRow('Medical Record', patient.medicalRecord),
                    ],
                  ]),
                ),
              ])),
              const SizedBox(height: 16),
            ],

            // ── Clinic info (doctor only) ─────────────────────────
            if (isDoctor && doctor != null) ...[
              AppCard(child: Column(children: [
                const CardHeader(title: 'Clinic Info'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _EditField('Clinic Name',    _clinicNameCtrl,    isDark, hint: 'e.g. Al-Noor Clinic'),
                    _EditField('Clinic Address', _clinicAddressCtrl, isDark, hint: 'e.g. 12 Tahrir St, Cairo'),
                    StaticLocationPickerField(
                      label:      'Clinic Location on Map',
                      initialLat: _clinicLat,
                      initialLng: _clinicLng,
                      onPicked:   (lat, lng) => setState(() { _clinicLat = lat; _clinicLng = lng; }),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savingProfile ? null : () => _saveDoctor(doctor),
                        child: _savingProfile
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Clinic Info'),
                      ),
                    ),
                  ]),
                ),
              ])),
              const SizedBox(height: 16),
            ],

            // ── Lab info (lab only) ───────────────────────────────
            if (isLab && lab != null) ...[
              AppCard(child: Column(children: [
                const CardHeader(title: 'Lab Info'),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    _EditField('Lab Name',  _labNameCtrl,     isDark),
                    _EditField('Location',  _labLocationCtrl, isDark, hint: 'e.g. Nasr City, Cairo'),
                    _EditField('Phone',     _labPhoneCtrl,    isDark, kb: TextInputType.phone),
                    StaticLocationPickerField(
                      label:      'Lab Location on Map',
                      initialLat: _labLat,
                      initialLng: _labLng,
                      onPicked:   (lat, lng) => setState(() { _labLat = lat; _labLng = lng; }),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savingProfile ? null : () => _saveLab(lab),
                        child: _savingProfile
                            ? const SizedBox(width: 18, height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Save Lab Info'),
                      ),
                    ),
                  ]),
                ),
              ])),
              const SizedBox(height: 16),
            ],

            // ── Appearance ────────────────────────────────────────
            AppCard(child: Column(children: [
              const CardHeader(title: 'Appearance'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  _SettingsRow(
                    icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    label: 'Dark mode',
                    trailing: Switch(
                      value: theme.isDark,
                      onChanged: (_) => theme.toggle(),
                      activeThumbColor: isDark ? AppColors.darkAccent : AppColors.accent,
                    ),
                  ),
                  _SettingsRow(
                    icon: Icons.auto_mode_rounded,
                    label: 'Follow system theme',
                    trailing: Switch(
                      value: theme.mode == ThemeMode.system,
                      onChanged: (v) => theme.setMode(v
                          ? ThemeMode.system
                          : (isDark ? ThemeMode.dark : ThemeMode.light)),
                      activeThumbColor: isDark ? AppColors.darkAccent : AppColors.accent,
                    ),
                  ),
                ]),
              ),
            ])),
            const SizedBox(height: 16),

            // ── Session ───────────────────────────────────────────
            AppCard(child: Column(children: [
              const CardHeader(title: 'Session'),
              InkWell(
                onTap: _loggingOut ? null : _logout,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    if (_loggingOut)
                      const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                    else
                      Icon(Icons.logout_rounded, size: 18,
                          color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
                    const SizedBox(width: 10),
                    Text(
                      auth.role == UserRole.ambulance
                          ? 'Sign out (marks you as Unavailable)'
                          : 'Sign out',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w500,
                          color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
                    ),
                  ]),
                ),
              ),
            ])),

          ]),
        ),
      ),
    ),
    );
  }

  // Build the 60×60 avatar: photo if available, else gradient+initials
  Widget _buildAvatar(AppUser? user, bool isDark) {
    final picUrl = user?.profilePictureUrl;
    if (picUrl == null) return _initialsCircle(user, isDark);

    final fullUrl = picUrl.startsWith('http') ? picUrl : '$_picBase$picUrl';

    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: fullUrl,
        cacheKey: fullUrl,
        width: 60, height: 60,
        fit: BoxFit.cover,
        placeholder: (_, __) => _initialsCircle(user, isDark),
        errorWidget: (_, __, ___) => _initialsCircle(user, isDark),
      ),
    );
  }

  Widget _initialsCircle(AppUser? user, bool isDark) => Container(
    width: 60, height: 60,
    decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: isDark ? AppColors.darkLogoGradient : AppColors.logoGradient),
    child: Center(child: Text(user?.initials ?? 'U',
        style: GoogleFonts.dmSans(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
  );
}

// ── Profile picture source picker ────────────────────────────

class _PicSourceSheet extends StatelessWidget {
  final bool hasPicture;
  const _PicSourceSheet({this.hasPicture = false});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        Text('Change Profile Picture',
            style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.camera_alt_rounded, size: 20,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ),
          title: Text('Take Photo',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('Use your camera',
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          onTap: () => Navigator.of(context).pop(ImageSource.camera),
        ),
        ListTile(
          leading: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.photo_library_rounded, size: 20,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ),
          title: Text('Choose from Gallery',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500)),
          subtitle: Text('Pick from your photos',
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          onTap: () => Navigator.of(context).pop(ImageSource.gallery),
        ),
        if (hasPicture) ...[
          ListTile(
            leading: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline_rounded, size: 20,
                  color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
            ),
            title: Text('Remove Photo',
                style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500,
                    color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)),
            subtitle: Text('Delete your current picture',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            onTap: () => Navigator.of(context).pop('delete'),
          ),
        ],
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: GoogleFonts.dmSans(fontSize: 14)),
          ),
        ),
      ]),
    );
  }
}

// ── Account settings row ──────────────────────────────────────

class _AccountRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _AccountRow({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 18,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 14,
                  color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
          Icon(Icons.chevron_right_rounded, size: 18,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
        ]),
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label, value;
  const _InfoRow(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        SizedBox(width: 90, child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
        Expanded(child: Text(value,
            style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
      ]),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  final IconData icon; final String label; final Widget trailing;
  const _SettingsRow({required this.icon, required this.label, required this.trailing});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
        const SizedBox(width: 12),
        Expanded(child: Text(label,
            style: GoogleFonts.dmSans(fontSize: 14,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
        trailing,
      ]),
    );
  }
}

class _EditField extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final bool isDark;
  final String hint;
  final TextInputType? kb;
  const _EditField(this.label, this.ctrl, this.isDark, {this.hint = '', this.kb});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label.toUpperCase(),
          style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
              letterSpacing: 0.05)),
      const SizedBox(height: 5),
      TextField(
        controller: ctrl,
        keyboardType: kb,
        decoration: InputDecoration(hintText: hint),
      ),
    ]),
  );
}

// ── Connect Sensor button (patient only) ─────────────────────

class _ConnectSensorButton extends StatelessWidget {
  final int patientId;
  const _ConnectSensorButton({required this.patientId});

  void _showSensorSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _SensorSimulatorSheet(patientId: patientId),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        icon: Icon(Icons.sensors_rounded, size: 16,
            color: isDark ? AppColors.darkAccent : AppColors.accent),
        label: Text('Connect Sensor',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkAccent : AppColors.accent)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
              color: isDark
                  ? AppColors.darkAccent.withValues(alpha: 0.5)
                  : AppColors.accent.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          padding: const EdgeInsets.symmetric(vertical: 10),
        ),
        onPressed: () => _showSensorSheet(context),
      ),
    );
  }
}

// ── Sensor simulator bottom sheet ────────────────────────────

class _SensorSimulatorSheet extends StatefulWidget {
  final int patientId;
  const _SensorSimulatorSheet({required this.patientId});
  @override
  State<_SensorSimulatorSheet> createState() => _SensorSimulatorSheetState();
}

class _SensorSimulatorSheetState extends State<_SensorSimulatorSheet>
    with SingleTickerProviderStateMixin {

  late final TabController _tab;

  // ── Simulator state ──────────────────────────────────────────
  String _scenario = 'normal';
  bool   _sending  = false;
  Map<String, dynamic>? _lastResult;
  String? _error;

  static const _scenarios = [
    ('normal',   'Normal',   Icons.favorite_rounded),
    ('high_hr',  'High HR',  Icons.trending_up_rounded),
    ('low_spo2', 'Low SpO₂', Icons.air_rounded),
    ('low_hr',   'Low HR',   Icons.trending_down_rounded),
  ];

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
    _tab.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() { _sending = true; _lastResult = null; _error = null; });
    final res = await apiService.sendSimulatedReading(
      patientId: widget.patientId,
      scenario:  _scenario,
    );
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (res.ok) { _lastResult = res.data; }
      else        { _error = res.error; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final isEmerg = _lastResult?['isEmergency'] == true;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [

        // Handle bar
        Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        )),

        // Icon + title
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(Icons.sensors_rounded, size: 26,
              color: isDark ? AppColors.darkAccent : AppColors.accent),
        ),
        const SizedBox(height: 10),
        Text('Connect Sensor',
            style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // ── Tabs ────────────────────────────────────────────────
        Container(
          height: 38,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBgBase : AppColors.bgBase,
            borderRadius: BorderRadius.circular(10),
          ),
          child: TabBar(
            controller: _tab,
            indicator: BoxDecoration(
              color: isDark ? AppColors.darkAccent : AppColors.accent,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            labelColor: Colors.white,
            unselectedLabelColor:
                isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
            labelStyle: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: '🧪  Simulator'),
              Tab(text: '📡  Real Sensor'),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // ── Tab content ─────────────────────────────────────────
        // Simulator tab
        if (_tab.index == 0) ...[
          Text('SCENARIO',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                  letterSpacing: 0.8,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          const SizedBox(height: 10),
          Row(children: _scenarios.map((s) {
            final selected = _scenario == s.$1;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _scenario = s.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
                        : (isDark ? AppColors.darkBgBase : AppColors.bgBase),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: selected
                          ? (isDark ? AppColors.darkAccent : AppColors.accent)
                          : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
                    ),
                  ),
                  child: Column(children: [
                    Icon(s.$3, size: 18,
                        color: selected
                            ? (isDark ? AppColors.darkAccent : AppColors.accent)
                            : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
                    const SizedBox(height: 4),
                    Text(s.$2,
                        style: GoogleFonts.dmSans(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: selected
                                ? (isDark ? AppColors.darkAccent : AppColors.accent)
                                : (isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary))),
                  ]),
                ),
              ),
            );
          }).toList()),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: _sending
                  ? const SizedBox(width: 16, height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(_sending ? 'Sending…' : 'Send Reading',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onPressed: _sending ? null : _send,
            ),
          ),
          const SizedBox(height: 12),
          // result / error
          if (_lastResult != null)
            _ResultBox(result: _lastResult!, isEmerg: isEmerg, isDark: isDark),
          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('❌ $_error',
                  style: GoogleFonts.dmSans(fontSize: 12,
                      color: isDark
                          ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)),
            ),
        ],

        // Real Sensor tab
        if (_tab.index == 1) ...[
          Text(
            'Link a physical MAX30102 sensor to your account.\n'
            'The sensor will automatically send readings every 30 seconds.',
            style: GoogleFonts.dmSans(fontSize: 13,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.sensors_rounded, size: 18),
              label: Text('Set Up Real Sensor',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
              onPressed: () {
                Navigator.of(context).pop(); // close sheet
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => SensorProvisionPage(
                      patientId: widget.patientId),
                ));
              },
            ),
          ),
          const SizedBox(height: 4),
        ],

      ]),
    );
  }
}

// ── Result box ────────────────────────────────────────────────

class _ResultBox extends StatelessWidget {
  final Map<String, dynamic> result;
  final bool isEmerg, isDark;
  const _ResultBox({required this.result, required this.isEmerg, required this.isDark});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: isEmerg
          ? (isDark ? AppColors.darkEmergencyBg  : AppColors.emergencyBg)
          : (isDark ? AppColors.darkBgBase        : AppColors.bgBase),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isEmerg
            ? (isDark ? AppColors.darkEmergencyBdr : AppColors.emergencyBdr)
            : (isDark ? AppColors.darkBorderColor  : AppColors.borderColor),
      ),
    ),
    child: Row(children: [
      Icon(
        isEmerg
            ? Icons.warning_amber_rounded
            : Icons.check_circle_outline_rounded,
        size: 20,
        color: isEmerg
            ? (isDark ? AppColors.darkEmergencyTxt : AppColors.emergencyTxt)
            : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(
          isEmerg ? '🚨 Emergency triggered!' : '✅ Reading sent',
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
              color: isEmerg
                  ? (isDark ? AppColors.darkEmergencyTxt : AppColors.emergencyTxt)
                  : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)),
        ),
        const SizedBox(height: 2),
        Text(
          'HR: ${result['heartRate']} bpm  |  SpO₂: ${result['spo2']}%',
          style: GoogleFonts.sourceCodePro(fontSize: 11.5,
              color: isDark
                  ? AppColors.darkTextSecondary : AppColors.textSecondary),
        ),
      ])),
    ]),
  );
}


