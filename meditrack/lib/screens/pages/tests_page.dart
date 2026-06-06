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

  Future<void> _refresh() async {
    final app = context.read<AppProvider>();
    await Future.wait([
      app.refreshTests(),
      app.refreshLabAppointments(),
    ]);
  }

  Future<void> _updateStatus(LabAppointmentResponse appointment, String status) async {
    setState(() { _busy = true; _message = null; });
    final app = context.read<AppProvider>();
    final res = await apiService.updateLabAppointmentStatus(appointment.id, status);
    await app.refreshLabAppointments();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isError = !res.ok;
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
      appointment.id,
      CompleteLabAppointmentRequest(results: results),
    );
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isError = !res.ok;
      _message = res.ok ? 'Results saved and sent to patient.' : res.error ?? 'Failed to save results.';
    });
  }

  Future<void> _scanOcr(LabAppointmentResponse appointment) async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'tif', 'tiff'],
      withData: true,
    );
    if (picked == null || picked.files.isEmpty) return;

    final file = picked.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      setState(() {
        _isError = true;
        _message = 'Could not read selected image.';
      });
      return;
    }

    setState(() { _busy = true; _message = null; });
    final res = await apiService.uploadOcrReport(
      fileName: file.name,
      bytes: bytes,
      patientId: appointment.patientId,
      labId: appointment.labId,
    );
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isError = !res.ok || !(res.data?.isValidScan ?? false);
      _message = res.ok
          ? ((res.data?.isValidScan ?? false)
              ? 'Report scanned and saved.'
              : 'The scan was uploaded, but no valid lab values were detected.')
          : res.error ?? 'Failed to scan report.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final auth = context.watch<AuthProvider>();
    final role = auth.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patient = role == UserRole.patient
        ? app.patientByEmail(auth.user?.email ?? '')
        : null;
    final visibleTests = patient != null ? app.testsForPatient(patient.id) : app.tests;
    final visibleAppointments = patient != null
        ? app.labAppointmentsForPatient(patient.id)
        : app.labAppointments;

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
                Text(
                  role == UserRole.lab ? 'Lab Requests' : 'My Lab Tests',
                  style: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  role == UserRole.lab
                      ? '${visibleAppointments.length} request${visibleAppointments.length == 1 ? "" : "s"} waiting or completed'
                      : '${visibleTests.length} result${visibleTests.length == 1 ? "" : "s"} saved',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                  ),
                ),
              ]),
            ),
          ),
          if (role == UserRole.lab) ...[
            if (visibleAppointments.isEmpty)
              const SliverToBoxAdapter(child: EmptyState(message: 'No lab requests yet', icon: Icons.science_outlined))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _LabRequestCard(
                      appointment: visibleAppointments[i],
                      onScan: () => _scanOcr(visibleAppointments[i]),
                      onConfirm: visibleAppointments[i].status == 'Pending'
                          ? () => _updateStatus(visibleAppointments[i], 'Confirmed')
                          : null,
                      onComplete: visibleAppointments[i].status != 'Completed' &&
                              visibleAppointments[i].status != 'Cancelled'
                          ? () => _complete(visibleAppointments[i])
                          : null,
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
              const SliverToBoxAdapter(child: EmptyState(message: 'No test results found', icon: Icons.description_outlined))
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (_, i) => _TestTile(test: visibleTests[i], app: app),
                    childCount: visibleTests.length,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final LabAppointmentResponse appointment;
  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.tryParse(appointment.appointmentDate)?.toLocal();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(appointment.testNames.join(', '), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 3),
          Text('${appointment.labName.isNotEmpty ? appointment.labName : 'Lab #${appointment.labId}'} - $dateStr',
              style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          if (appointment.notes.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(appointment.notes, style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ],
        ])),
        _StatusBadge(status: appointment.status),
      ]),
    );
  }
}

class _LabRequestCard extends StatelessWidget {
  final LabAppointmentResponse appointment;
  final VoidCallback? onScan;
  final VoidCallback? onConfirm;
  final VoidCallback? onComplete;
  const _LabRequestCard({required this.appointment, this.onScan, this.onConfirm, this.onComplete});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = DateTime.tryParse(appointment.appointmentDate)?.toLocal();
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(
            appointment.patientName.isNotEmpty ? appointment.patientName : 'Patient #${appointment.patientId}',
            style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w700),
          )),
          _StatusBadge(status: appointment.status),
        ]),
        const SizedBox(height: 6),
        Text(appointment.testNames.join(', '), style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 3),
        Text('Appointment: $dateStr',
            style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        if (appointment.notes.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(appointment.notes, style: GoogleFonts.dmSans(fontSize: 12, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
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
    _controllers = widget.appointment.testNames
        .map((_) => TextEditingController())
        .toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
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
              minLines: 2,
              maxLines: 4,
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
              if (result.isEmpty) return;
              results.add(LabTestResultRequest(
                name: widget.appointment.testNames[i],
                result: result,
              ));
            }
            Navigator.of(context).pop(results);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final type = status == 'Completed'
        ? BadgeType.green
        : status == 'Cancelled'
            ? BadgeType.red
            : status == 'Confirmed'
                ? BadgeType.blue
                : BadgeType.amber;
    return BadgeWidget(label: status, type: type);
  }
}

class _TestTile extends StatelessWidget {
  final MedicalTestResponse test;
  final AppProvider app;
  const _TestTile({required this.test, required this.app});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final date = test.date != null ? DateTime.tryParse(test.date!)?.toLocal() : null;
    final dateStr = date != null ? '${date.day}/${date.month}/${date.year}' : '-';
    final labName = app.labName(test.labId) ?? 'Lab #${test.labId}';
    final patName = app.patientName(test.patientId) ?? 'Patient #${test.patientId}';
    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(test.name, style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600))),
          Text(dateStr, style: GoogleFonts.dmSans(fontSize: 11, color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ]),
        const SizedBox(height: 4),
        Text('$patName - $labName', style: GoogleFonts.dmSans(fontSize: 12,
            color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
        if (test.result.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(test.result, style: GoogleFonts.dmSans(fontSize: 12.5,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
        ],
      ]),
    );
  }
}
