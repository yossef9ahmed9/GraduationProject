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
  String _ocrTestType = 'CBC'; // auto-detected by backend
  final Map<String, TextEditingController> _manualCtrls = {};

  // Holds the latest OCR scan in memory only — never persisted to DB until
  // the user explicitly presses "Save". Cleared on discard or app restart.
  List<Map> _pendingOcrTests = [];
  String   _pendingFileName  = '';
  String   _pendingTestType  = 'CBC';

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

  Future<void> _fillForm(LabAppointmentResponse appointment) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LabFormSheet(
        appointment: appointment,
        onSuccess: () async {
          await _refresh();
          if (mounted) setState(() {
            _message = 'Results saved and sent to patient.';
            _isError = false;
          });
        },
      ),
    );
  }
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
      _pendingOcrTests = []; _pendingFileName = file.name; _pendingTestType = 'CBC';
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
    final detectedType = scan.testType; // e.g. "CBC", "Lipid Panel", etc.

    // Identify fields the OCR could not read clearly
    final unreadable = tests
        .where((t) => (t as Map)['status'] == 'UnreadableValue')
        .map((t) => (t as Map)['name'] as String)
        .toList();

    // Fallback: all known fields for the detected test type
    final allFieldsForType = kTestFields[detectedType] ?? kTestFields['CBC']!;

    if (!scan.isValidScan) {
      // Completely unreadable — show manual entry for all fields of this type
      final fieldsToPrompt = unreadable.isNotEmpty ? unreadable : allFieldsForType;
      setState(() {
        _busy = false; _isError = false;
        _message = fieldsToPrompt.length < allFieldsForType.length
            ? 'Some values could not be read. Please enter them manually.'
            : 'Could not read values from image. Please enter them manually.';
        _ocrResult = scan;
        _ocrTestType = detectedType;
        _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
        for (final f in fieldsToPrompt) _manualCtrls[f] = TextEditingController();
      });
      return;
    }

    if (unreadable.isNotEmpty) {
      // Partially unreadable — manual entry only for unrecognised fields
      setState(() {
        _busy = false; _isError = false;
        _message = 'Some values could not be read. Please enter them manually.';
        _ocrResult = scan;
        _ocrTestType = detectedType;
        _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
        for (final f in unreadable) _manualCtrls[f] = TextEditingController();
      });
      return;
    }

    // Fully readable — store as pending preview
    setState(() {
      _busy = false; _isError = false;
      _message = 'Scan complete ($detectedType). Review below and press Save to keep it.';
      _ocrPatientId = patientId; _ocrLabId = labId; _ocrAppointmentId = appointmentId;
      _pendingOcrTests = tests.whereType<Map>().toList();
      _pendingFileName = file.name;
      _pendingTestType = detectedType;
    });
  }

  // Step 2 of 2: user explicitly confirms — now save to the database.
  Future<void> _saveOcrResult() async {
    if (_ocrPatientId == null || _ocrLabId == null || _pendingOcrTests.isEmpty) return;

    // Build pipe-separated result WITH status so _TestTile can colour chips:
    // "Hemoglobin: 14.8 (Normal)" → normal chip, "MCV: 79.6 (Low)" → red chip
    final resultStr = _pendingOcrTests
        .where((t) => (t['status'] ?? t['Status'] ?? '') != 'UnreadableValue')
        .map((t) {
          final name   = (t['name']   ?? t['Name']   ?? '').toString();
          final value  = (t['value']  ?? t['Value']  ?? 0).toString();
          final status = (t['status'] ?? t['Status'] ?? 'Normal').toString();
          return status == 'Normal' ? '$name: $value' : '$name: $value ($status)';
        })
        .join(' | ');

    setState(() { _busy = true; _message = null; });

    final res = await apiService.addMedicalTest(MedicalTestRequest(
      name: _pendingTestType, result: resultStr,
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
        _pendingOcrTests = []; _pendingFileName = ''; _pendingTestType = 'CBC';
        _ocrPatientId = null; _ocrLabId = null; _ocrAppointmentId = null;
      }
    });
  }

  // Discard the pending preview without saving anything
  void _discardOcrResult() {
    setState(() {
      _pendingOcrTests = []; _pendingFileName = ''; _pendingTestType = 'CBC';
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
  // If appointment has multiple tests, lets the lab pick multiple images —
  // one per test. Each image is sent as a separate OCR call and saved as a
  // separate MedicalTest. Single-test appointments use the existing single-
  // file flow so the preview/manual-entry path is preserved.
  Future<void> _scanOcr(LabAppointmentResponse appointment) async {
    final testNames = appointment.testNames;

    if (testNames.length <= 1) {
      // Single test — use existing preview flow
      await _runOcr(
        patientId:     appointment.patientId,
        labId:         appointment.labId,
        appointmentId: appointment.id,
      );
      return;
    }

    // Multiple tests — pick multiple images (ideally one per test)
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'tif', 'tiff'],
      allowMultiple: true,
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    setState(() { _busy = true; _message = null; });

    int saved = 0;
    for (final file in picked.files) {
      final bytes = file.bytes;
      if (bytes == null) continue;
      final res = await apiService.uploadOcrReport(
        fileName:  file.name,
        bytes:     bytes,
        patientId: appointment.patientId,
        labId:     appointment.labId,
      );
      if (res.ok) saved++;
    }

    // Mark appointment complete if at least one image was saved
    if (saved > 0) {
      await apiService.updateLabAppointmentStatus(appointment.id, 'Completed');
    }

    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy    = false;
      _isError = saved == 0;
      _message = saved == 0
          ? 'Failed to upload any images.'
          : 'Saved $saved of ${picked.files.length} '
            'result image${saved > 1 ? 's' : ''}.';
    });
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

    // Start with OCR-recognised values (skip unreadable ones)
    final allFields = <String, Map<String, String>>{};
    for (final t in tests) {
      final name   = (t['name']   ?? t['Name']   ?? '').toString();
      final value  = (t['value']  ?? t['Value']  ?? 0).toString();
      final status = (t['status'] ?? t['Status'] ?? 'Normal').toString();
      if (name.isNotEmpty && status != 'UnreadableValue') {
        allFields[name] = {'value': value, 'status': status};
      }
    }

    // Override/add manual entries (status defaults to Normal for user-typed values)
    for (final e in _manualCtrls.entries) {
      final v = e.value.text.trim();
      if (v.isNotEmpty) allFields[e.key] = {'value': v, 'status': 'Normal'};
    }

    // Build "Name: value (Status)" pipe string — omit status label when Normal
    final resultStr = allFields.entries.map((e) {
      final status = e.value['status'] ?? 'Normal';
      return status == 'Normal'
          ? '${e.key}: ${e.value['value']}'
          : '${e.key}: ${e.value['value']} ($status)';
    }).join(' | ');
    setState(() { _busy = true; _message = null; });
    final res = await apiService.addMedicalTest(MedicalTestRequest(
      name: _ocrTestType, result: resultStr,
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
        _ocrResult = null; _manualCtrls.clear(); _ocrTestType = 'CBC';
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
                    testType: _pendingTestType,
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
                      onFillForm: visibleAppointments[i].status != 'Completed' &&
                          visibleAppointments[i].status != 'Cancelled'
                          ? () => _fillForm(visibleAppointments[i]) : null,
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
  final String    testType;
  final VoidCallback? onSave;
  final VoidCallback? onDiscard;
  final bool busy;

  const _OcrPreviewPanel({
    required this.tests,
    required this.fileName,
    required this.testType,
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
            Text('$testType — Scan Preview (not saved yet)',
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
  final VoidCallback? onFillForm;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplete;
  const _LabRequestCard({
    required this.appointment, this.onScan, this.onFillForm, this.onConfirm, this.onComplete,
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
        if (onScan != null || onFillForm != null || onConfirm != null || onComplete != null) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: [
            if (onConfirm != null)
              OutlinedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.check_outlined, size: 16),
                label: const Text('Confirm'),
              ),
            if (onFillForm != null)
              ElevatedButton.icon(
                onPressed: onFillForm,
                icon: const Icon(Icons.assignment_turned_in_outlined, size: 16),
                label: const Text('Fill Test Results'),
              ),
            if (onScan != null)
              OutlinedButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.document_scanner_outlined, size: 16),
                label: const Text('Upload Result Image'),
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

// ════════════════════════════════════════════════════════════════
// Lab Form Sheet — structured form per test type
// ════════════════════════════════════════════════════════════════

const Map<String, List<String>> kTestFields = {
  'CBC': ['Hemoglobin', 'Hematocrit', 'RBCs Count', 'MCV', 'MCH', 'MCHC', 'RDW-CV', 'Platelets', 'WBC', 'Neutrophils', 'Lymphocytes', 'Monocytes', 'Eosinophils', 'Basophils'],
  'Glucose': ['Fasting Glucose', 'Random Glucose', 'Fasting Insulin', 'HOMA-IR'],
  'HbA1c': ['HbA1c %', 'Average Blood Glucose', 'eAG mg/dL'],
  'Lipid Panel': ['Total Cholesterol', 'LDL Cholesterol', 'HDL Cholesterol', 'Triglycerides', 'VLDL', 'Non-HDL Cholesterol', 'LDL/HDL Ratio'],
  'Kidney Function': ['Creatinine', 'BUN', 'BUN/Creatinine Ratio', 'eGFR', 'Uric Acid', 'Sodium', 'Potassium', 'Chloride', 'Bicarbonate'],
  'Liver Function': ['ALT', 'AST', 'ALP', 'GGT', 'Total Bilirubin', 'Direct Bilirubin', 'Indirect Bilirubin', 'Total Protein', 'Albumin', 'Globulin', 'A/G Ratio'],
  'Thyroid (TSH)': ['TSH', 'Free T4', 'Free T3', 'Total T4', 'Total T3', 'Anti-TPO', 'Anti-TG'],
  'Vitamin D': ['25-OH Vitamin D', '1,25-OH Vitamin D', 'PTH'],
  'Iron Studies': ['Serum Iron', 'TIBC', 'Transferrin Saturation %', 'Ferritin', 'Transferrin'],
  'Urine Analysis': ['Color', 'Clarity', 'pH', 'Specific Gravity', 'Protein', 'Glucose', 'Ketones', 'Blood', 'Nitrite', 'Leukocyte Esterase', 'WBC/hpf', 'RBC/hpf', 'Bacteria', 'Casts'],
};

class _LabFormSheet extends StatefulWidget {
  final LabAppointmentResponse appointment;
  final VoidCallback onSuccess;
  const _LabFormSheet({required this.appointment, required this.onSuccess});
  @override
  State<_LabFormSheet> createState() => _LabFormSheetState();
}

class _LabFormSheetState extends State<_LabFormSheet> {
  // Map: testName → (fieldName → TextEditingController)
  late final Map<String, Map<String, TextEditingController>> _ctrls;
  // Track expanded sections
  late final Map<String, bool> _expanded;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _ctrls = {};
    _expanded = {};
    for (final testName in widget.appointment.testNames) {
      final fields = kTestFields[testName] ?? [];
      _ctrls[testName] = {
        for (final f in fields) f: TextEditingController(),
      };
      _expanded[testName] = true; // expanded by default
    }
  }

  @override
  void dispose() {
    for (final map in _ctrls.values) {
      for (final c in map.values) c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitting = true);

    final results = <LabTestResultRequest>[];
    for (final entry in _ctrls.entries) {
      final testName = entry.key;
      final fieldMap = entry.value;
      // Build pipe-separated string — skip empty fields
      final parts = fieldMap.entries
          .where((e) => e.value.text.trim().isNotEmpty)
          .map((e) => '${e.key}: ${e.value.text.trim()}')
          .toList();
      if (parts.isEmpty) {
        results.add(LabTestResultRequest(name: testName, result: 'Pending'));
      } else {
        results.add(LabTestResultRequest(name: testName, result: parts.join(' | ')));
      }
    }

    final res = await apiService.completeLabAppointment(
      widget.appointment.id,
      CompleteLabAppointmentRequest(results: results),
    );

    if (!mounted) return;
    setState(() => _submitting = false);

    if (res.ok) {
      widget.onSuccess();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Results saved and sent to patient.')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(res.error ?? 'Failed to save results.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date   = DateTime.tryParse(widget.appointment.appointmentDate)?.toLocal();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';

    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollCtrl) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            width: 36, height: 4,
            margin: const EdgeInsets.only(top: 10, bottom: 4),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
              borderRadius: BorderRadius.circular(2),
            ),
          )),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.science_outlined, size: 20),
                const SizedBox(width: 8),
                Expanded(child: Text('Fill Lab Results',
                    style: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 4),
              Text(
                '${widget.appointment.patientName.isNotEmpty ? widget.appointment.patientName : 'Patient #${widget.appointment.patientId}'} · ${widget.appointment.testNames.join(', ')} · $dateStr',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
              ),
            ]),
          ),
          Divider(height: 1, color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
          // Scrollable form
          Expanded(
            child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              children: [
                for (final testName in widget.appointment.testNames) ...[
                  // Section header with toggle
                  InkWell(
                    onTap: () => setState(() => _expanded[testName] = !(_expanded[testName] ?? true)),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.science_outlined, size: 16),
                        const SizedBox(width: 8),
                        Expanded(child: Text(testName,
                            style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w700))),
                        Icon((_expanded[testName] ?? true)
                            ? Icons.expand_less : Icons.expand_more, size: 20),
                      ]),
                    ),
                  ),
                  if (_expanded[testName] ?? true) ...[
                    if ((kTestFields[testName]?.isEmpty ?? true))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: (_ctrls[testName]?['result'] ??= TextEditingController()),
                          decoration: const InputDecoration(
                              labelText: 'Result', hintText: 'Enter result'),
                        ),
                      )
                    else
                      ...?(_ctrls[testName]?.entries.map((e) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: TextField(
                          controller: e.value,
                          keyboardType: TextInputType.text,
                          decoration: InputDecoration(
                            labelText: e.key,
                            hintText: 'Enter value',
                            isDense: true,
                          ),
                        ),
                      )).toList()),
                  ],
                  Divider(height: 1,
                      color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          ),
          // Submit button
          Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20,
                MediaQuery.of(context).viewInsets.bottom + 20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _submitting ? null : _submit,
                icon: _submitting
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Submit Results'),
              ),
            ),
          ),
        ]),
      ),
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