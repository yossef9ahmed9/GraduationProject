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

// ════════════════════════════════════════════════════════════════
// Patient File Page — unified health record for a patient:
//   Tab 1: Overview    — snapshot + latest vitals
//   Tab 2: Record History — all medical record edits with author
//   Tab 3: Prescriptions  — doctor prescriptions from follow-ups
//   Tab 4: Vitals         — HR + SpO₂ line charts
//   Tab 5: Lab Tests      — colour-coded test result chips
// ════════════════════════════════════════════════════════════════

class PatientFilePage extends StatefulWidget {
  const PatientFilePage({super.key});
  @override
  State<PatientFilePage> createState() => _PatientFilePageState();
}

class _PatientFilePageState extends State<PatientFilePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  Map<String, dynamic>? _data;
  bool _loading = false;
  String? _error;
  int? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _init() {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    int? id;
    if (auth.role == UserRole.patient) {
      id = app.patientByEmail(auth.user?.email ?? '')?.id;
    } else {
      id = app.patients.isNotEmpty ? app.patients.first.id : null;
    }
    if (id != null) _load(id);
  }

  Future<void> _load(int patientId) async {
    setState(() { _loading = true; _error = null; _selectedPatientId = patientId; });
    final res = await apiService.getPatientFile(patientId);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      setState(() { _data = res.data; _loading = false; });
    } else {
      setState(() { _error = res.error ?? 'Failed to load patient file.'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;
    final canSelect = role == UserRole.doctor || role == UserRole.admin ||
                      role == UserRole.relative;

    return RefreshIndicator(
      onRefresh: () async {
        if (_selectedPatientId != null) await _load(_selectedPatientId!);
      },
      child: Column(children: [

        // ── Patient selector (Doctor / Admin / Relative) ──────
        if (canSelect && app.patients.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: DropdownButtonFormField<int>(
              value: _selectedPatientId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Patient', isDense: true),
              items: app.patients
                  .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                  .toList(),
              onChanged: (id) { if (id != null) _load(id); },
            ),
          ),

        // ── Tab bar ───────────────────────────────────────────
        Container(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: TabBar(
            controller: _tabs,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600),
            tabs: const [
              Tab(text: 'Overview'),
              Tab(text: 'Record History'),
              Tab(text: 'Prescriptions'),
              Tab(text: 'Vitals'),
              Tab(text: 'Lab Tests'),
            ],
          ),
        ),

        // ── Content ───────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: AlertWidget(message: _error!, isError: true),
                      ),
                    )
                  : _data == null
                      ? const EmptyState(
                            message: 'Select a patient to view their file',
                            icon: Icons.folder_open_outlined)
                      : TabBarView(controller: _tabs, children: [
                          _OverviewTab(data: _data!),
                          _RecordHistoryTab(data: _data!),
                          _PrescriptionsTab(data: _data!),
                          _VitalsTab(data: _data!),
                          _LabTestsTab(data: _data!),
                        ]),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 1 — Overview
// ════════════════════════════════════════════════════════════════
class _OverviewTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _OverviewTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final vitals  = data['vitals'] as List? ?? [];
    final latest  = vitals.isNotEmpty ? vitals.first as Map : null;
    final hr      = latest?['heartRate'] as int?;
    final spo2    = (latest?['oxygenSaturation'] as num?)?.toDouble();
    final emg     = latest?['emergencyStatus'] as bool? ?? false;
    final bt      = (data['bloodType'] as String? ?? '').trim();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // Patient name + badges
        Text(data['patientName'] as String? ?? '—',
            style: GoogleFonts.dmSans(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [
          if (bt.isNotEmpty && bt != 'Unknown')
            BadgeWidget(label: '🩸 $bt', type: BadgeType.blue),
          if (emg)
            BadgeWidget(label: '🚨 Emergency', type: BadgeType.red),
        ]),
        const SizedBox(height: 20),

        // Latest vitals
        if (latest != null) ...[
          _SectionTitle('Latest Vitals', isDark),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _StatCard(
              label: 'Heart Rate', value: '${hr ?? '—'} bpm',
              icon: Icons.favorite_rounded,
              color: (hr != null && (hr > 100 || hr < 60))
                  ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null,
            )),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(
              label: 'SpO₂', value: '${spo2?.toStringAsFixed(1) ?? '—'}%',
              icon: Icons.air_rounded,
              color: (spo2 != null && spo2 < 95)
                  ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt) : null,
            )),
          ]),
          const SizedBox(height: 20),
        ],

        // Current medical record snapshot
        if ((data['medicalRecord'] as String? ?? '').isNotEmpty) ...[
          _SectionTitle('Current Medical Record', isDark),
          const SizedBox(height: 8),
          AppCard(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _InfoRow(Icons.description_outlined,
                  data['medicalRecord'] as String, isDark),
              if ((data['chronicDiseases'] as String? ?? '').isNotEmpty)
                _InfoRow(Icons.medical_services_outlined,
                    'Chronic: ${data['chronicDiseases']}', isDark),
              if ((data['allergies'] as String? ?? '').isNotEmpty)
                _InfoRow(Icons.warning_amber_outlined,
                    'Allergies: ${data['allergies']}', isDark),
            ]),
          )),
        ] else ...[
          _SectionTitle('Current Medical Record', isDark),
          const SizedBox(height: 8),
          AppCard(child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text('No medical record yet.',
                style: GoogleFonts.dmSans(fontSize: 13,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          )),
        ],

        // Quick stats
        const SizedBox(height: 20),
        _SectionTitle('Summary', isDark),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _StatCard(
            label: 'Vitals', value: '${(data['vitals'] as List? ?? []).length}',
            icon: Icons.monitor_heart_outlined,
          )),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(
            label: 'Prescriptions', value: '${(data['prescriptions'] as List? ?? []).length}',
            icon: Icons.medication_outlined,
          )),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(
            label: 'Lab Tests', value: '${(data['labTests'] as List? ?? []).length}',
            icon: Icons.science_outlined,
          )),
        ]),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 2 — Record History
// ════════════════════════════════════════════════════════════════
class _RecordHistoryTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RecordHistoryTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final history = data['recordHistory'] as List? ?? [];

    if (history.isEmpty) {
      return const EmptyState(
          message: 'No record history yet', icon: Icons.history_rounded);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: history.length,
      itemBuilder: (_, i) {
        final e       = history[i] as Map;
        final date    = DateTime.tryParse(e['createdAt'] as String? ?? '')?.toLocal();
        final dateStr = date != null
            ? '${date.day}/${date.month}/${date.year} '
              '${date.hour.toString().padLeft(2, '0')}:'
              '${date.minute.toString().padLeft(2, '0')}'
            : '—';
        final role = (e['authorRole'] as String? ?? '').trim();

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Author header
            Row(children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: role == 'Doctor'
                    ? (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted)
                    : (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F2F8)),
                child: Icon(
                  role == 'Doctor'
                      ? Icons.medical_services_outlined
                      : Icons.person_outline,
                  size: 16,
                  color: isDark ? AppColors.darkAccent : AppColors.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    (e['authorName'] as String? ?? '').isNotEmpty
                        ? e['authorName'] as String
                        : e['authorEmail'] as String? ?? '—',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '${e['authorEmail'] ?? ''} · $dateStr',
                    style: GoogleFonts.dmSans(fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary),
                  ),
                ],
              )),
              if (role.isNotEmpty)
                BadgeWidget(
                  label: role,
                  type: role == 'Doctor' ? BadgeType.blue : BadgeType.green,
                ),
            ]),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            // Changed fields
            if ((e['medicalRecord'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.description_outlined,
                  e['medicalRecord'] as String, isDark),
            if ((e['chronicDiseases'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.medical_services_outlined,
                  'Chronic: ${e['chronicDiseases']}', isDark),
            if ((e['allergies'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.warning_amber_outlined,
                  'Allergies: ${e['allergies']}', isDark),
            if ((e['bloodType'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.water_drop_outlined,
                  'Blood type: ${e['bloodType']}', isDark),
          ]),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 3 — Prescriptions
// ════════════════════════════════════════════════════════════════
class _PrescriptionsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PrescriptionsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark        = Theme.of(context).brightness == Brightness.dark;
    final prescriptions = data['prescriptions'] as List? ?? [];

    if (prescriptions.isEmpty) {
      return const EmptyState(
          message: 'No prescriptions yet', icon: Icons.medication_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: prescriptions.length,
      itemBuilder: (_, i) {
        final p       = prescriptions[i] as Map;
        final date    = DateTime.tryParse(p['lastUpdate'] as String? ?? '')?.toLocal();
        final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '—';
        final severity = p['severity'] as String? ?? '';

        return AppCard(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

            // Doctor info
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. ${p['doctorName'] ?? '—'}',
                      style: GoogleFonts.dmSans(
                          fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(
                    '${p['specialization'] ?? ''} · ${p['doctorEmail'] ?? ''} · $dateStr',
                    style: GoogleFonts.dmSans(fontSize: 11,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary),
                  ),
                ],
              )),
              if (severity.isNotEmpty)
                BadgeWidget(
                  label: severity,
                  type: severity == 'High' || severity == 'Critical'
                      ? BadgeType.red
                      : severity == 'Medium'
                          ? BadgeType.amber
                          : BadgeType.green,
                ),
            ]),

            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 10),

            if ((p['diagnosis'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.medical_information_outlined,
                  p['diagnosis'] as String, isDark),
            if ((p['treatmentPlan'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.medication_outlined,
                  p['treatmentPlan'] as String, isDark),
            if ((p['notes'] as String? ?? '').isNotEmpty)
              _InfoRow(Icons.notes_rounded, p['notes'] as String, isDark),

            if (p['nextVisitDate'] != null) ...[
              const SizedBox(height: 6),
              Row(children: [
                Icon(Icons.calendar_today_outlined, size: 13,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(
                  'Next visit: ${_formatDate(p['nextVisitDate'] as String)}',
                  style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500,
                      color: isDark
                          ? AppColors.darkBadgeBlueTxt
                          : AppColors.badgeBlueTxt),
                ),
              ]),
            ],
          ]),
        );
      },
    );
  }

  String _formatDate(String raw) {
    final d = DateTime.tryParse(raw)?.toLocal();
    if (d == null) return raw;
    return '${d.day}/${d.month}/${d.year}';
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 4 — Vitals
// ════════════════════════════════════════════════════════════════
class _VitalsTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _VitalsTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // API returns newest first — reverse for chart (oldest→newest left→right)
    final vitals = (data['vitals'] as List? ?? []).reversed.toList();

    if (vitals.isEmpty) {
      return const EmptyState(
          message: 'No vitals data', icon: Icons.monitor_heart_outlined);
    }

    final hrSpots   = <FlSpot>[];
    final spo2Spots = <FlSpot>[];
    for (int i = 0; i < vitals.length; i++) {
      final v  = vitals[i] as Map;
      final hr = (v['heartRate'] as num?)?.toDouble();
      final o2 = (v['oxygenSaturation'] as num?)?.toDouble();
      if (hr != null && hr > 0)  hrSpots.add(FlSpot(i.toDouble(), hr));
      if (o2 != null && o2 > 0)  spo2Spots.add(FlSpot(i.toDouble(), o2));
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _ChartCard(
          title: 'Heart Rate (bpm)',
          spots: hrSpots,
          color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
          minY: 40, maxY: 160,
        ),
        const SizedBox(height: 16),
        _ChartCard(
          title: 'SpO₂ (%)',
          spots: spo2Spots,
          color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt,
          minY: 85, maxY: 100,
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Tab 5 — Lab Tests  (Charts + Results with collapsible sections)
// ════════════════════════════════════════════════════════════════

// ── Data point for a single field reading ────────────────────
class _FieldPoint {
  final DateTime date;
  final double   value;
  final String   status; // Normal | High | Low
  const _FieldPoint({required this.date, required this.value, required this.status});
}

class _LabTestsTab extends StatefulWidget {
  final Map<String, dynamic> data;
  const _LabTestsTab({required this.data});

  @override
  State<_LabTestsTab> createState() => _LabTestsTabState();
}

class _LabTestsTabState extends State<_LabTestsTab> {
  bool _chartsExpanded  = true;
  bool _resultsExpanded = true;

  // ── Parse result string → list of typed chips ─────────────
  static List<Map<String, String>> _parseChips(String result) {
    if (result.isEmpty) return [];
    // Try JSON first (legacy format)
    try {
      final decoded = jsonDecode(result);
      if (decoded is Map) {
        final list = (decoded['Tests'] ?? decoded['tests']) as List?;
        if (list != null) {
          return list
              .whereType<Map>()
              .where((t) {
                final s = (t['Status'] ?? t['status'] ?? '').toString();
                return s != 'UnreadableValue';
              })
              .map((t) => {
                    'name':   (t['Name']   ?? t['name']   ?? '').toString(),
                    'value':  (t['Value']  ?? t['value']  ?? 0).toString(),
                    'status': (t['Status'] ?? t['status'] ?? 'Normal').toString(),
                  })
              .where((c) => c['name']!.isNotEmpty)
              .toList();
        }
      }
    } catch (_) {}
    // Pipe format: "Name: value (Status) | ..."
    return result.split('|').map((segment) {
      final part = segment.trim();
      if (!part.contains(':')) return null;
      final ci   = part.indexOf(':');
      final name = part.substring(0, ci).trim();
      var   rest = part.substring(ci + 1).trim();
      String status = 'Normal';
      final m = RegExp(r'\((\w+)\)\s*$').firstMatch(rest);
      if (m != null) {
        status = m.group(1) ?? 'Normal';
        rest   = rest.substring(0, m.start).trim();
      }
      return name.isNotEmpty
          ? <String, String>{'name': name, 'value': rest, 'status': status}
          : null;
    }).whereType<Map<String, String>>().toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tests  = (widget.data['labTests'] as List? ?? []);

    if (tests.isEmpty) {
      return const EmptyState(message: 'No lab tests', icon: Icons.science_outlined);
    }

    // Build fieldPoints from ALL tests (not just those with ≥2 readings)
    final Map<String, List<_FieldPoint>> fieldPoints = {};
    for (final t in tests) {
      final tm   = t as Map;
      final date = DateTime.tryParse(tm['date'] as String? ?? '');
      if (date == null) continue;
      for (final c in _parseChips(tm['result'] as String? ?? '')) {
        final val = double.tryParse(c['value'] ?? '');
        if (val == null) continue;
        fieldPoints
            .putIfAbsent(c['name']!, () => [])
            .add(_FieldPoint(
              date:   date,
              value:  val,
              status: c['status'] ?? 'Normal',
            ));
      }
    }
    // Sort each field's points oldest → newest
    for (final pts in fieldPoints.values) {
      pts.sort((a, b) => a.date.compareTo(b.date));
    }

    return RefreshIndicator(
      onRefresh: () async {},
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Charts section ───────────────────────────────────
          _SectionToggle(
            title: 'Trends',
            count: fieldPoints.length,
            expanded: _chartsExpanded,
            onTap: () => setState(() => _chartsExpanded = !_chartsExpanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _chartsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 8),
                if (fieldPoints.isEmpty)
                  const EmptyState(
                      message: 'No chart data', icon: Icons.bar_chart_rounded)
                else
                  ...fieldPoints.entries.map(
                    (e) => _FieldChart(fieldName: e.key, points: e.value),
                  ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),

          const SizedBox(height: 4),

          // ── Results section ──────────────────────────────────
          _SectionToggle(
            title: 'All Results',
            count: tests.length,
            expanded: _resultsExpanded,
            onTap: () => setState(() => _resultsExpanded = !_resultsExpanded),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 220),
            crossFadeState: _resultsExpanded
                ? CrossFadeState.showFirst
                : CrossFadeState.showSecond,
            firstChild: Column(
              children: [
                const SizedBox(height: 8),
                ...tests.map(
                  (t) => _TestResultCard(test: t as Map, isDark: isDark),
                ),
              ],
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ]),
      ),
    );
  }
}

// ── Collapsible section header with chevron ───────────────────
class _SectionToggle extends StatelessWidget {
  final String title;
  final int count;
  final bool expanded;
  final VoidCallback onTap;
  const _SectionToggle({
    required this.title, required this.count,
    required this.expanded, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(children: [
          Expanded(child: Row(children: [
            Text(title,
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkAccentMuted : AppColors.accentMuted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('$count',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkAccent : AppColors.accent)),
            ),
          ])),
          AnimatedRotation(
            duration: const Duration(milliseconds: 220),
            turns: expanded ? 0 : -0.25,
            child: Icon(Icons.keyboard_arrow_down_rounded,
                size: 22,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary),
          ),
        ]),
      ),
    );
  }
}

// ── Chart for a single field across all readings ─────────────
class _FieldChart extends StatelessWidget {
  final String fieldName;
  final List<_FieldPoint> points;
  const _FieldChart({required this.fieldName, required this.points});

  String _fmtDate(DateTime d) => '${d.day}/${d.month}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final spots     = points.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();
    final vals      = points.map((p) => p.value).toList();
    final minVal    = vals.reduce((a, b) => a < b ? a : b);
    final maxVal    = vals.reduce((a, b) => a > b ? a : b);
    final pad       = (maxVal - minVal) * 0.25 + 0.5;
    final latest    = points.last;
    final isHigh    = latest.status == 'High';
    final isLow     = latest.status == 'Low';
    final isAlert   = isHigh || isLow;
    final lineColor = isHigh
        ? (isDark ? AppColors.darkBadgeRedTxt   : AppColors.badgeRedTxt)
        : isLow
        ? (isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt)
        : (isDark ? AppColors.darkAccent        : AppColors.accent);
    final delta     = points.length >= 2
        ? latest.value - points[points.length - 2].value
        : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header: field name + latest value + alert + trend arrow
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
          child: Row(children: [
            Expanded(child: Text(fieldName,
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w700))),
            Text(latest.value.toStringAsFixed(1),
                style: GoogleFonts.dmMono(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: isAlert
                        ? lineColor
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
            if (isAlert) ...[
              const SizedBox(width: 3),
              Text(isHigh ? '↑' : '↓',
                  style: GoogleFonts.dmSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: lineColor)),
            ],
            if (delta != null) ...[
              const SizedBox(width: 6),
              Icon(
                delta > 0.01
                    ? Icons.trending_up_rounded
                    : delta < -0.01
                        ? Icons.trending_down_rounded
                        : Icons.trending_flat_rounded,
                size: 15,
                color: isDark
                    ? AppColors.darkTextTertiary
                    : AppColors.textTertiary,
              ),
            ],
          ]),
        ),
        // Date range label (only when >1 point)
        if (points.length > 1)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmtDate(points.first.date),
                    style: GoogleFonts.dmSans(fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary)),
                Text('${points.length} readings',
                    style: GoogleFonts.dmSans(fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary)),
                Text(_fmtDate(points.last.date),
                    style: GoogleFonts.dmSans(fontSize: 10,
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary)),
              ],
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(_fmtDate(points.first.date),
                style: GoogleFonts.dmSans(fontSize: 10,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary)),
          ),

        // Chart
        SizedBox(
          height: 90,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
            child: LineChart(LineChartData(
              minY: minVal - pad,
              maxY: maxVal + pad,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: const FlTitlesData(
                leftTitles:   AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: spots.length > 2,
                  color: lineColor,
                  barWidth: 2.5,
                  dotData: FlDotData(
                    show: true,
                    getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                      radius: 3.5,
                      color: lineColor,
                      strokeWidth: 0,
                      strokeColor: Colors.transparent,
                    ),
                  ),
                  belowBarData: BarAreaData(
                      show: true,
                      color: lineColor.withValues(alpha: 0.08)),
                ),
              ],
            )),
          ),
        ),
      ])),
    );
  }
}

// ── Single test result card ───────────────────────────────────
class _TestResultCard extends StatelessWidget {
  final Map  test;
  final bool isDark;
  const _TestResultCard({required this.test, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final date     = DateTime.tryParse(test['date'] as String? ?? '')?.toLocal();
    final dateStr  = date != null ? '${date.day}/${date.month}/${date.year}' : '—';
    final chips    = _LabTestsTabState._parseChips(test['result'] as String? ?? '');
    final hasAlert = chips.any((c) => c['status'] == 'High' || c['status'] == 'Low');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(test['name'] as String? ?? '—',
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w700))),
            if (chips.isNotEmpty)
              BadgeWidget(
                label: hasAlert ? 'Has Alerts' : 'Normal',
                type:  hasAlert ? BadgeType.red  : BadgeType.green,
              ),
          ]),
          const SizedBox(height: 2),
          Text('${test['labName'] ?? '—'} · $dateStr',
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
          if (chips.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: chips.map((c) {
              final isHigh  = c['status'] == 'High';
              final isLow   = c['status'] == 'Low';
              final isAlert = isHigh || isLow;
              final bg = isHigh
                  ? (isDark ? AppColors.darkBadgeRedBg   : AppColors.badgeRedBg)
                  : isLow
                  ? (isDark ? AppColors.darkBadgeAmberBg : AppColors.badgeAmberBg)
                  : (isDark ? const Color(0xFF1A1A1A)    : const Color(0xFFF5F7FB));
              final fg = isHigh
                  ? (isDark ? AppColors.darkBadgeRedTxt   : AppColors.badgeRedTxt)
                  : isLow
                  ? (isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt)
                  : (isDark ? AppColors.darkTextPrimary   : AppColors.textPrimary);
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: fg.withValues(alpha: isAlert ? 0.3 : 0.15))),
                child: Text(
                  '${c['name']}: ${c['value']}'
                  '${isHigh ? ' ↑' : isLow ? ' ↓' : ''}',
                  style: GoogleFonts.dmMono(fontSize: 11,
                      fontWeight: isAlert ? FontWeight.w600 : FontWeight.w400,
                      color: fg),
                ),
              );
            }).toList()),
          ] else if ((test['result'] as String? ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(test['result'] as String,
                style: GoogleFonts.dmSans(fontSize: 12.5,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary)),
          ],
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// Shared helpers
// ════════════════════════════════════════════════════════════════

class _SectionTitle extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionTitle(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Text(text,
      style: GoogleFonts.dmSans(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.04,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary));
}

class _StatCard extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color? color;
  const _StatCard({required this.label, required this.value,
      required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final c = color ?? (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 18, color: c),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.dmMono(
            fontSize: 16, fontWeight: FontWeight.w700, color: c)),
        Text(label, style: GoogleFonts.dmSans(fontSize: 10,
            color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  final bool isDark;
  const _InfoRow(this.icon, this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 14,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: GoogleFonts.dmSans(fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
    ]),
  );
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<FlSpot> spots;
  final Color color;
  final double minY, maxY;
  const _ChartCard({required this.title, required this.spots,
      required this.color, required this.minY, required this.maxY});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (spots.isEmpty) return const SizedBox.shrink();
    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Text(title,
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
      SizedBox(
        height: 160,
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                        color: isDark
                            ? AppColors.darkTextTertiary
                            : AppColors.textTertiary)),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:    AxisTitles(sideTitles: SideTitles(showTitles: false)),
              rightTitles:  AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            lineBarsData: [
              LineChartBarData(
                spots: spots, isCurved: true, color: color, barWidth: 2.5,
                dotData: FlDotData(show: spots.length < 30),
                belowBarData: BarAreaData(
                    show: true, color: color.withValues(alpha: 0.08)),
              ),
            ],
          )),
        ),
      ),
    ]));
  }
}
