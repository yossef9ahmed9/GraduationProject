import 'dart:convert';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class ProgressPage extends StatefulWidget {
  const ProgressPage({super.key});
  @override
  State<ProgressPage> createState() => _ProgressPageState();
}

class _ProgressPageState extends State<ProgressPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  PatientProgressResponse? _data;
  bool _loading = false;
  String? _error;
  int? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  void _init() {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    int? id;
    if (auth.role == UserRole.patient) {
      id = app.patientByEmail(auth.user?.email ?? '')?.id;
    } else if (auth.role == UserRole.relative) {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    } else {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    }
    if (id != null) _load(id);
  }

  Future<void> _load(int patientId) async {
    setState(() { _loading = true; _error = null; _selectedPatientId = patientId; });
    final res = await apiService.getPatientProgress(patientId);
    if (!mounted) return;
    if (res.ok) {
      setState(() { _data = res.data; _loading = false; });
    } else {
      setState(() { _error = res.error ?? 'Failed to load progress.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    final selectablePatients = role == UserRole.doctor
        ? app.patients.where((p) =>
            app.followUps.any((f) => f.patientId == p.id)).toList()
        : app.patients;
    final canSelectPatient =
        (role == UserRole.doctor || role == UserRole.admin || role == UserRole.lab) &&
        selectablePatients.length > 1;

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedPatientId != null) await _load(_selectedPatientId!);
      },
      child: Column(children: [
        if (canSelectPatient && selectablePatients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<int>(
              value: _selectedPatientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Patient', isDense: true),
              items: selectablePatients.map((p) =>
                  DropdownMenuItem(value: p.id, child: Text('${p.name} — #${p.id}'))).toList(),
              onChanged: (id) { if (id != null) _load(id); },
            ),
          ),
        Container(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: TabBar(
            controller: _tabs,
            labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Vitals'),
              Tab(text: 'Tests'),
              Tab(text: 'Summary'),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? Center(child: AlertWidget(message: _error!, isError: true))
                  : _data == null
                      ? const EmptyState(
                          message: 'No data', icon: Icons.show_chart_rounded)
                      : TabBarView(controller: _tabs, children: [
                          // Tab 1: Vitals (Heart Rate + SpO₂ stacked)
                          _VitalsTab(vitals: _data!.vitals),
                          // Tab 2: Test charts (CBC fields over time)
                          _TestChartsTab(tests: _data!.tests),
                          // Tab 3: Summary stats
                          _SummaryTab(data: _data!),
                        ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 1 — Vitals: Heart Rate + SpO₂ line charts
// ════════════════════════════════════════════════════════════════
class _VitalsTab extends StatelessWidget {
  final List<VitalPoint> vitals;
  const _VitalsTab({required this.vitals});

  @override
  Widget build(BuildContext context) {
    if (vitals.isEmpty) {
      return const EmptyState(
          message: 'No vitals data', icon: Icons.monitor_heart_outlined);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sorted = List<VitalPoint>.from(vitals)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _VitalChart(
          sorted:  sorted,
          label:   'Heart Rate (bpm)',
          color:   isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
          getValue: (v) => v.heartRate.toDouble(),
          minY: 40, maxY: 160,
        ),
        const SizedBox(height: 24),
        _VitalChart(
          sorted:  sorted,
          label:   'SpO₂ (%)',
          color:   isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt,
          getValue: (v) => v.oxygenSaturation,
          minY: 85, maxY: 100,
        ),
      ]),
    );
  }
}

class _VitalChart extends StatelessWidget {
  final List<VitalPoint>            sorted;
  final String                      label;
  final Color                       color;
  final double Function(VitalPoint) getValue;
  final double                      minY, maxY;

  const _VitalChart({
    required this.sorted, required this.label, required this.color,
    required this.getValue, required this.minY, required this.maxY,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final spots = sorted.asMap().entries
        .map((e) {
          final v = getValue(e.value);
          return (v == 0) ? null : FlSpot(e.key.toDouble(), v);
        })
        .whereType<FlSpot>()
        .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text('${sorted.length} readings',
          style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
      const SizedBox(height: 12),
      SizedBox(
        height: 180,
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
              showTitles: true, reservedSize: 36,
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
              dotData: FlDotData(show: spots.length < 30),
              belowBarData: BarAreaData(
                  show: true, color: color.withValues(alpha: 0.08)),
            ),
          ],
        )),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _StatBox(label: 'Latest',
            value: spots.isNotEmpty ? spots.last.y.toStringAsFixed(1) : '—'),
        const SizedBox(width: 8),
        _StatBox(label: 'Min',
            value: spots.isNotEmpty
                ? spots.map((s) => s.y).reduce((a, b) => a < b ? a : b).toStringAsFixed(1)
                : '—'),
        const SizedBox(width: 8),
        _StatBox(label: 'Max',
            value: spots.isNotEmpty
                ? spots.map((s) => s.y).reduce((a, b) => a > b ? a : b).toStringAsFixed(1)
                : '—'),
        const SizedBox(width: 8),
        _StatBox(label: 'Avg',
            value: spots.isNotEmpty
                ? (spots.map((s) => s.y).reduce((a, b) => a + b) / spots.length)
                    .toStringAsFixed(1)
                : '—'),
      ]),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 2 — Tests: one line chart per CBC field across visits
// ════════════════════════════════════════════════════════════════
class _TestChartsTab extends StatelessWidget {
  final List<TestPoint> tests;
  const _TestChartsTab({required this.tests});

  /// Parse a pipe-separated result string into { fieldName → value }
  static Map<String, double> _parseResult(String result) {
    final map = <String, double>{};
    // Try JSON first
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        final list = decoded['Tests'] ?? decoded['tests'];
        if (list is List) {
          for (final item in list) {
            final name   = (item['Name'] ?? item['name'] ?? '').toString();
            final rawVal = item['Value'] ?? item['value'];
            final status = (item['Status'] ?? item['status'] ?? '').toString();
            // Skip UnreadableValue — value is 0 placeholder, not real
            if (status == 'UnreadableValue') continue;
            final dval = rawVal is num
                ? (rawVal as num).toDouble()
                : double.tryParse(rawVal?.toString() ?? '');
            if (name.isNotEmpty && dval != null) map[name] = dval;
          }
          return map;
        }
      }
    } catch (_) {}
    // Pipe-separated: "Hemoglobin: 13.5 | WBC: 6.2 | ..."
    for (final part in result.split('|')) {
      final idx = part.indexOf(':');
      if (idx < 0) continue;
      final name = part.substring(0, idx).trim();
      final raw  = part.substring(idx + 1)
          .replaceAll(RegExp(r'\([^)]*\)'), '') // remove (High)/(Low)
          .trim();
      final val  = double.tryParse(raw);
      if (name.isNotEmpty && val != null) map[name] = val;
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    if (tests.isEmpty) {
      return const EmptyState(
          message: 'No test results', icon: Icons.description_outlined);
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Group tests by name, sorted oldest → newest
    final sorted = List<TestPoint>.from(tests)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Build { fieldName → List<(date, value)> }
    final Map<String, List<_FieldPoint>> byField = {};
    for (final t in sorted) {
      final fields = _parseResult(t.result);
      for (final e in fields.entries) {
        byField.putIfAbsent(e.key, () => [])
            .add(_FieldPoint(t.date, e.value));
      }
    }

    if (byField.isEmpty) {
      // No parseable numeric data across visits —
      // try to show latest test values as a horizontal bar chart
      final latestByName = <String, Map<String, double>>{};
      for (final t in sorted.reversed) {
        if (latestByName.containsKey(t.name)) continue;
        final fields = _parseResultRaw(t.result); // include UnreadableValue=0
        if (fields.isNotEmpty) latestByName[t.name] = fields;
      }

      if (latestByName.isEmpty) {
        // Truly no numeric data — show plain list
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tests.length,
          itemBuilder: (_, i) {
            final t = tests[i];
            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(t.name,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w600))),
                  Text('${t.date.day}/${t.date.month}/${t.date.year}',
                      style: GoogleFonts.dmSans(fontSize: 11,
                          color: isDark
                              ? AppColors.darkTextTertiary
                              : AppColors.textTertiary)),
                ]),
                const SizedBox(height: 4),
                Text(t.labName, style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
              ]),
            );
          },
        );
      }

      // Show latest test values as grouped bar cards
      return SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: latestByName.entries.map((entry) {
            final testName = entry.key;
            final fields   = entry.value;
            if (fields.isEmpty) return const SizedBox.shrink();

            final maxVal = fields.values.reduce((a, b) => a > b ? a : b);

            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(testName, style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                ...fields.entries.map((f) {
                  final fcolor  = _fieldColor(f.key, isDark);
                  final pct     = maxVal > 0 ? (f.value / maxVal).clamp(0.0, 1.0) : 0.0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        Expanded(child: Text(f.key,
                            style: GoogleFonts.dmSans(fontSize: 12,
                                color: isDark
                                    ? AppColors.darkTextSecondary
                                    : AppColors.textSecondary))),
                        Text(f.value.toStringAsFixed(2),
                            style: GoogleFonts.dmMono(fontSize: 12,
                                fontWeight: FontWeight.w600, color: fcolor)),
                      ]),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: pct,
                          minHeight: 8,
                          backgroundColor: isDark
                              ? AppColors.darkBorderColor
                              : AppColors.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(fcolor),
                        ),
                      ),
                    ]),
                  );
                }),
              ]),
            );
          }).toList(),
        ),
      );
    }

    // Render a mini line chart for each field
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: byField.entries.map((e) {
          final points = e.value;
          final color  = _fieldColor(e.key, isDark);
          final spots  = points.asMap().entries
              .map((en) => FlSpot(en.key.toDouble(), en.value.value))
              .toList();
          final latest = points.last.value;
          final minV   = points.map((p) => p.value).reduce((a, b) => a < b ? a : b);
          final maxV   = points.map((p) => p.value).reduce((a, b) => a > b ? a : b);
          final yMin   = (minV * 0.8).floorToDouble();
          final yMax   = (maxV * 1.2).ceilToDouble();

          return Padding(
            padding: const EdgeInsets.only(bottom: 28),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(e.key,
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w700))),
                Text(latest.toStringAsFixed(2),
                    style: GoogleFonts.dmMono(fontSize: 13,
                        fontWeight: FontWeight.w600, color: color)),
              ]),
              const SizedBox(height: 8),
              if (points.length > 1) ...[
                SizedBox(
                  height: 120,
                  child: LineChart(LineChartData(
                    minY: yMin, maxY: yMax == yMin ? yMax + 1 : yMax,
                    gridData: FlGridData(
                      show: true, drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: isDark
                            ? AppColors.darkBorderColor
                            : AppColors.borderColor,
                        strokeWidth: 1),
                    ),
                    borderData: FlBorderData(show: false),
                    titlesData: FlTitlesData(
                      leftTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 42,
                        getTitlesWidget: (v, _) => Text(
                          v.toStringAsFixed(1),
                          style: GoogleFonts.dmMono(fontSize: 8,
                              color: isDark
                                  ? AppColors.darkTextTertiary
                                  : AppColors.textTertiary)),
                      )),
                      bottomTitles: AxisTitles(sideTitles: SideTitles(
                        showTitles: true, reservedSize: 22,
                        getTitlesWidget: (v, _) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final d = points[idx].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text('${d.day}/${d.month}',
                                style: GoogleFonts.dmMono(fontSize: 8,
                                    color: isDark
                                        ? AppColors.darkTextTertiary
                                        : AppColors.textTertiary)),
                          );
                        },
                      )),
                      topTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 2,
                        dotData: FlDotData(show: true,
                            getDotPainter: (s, _, __, ___) =>
                                FlDotCirclePainter(radius: 3, color: color,
                                    strokeColor: Colors.transparent)),
                        belowBarData: BarAreaData(
                            show: true,
                            color: color.withValues(alpha: 0.08)),
                      ),
                    ],
                  )),
                ),
              ] else ...[
                // Only 1 data point — show as single chip
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${points.first.date.day}/${points.first.date.month}/'
                    '${points.first.date.year}  →  '
                    '${points.first.value.toStringAsFixed(2)}',
                    style: GoogleFonts.dmMono(fontSize: 12, color: color),
                  ),
                ),
              ],
              // mini stats row
              if (points.length > 1) ...[
                const SizedBox(height: 8),
                Row(children: [
                  _MiniStat('Latest', latest.toStringAsFixed(2)),
                  const SizedBox(width: 8),
                  _MiniStat('Min',    minV.toStringAsFixed(2)),
                  const SizedBox(width: 8),
                  _MiniStat('Max',    maxV.toStringAsFixed(2)),
                ]),
              ],
            ]),
          );
        }).toList(),
      ),
    );
  }

  /// Like _parseResult but includes all readable values (not just cross-visit)
  /// Used when there's only one visit — shows actual CBC values including normals
  static Map<String, double> _parseResultRaw(String result) {
    final map = <String, double>{};
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        final list = decoded['Tests'] ?? decoded['tests'];
        if (list is List) {
          for (final item in list) {
            final name   = (item['Name'] ?? item['name'] ?? '').toString();
            final rawVal = item['Value'] ?? item['value'];
            final status = (item['Status'] ?? item['status'] ?? '').toString();
            if (status == 'UnreadableValue') continue;
            final dval = rawVal is num
                ? (rawVal as num).toDouble()
                : double.tryParse(rawVal?.toString() ?? '');
            if (name.isNotEmpty && dval != null) map[name] = dval;
          }
        }
      }
    } catch (_) {}
    return map;
  }

  Color _fieldColor(String field, bool isDark) {
    final f = field.toLowerCase();
    if (f.contains('hemoglobin'))  return isDark ? AppColors.darkBadgeRedTxt  : AppColors.badgeRedTxt;
    if (f.contains('hematocrit'))  return isDark ? AppColors.darkBadgeAmberTxt: AppColors.badgeAmberTxt;
    if (f.contains('wbc') || f.contains('white'))
                                   return isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt;
    if (f.contains('platelet'))    return isDark ? AppColors.darkBadgePurpleTxt ?? AppColors.darkBadgeBlueTxt
                                                 : AppColors.badgePurpleTxt ?? AppColors.badgeBlueTxt;
    if (f.contains('glucose'))     return isDark ? AppColors.darkBadgeGreenTxt: AppColors.badgeGreenTxt;
    return isDark ? AppColors.darkAccent : AppColors.accent;
  }
}

class _FieldPoint {
  final DateTime date;
  final double   value;
  const _FieldPoint(this.date, this.value);
}

// ════════════════════════════════════════════════════════════════
// Tab 3 — Summary
// ════════════════════════════════════════════════════════════════
// ═══════════════════════════════════════════════════════════════
// في progress_page.dart — استبدل class _SummaryTab بالكود ده
// ═══════════════════════════════════════════════════════════════

class _SummaryTab extends StatelessWidget {
  final PatientProgressResponse data;
  const _SummaryTab({required this.data});

  // Parse result string → { name: {value, status} }
  static List<Map<String, dynamic>> _parseTestFields(String result) {
    // Try JSON first
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        final list = decoded['Tests'] ?? decoded['tests'];
        if (list is List) {
          return list
              .where((t) => (t as Map)['status'] != 'UnreadableValue')
              .map((t) => {
            'name':   (t['Name'] ?? t['name'] ?? '').toString(),
            'value':  (t['Value'] ?? t['value'] ?? 0).toString(),
            'status': (t['Status'] ?? t['status'] ?? 'Normal').toString(),
          })
              .where((t) => (t['name'] as String).isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}

    // Pipe-separated: "Hemoglobin: 13.5 (Low) | WBC: 6.2 | ..."
    final parts = result.split('|').map((s) => s.trim()).where((s) => s.isNotEmpty);
    return parts.map((part) {
      final idx = part.indexOf(':');
      if (idx < 0) return <String, dynamic>{};
      final name   = part.substring(0, idx).trim();
      final rest   = part.substring(idx + 1).trim();
      final status = rest.toLowerCase().contains('high') ? 'High'
          : rest.toLowerCase().contains('low') ? 'Low'
          : 'Normal';
      final value = rest
          .replaceAll(RegExp(r'\([^)]*\)'), '')
          .trim();
      return {'name': name, 'value': value, 'status': status};
    }).where((m) => (m['name'] as String? ?? '').isNotEmpty).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final v = data.vitals;
    final t = data.tests;

    if (v.isEmpty && t.isEmpty) {
      return const EmptyState(message: 'No data yet', icon: Icons.show_chart_rounded);
    }

    final hrValues = v.map((p) => p.heartRate.toDouble()).toList();
    final o2Values = v
        .map((p) => p.oxygenSaturation)
        .where((x) => x != null && x > 0)
        .map((x) => x!)
        .toList();
    final emergencies = v.where((p) => p.isEmergency).length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(data.patientName,
            style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),

        // ── Vitals summary ────────────────────────────────────
        if (v.isNotEmpty) ...[
          _sectionTitle('Vital Signs — ${v.length} readings', isDark),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _SummaryCard(
              label: 'Heart Rate',
              icon:  Icons.favorite_rounded,
              color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
              rows: hrValues.isEmpty ? [] : [
                ('Avg', '${(hrValues.reduce((a, b) => a + b) / hrValues.length).toStringAsFixed(1)} bpm'),
                ('Min', '${hrValues.reduce((a, b) => a < b ? a : b).toStringAsFixed(0)} bpm'),
                ('Max', '${hrValues.reduce((a, b) => a > b ? a : b).toStringAsFixed(0)} bpm'),
              ],
            )),
            const SizedBox(width: 12),
            Expanded(child: _SummaryCard(
              label: 'SpO₂',
              icon:  Icons.air_rounded,
              color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt,
              rows: o2Values.isEmpty ? [] : [
                ('Avg', '${(o2Values.reduce((a, b) => a + b) / o2Values.length).toStringAsFixed(1)}%'),
                ('Min', '${o2Values.reduce((a, b) => a < b ? a : b).toStringAsFixed(1)}%'),
                ('Max', '${o2Values.reduce((a, b) => a > b ? a : b).toStringAsFixed(1)}%'),
              ],
            )),
          ]),
          if (emergencies > 0) ...[
            const SizedBox(height: 10),
            EmergencyBanner(text: '$emergencies emergency event${emergencies > 1 ? 's' : ''} recorded'),
          ],
          const SizedBox(height: 20),
        ],

        // ── Tests summary ─────────────────────────────────────
        if (t.isNotEmpty) ...[
          _sectionTitle('Lab Tests — ${t.length} result${t.length != 1 ? 's' : ''}', isDark),
          const SizedBox(height: 10),
          ...t.map((test) {
            final fields = _parseTestFields(test.result);
            final date   = '${test.date.day}/${test.date.month}/${test.date.year}';
            final hasAlerts = fields.any((f) =>
            f['status'] == 'High' || f['status'] == 'Low');

            return AppCard(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                // Header
                Row(children: [
                  Expanded(child: Text(test.name,
                      style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
                  if (hasAlerts)
                    BadgeWidget(label: 'Has Alerts', type: BadgeType.red)
                  else
                    BadgeWidget(label: 'Normal', type: BadgeType.green),
                ]),
                const SizedBox(height: 4),
                Text('${test.labName} · $date',
                    style: GoogleFonts.dmSans(fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 10),

                // Fields as chips
                if (fields.isNotEmpty)
                  Wrap(spacing: 6, runSpacing: 6, children: fields.map((f) {
                    final status  = f['status'] as String;
                    final isHigh  = status == 'High';
                    final isLow   = status == 'Low';
                    final isAlert = isHigh || isLow;

                    Color bg, fg;
                    if (isHigh) {
                      bg = isDark ? AppColors.darkBadgeRedBg  : AppColors.badgeRedBg;
                      fg = isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt;
                    } else if (isLow) {
                      bg = isDark ? AppColors.darkBadgeAmberBg  : AppColors.badgeAmberBg;
                      fg = isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt;
                    } else {
                      bg = isDark ? AppColors.darkBadgeGreenBg  : AppColors.badgeGreenBg;
                      fg = isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt;
                    }

                    return Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: fg.withValues(alpha: 0.3))),
                      child: RichText(text: TextSpan(children: [
                        TextSpan(
                          text: '${f['name']}: ',
                          style: GoogleFonts.dmSans(fontSize: 11,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                        ),
                        TextSpan(
                          text: f['value'] as String,
                          style: GoogleFonts.dmMono(fontSize: 12,
                              fontWeight: FontWeight.w600, color: fg),
                        ),
                        if (isAlert)
                          TextSpan(
                            text: ' ↑' * (isHigh ? 1 : 0) + ' ↓' * (isLow ? 1 : 0),
                            style: GoogleFonts.dmSans(fontSize: 11, color: fg),
                          ),
                      ])),
                    );
                  }).toList())
                else
                  Text(test.result,
                      style: GoogleFonts.dmSans(fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ]),
            );
          }),
        ],
      ]),
    );
  }

  Widget _sectionTitle(String text, bool isDark) => Text(
    text,
    style: GoogleFonts.dmSans(
      fontSize: 13, fontWeight: FontWeight.w700,
      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
      letterSpacing: 0.05,
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool   isDark;
  const _SectionTitle(this.text, this.isDark);
  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
          letterSpacing: 0.3));
}

class _SummaryCard extends StatelessWidget {
  final String              label;
  final IconData            icon;
  final Color               color;
  final List<(String, String)> rows;
  const _SummaryCard({required this.label, required this.icon,
      required this.color, required this.rows});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.dmSans(
              fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ]),
        const SizedBox(height: 10),
        ...rows.map((r) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(children: [
            Expanded(child: Text(r.$1, style: GoogleFonts.dmSans(fontSize: 11,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
            Text(r.$2, style: GoogleFonts.dmMono(fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
          ]),
        )),
      ]),
    );
  }
}

// ── Shared widgets ─────────────────────────────────────────────
class _StatBox extends StatelessWidget {
  final String label, value;
  const _StatBox({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(child: Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Column(children: [
        Text(value, style: GoogleFonts.dmMono(fontSize: 15,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      ]),
    ));
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat(this.label, this.value);
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text('$label: ', style: GoogleFonts.dmSans(fontSize: 11,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      Text(value, style: GoogleFonts.dmMono(fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
    ]);
  }
}
