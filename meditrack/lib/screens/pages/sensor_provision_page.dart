import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

// The ESP32 AP always gets this IP when acting as Access Point
const String _espIp = 'http://192.168.4.1';

class SensorProvisionPage extends StatefulWidget {
  final int patientId;
  const SensorProvisionPage({super.key, required this.patientId});

  @override
  State<SensorProvisionPage> createState() => _SensorProvisionPageState();
}

class _SensorProvisionPageState extends State<SensorProvisionPage> {
  // ── State machine ─────────────────────────────────────────
  _Step _step = _Step.connect;

  // ── Form controllers ──────────────────────────────────────
  final _ssidCtrl    = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _serverCtrl  = TextEditingController(
      text: 'http://192.168.0.102:5098/api/vitalsigns/sensor');
  bool _obscurePass  = true;

  // ── Operation state ───────────────────────────────────────
  bool    _checking   = false;
  bool    _sending    = false;
  String? _error;

  @override
  void dispose() {
    _ssidCtrl.dispose();
    _passCtrl.dispose();
    _serverCtrl.dispose();
    super.dispose();
  }

  // ── Step 1: verify ESP32 is reachable ─────────────────────
  Future<void> _checkConnection() async {
    setState(() { _checking = true; _error = null; });
    try {
      final res = await http
          .get(Uri.parse('$_espIp/status'))
          .timeout(const Duration(seconds: 5));
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        if (body['mode'] == 'provisioning') {
          setState(() { _step = _Step.configure; });
        } else {
          setState(() { _error = 'Unexpected response from sensor.'; });
        }
      } else {
        setState(() { _error = 'Sensor responded with HTTP ${res.statusCode}'; });
      }
    } catch (_) {
      setState(() {
        _error = 'Cannot reach sensor.\n'
            'Make sure your phone is connected to "$_apName" WiFi.';
      });
    } finally {
      setState(() => _checking = false);
    }
  }

  // ── Step 2: send config to ESP32 ──────────────────────────
  Future<void> _sendConfig() async {
    final ssid   = _ssidCtrl.text.trim();
    final server = _serverCtrl.text.trim();
    if (ssid.isEmpty) {
      setState(() => _error = 'WiFi name is required.');
      return;
    }

    setState(() { _sending = true; _error = null; });
    try {
      final res = await http
          .post(
            Uri.parse('$_espIp/provision'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'patientId': widget.patientId,
              'ssid':      ssid,
              'password':  _passCtrl.text,
              'serverUrl': server,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (res.statusCode == 200) {
        setState(() { _step = _Step.done; });
      } else {
        final msg = (jsonDecode(res.body) as Map)['error'] ?? 'Failed';
        setState(() => _error = msg.toString());
      }
    } catch (_) {
      // ESP32 reboots immediately → connection drops → that's expected
      setState(() { _step = _Step.done; });
    } finally {
      setState(() => _sending = false);
    }
  }

  static const _apName = 'MediTrack-Setup';

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('Setup Sensor',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // ── Progress indicator ───────────────────
                  _ProvisionStepper(step: _step, isDark: isDark),
                  const SizedBox(height: 28),

                  // ── Step content ─────────────────────────
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    child: _buildStepContent(isDark),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStepContent(bool isDark) {
    switch (_step) {
      case _Step.connect:
        return _buildConnectStep(isDark);
      case _Step.configure:
        return _buildConfigureStep(isDark);
      case _Step.done:
        return _buildDoneStep(isDark);
    }
  }

  // ── STEP 1: Connect ───────────────────────────────────────
  Widget _buildConnectStep(bool isDark) {
    return Column(
      key: const ValueKey('connect'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionIcon(
            icon: Icons.wifi_tethering_rounded,
            isDark: isDark),
        const SizedBox(height: 14),
        Text('Connect to Sensor',
            style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(
          'Your sensor is in setup mode. Follow these steps:',
          style: GoogleFonts.dmSans(fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        // Instructions card
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _InstructionRow(
              number: '1',
              text: 'Power on your ESP32 sensor',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InstructionRow(
              number: '2',
              text: 'Go to your phone WiFi settings',
              isDark: isDark,
            ),
            const SizedBox(height: 12),
            _InstructionRow(
              number: '3',
              isDark: isDark,
              child: RichText(
                text: TextSpan(
                  style: GoogleFonts.dmSans(fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.textPrimary),
                  children: [
                    const TextSpan(text: 'Connect to '),
                    TextSpan(
                      text: _apName,
                      style: GoogleFonts.sourceCodePro(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? AppColors.darkAccent
                              : AppColors.accent),
                    ),
                    const TextSpan(text: ' (no password)'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _InstructionRow(
              number: '4',
              text: 'Come back here and tap "Sensor Connected"',
              isDark: isDark,
            ),
          ]),
        ),
        const SizedBox(height: 16),

        // Patient ID reminder
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark
                  ? AppColors.darkAccent.withValues(alpha: 0.3)
                  : AppColors.accent.withValues(alpha: 0.2),
            ),
          ),
          child: Row(children: [
            Icon(Icons.badge_outlined, size: 18,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'This sensor will be linked to your account',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.accent),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        if (_error != null) _ErrorBox(message: _error!, isDark: isDark),
        if (_error != null) const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _checking
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.wifi_rounded, size: 18),
            label: Text(
              _checking ? 'Checking...' : 'Sensor Connected ✓',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onPressed: _checking ? null : _checkConnection,
          ),
        ),
      ],
    );
  }

  // ── STEP 2: Configure ─────────────────────────────────────
  Widget _buildConfigureStep(bool isDark) {
    return Column(
      key: const ValueKey('configure'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionIcon(icon: Icons.settings_rounded, isDark: isDark),
        const SizedBox(height: 14),
        Text('Configure Sensor',
            style: GoogleFonts.dmSans(
                fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(
          'Enter your home WiFi so the sensor can send readings to the backend.',
          style: GoogleFonts.dmSans(fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
        ),
        const SizedBox(height: 20),

        AppCard(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            // WiFi name
            _FieldLabel('WiFi Name (SSID)', isDark),
            const SizedBox(height: 6),
            TextField(
              controller: _ssidCtrl,
              decoration: const InputDecoration(
                  hintText: 'e.g. HomeNetwork'),
            ),
            const SizedBox(height: 14),

            // WiFi password
            _FieldLabel('WiFi Password', isDark),
            const SizedBox(height: 6),
            TextField(
              controller: _passCtrl,
              obscureText: _obscurePass,
              decoration: InputDecoration(
                hintText: 'Leave empty if open network',
                suffixIcon: IconButton(
                  icon: Icon(_obscurePass
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded),
                  onPressed: () =>
                      setState(() => _obscurePass = !_obscurePass),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Server URL
            _FieldLabel('Backend Server URL', isDark),
            const SizedBox(height: 6),
            TextField(
              controller: _serverCtrl,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  hintText: 'http://192.168.x.x:5098/api/vitalsigns/sensor'),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline_rounded, size: 13,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  'Must be on the same network as the sensor',
                  style: GoogleFonts.dmSans(fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary),
                ),
              ),
            ]),
          ]),
        ),
        const SizedBox(height: 16),

        if (_error != null) _ErrorBox(message: _error!, isDark: isDark),
        if (_error != null) const SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            icon: _sending
                ? const SizedBox(width: 16, height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded, size: 18),
            label: Text(
              _sending ? 'Sending config...' : 'Send to Sensor',
              style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
            ),
            onPressed: _sending ? null : _sendConfig,
          ),
        ),
      ],
    );
  }

  // ── STEP 3: Done ──────────────────────────────────────────
  Widget _buildDoneStep(bool isDark) {
    return Column(
      key: const ValueKey('done'),
      children: [
        const SizedBox(height: 20),
        Center(
          child: Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.darkBadgeGreenBg
                  : AppColors.badgeGreenBg,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_rounded, size: 40,
                color: isDark
                    ? AppColors.darkBadgeGreenTxt
                    : AppColors.badgeGreenTxt),
          ),
        ),
        const SizedBox(height: 20),
        Text('Sensor Configured!',
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
                fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        Text(
          'Your sensor is rebooting and will connect to your WiFi automatically.\n\n'
          'Once connected, it will start sending readings every 30 seconds.',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 14,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        Text(
          '📱 Remember to reconnect your phone to your normal WiFi!',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkAccent : AppColors.accent),
        ),
        const SizedBox(height: 30),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Done',
                style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

// ── Step enum ─────────────────────────────────────────────────

enum _Step { connect, configure, done }

// ── Stepper indicator ─────────────────────────────────────────

class _ProvisionStepper extends StatelessWidget {
  final _Step step;
  final bool isDark;
  const _ProvisionStepper({required this.step, required this.isDark});

  @override
  Widget build(BuildContext context) {
    const labels = ['Connect', 'Configure', 'Done'];
    return Row(
      children: List.generate(3, (i) {
        final active   = i == step.index;
        final complete = i < step.index;
        return Expanded(
          child: Row(children: [
            if (i > 0)
              Expanded(
                child: Container(
                  height: 2,
                  color: complete
                      ? (isDark ? AppColors.darkAccent : AppColors.accent)
                      : (isDark
                          ? AppColors.darkBorderColor
                          : AppColors.borderColor),
                ),
              ),
            Column(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: complete || active
                      ? (isDark ? AppColors.darkAccent : AppColors.accent)
                      : (isDark
                          ? AppColors.darkBorderColor
                          : AppColors.borderColor),
                ),
                child: Center(
                  child: complete
                      ? const Icon(Icons.check_rounded,
                          size: 14, color: Colors.white)
                      : Text('${i + 1}',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: active || complete
                                  ? Colors.white
                                  : (isDark
                                      ? AppColors.darkTextTertiary
                                      : AppColors.textTertiary))),
                ),
              ),
              const SizedBox(height: 4),
              Text(labels[i],
                  style: GoogleFonts.dmSans(
                      fontSize: 10,
                      fontWeight:
                          active ? FontWeight.w700 : FontWeight.w400,
                      color: active || complete
                          ? (isDark
                              ? AppColors.darkAccent
                              : AppColors.accent)
                          : (isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary))),
            ]),
            if (i < 2) const Expanded(child: SizedBox()),
          ]),
        );
      }),
    );
  }
}

// ── Small helpers ─────────────────────────────────────────────

class _SectionIcon extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  const _SectionIcon({required this.icon, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: 52, height: 52,
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Icon(icon, size: 26,
        color: isDark ? AppColors.darkAccent : AppColors.accent),
  );
}

class _InstructionRow extends StatelessWidget {
  final String number;
  final String? text;
  final Widget? child;
  final bool isDark;
  const _InstructionRow({
    required this.number,
    required this.isDark,
    this.text,
    this.child,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22, height: 22,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkAccent : AppColors.accent,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(number,
              style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: child ??
            Text(text ?? '',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary)),
      ),
    ],
  );
}

class _FieldLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _FieldLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: Text(text.toUpperCase(),
        style: GoogleFonts.dmSans(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.textTertiary)),
  );
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final bool isDark;
  const _ErrorBox({required this.message, required this.isDark});

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(message,
        style: GoogleFonts.dmSans(fontSize: 13,
            color: isDark
                ? AppColors.darkBadgeRedTxt
                : AppColors.badgeRedTxt)),
  );
}
