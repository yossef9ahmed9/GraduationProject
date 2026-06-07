import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class VitalsPage extends StatefulWidget {
  const VitalsPage({super.key});
  @override
  State<VitalsPage> createState() => _VitalsPageState();
}

class _VitalsPageState extends State<VitalsPage> {
  int? _selectedPatientId;
  List<VitalSignsResponse> _history = [];
  bool _loading = false;
  String? _error;

  // ── AI risk analysis ──────────────────────────────────────────
  HeartRiskResponse? _riskResult;
  bool _analyzingRisk = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  void _init() {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final role = auth.role;
    int? id;
    if (role == UserRole.patient) {
      id = app.patientByEmail(auth.user?.email ?? '')?.id;
    } else if (role == UserRole.relative) {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    } else {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    }
    if (id != null) _loadVitals(id);
  }

  Future<void> _loadVitals(int patientId) async {
    setState(() { _loading = true; _error = null; _selectedPatientId = patientId; _riskResult = null; });
    try {
      final res = await apiService.getVitalsByPatient(patientId);
      if (res.ok) {
        setState(() { _history = res.data ?? []; _loading = false; });
        if (_history.isNotEmpty) _analyzeRisk(_history.first);
      } else {
        setState(() { _error = res.error ?? 'Failed to load vitals.'; _loading = false; });
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _analyzeRisk(VitalSignsResponse vital) async {
    final app = context.read<AppProvider>();
    final patient = _selectedPatientId != null
        ? app.patients.where((p) => p.id == _selectedPatientId).firstOrNull
        : null;

    // Compute age from birthDate
    int age = 40; // default
    if (patient?.birthDate != null) {
      final birth = DateTime.tryParse(patient!.birthDate!);
      if (birth != null) age = DateTime.now().year - birth.year;
    }
    final sex = (patient?.gender.toLowerCase() == 'male') ? 1 : 0;

    setState(() => _analyzingRisk = true);
    final res = await apiService.predictHeartRisk(HeartRiskRequest(
      bpm:   vital.heartRate.toDouble(),
      spo2:  vital.oxygenSaturation ?? 98.0,
      hrvMs: 50.0, // default — not measured yet
      age:   age,
      sex:   sex,
    ));
    if (!mounted) return;
    setState(() {
      _analyzingRisk = false;
      if (res.ok) _riskResult = res.data;
    });
  }

  String _alertText(VitalSignsResponse v) {
    if (v.heartRate > 100) return 'Heart rate ${v.heartRate} bpm — elevated';
    if (v.heartRate < 60)  return 'Heart rate ${v.heartRate} bpm — low';
    if ((v.oxygenSaturation ?? 100) < 95)
      return 'SpO₂ ${v.oxygenSaturation?.toStringAsFixed(1)}% — low';
    return 'Emergency status active';
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    final latest  = _history.isNotEmpty ? _history.first : null;
    final hrHigh  = (latest?.heartRate ?? 0) > 100;
    final hrLow   = (latest?.heartRate ?? 0) < 60 && latest != null;
    final o2Low   = (latest?.oxygenSaturation ?? 100) < 95 && latest != null;
    final isAlert = latest?.isAlert ?? false;
    final isFixed = role == UserRole.patient || role == UserRole.relative;

    String patientLabel = '—';
    if (role == UserRole.patient) {
      final me = app.patientByEmail(auth.user?.email ?? '');
      patientLabel = me?.name ?? auth.user?.name ?? '—';
    } else if (_selectedPatientId != null) {
      try { patientLabel = app.patients.firstWhere((p) => p.id == _selectedPatientId).name; }
      catch (_) {}
    }

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedPatientId != null) await _loadVitals(_selectedPatientId!);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Patient selector ──────────────────────────────────
          Row(children: [
            const Icon(Icons.person_outline, size: 15),
            const SizedBox(width: 6),
            Expanded(
              child: isFixed
                  ? Text(patientLabel,
                      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500))
                  : app.patients.isEmpty
                  ? Text('No patients',
                      style: GoogleFonts.dmSans(fontSize: 13,
                          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))
                  : DropdownButton<int>(
                      value: _selectedPatientId,
                      isDense: true,
                      underline: const SizedBox(),
                      style: GoogleFonts.dmSans(fontSize: 13,
                          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                      items: app.patients.map((p) =>
                          DropdownMenuItem(value: p.id, child: Text('${p.name} — #${p.id}'))).toList(),
                      onChanged: (id) { if (id != null) _loadVitals(id); },
                    ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _selectedPatientId != null ? () => _loadVitals(_selectedPatientId!) : null,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              tooltip: 'Refresh',
              style: IconButton.styleFrom(
                  padding: const EdgeInsets.all(6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            ),
          ]),
          const SizedBox(height: 14),

          if (_error != null) ...[
            AlertWidget(message: _error!, isError: true),
            const SizedBox(height: 12),
          ],
          if (isAlert && latest != null) ...[
            EmergencyBanner(text: _alertText(latest)),
            const SizedBox(height: 12),
          ],

          if (_loading)
            const Center(child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: CircularProgressIndicator()))
          else if (latest == null)
            const EmptyState(
                message: 'No vitals data for this patient',
                icon: Icons.monitor_heart_outlined)
          else ...[
            // ── Vital cards grid ────────────────────────────────
            GridView.count(
              crossAxisCount: 2, shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55,
              children: [
                VitalCard(label: 'Heart rate', value: '${latest.heartRate}', unit: 'bpm',
                    valueColor: hrHigh || hrLow
                        ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null),
                VitalCard(label: 'Oxygen saturation',
                    value: latest.oxygenSaturation?.toStringAsFixed(1) ?? '—', unit: '% SpO₂',
                    valueColor: o2Low
                        ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null),
                VitalCard(label: 'Temperature',
                    value: latest.temperature?.toStringAsFixed(1) ?? '—', unit: '°C'),
                VitalCard(label: 'Blood pressure', value: latest.bpDisplay, unit: 'mmHg'),
                VitalCard(label: 'Respiratory rate',
                    value: latest.respiratoryRate?.toString() ?? '—', unit: 'breaths/min'),
                VitalCard(label: 'Blood glucose',
                    value: latest.bloodGlucose?.toStringAsFixed(1) ?? '—', unit: 'mg/dL'),
              ],
            ),
            const SizedBox(height: 16),

            // ── AI Risk Assessment card ─────────────────────────
            _RiskCard(
              result: _riskResult,
              analyzing: _analyzingRisk,
              onReanalyze: () => _analyzeRisk(latest),
            ),
            const SizedBox(height: 16),

            // ── Mini vitals charts ──────────────────────────────
            if (_history.length > 1) ...[
              _MiniVitalChart(
                history: _history,
                label: 'Heart Rate',
                unit: 'bpm',
                color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
                getValue: (v) => v.heartRate.toDouble(),
                minY: 40, maxY: 160,
              ),
              const SizedBox(height: 16),
              _MiniVitalChart(
                history: _history,
                label: 'SpO₂',
                unit: '%',
                color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt,
                getValue: (v) => v.oxygenSaturation ?? 0,
                minY: 85, maxY: 100,
              ),
              const SizedBox(height: 16),
            ],

            // ── History table ───────────────────────────────────
            AppCard(child: Column(children: [
              const CardHeader(title: 'Vitals history'),
              if (_history.isEmpty)
                const EmptyState(message: 'No history')
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    headingRowHeight: 36,
                    dataRowMinHeight: 40, dataRowMaxHeight: 48,
                    columnSpacing: 20,
                    headingTextStyle: GoogleFonts.dmSans(
                        fontSize: 10.5, fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        letterSpacing: 0.05),
                    dataTextStyle: GoogleFonts.dmSans(fontSize: 12.5,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary),
                    columns: const [
                      DataColumn(label: Text('TIME')),
                      DataColumn(label: Text('HR')),
                      DataColumn(label: Text('SPO₂')),
                      DataColumn(label: Text('TEMP')),
                      DataColumn(label: Text('BP')),
                      DataColumn(label: Text('STATUS')),
                    ],
                    rows: _history.take(20).map((v) {
                      final ts = DateTime.tryParse(v.timeStamp)?.toLocal();
                      final timeStr = ts != null
                          ? '${ts.hour.toString().padLeft(2,'0')}:${ts.minute.toString().padLeft(2,'0')} ${ts.day}/${ts.month}'
                          : '—';
                      return DataRow(cells: [
                        DataCell(Text(timeStr, style: GoogleFonts.dmMono(fontSize: 11.5))),
                        DataCell(Text('${v.heartRate}', style: GoogleFonts.dmMono(fontSize: 12,
                            color: v.heartRate > 100 || v.heartRate < 60
                                ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null))),
                        DataCell(Text(v.oxygenSaturation?.toStringAsFixed(1) ?? '—',
                            style: GoogleFonts.dmMono(fontSize: 12,
                                color: (v.oxygenSaturation ?? 100) < 95
                                    ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null))),
                        DataCell(Text(v.temperature?.toStringAsFixed(1) ?? '—',
                            style: GoogleFonts.dmMono(fontSize: 12))),
                        DataCell(Text(v.bpDisplay, style: GoogleFonts.dmMono(fontSize: 12))),
                        DataCell(BadgeWidget(
                            label: v.emergencyStatus ? 'Alert' : 'Normal',
                            type: v.emergencyStatus ? BadgeType.red : BadgeType.green)),
                      ]);
                    }).toList(),
                  ),
                ),
            ])),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// AI Risk Assessment Card
// ════════════════════════════════════════════════════════════════

class _RiskCard extends StatelessWidget {
  final HeartRiskResponse? result;
  final bool analyzing;
  final VoidCallback onReanalyze;
  const _RiskCard({required this.result, required this.analyzing, required this.onReanalyze});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    BadgeType tierBadge(String tier) {
      switch (tier.toUpperCase()) {
        case 'CRITICAL': return BadgeType.red;
        case 'WARNING':  return BadgeType.amber;
        default:         return BadgeType.green;
      }
    }

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
        child: Row(children: [
          Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.psychology_rounded, size: 18,
                color: isDark ? AppColors.darkAccent : AppColors.accent),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text('AI Risk Assessment',
              style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
          if (analyzing)
            const SizedBox(width: 18, height: 18,
                child: CircularProgressIndicator(strokeWidth: 2))
          else
            TextButton(
              onPressed: onReanalyze,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Re-analyze',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500)),
            ),
        ]),
      ),

      if (result == null && !analyzing)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Text('Analysis will appear after vitals load.',
              style: GoogleFonts.dmSans(fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        )
      else if (result != null) ...[
        Divider(height: 1, color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Tier + score row
            Row(children: [
              BadgeWidget(label: result!.tier, type: tierBadge(result!.tier)),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Risk score: ${result!.score.toStringAsFixed(1)}%',
                    style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600)),
                Text('Confidence: ${result!.confidence.toStringAsFixed(1)}%',
                    style: GoogleFonts.dmSans(fontSize: 11,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ]),
            ]),
            const SizedBox(height: 10),
            // Action
            Text(result!.action,
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                    color: result!.tier == 'CRITICAL'
                        ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                        : result!.tier == 'WARNING'
                        ? (isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt)
                        : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt))),
            const SizedBox(height: 6),
            // Message
            Text(result!.message,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            // Override reason
            if (result!.overrideReason != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBadgeAmberBg : AppColors.badgeAmberBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, size: 14,
                      color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt),
                  const SizedBox(width: 6),
                  Expanded(child: Text(result!.overrideReason!,
                      style: GoogleFonts.dmSans(fontSize: 11,
                          color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt))),
                ]),
              ),
            ],
            // Probability bars
            const SizedBox(height: 12),
            _ProbRow('Normal',   result!.probabilities.normal,   BadgeType.green,  isDark),
            const SizedBox(height: 4),
            _ProbRow('Warning',  result!.probabilities.warning,  BadgeType.amber,  isDark),
            const SizedBox(height: 4),
            _ProbRow('Critical', result!.probabilities.critical, BadgeType.red,    isDark),
          ]),
        ),
      ],
    ]));
  }
}

class _ProbRow extends StatelessWidget {
  final String label;
  final double value;
  final BadgeType type;
  final bool isDark;
  const _ProbRow(this.label, this.value, this.type, this.isDark);

  Color _color() {
    switch (type) {
      case BadgeType.green: return isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt;
      case BadgeType.amber: return isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt;
      case BadgeType.red:   return isDark ? AppColors.darkBadgeRedTxt   : AppColors.badgeRedTxt;
      default:              return isDark ? AppColors.darkAccent         : AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Row(children: [
      SizedBox(width: 56,
          child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 11,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
      Expanded(child: ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: (value / 100).clamp(0.0, 1.0),
          minHeight: 6,
          backgroundColor: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
          valueColor: AlwaysStoppedAnimation<Color>(color),
        ),
      )),
      const SizedBox(width: 8),
      SizedBox(width: 40,
          child: Text('${value.toStringAsFixed(1)}%',
              textAlign: TextAlign.right,
              style: GoogleFonts.dmMono(fontSize: 11,
                  fontWeight: FontWeight.w600, color: color))),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// Mini Vitals Chart
// ════════════════════════════════════════════════════════════════

class _MiniVitalChart extends StatelessWidget {
  final List<VitalSignsResponse> history;
  final String label;
  final String unit;
  final Color color;
  final double Function(VitalSignsResponse) getValue;
  final double minY, maxY;

  const _MiniVitalChart({
    required this.history,
    required this.label,
    required this.unit,
    required this.color,
    required this.getValue,
    required this.minY,
    required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Show last 20, oldest first
    final sorted = history.reversed.take(20).toList();
    final spots = sorted.asMap().entries
        .map((e) {
          final v = getValue(e.value);
          return v == 0 ? null : FlSpot(e.key.toDouble(), v);
        })
        .whereType<FlSpot>()
        .toList();

    if (spots.isEmpty) return const SizedBox.shrink();

    final latest = spots.last.y;
    final min    = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final max    = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);

    return AppCard(child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700))),
          Text('${latest.toStringAsFixed(1)} $unit',
              style: GoogleFonts.dmMono(fontSize: 13,
                  fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 12),
        SizedBox(
          height: 120,
          child: LineChart(LineChartData(
            minY: minY, maxY: maxY,
            gridData: FlGridData(
              show: true, drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => FlLine(
                color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
                strokeWidth: 1),
            ),
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true, reservedSize: 32,
                getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                    style: GoogleFonts.dmMono(fontSize: 9,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: color,
                barWidth: 2.5,
                dotData: FlDotData(show: spots.length < 10),
                belowBarData: BarAreaData(
                    show: true, color: color.withValues(alpha: 0.08)),
              ),
            ],
          )),
        ),
        const SizedBox(height: 10),
        Row(children: [
          _StatChip('Latest', '${latest.toStringAsFixed(1)} $unit', isDark),
          const SizedBox(width: 8),
          _StatChip('Min',    '${min.toStringAsFixed(1)} $unit',    isDark),
          const SizedBox(width: 8),
          _StatChip('Max',    '${max.toStringAsFixed(1)} $unit',    isDark),
        ]),
      ]),
    ));
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _StatChip(this.label, this.value, this.isDark);
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF5F7FB),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 9, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
            letterSpacing: 0.05)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
      ]),
    ),
  );
}
