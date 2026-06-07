import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class TestsPage extends StatefulWidget {
  const TestsPage({super.key});
  @override
  State<TestsPage> createState() => _TestsPageState();
}

class _TestsPageState extends State<TestsPage> {
  bool _busy = false;
  String? _message;
  bool _isError = false;

  // ── OCR state ─────────────────────────────────────────────────
  OcrScanResponse? _ocrResult;
  int? _ocrPatientId;
  int? _ocrLabId;
  int? _ocrAppointmentId;
  final Map<String, TextEditingController> _manualCtrls = {};

  // Holds the latest OCR scan in memory only — never persisted to DB until
  // the user explicitly presses "Save". Cleared on discard or app restart.
  List<Map> _pendingOcrTests = [];
  String   _pendingFileName  = '';

  @override
  void dispose() {
    for (final c in _manualCtrls.values) c.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final app = context.read<AppProvider>();
    await Future.wait([app.refreshTests(), app.refreshLabAppointments()]);
  }

  Future<void> _updateStatus(LabAppointmentResponse appointment, String status) async {
    setState(() { _busy = true; _message = null; });
    final app = context.read<AppProvider>();
    final res = await apiService.updateLabAppointmentStatus(appointment.id, status);
    await app.refreshLabAppointments();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _message = res.ok ? 'Request marked as $status.' : res.error ?? 'Failed to update request.';
    });
  }

  Future<void> _complete(LabAppointmentResponse appointment) async {
    final results = await showDialog<List<LabTestResultRequest>>(
      context: context,
      builder: (_) => _CompleteResultDialog(appointment: appointment),
    );
    if (results == null || results.isEmpty) return;
    setState(() { _busy = true; _message = null; });
    final res = await apiService.completeLabAppointment(
      appointment.id, CompleteLabAppointmentRequest(results: results),
    );
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _message = res.ok ? 'Results saved and sent to patient.' : res.error ?? 'Failed to save results.';
    });
  }

  // ── OCR core ──────────────────────────────────────────────────
  // Step 1 of 2: scan the image for a PREVIEW only.
  // We deliberately omit patientId/labId from the OCR request so the backend
  // performs OCR + analysis but does NOT save anything to the database.
  // The result is held in _pendingOcrTests (widget state only) until the user
  // explicitly presses "Save" or "Discard".
  Future<void> _runOcr({
    required int patientId,
    required int labId,
    int? appointmentId,
  }) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'tif', 'tiff'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;
    final file  = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() { _isError = true; _message = 'Could not read selected image.'; });
      return;
    }

    // Clear any previous pending preview before starting a new scan
    setState(() {
      _busy = true; _message = null;
      _ocrResult = null; _manualCtrls.clear();
      _pendingOcrTests = []; _pendingFileName = file.name;
    });

    // Send WITHOUT patientId/labId — backend returns analysis but saves nothing
    final res = await apiService.uploadOcrReport(
      fileName: file.name, bytes: bytes,
      // patientId and labId intentionally omitted for preview-only mode
    );
    if (!mounted) return;

    if (!res.ok) {
      setState(() { _busy = false; _isError = true; _message = res.error ?? 'Failed to scan report.'; });
      return;
    }

    final scan  = res.data!;
    final tests = (scan.analysis['tests'] as List? ?? []);

    // Identify fields the OCR could not read clearly
    final unreadable = tests
        .where((t) => (t as Map)['status'] == 'UnreadableValue')
        .map((t) => (t as Map)['name'] as String)
        .toList();

    // Fallback: if backend returned no test entries at all, prompt all fields
    const _allCbcFields = [
      'Hemoglobin','Hematocrit','RBCs Count','MCV','MCH','MCHC',
      'RDW-CV','Platelets','WBC','Neutrophils','Lymphocytes',
      'Monocytes','Eosinophils','Basophils',
    ];

    if (!scan.isValidScan) {
      // Completely unreadable — show manual entry for unrecognised fields only
      final fieldsToPrompt = unreadable.isNotEmpty ? unreadable : _allCbcFields;
      setState(() {
        _busy = false; _isError = false;
        _message = fieldsToPrompt.length < _allCbcFields.length
            ? 'Some values could not be read. Please enter them manually.'
            : 'Could not read values from image. Please enter them manually.';
        _ocrResult = scan;
        _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
        for (final f in fieldsToPrompt) _manualCtrls[f] = TextEditingController();
      });
      return;
    }

    if (unreadable.isNotEmpty) {
      // Partially unreadable — show manual entry only for unrecognised fields
      setState(() {
        _busy = false; _isError = false;
        _message = 'Some values could not be read. Please enter them manually.';
        _ocrResult = scan;
        _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
        for (final f in unreadable) _manualCtrls[f] = TextEditingController();
      });
      return;
    }

    // Fully readable — store in memory as a pending preview (NOT saved to DB yet)
    setState(() {
      _busy = false; _isError = false;
      _message = 'Scan complete. Review below and press Save to keep it.';
      _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
      // Store tests in widget state only — temporary until user confirms save
      _pendingOcrTests = tests.whereType<Map>().toList();
    });
  }

  // Step 2 of 2: user explicitly confirms — now save to the database.
  Future<void> _saveOcrResult() async {
    if (_ocrPatientId == null || _ocrLabId == null || _pendingOcrTests.isEmpty) return;

    // Build the same pipe-separated string used by _submitManual
    final resultStr = _pendingOcrTests
        .map((t) => '${t['name'] ?? t['Name']}: ${t['value'] ?? t['Value']}')
        .join(' | ');

    setState(() { _busy = true; _message = null; });

    final res = await apiService.addMedicalTest(MedicalTestRequest(
      name: 'CBC', result: resultStr,
      patientId: _ocrPatientId!, labId: _ocrLabId!,
    ));
    if (res.ok && _ocrAppointmentId != null) {
      await apiService.updateLabAppointmentStatus(_ocrAppointmentId!, 'Completed');
    }
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _message = res.ok ? 'Results saved successfully.' : (res.error ?? 'Failed to save.');
      if (res.ok) {
        // Clear the pending preview after successful save
        _pendingOcrTests = []; _pendingFileName = '';
        _ocrPatientId = null; _ocrLabId = null; _ocrAppointmentId = null;
      }
    });
  }

  // Discard the pending preview without saving anything
  void _discardOcrResult() {
    setState(() {
      _pendingOcrTests = []; _pendingFileName = '';
      _ocrPatientId = null; _ocrLabId = null; _ocrAppointmentId = null;
      _message = null;
    });
  }

  // ── Popup: show all test results in a bottom sheet ───────────
  void _showAllTestsPopup(BuildContext context,
      List<MedicalTestResponse> tests, AppProvider app, bool isDark) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AllTestsSheet(tests: tests, app: app),
    );
  }

  // OCR for Lab (linked to appointment)
  Future<void> _scanOcr(LabAppointmentResponse appointment) async {
    await _runOcr(
      patientId: appointment.patientId,
      labId: appointment.labId,
      appointmentId: appointment.id,
    );
  }

  // OCR for Patient (standalone)
  Future<void> _scanOcrPatient() async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    final patientId = app.patientByEmail(auth.user?.email ?? '')?.id;
    if (patientId == null || app.labs.isEmpty) {
      setState(() { _isError = true; _message = 'No labs available.'; });
      return;
    }
    await _runOcr(patientId: patientId, labId: app.labs.first.id);
  }

  // Submit manual corrections
  Future<void> _submitManual() async {
    if (_ocrPatientId == null || _ocrLabId == null) return;
    final tests = List<Map>.from((_ocrResult?.analysis['tests'] as List? ?? []));
    final allFields = Map<String, String>.fromEntries(
        tests.map((t) => MapEntry(t['name'] as String, '${t['value']}')));
    for (final e in _manualCtrls.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) allFields[e.key] = v;
    }
    final resultStr = allFields.entries.map((e) => '${e.key}: ${e.value}').join(' | ');
    setState(() { _busy = true; _message = null; });
    final res = await apiService.addMedicalTest(MedicalTestRequest(
      name: 'CBC', result: resultStr,
      patientId: _ocrPatientId!, labId: _ocrLabId!,
    ));
    if (res.ok && _ocrAppointmentId != null) {
      await apiService.updateLabAppointmentStatus(_ocrAppointmentId!, 'Completed');
    }
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _message = res.ok ? 'Results saved successfully.' : (res.error ?? 'Failed to save.');
      if (res.ok) {
        _ocrResult = null; _manualCtrls.clear();
        _ocrPatientId = null; _ocrLabId = null; _ocrAppointmentId = null;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final role   = auth.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final patient = role == UserRole.patient
        ? app.patientByEmail(auth.user?.email ?? '') : null;

    // ── Visibility rules ──────────────────────────────────────
    // Patient  → own tests only
    // Doctor   → tests for their linked patients only
    // Relative → tests for their linked patient only
    // Lab      → tests from appointments with this lab only
    // Admin    → everything
    List<MedicalTestResponse> visibleTests;
    List<LabAppointmentResponse> visibleAppointments;

    if (role == UserRole.patient && patient != null) {
      visibleTests        = app.testsForPatient(patient.id);
      visibleAppointments = app.labAppointmentsForPatient(patient.id);
    } else if (role == UserRole.relative) {
      // Relative sees only their linked patient's data
      final linked = app.patients.isNotEmpty ? app.patients.first : null;
      visibleTests        = linked != null ? app.testsForPatient(linked.id) : [];
      visibleAppointments = linked != null ? app.labAppointmentsForPatient(linked.id) : [];
    } else if (role == UserRole.doctor) {
      // Doctor sees only patients they follow up with
      final myPatientIds = app.followUps
          .map((f) => f.patientId)
          .toSet();
      visibleTests        = app.tests.where((t) => myPatientIds.contains(t.patientId)).toList();
      visibleAppointments = app.labAppointments.where((a) => myPatientIds.contains(a.patientId)).toList();
    } else if (role == UserRole.lab) {
      // Lab sees only appointments & tests for this specific lab
      final myLab = app.labs
          .where((l) => l.email.toLowerCase() == (auth.user?.email ?? '').toLowerCase())
          .firstOrNull;
      if (myLab != null) {
        visibleAppointments = app.labAppointments.where((a) => a.labId == myLab.id).toList();
        visibleTests        = app.tests.where((t) => t.labId == myLab.id).toList();
      } else {
        visibleAppointments = app.labAppointments;
        visibleTests        = app.tests;
      }
    } else {
      // Admin
      visibleTests        = app.tests;
      visibleAppointments = app.labAppointments;
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (_message != null) ...[
                  AlertWidget(message: _message!, isError: _isError),
                  const SizedBox(height: 12),
                ],
                if (_busy) const LinearProgressIndicator(minHeight: 2),
                if (_busy) const SizedBox(height: 12),

                // OCR preview panel — temporary, shown before user saves
                if (_pendingOcrTests.isNotEmpty) ...[
                  _OcrPreviewPanel(
                    tests: _pendingOcrTests,
                    fileName: _pendingFileName,
                    onSave: _busy ? null : _saveOcrResult,
                    onDiscard: _busy ? null : _discardOcrResult,
                    busy: _busy,
                  ),
                  const SizedBox(height: 16),
                ],

                // Manual entry panel — appears after partially unreadable OCR
                if (_ocrResult != null && _manualCtrls.isNotEmpty) ...[
                  _ManualEntryPanel(
                    ctrls: _manualCtrls,
                    ocrTests: (_ocrResult!.analysis['tests'] as List? ?? []),
                    onSubmit: _submitManual,
                    onCancel: () => setState(() {
                      _ocrResult = null; _manualCtrls.clear(); _message = null;
                    }),
                    busy: _busy,
                  ),
                  const SizedBox(height: 16),
                ],

                Text(
                  role == UserRole.lab ? 'Lab Requests' : 'My Lab Tests',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Row(children: [
                  Expanded(child: Text(
                    role == UserRole.lab
                        ? '${visibleAppointments.length} request${visibleAppointments.length == 1 ? "" : "s"} waiting or completed'
                        : '${visibleTests.length} result${visibleTests.length == 1 ? "" : "s"} saved',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
                  )),
                  // Popup: show all my results in a bottom sheet
                  if (role != UserRole.lab && visibleTests.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _showAllTestsPopup(context, visibleTests, app, isDark),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text('View All',
                          style: GoogleFonts.dmSans(fontSize: 12)),
                    ),
                ]),

                // Scan button for patient
                if (role == UserRole.patient && app.labs.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _busy ? null : _scanOcrPatient,
                      icon: const Icon(Icons.document_scanner_outlined, size: 16),
                      label: Text('Scan Lab Report',
                          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ],
              ]),
            ),
          ),

          if (role == UserRole.lab) ...[
            if (visibleAppointments.isEmpty)
              const SliverToBoxAdapter(
                  child: EmptyState(message: 'No lab requests yet', icon: Icons.science_outlined))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _LabRequestCard(
                      appointment: visibleAppointments[i],
                      onScan: () => _scanOcr(visibleAppointments[i]),
                      onConfirm: visibleAppointments[i].status == 'Pending'
                          ? () => _updateStatus(visibleAppointments[i], 'Confirmed') : null,
                      onComplete: visibleAppointments[i].status != 'Completed' &&
                          visibleAppointments[i].status != 'Cancelled'
                          ? () => _complete(visibleAppointments[i]) : null,
                    ),
                    childCount: visibleAppointments.length,
                  ),
                ),
              ),
          ] else ...[
            if (visibleAppointments.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                        (_, i) => _AppointmentCard(appointment: visibleAppointments[i]),
                    childCount: visibleAppointments.length,
                  ),
                ),
              ),
            if (visibleTests.isEmpty)
              const SliverToBoxAdapter(
                  child: EmptyState(message: 'No test results found', icon: Icons.description_outlined))
            // Tests are shown in the popup only — tap "View All" above
            else
              const SliverToBoxAdapter(child: SizedBox.shrink()),
          ],
        ],
      ),
    );
  }
}

// ── OCR Preview Panel ─────────────────────────────────────────
// Displays the OCR result temporarily in memory.
// Nothing is saved to the database until the user presses "Save".
// Pressing "Discard" clears the preview with no side effects.
// This widget is never shown after an app restart — state is not persisted.

class _OcrPreviewPanel extends StatelessWidget {
  final List<Map> tests;
  final String    fileName;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;
  final bool busy;

  const _OcrPreviewPanel({
    required this.tests,
    required this.fileName,
    required this.onSave,
    required this.onDiscard,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(children: [
          Icon(Icons.document_scanner_outlined, size: 18,
              color: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt),
          const SizedBox(width: 8),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Scan Preview — not saved yet',
                style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)),
            if (fileName.isNotEmpty)
              Text(fileName,
                  style: GoogleFonts.dmSans(fontSize: 11,
                      color: (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                          .withOpacity(0.75))),
          ])),
        ]),
      ),

      // Results: one chip per test showing Name: value
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Wrap(spacing: 6, runSpacing: 6,
            children: tests.map((t) {
              // Support both camelCase (from OCR analysis) and PascalCase keys
              final name   = (t['name']   ?? t['Name']   ?? '').toString();
              final value  = (t['value']  ?? t['Value']  ?? '').toString();
              final status = (t['status'] ?? t['Status'] ?? '').toString();
              final isAlert = status == 'Low' || status == 'High';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAlert
                      ? (isDark ? AppColors.darkBadgeRedBg    : AppColors.badgeRedBg)
                      : (isDark ? AppColors.darkBadgeGreenBg  : AppColors.badgeGreenBg),
                  borderRadius: BorderRadius.circular(6),
                ),
                // Display each field as "Name: value" with alert label if abnormal
                child: Text(
                  '$name: $value${isAlert ? " ($status)" : ""}',
                  style: GoogleFonts.dmMono(fontSize: 11, fontWeight: FontWeight.w500,
                      color: isAlert
                          ? (isDark ? AppColors.darkBadgeRedTxt  : AppColors.badgeRedTxt)
                          : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)),
                ),
              );
            }).toList()),
      ),

      // Save / Discard buttons
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onDiscard,
            icon: const Icon(Icons.close, size: 15),
            label: const Text('Discard'),
          )),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(
            onPressed: onSave,
            icon: busy
                ? const SizedBox(width: 14, height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save_outlined, size: 15),
            label: const Text('Save'),
          )),
        ]),
      ),
    ]));
  }
}

// ── Manual Entry Panel ────────────────────────────────────────

class _ManualEntryPanel extends StatelessWidget {
  final Map<String, TextEditingController> ctrls;
  final List ocrTests;
  final VoidCallback onSubmit;
  final VoidCallback onCancel;
  final bool busy;
  const _ManualEntryPanel({
    required this.ctrls, required this.ocrTests,
    required this.onSubmit, required this.onCancel, required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    // ── Bug 1 fix: correctly identify recognised fields ──
    // A field is "recognised" when its status is anything other than 'UnreadableValue'
    // (Normal, Low, and High all have a valid parsed value).
    // We do NOT filter by value != 0 because 0 is a valid reading
    // (e.g. Basophils = 0.05 would be cast to 0 with the old num check).
    final readable = ocrTests
        .where((t) => (t as Map)['status'] != 'UnreadableValue')
        .toList();

    return AppCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBadgeAmberBg : AppColors.badgeAmberBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
        ),
        child: Row(children: [
          Icon(Icons.edit_note_rounded, size: 18,
              color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt),
          const SizedBox(width: 8),
          Expanded(child: Text('Enter unreadable values manually',
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt))),
        ]),
      ),

      if (readable.isNotEmpty) ...[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Recognised values (read-only):',
              style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                  letterSpacing: 0.05)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Wrap(spacing: 6, runSpacing: 6,
              children: readable.map((t) {
                final m = t as Map;
                final isAlert = m['status'] == 'Low' || m['status'] == 'High';

                // ── Bug 1 fix: safely format the value as a plain string ──
                // m['value'] is a num from the backend JSON. We call toString()
                // explicitly so it always renders as "13.5" and never as a
                // raw Map/object literal if the type ever changes unexpectedly.
                final rawVal = m['value'];
                final displayVal = (rawVal is num)
                    ? rawVal.toString()          // e.g. "13.5" or "310"
                    : (rawVal?.toString() ?? '—'); // graceful fallback

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAlert
                        ? (isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg)
                        : (isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    // Display: "Name: value" and append status if abnormal
                    '${m['name']}: $displayVal${isAlert ? ' (${m['status']})' : ''}',
                    style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w500,
                        color: isAlert
                            ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                            : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)),
                  ),
                );
              }).toList()),
        ),
      ],

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Text('Enter missing values:',
            style: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
                letterSpacing: 0.05)),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(children: ctrls.entries.map((e) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: TextFormField(
            controller: e.value,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: e.key,
              hintText: 'Enter value for ${e.key}',
              isDense: true,
            ),
          ),
        )).toList()),
      ),

      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Row(children: [
          Expanded(child: OutlinedButton(
              onPressed: busy ? null : onCancel, child: const Text('Cancel'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton(
            onPressed: busy ? null : onSubmit,
            child: busy
                ? const SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save Results'),
          )),
        ]),
      ),
    ]));
  }
}

// ── Appointment card (patient view) ──────────────────────────

class _AppointmentCard extends StatelessWidget {
  final LabAppointmentResponse appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final date    = DateTime.tryParse(appointment.appointmentDate)?.toLocal();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appointment.testNames.join(', '),
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text(
            '${appointment.labName.isNotEmpty ? appointment.labName : 'Lab #${appointment.labId}'} - $dateStr',
            style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
          ),
          if (appointment.notes.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(appointment.notes, style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ],
        ])),
        _StatusBadge(status: appointment.status),
      ]),
    );
  }
}

// ── Lab request card ──────────────────────────────────────────

class _LabRequestCard extends StatelessWidget {
  final LabAppointmentResponse appointment;
  final VoidCallback? onScan;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplete;
  const _LabRequestCard({
    required this.appointment, this.onScan, this.onConfirm, this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final date    = DateTime.tryParse(appointment.appointmentDate)?.toLocal();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            appointment.patientName.isNotEmpty
                ? appointment.patientName : 'Patient #${appointment.patientId}',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
          )),
          _StatusBadge(status: appointment.status),
        ]),
        const SizedBox(height: 6),
        Text(appointment.testNames.join(', '),
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('Appointment: $dateStr',
            style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        if (appointment.notes.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(appointment.notes, style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ],
        if (onScan != null || onConfirm != null || onComplete != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (onScan != null)
              OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                label: const Text('Scan report'),
              ),
            if (onConfirm != null)
              OutlinedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_outlined, size: 16),
                label: const Text('Confirm'),
              ),
            if (onComplete != null)
              ElevatedButton.icon(
                onPressed: onComplete,
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                label: const Text('Enter results'),
              ),
          ]),
        ],
      ]),
    );
  }
}

// ── Test tile ─────────────────────────────────────────────────

class _TestTile extends StatelessWidget {
  final MedicalTestResponse test;
  final AppProvider app;
  const _TestTile({required this.test, required this.app});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final date    = test.date != null ? DateTime.tryParse(test.date!)?.toLocal() : null;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    final labName = app.labName(test.labId) ?? 'Lab #${test.labId}';
    final patName = app.patientName(test.patientId) ?? 'Patient #${test.patientId}';

    // ── Bug 1 fix: parse result as JSON if the backend stored it that way ──
    // The backend may store the OCR analysis directly as a JSON string in the
    // result field (e.g. {"Status":"Warning","Tests":[{"Name":"Hemoglobin",...}]}).
    // We try to decode it and extract the Tests array. If that succeeds we render
    // each test as a name+value chip. If parsing fails we fall back to the
    // existing pipe-separated chip path, and finally to plain text.

    // Step 1: attempt JSON decode
    List<Map> jsonTests = [];
    try {
      final decoded = jsonDecode(test.result);
      if (decoded is Map) {
        // Backend key may be 'Tests' (PascalCase) or 'tests' (camelCase)
        final rawList = decoded['Tests'] ?? decoded['tests'];
        if (rawList is List) {
          jsonTests = rawList.whereType<Map>().toList();
        }
      }
    } catch (_) {
      // Not JSON — fall through to pipe/plain-text paths below
    }

    // Step 2: pipe-separated chips (legacy format: "Name: value | Name: value")
    final parts = jsonTests.isEmpty && test.result.contains('|')
        ? test.result.split('|').map((s) => s.trim()).toList()
        : <String>[];

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(test.name,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(dateStr, style: GoogleFonts.dmSans(fontSize: 11,
              color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ]),
        const SizedBox(height: 4),
        Text('$patName - $labName', style: GoogleFonts.dmSans(fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        if (test.result.isNotEmpty) ...[
          const SizedBox(height: 8),

          // Path A: JSON format — render each Test entry as "Name: Value" chip
          if (jsonTests.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: jsonTests.map((t) {
              // Keys may be PascalCase or camelCase depending on backend serialiser
              final name   = (t['Name']   ?? t['name']   ?? '').toString();
              final value  = (t['Value']  ?? t['value']  ?? '').toString();
              final status = (t['Status'] ?? t['status'] ?? '').toString();
              final isAlert = status == 'Low' || status == 'High';
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAlert
                      ? (isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg)
                      : (isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F7FB)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isAlert
                      ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt).withOpacity(0.3)
                      : (isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
                ),
                // Display "Name: value" and mark abnormal with (Low)/(High)
                child: Text(
                  '$name: $value${isAlert ? " ($status)" : ""}',
                  style: GoogleFonts.dmMono(fontSize: 11,
                      color: isAlert
                          ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                          : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
                ),
              );
            }).toList())

          // Path B: pipe-separated format — existing chip rendering
          else if (parts.isNotEmpty)
            Wrap(spacing: 6, runSpacing: 6, children: parts.map((p) {
              final isAlert = p.toLowerCase().contains('(high)') || p.toLowerCase().contains('(low)');
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isAlert
                      ? (isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg)
                      : (isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF5F7FB)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isAlert
                      ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt).withOpacity(0.3)
                      : (isDark ? AppColors.darkBorderColor : AppColors.borderColor)),
                ),
                child: Text(p, style: GoogleFonts.dmMono(fontSize: 11,
                    color: isAlert
                        ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                        : (isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
              );
            }).toList())

          // Path C: plain text fallback
          else
            Text(test.result, style: GoogleFonts.dmSans(fontSize: 12.5,
                color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
        ],
      ]),
    );
  }
}

// ── All Tests Bottom Sheet ────────────────────────────────────
class _AllTestsSheet extends StatelessWidget {
  final List<MedicalTestResponse> tests;
  final AppProvider app;
  const _AllTestsSheet({required this.tests, required this.app});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
            borderRadius: BorderRadius.circular(2),
          ),
        )),
        Row(children: [
          Expanded(child: Text('All Test Results',
              style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700))),
          Text('${tests.length} total',
              style: GoogleFonts.dmSans(fontSize: 13,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        ]),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: tests.length,
            itemBuilder: (_, i) => _TestTile(test: tests[i], app: app),
          ),
        ),
      ]),
    );
  }
}

// ── Complete result dialog ────────────────────────────────────

class _CompleteResultDialog extends StatefulWidget {
  final LabAppointmentResponse appointment;
  const _CompleteResultDialog({required this.appointment});
  @override
  State<_CompleteResultDialog> createState() => _CompleteResultDialogState();
}

class _CompleteResultDialogState extends State<_CompleteResultDialog> {
  late final List<TextEditingController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = widget.appointment.testNames.map((_) => TextEditingController()).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Enter test results'),
      content: SingleChildScrollView(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          for (var i = 0; i < widget.appointment.testNames.length; i++) ...[
            TextField(
              controller: _controllers[i],
              minLines: 2, maxLines: 4,
              decoration: InputDecoration(
                labelText: widget.appointment.testNames[i],
                hintText: 'Write result, values, notes, or normal range',
              ),
            ),
            const SizedBox(height: 10),
          ],
        ]),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final results = <LabTestResultRequest>[];
            for (var i = 0; i < widget.appointment.testNames.length; i++) {
              final result = _controllers[i].text.trim();
              // Allow empty results — backend validates, not Flutter
              results.add(LabTestResultRequest(
                name: widget.appointment.testNames[i],
                result: result.isNotEmpty ? result : 'Pending',
              ));
            }
            if (results.isEmpty) return;
            Navigator.of(context).pop(results);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Status badge ──────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final type = status == 'Completed' ? BadgeType.green
        : status == 'Cancelled' ? BadgeType.red
        : status == 'Confirmed' ? BadgeType.blue
        : BadgeType.amber;
    return BadgeWidget(label: status, type: type);
  }
}