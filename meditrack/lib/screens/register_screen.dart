
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/home_screen.dart';
import 'package:meditrack/screens/relative_link_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  int _step = 1;
  UserRole? _selectedRole;
  final _nameCtrl    = TextEditingController(); // first name
  final _lastNameCtrl= TextEditingController(); // last name
  final _emailCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _cpassCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _medicalCtrl = TextEditingController();
  final _specCtrl    = TextEditingController();
  final _locationCtrl= TextEditingController();
  final _relationCtrl= TextEditingController();
  final _patientIdCtrl= TextEditingController();
  final _stationCtrl = TextEditingController();
  final _licensePlateCtrl = TextEditingController();
  final _driverNameCtrl   = TextEditingController();
  final _driverPhoneCtrl  = TextEditingController();
  final _clinicNameCtrl   = TextEditingController();
  final _clinicAddressCtrl= TextEditingController();
  final _clinicLatCtrl    = TextEditingController();
  final _clinicLngCtrl    = TextEditingController();
  final _labLatCtrl       = TextEditingController();
  final _labLngCtrl       = TextEditingController();
  String _gender = 'male';
  String _bloodType = 'Unknown';
  bool _obscurePass = true;

  final _roles = [
    (UserRole.patient,   Icons.person_outline,     'Patient'),
    (UserRole.doctor,    Icons.medical_services_outlined, 'Doctor'),
    (UserRole.lab,       Icons.science_outlined,   'Lab'),
    (UserRole.relative,  Icons.group_outlined,     'Relative'),
    (UserRole.ambulance, Icons.emergency_outlined, 'Ambulance'),
  ];

  @override
  void dispose() {
    for (final c in [_nameCtrl,_lastNameCtrl,_emailCtrl,_passCtrl,_cpassCtrl,_phoneCtrl,_addressCtrl,
        _medicalCtrl,_specCtrl,_locationCtrl,_relationCtrl,_patientIdCtrl,_stationCtrl,
        _licensePlateCtrl,_driverNameCtrl,_driverPhoneCtrl,
        _clinicNameCtrl,_clinicAddressCtrl,_clinicLatCtrl,_clinicLngCtrl,
        _labLatCtrl,_labLngCtrl]) { c.dispose(); }
    super.dispose();
  }

  Map<String, dynamic>? _buildBody() {
    switch (_selectedRole) {
      case UserRole.patient:
        return {'fullName': '${_nameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'confirmPassword': _cpassCtrl.text,
          'phone': _phoneCtrl.text.trim(), 'address': _addressCtrl.text.trim(),
          'gender': _gender, 'medicalRecord': _medicalCtrl.text.trim(),
          'bloodType': _bloodType};
      case UserRole.doctor:
        return {
          'fullName': '${_nameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'confirmPassword': _cpassCtrl.text,
          'phone': _phoneCtrl.text.trim(), 'specialization': _specCtrl.text.trim(),
          if (_clinicNameCtrl.text.trim().isNotEmpty)
            'clinicName': _clinicNameCtrl.text.trim(),
          if (_clinicAddressCtrl.text.trim().isNotEmpty)
            'clinicAddress': _clinicAddressCtrl.text.trim(),
          if (_clinicLatCtrl.text.trim().isNotEmpty)
            'clinicLatitude': double.tryParse(_clinicLatCtrl.text.trim()),
          if (_clinicLngCtrl.text.trim().isNotEmpty)
            'clinicLongitude': double.tryParse(_clinicLngCtrl.text.trim()),
        };
      case UserRole.lab:
        return {
          'labName': _nameCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'confirmPassword': _cpassCtrl.text,
          'phone': _phoneCtrl.text.trim(), 'location': _locationCtrl.text.trim(),
          if (_labLatCtrl.text.trim().isNotEmpty)
            'latitude': double.tryParse(_labLatCtrl.text.trim()),
          if (_labLngCtrl.text.trim().isNotEmpty)
            'longitude': double.tryParse(_labLngCtrl.text.trim()),
        };
      case UserRole.relative:
        return {'fullName': '${_nameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
          'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'confirmPassword': _cpassCtrl.text,
          'phone': _phoneCtrl.text.trim(), 'relationType': 'Family'};
      case UserRole.ambulance:
        return {'stationName': _stationCtrl.text.trim(), 'email': _emailCtrl.text.trim(),
          'password': _passCtrl.text, 'confirmPassword': _cpassCtrl.text,
          'phone': _phoneCtrl.text.trim(), 'availabilityStatus': 'Available',
          'licensePlate': _licensePlateCtrl.text.trim(),
          'driverName': _driverNameCtrl.text.trim(),
          'driverPhone': _driverPhoneCtrl.text.trim()};
      default: return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(child: SingleChildScrollView(padding: const EdgeInsets.all(24), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (_step == 1) ...[
            Text('Choose your role', style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            ..._roles.map((r) => _RoleTile(icon: r.$2, label: r.$3, selected: _selectedRole == r.$1,
              onTap: () => setState(() => _selectedRole = r.$1))),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Continue', onPressed: _selectedRole == null ? null : () => setState(() => _step = 2)),
          ] else ...[
            if (auth.error != null) ...[AlertWidget(message: auth.error!, isError: true), const SizedBox(height: 14)],
            _buildFields(isDark),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Create account', isLoading: auth.isLoading,
              onPressed: () async {
                final body = _buildBody();
                if (body == null || _selectedRole == null) return;
                final role   = _selectedRole!;
                final appPrv = context.read<AppProvider>();
                final ok     = await auth.register(role, body);
                if (!mounted) return;
                if (ok) {
                  await appPrv.loadAll(auth.role);
                  if (!mounted) return;
                  if (role == UserRole.relative) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const RelativeLinkScreen()),
                      (_) => false);
                  } else {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (_) => false);
                  }
                }
              }),
            const SizedBox(height: 10),
            TextButton(onPressed: () => setState(() { _step = 1; auth.clearError(); }), child: const Text('← Back')),
          ],
        ],
      ))),
    );
  }

  Widget _buildFields(bool isDark) {
    final fields = <Widget>[];
    void add(String label, TextEditingController ctrl, {bool obscure=false, TextInputType? kb, String hint=''}) {
      fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(), style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
        const SizedBox(height: 5),
        TextField(controller: ctrl, obscureText: obscure, keyboardType: kb,
          decoration: InputDecoration(hintText: hint,
            suffixIcon: obscure ? IconButton(icon: Icon(_obscurePass ? Icons.visibility_outlined : Icons.visibility_off_outlined, size: 18),
              onPressed: () => setState(() => _obscurePass = !_obscurePass)) : null)),
        const SizedBox(height: 12),
      ]));
    }

    switch (_selectedRole) {
      case UserRole.patient:
        add('First Name', _nameCtrl, hint: 'Ahmed');
        add('Last Name',  _lastNameCtrl, hint: 'Hassan');
        add('Email', _emailCtrl, kb: TextInputType.emailAddress, hint: 'ahmed@example.com');
        add('Password', _passCtrl, obscure: true);
        add('Confirm Password', _cpassCtrl, obscure: true);
        add('Phone', _phoneCtrl, kb: TextInputType.phone, hint: '01XXXXXXXXX');
        add('Address', _addressCtrl);
        add('Medical Record', _medicalCtrl);
        fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('GENDER', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          Row(children: ['male','female'].map((g) => Expanded(child: RadioListTile<String>(title: Text(g, style: GoogleFonts.dmSans(fontSize: 13)),
            value: g, groupValue: _gender, onChanged: (v) => setState(() => _gender = v!)))).toList()),
          const SizedBox(height: 12),
        ]));
        fields.add(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('BLOOD TYPE', style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary, letterSpacing: 0.05)),
          const SizedBox(height: 5),
          DropdownButtonFormField<String>(
            value: _bloodType,
            items: const ['Unknown', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _bloodType = v ?? 'Unknown'),
          ),
          const SizedBox(height: 12),
        ]));
        break;
      case UserRole.doctor:
        add('First Name', _nameCtrl, hint: 'Ahmed');
        add('Last Name',  _lastNameCtrl, hint: 'Hassan');
        add('Email', _emailCtrl, kb: TextInputType.emailAddress);
        add('Password', _passCtrl, obscure: true);
        add('Confirm Password', _cpassCtrl, obscure: true);
        add('Phone', _phoneCtrl, kb: TextInputType.phone);
        add('Specialization', _specCtrl, hint: 'Cardiology');
        // Optional clinic info
        fields.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('CLINIC INFO (OPTIONAL)',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  letterSpacing: 0.05)),
        ));
        add('Clinic Name', _clinicNameCtrl, hint: 'e.g. Al-Noor Clinic');
        add('Clinic Address', _clinicAddressCtrl, hint: 'e.g. 12 Tahrir St, Cairo');
        add('Clinic Latitude', _clinicLatCtrl, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), hint: 'e.g. 30.0444');
        add('Clinic Longitude', _clinicLngCtrl, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), hint: 'e.g. 31.2357');
        break;
      case UserRole.lab:
        add('Lab Name', _nameCtrl, hint: 'Cairo Central Lab');
        add('Email', _emailCtrl, kb: TextInputType.emailAddress);
        add('Password', _passCtrl, obscure: true);
        add('Confirm Password', _cpassCtrl, obscure: true);
        add('Phone', _phoneCtrl, kb: TextInputType.phone);
        add('Location', _locationCtrl, hint: 'Nasr City, Cairo');
        // Optional coordinates
        fields.add(Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text('LOCATION COORDINATES (OPTIONAL)',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  letterSpacing: 0.05)),
        ));
        add('Latitude',  _labLatCtrl, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), hint: 'e.g. 30.0444');
        add('Longitude', _labLngCtrl, kb: const TextInputType.numberWithOptions(decimal: true, signed: true), hint: 'e.g. 31.2357');
        break;
      case UserRole.relative:
        add('First Name', _nameCtrl);
        add('Last Name',  _lastNameCtrl);
        add('Email', _emailCtrl, kb: TextInputType.emailAddress);
        add('Password', _passCtrl, obscure: true);
        add('Confirm Password', _cpassCtrl, obscure: true);
        add('Phone', _phoneCtrl, kb: TextInputType.phone);
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
              "After registering, you'll search for your patient and send a link request.",
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
            )),
          ]),
        ));
        break;
      case UserRole.ambulance:
        add('Station Name', _stationCtrl, hint: 'Nasr City Station');
        add('Email', _emailCtrl, kb: TextInputType.emailAddress);
        add('Password', _passCtrl, obscure: true);
        add('Confirm Password', _cpassCtrl, obscure: true);
        add('Phone', _phoneCtrl, kb: TextInputType.phone);
        add('License Plate', _licensePlateCtrl, hint: 'Cairo A-1234');
        add('Driver Name', _driverNameCtrl, hint: 'Ali Hassan');
        add('Driver Phone', _driverPhoneCtrl, kb: TextInputType.phone);
        break;
      default: break;
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: fields);
  }
}

class _RoleTile extends StatelessWidget {
  final IconData icon; final String label; final bool selected; final VoidCallback onTap;
  const _RoleTile({required this.icon, required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(onTap: onTap, child: Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted) : (isDark ? AppColors.darkBgCard : AppColors.bgCard),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: selected ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkBorderColor : AppColors.borderColor), width: selected ? 1.5 : 1)),
      child: Row(children: [
        Icon(icon, size: 20, color: selected ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        const SizedBox(width: 12),
        Text(label, style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w500,
          color: selected ? (isDark ? AppColors.darkAccent : AppColors.accent) : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
      ])));
  }
}
