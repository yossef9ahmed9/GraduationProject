import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/widgets/location_picker_widget.dart';
import 'package:meditrack/widgets/map_location_picker.dart';
import 'package:meditrack/screens/home_screen.dart';
import 'package:meditrack/screens/relative_link_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int       _step         = 1;
  UserRole? _selectedRole;

  // ── Common ────────────────────────────────────────────────────
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  final _cpassCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _obscurePass  = true;
  bool _obscureCpass = true;

  // ── Patient ───────────────────────────────────────────────────
  final _addressCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController(); // optional
  String  _gender    = 'male';
  String  _bloodType = 'Unknown';
  DateTime? _birthDate;
  // latitude/longitude tracked live by GPS — not stored at registration

  // ── Doctor ────────────────────────────────────────────────────
  final _specCtrl      = TextEditingController();
  final _clinicNameCtrl= TextEditingController();
  double? _clinicLat;
  double? _clinicLng;

  // ── Lab ───────────────────────────────────────────────────────
  final _labNameCtrl  = TextEditingController();
  final _locationCtrl = TextEditingController(); // text address
  double? _labLat;
  double? _labLng;

  // ── Relative ──────────────────────────────────────────────────
  final _relationCtrl = TextEditingController();

  // ── Ambulance — no station name anymore ───────────────────────
  final _driverFirstNameCtrl = TextEditingController();
  final _driverLastNameCtrl  = TextEditingController();
  final _driverPhoneCtrl = TextEditingController();
  final _licensePlateCtrl= TextEditingController();
  final _serviceAreaCtrl = TextEditingController(); // optional zone label

  final _roles = [
    (UserRole.patient,   Icons.person_outline,              'Patient'),
    (UserRole.doctor,    Icons.medical_services_outlined,   'Doctor'),
    (UserRole.lab,       Icons.science_outlined,            'Lab'),
    (UserRole.relative,  Icons.group_outlined,              'Relative'),
    (UserRole.ambulance, Icons.emergency_outlined,          'Ambulance'),
  ];

  @override
  void dispose() {
    for (final c in [
      _firstNameCtrl, _lastNameCtrl, _emailCtrl, _passCtrl, _cpassCtrl, _phoneCtrl,
      _addressCtrl, _medicalCtrl,
      _specCtrl, _clinicNameCtrl,
      _labNameCtrl, _locationCtrl,
      _relationCtrl,
      _driverFirstNameCtrl, _driverLastNameCtrl, _driverPhoneCtrl, _licensePlateCtrl, _serviceAreaCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  // Helper — combines first and last name into a full name string
  String get _fullName =>
      '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim();

  Map<String, dynamic>? _buildBody() {
    switch (_selectedRole) {
      case UserRole.patient:
        return {
          'fullName':        _fullName,
          'email':           _emailCtrl.text.trim(),
          'password':        _passCtrl.text,
          'confirmPassword': _cpassCtrl.text,
          'phone':           _phoneCtrl.text.trim(),
          'address':         _addressCtrl.text.trim(),
          'gender':          _gender,
          'bloodType':       _bloodType,
          'birthDate':       _birthDate != null
              ? '${_birthDate!.year.toString().padLeft(4,'0')}-${_birthDate!.month.toString().padLeft(2,'0')}-${_birthDate!.day.toString().padLeft(2,'0')}'
              : '2000-01-01',
          if (_medicalCtrl.text.trim().isNotEmpty)
            'medicalRecord': _medicalCtrl.text.trim(),
          // latitude/longitude not set at registration — pushed live by GPS tracking
        };

      case UserRole.doctor:
        return {
          'fullName':        _fullName,
          'email':           _emailCtrl.text.trim(),
          'password':        _passCtrl.text,
          'confirmPassword': _cpassCtrl.text,
          'phone':           _phoneCtrl.text.trim(),
          'specialization':  _specCtrl.text.trim(),
          if (_clinicNameCtrl.text.trim().isNotEmpty)
            'clinicName':    _clinicNameCtrl.text.trim(),
          if (_clinicLat != null) 'clinicLatitude':  _clinicLat,
          if (_clinicLng != null) 'clinicLongitude': _clinicLng,
        };

      case UserRole.lab:
        return {
          'labName':         _labNameCtrl.text.trim(),
          'email':           _emailCtrl.text.trim(),
          'password':        _passCtrl.text,
          'confirmPassword': _cpassCtrl.text,
          'phone':           _phoneCtrl.text.trim(),
          'location':        _locationCtrl.text.trim(),
          if (_labLat != null) 'latitude':  _labLat,
          if (_labLng != null) 'longitude': _labLng,
        };

      case UserRole.relative:
        return {
          'fullName':        _fullName,
          'email':           _emailCtrl.text.trim(),
          'password':        _passCtrl.text,
          'confirmPassword': _cpassCtrl.text,
          'phone':           _phoneCtrl.text.trim(),
          'relationType': _relationCtrl.text.trim().isEmpty
              ? 'Family'
              : _relationCtrl.text.trim(),
        };

      case UserRole.ambulance:
        return {
          'email':           _emailCtrl.text.trim(),
          'password':        _passCtrl.text,
          'confirmPassword': _cpassCtrl.text,
          'phone':           _phoneCtrl.text.trim(),
          'driverName':      '${_driverFirstNameCtrl.text.trim()} ${_driverLastNameCtrl.text.trim()}'.trim(),
          'driverPhone':     _driverPhoneCtrl.text.trim(),
          'licensePlate':    _licensePlateCtrl.text.trim(),
          if (_serviceAreaCtrl.text.trim().isNotEmpty)
            'serviceArea':   _serviceAreaCtrl.text.trim(),
        };

      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (_step == 1) ...[
              Text('Choose your role',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              ..._roles.map((r) => _RoleTile(
                icon:     r.$2,
                label:    r.$3,
                selected: _selectedRole == r.$1,
                onTap:    () => setState(() => _selectedRole = r.$1),
              )),
              const SizedBox(height: 20),
              PrimaryButton(
                label:     'Continue',
                onPressed: _selectedRole == null
                    ? null
                    : () => setState(() => _step = 2),
              ),
            ] else ...[
              if (auth.error != null) ...[
                AlertWidget(message: auth.error!, isError: true),
                const SizedBox(height: 14),
              ],
              // When there are field errors, show a compact hint above the form
              if (auth.fieldErrors.isNotEmpty && auth.error == null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'Please fix the highlighted fields below.',
                      style: GoogleFonts.dmSans(fontSize: 13, color: Colors.red.shade700),
                    )),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              _buildFields(isDark),
              const SizedBox(height: 20),
              PrimaryButton(
                label:     'Create account',
                isLoading: auth.isLoading,
                onPressed: () async {
                  final body = _buildBody();
                  if (body == null || _selectedRole == null) return;
                  final role = _selectedRole!;
                  final ok   = await auth.register(role, body);
                  if (!mounted) return;
                  if (ok) {
                    final app = context.read<AppProvider>();
                    await app.loadAll(auth.role,
                        patientEmail: auth.role == UserRole.patient ? auth.user?.email : null);
                    if (!mounted) return;
                    if (role == UserRole.relative) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const RelativeLinkScreen()),
                        (_) => false,
                      );
                    } else {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const HomeScreen()),
                        (_) => false,
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => setState(() { _step = 1; auth.clearError(); }),
                child: const Text('← Back'),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildFields(bool isDark) {
    final fields = <Widget>[];
    final auth = context.read<AuthProvider>();

    // Maps display label → JSON field name (lowercased, matches backend errors key)
    String fieldKey(String label) {
      switch (label.toLowerCase()) {
        case 'first name':   return 'fullname';
        case 'last name':    return 'fullname';
        case 'driver first name': return 'drivername';
        case 'driver last name':  return 'drivername';
        case 'email':        return 'email';
        case 'password':     return 'password';
        case 'confirm':      return 'confirmpassword';
        case 'phone':        return 'phone';
        case 'address':      return 'address';
        case 'medical record': return 'medicalrecord';
        case 'specialization': return 'specialization';
        case 'clinic name':    return 'clinicname';
        case 'lab name':       return 'labname';
        case 'relation type':  return 'relationtype';
        case 'driver phone':   return 'driverphone';
        case 'license plate':  return 'licenseplate';
        case 'service area':   return 'servicearea';
        case 'unit phone':     return 'phone';
        default:               return label.toLowerCase().replaceAll(' ', '');
      }
    }

    // Helper — adds a labelled text field
    void text(
      String label,
      TextEditingController ctrl, {
      bool obscure          = false,
      TextInputType? kb,
      String hint           = '',
      bool required         = true,
    }) {
      final displayLabel = required
          ? label.toUpperCase()
          : '${label.toUpperCase()} (OPTIONAL)';

      // Each password field gets its own toggle state
      final isPassField  = obscure && ctrl == _passCtrl;
      final isCpassField = obscure && ctrl == _cpassCtrl;
      final actualObscure = isPassField  ? _obscurePass
                          : isCpassField ? _obscureCpass
                          : obscure;

      final fieldError = auth.fieldErrors[fieldKey(label)];
      final hasError   = fieldError != null;

      fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(displayLabel,
            style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: hasError
                  ? Colors.red.shade700
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              letterSpacing: 0.05,
            )),
        const SizedBox(height: 5),
        TextField(
          controller: ctrl,
          obscureText: actualObscure,
          keyboardType: kb,
          decoration: InputDecoration(
            hintText: hint,
            errorText: fieldError,
            suffixIcon: obscure
                ? IconButton(
                    icon: Icon(
                      actualObscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () {
                      if (isPassField) {
                        setState(() => _obscurePass = !_obscurePass);
                      } else if (isCpassField) {
                        setState(() => _obscureCpass = !_obscureCpass);
                      }
                    },
                  )
                : null,
          ),
        ),
        const SizedBox(height: 12),
      ]));
    }

    switch (_selectedRole) {
      // ── Patient ──────────────────────────────────────────────
      case UserRole.patient:
        text('First Name',     _firstNameCtrl, hint: 'Ahmed');
        text('Last Name',      _lastNameCtrl,  hint: 'Hassan');
        text('Email',          _emailCtrl,   kb: TextInputType.emailAddress, hint: 'ahmed@example.com');
        text('Password',       _passCtrl,    obscure: true);
        text('Confirm',        _cpassCtrl,   obscure: true);
        text('Phone',          _phoneCtrl,   kb: TextInputType.phone, hint: '01XXXXXXXXX');
        text('Address',        _addressCtrl, hint: 'Nasr City, Cairo');
        text('Medical Record', _medicalCtrl, hint: 'Any known conditions…', required: false);

        // Birth Date
        fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BIRTH DATE',
              style: GoogleFonts.dmSans(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                letterSpacing: 0.05,
              )),
          const SizedBox(height: 5),
          GestureDetector(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: _birthDate ?? DateTime(1995, 1, 1),
                firstDate: DateTime(1900),
                lastDate: DateTime.now().subtract(const Duration(days: 1)),
              );
              if (picked != null) setState(() => _birthDate = picked);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isDark ? AppColors.darkBgCard : Colors.white,
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_outlined, size: 16,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                const SizedBox(width: 10),
                Text(
                  _birthDate != null
                      ? '${_birthDate!.day}/${_birthDate!.month}/${_birthDate!.year}'
                      : 'Select your birth date',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: _birthDate != null
                        ? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)
                        : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
        ]));

        // Gender
        fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GENDER', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              letterSpacing: 0.05)),
          Row(children: ['male', 'female'].map((g) => Expanded(child: RadioListTile<String>(
            title: Text(g, style: GoogleFonts.dmSans(fontSize: 13)),
            value: g, groupValue: _gender,
            onChanged: (v) => setState(() => _gender = v!),
          ))).toList()),
          const SizedBox(height: 4),
        ]));

        // Blood type
        fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BLOOD TYPE', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              letterSpacing: 0.05)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _bloodType,
            items: ['Unknown', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bloodType = v ?? 'Unknown'),
          ),
          const SizedBox(height: 12),
        ]));

        // Location is handled by live GPS tracking after login — not set at registration
        break;

      // ── Doctor ───────────────────────────────────────────────
      case UserRole.doctor:
        text('First Name',     _firstNameCtrl,  hint: 'Ahmed');
        text('Last Name',      _lastNameCtrl,   hint: 'Ali');
        text('Email',          _emailCtrl,     kb: TextInputType.emailAddress);
        text('Password',       _passCtrl,      obscure: true);
        text('Confirm',        _cpassCtrl,     obscure: true);
        text('Phone',          _phoneCtrl,     kb: TextInputType.phone);
        text('Specialization', _specCtrl,      hint: 'Cardiology');
        text('Clinic Name',    _clinicNameCtrl,hint: 'HealthCare Clinic', required: false);
        fields.add(StaticLocationPickerField(
          label:      'Clinic Location (optional)',
          initialLat: _clinicLat,
          initialLng: _clinicLng,
          onPicked:   (lat, lng) =>
              setState(() { _clinicLat = lat; _clinicLng = lng; }),
        ));
        break;

      // ── Lab ──────────────────────────────────────────────────
      case UserRole.lab:
        text('Lab Name', _labNameCtrl,  hint: 'Cairo Central Lab');
        text('Email',    _emailCtrl,    kb: TextInputType.emailAddress);
        text('Password', _passCtrl,     obscure: true);
        text('Confirm',  _cpassCtrl,    obscure: true);
        text('Phone',    _phoneCtrl,    kb: TextInputType.phone);
        text('Address',  _locationCtrl, hint: 'Shubra, Cairo');
        fields.add(StaticLocationPickerField(
          label:      'Lab Location on Map',
          initialLat: _labLat,
          initialLng: _labLng,
          onPicked:   (lat, lng) =>
              setState(() { _labLat = lat; _labLng = lng; }),
        ));
        break;

      // ── Relative ─────────────────────────────────────────────
      case UserRole.relative:
        text('First Name',    _firstNameCtrl, hint: 'Sara');
        text('Last Name',     _lastNameCtrl,  hint: 'Ahmed');
        text('Email',         _emailCtrl,   kb: TextInputType.emailAddress);
        text('Password',      _passCtrl,    obscure: true);
        text('Confirm',       _cpassCtrl,   obscure: true);
        text('Phone',         _phoneCtrl,   kb: TextInputType.phone);
        text('Relation Type', _relationCtrl, hint: 'Default: Family (optional)');
        fields.add(Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(children: [
            Icon(Icons.info_outline_rounded, size: 16,
                color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
            const SizedBox(width: 8),
            Expanded(child: Text(
              "After registering you'll search for your patient and send a link request.",
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
            )),
          ]),
        ));
        break;

      // ── Ambulance — driver is the identity, no station name ──
      case UserRole.ambulance:
        text('Driver First Name', _driverFirstNameCtrl, hint: 'Ali');
        text('Driver Last Name',  _driverLastNameCtrl,  hint: 'Hassan');
        text('Email',        _emailCtrl,        kb: TextInputType.emailAddress);
        text('Password',     _passCtrl,         obscure: true);
        text('Confirm',      _cpassCtrl,        obscure: true);
        text('Unit Phone',   _phoneCtrl,        kb: TextInputType.phone, hint: '01XXXXXXXXX');
        text('Driver Phone', _driverPhoneCtrl,  kb: TextInputType.phone);
        text('License Plate',_licensePlateCtrl, hint: 'Cairo A-1234');
        text('Service Area', _serviceAreaCtrl,  hint: 'Nasr City, Cairo', required: false);
        break;

      default:
        break;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: fields);
  }
}

// ── Role tile ─────────────────────────────────────────────────

class _RoleTile extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     selected;
  final VoidCallback onTap;

  const _RoleTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected
              ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
              : (isDark ? AppColors.darkBgCard     : AppColors.bgCard),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected
                ? (isDark ? AppColors.darkAccent : AppColors.accent)
                : (isDark ? AppColors.darkBorderColor : AppColors.borderColor),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Icon(icon, size: 20,
              color: selected
                  ? (isDark ? AppColors.darkAccent : AppColors.accent)
                  : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w500,
                color: selected
                    ? (isDark ? AppColors.darkAccent : AppColors.accent)
                    : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
              )),
        ]),
      ),
    );
  }
}
