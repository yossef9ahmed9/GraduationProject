import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class FollowUpsPage extends StatefulWidget {
  const FollowUpsPage({super.key});
  @override
  State<FollowUpsPage> createState() => _FollowUpsPageState();
}

class _FollowUpsPageState extends State<FollowUpsPage> {
  bool _busy = false;
  String? _msg;
  bool _isError = false;

  Future<void> _refresh() async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    await app.refreshFollowUps(auth.role, auth.user?.email ?? '');
  }

  Future<void> _act(Future<ApiResult<bool>> Function() call,
      String successMsg) async {
    setState(() { _busy = true; _msg = null; });
    final res = await call();
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _isError = !res.ok;
      _msg = res.ok ? successMsg : (res.error ?? 'Failed.');
    });
  }

  // ── Doctor: write prescription dialog ───────────────────────
  Future<void> _writePrescription(FollowUpResponse f) async {
    final treatCtrl = TextEditingController(text: f.treatmentPlan);
    final notesCtrl = TextEditingController(text: f.notes);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Prescription',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
        content: SingleChildScrollView(child: Column(
            mainAxisSize: MainAxisSize.min, children: [
          Text('Treatment Plan', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(controller: treatCtrl, maxLines: 4,
              decoration: const InputDecoration(hintText: 'Medications, dosage, instructions…')),
          const SizedBox(height: 14),
          Text('Notes', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          const SizedBox(height: 6),
          TextField(controller: notesCtrl, maxLines: 3,
              decoration: const InputDecoration(hintText: 'Additional notes…')),
        ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Save')),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await _act(
      () => apiService.updatePrescription(
          f.id, treatCtrl.text.trim(), notesCtrl.text.trim()),
      'Prescription saved.',
    );
    treatCtrl.dispose();
    notesCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final role   = auth.role;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  '${app.followUps.length} follow-up${app.followUps.length != 1 ? 's' : ''}',
                  style: GoogleFonts.dmSans(fontSize: 13,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary),
                ),
                if (_msg != null) ...[
                  const SizedBox(height: 10),
                  AlertWidget(message: _msg!, isError: _isError),
                ],
              ]),
            ),
          ),

          if (app.isLoading)
            const SliverToBoxAdapter(child: LoadingRows(count: 5))
          else if (app.followUps.isEmpty)
            const SliverToBoxAdapter(
              child: EmptyState(
                  message: 'No follow-ups found',
                  icon: Icons.assignment_outlined))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _FollowUpCard(
                    followUp:    app.followUps[i],
                    app:         app,
                    role:        role,
                    busy:        _busy,
                    onApprove:   role == UserRole.doctor
                        ? () => _act(
                            () => apiService.approveFollowUp(app.followUps[i].id),
                            'Follow-up approved.')
                        : null,
                    onReject:    role == UserRole.doctor
                        ? () => _act(
                            () => apiService.rejectFollowUp(app.followUps[i].id),
                            'Follow-up rejected.')
                        : null,
                    onCancel:    role == UserRole.patient &&
                            app.followUps[i].status != 'Rejected' &&
                            app.followUps[i].status != 'Cancelled'
                        ? () => _act(
                            () => apiService.cancelFollowUp(app.followUps[i].id),
                            'Appointment cancelled.')
                        : null,
                    onPrescribe: role == UserRole.doctor &&
                            app.followUps[i].status == 'Approved'
                        ? () => _writePrescription(app.followUps[i])
                        : null,
                  ),
                  childCount: app.followUps.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Follow-up card ─────────────────────────────────────────────
class _FollowUpCard extends StatelessWidget {
  final FollowUpResponse followUp;
  final AppProvider      app;
  final UserRole         role;
  final bool             busy;
  final VoidCallback?    onApprove;
  final VoidCallback?    onReject;
  final VoidCallback?    onCancel;
  final VoidCallback?    onPrescribe;

  const _FollowUpCard({
    required this.followUp, required this.app, required this.role,
    required this.busy,
    this.onApprove, this.onReject, this.onCancel, this.onPrescribe,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final pName   = app.patientName(followUp.patientId)
        ?? 'Patient #${followUp.patientId}';
    final dName   = app.doctorName(followUp.doctorId)
        ?? 'Doctor #${followUp.doctorId}';
    final dateStr = followUp.nextVisitDate != null
        ? DateTime.tryParse(followUp.nextVisitDate!)?.toLocal()
            .toString().split(' ').first ?? '—'
        : (followUp.lastUpdate != null
            ? DateTime.tryParse(followUp.lastUpdate!)?.toLocal()
                .toString().split(' ').first ?? '—'
            : '—');

    // Status badge
    BadgeType statusType;
    switch (followUp.status) {
      case 'Approved':  statusType = BadgeType.green;  break;
      case 'Rejected':  statusType = BadgeType.red;    break;
      case 'Cancelled': statusType = BadgeType.red;    break;
      default:          statusType = BadgeType.amber;  // Pending
    }

    // Severity badge
    BadgeType severityType;
    switch (followUp.severity) {
      case 'Critical': severityType = BadgeType.red;    break;
      case 'High':     severityType = BadgeType.red;    break;
      case 'Medium':   severityType = BadgeType.amber;  break;
      default:         severityType = BadgeType.green;  // Low
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Header row ──────────────────────────────────────
        Row(children: [
          Expanded(child: Text(
            role == UserRole.patient ? dName : pName,
            style: GoogleFonts.dmSans(
                fontSize: 14, fontWeight: FontWeight.w700),
          )),
          BadgeWidget(label: followUp.status, type: statusType),
        ]),

        // Sub header (doctor for patient view)
        if (role == UserRole.doctor) ...[
          const SizedBox(height: 2),
          Text(pName, style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary)),
        ],

        const SizedBox(height: 8),

        // ── Diagnosis ───────────────────────────────────────
        if (followUp.diagnosis.isNotEmpty) ...[
          _InfoRow(Icons.medical_information_outlined,
              followUp.diagnosis, isDark),
          const SizedBox(height: 4),
        ],

        // ── Treatment plan (prescription) ───────────────────
        if (followUp.treatmentPlan.isNotEmpty &&
            followUp.treatmentPlan != 'To be determined') ...[
          _InfoRow(Icons.medication_outlined,
              followUp.treatmentPlan, isDark),
          const SizedBox(height: 4),
        ],

        // ── Notes ───────────────────────────────────────────
        if (followUp.notes.isNotEmpty) ...[
          _InfoRow(Icons.notes_rounded, followUp.notes, isDark),
          const SizedBox(height: 4),
        ],

        // ── Meta row ────────────────────────────────────────
        Row(children: [
          BadgeWidget(label: followUp.severity, type: severityType),
          const SizedBox(width: 8),
          Icon(Icons.calendar_today_outlined, size: 12,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary),
          const SizedBox(width: 4),
          Text(dateStr, style: GoogleFonts.dmSans(fontSize: 11,
              color: isDark
                  ? AppColors.darkTextTertiary
                  : AppColors.textTertiary)),
        ]),

        // ── Actions ─────────────────────────────────────────
        if (onApprove != null || onReject != null ||
            onCancel   != null || onPrescribe != null) ...[
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 6, children: [

            // Doctor: approve pending
            if (onApprove != null && followUp.status == 'Pending')
              ElevatedButton.icon(
                onPressed: busy ? null : onApprove,
                icon: const Icon(Icons.check_rounded, size: 15),
                label: const Text('Approve'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.badgeGreenTxt,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),

            // Doctor: reject pending
            if (onReject != null && followUp.status == 'Pending')
              OutlinedButton.icon(
                onPressed: busy ? null : onReject,
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.darkBadgeRedTxt
                        : AppColors.badgeRedTxt,
                    side: BorderSide(
                        color: isDark
                            ? AppColors.darkBadgeRedTxt
                            : AppColors.badgeRedTxt),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),

            // Doctor: write prescription on approved
            if (onPrescribe != null)
              OutlinedButton.icon(
                onPressed: busy ? null : onPrescribe,
                icon: const Icon(Icons.edit_note_rounded, size: 15),
                label: const Text('Prescription'),
                style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),

            // Patient: cancel
            if (onCancel != null)
              OutlinedButton.icon(
                onPressed: busy ? null : onCancel,
                icon: const Icon(Icons.cancel_outlined, size: 15),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? AppColors.darkBadgeRedTxt
                        : AppColors.badgeRedTxt,
                    side: BorderSide(
                        color: isDark
                            ? AppColors.darkBadgeRedTxt
                            : AppColors.badgeRedTxt),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              ),
          ]),
        ],
      ]),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   text;
  final bool     isDark;
  const _InfoRow(this.icon, this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 14,
          color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
      const SizedBox(width: 6),
      Expanded(child: Text(text,
          style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary))),
    ],
  );
}
