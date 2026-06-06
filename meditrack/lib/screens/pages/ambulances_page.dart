import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// AMBULANCES PAGE
// Now uses real data from /api/emergencydispatches.
// The old demo fleet list has been replaced with live dispatch records.
// ════════════════════════════════════════════════════════════════

class AmbulancesPage extends StatefulWidget {
  const AmbulancesPage({super.key});

  @override
  State<AmbulancesPage> createState() => _AmbulancesPageState();
}

class _AmbulancesPageState extends State<AmbulancesPage> {
  bool _updating = false;
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final app = context.read<AppProvider>();
      if (!app.isLoading && app.ambulances.isEmpty && app.dispatches.isEmpty) {
        await _refresh();
      }
    });
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    final app = context.read<AppProvider>();
    await Future.wait([
      app.refreshAmbulances(),
      app.refreshDispatches(),
    ]);
    if (!mounted) return;
    setState(() => _refreshing = false);
  }

  Future<void> _updateStatus(int dispatchId, String status) async {
    setState(() => _updating = true);
    final app = context.read<AppProvider>();
    final ok = await app.updateDispatchStatus(dispatchId, status);
    if (!mounted) return;
    setState(() => _updating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok ? 'Status updated to "$status"' : 'Failed to update status',
        style: GoogleFonts.dmSans(),
      ),
    ));
  }

  Future<void> _updateAmbulanceAvailability(int ambulanceId, String status) async {
    setState(() => _updating = true);
    final app = context.read<AppProvider>();
    final ok = await app.updateAmbulanceAvailability(ambulanceId, status);
    if (!mounted) return;
    setState(() => _updating = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        ok ? 'Ambulance marked ${_availabilityLabel(status)}' : 'Failed to update ambulance',
        style: GoogleFonts.dmSans(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    final allDispatches = app.dispatches;
    final active   = allDispatches.where((d) => d.isActive).length;
    final resolved = allDispatches.where((d) => d.status == 'Resolved').length;
    final availableAmbulances = app.ambulances
        .where((a) => a.availabilityStatus == 'Available')
        .length;

    // Ambulance role sees only their own dispatches; others see all
    final visibleDispatches = allDispatches;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Stack(
        children: [
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (app.loadError != null) ...[
                  AlertWidget(message: app.loadError!, isError: true),
                  const SizedBox(height: 12),
                ],
                // ── Stat row ─────────────────────────────────────
                Row(children: [
                  Expanded(child: StatCard(
                    label: 'Ambulances',
                    value: '${app.ambulances.length}',
                    subtitle: '$availableAmbulances available',
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(
                    label: 'Active',
                    value: '$active',
                    subtitle: 'In progress',
                    valueColor: active > 0
                        ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                        : null,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: StatCard(
                    label: 'Resolved',
                    value: '$resolved',
                    subtitle: 'Completed',
                    valueColor: isDark
                        ? AppColors.darkBadgeGreenTxt
                        : AppColors.badgeGreenTxt,
                  )),
                ]),
                const SizedBox(height: 20),

                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardHeader(title: 'Ambulance Fleet'),
                      if (app.isLoading || _refreshing)
                        const LoadingRows(count: 3)
                      else if (app.ambulances.isEmpty)
                        const EmptyState(
                          message: 'No ambulances found',
                          icon: Icons.emergency_outlined,
                        )
                      else
                        ...app.ambulances.map((a) => _AmbulanceTile(
                              ambulance: a,
                              canUpdate: role == UserRole.ambulance ||
                                  role == UserRole.admin,
                              onUpdateAvailability: (status) =>
                                  _updateAmbulanceAvailability(a.id, status),
                            )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Active dispatches ─────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CardHeader(
                        title: 'Active Dispatches',
                        trailing: _updating
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2))
                            : null,
                      ),
                      if (app.isLoading || _refreshing)
                        const LoadingRows(count: 3)
                      else if (visibleDispatches.where((d) => d.isActive).isEmpty)
                        const EmptyState(
                          message: 'No active dispatches',
                          icon: Icons.check_circle_outline,
                        )
                      else
                        ...visibleDispatches
                            .where((d) => d.isActive)
                            .map((d) => _DispatchTile(
                                  dispatch: d,
                                  app: app,
                                  role: role,
                                  onUpdateStatus: (status) =>
                                      _updateStatus(d.id, status),
                                )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Dispatch history ──────────────────────────────
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const CardHeader(title: 'Dispatch History'),
                      if (visibleDispatches
                          .where((d) => !d.isActive)
                          .isEmpty)
                        const EmptyState(
                          message: 'No past dispatches',
                          icon: Icons.history,
                        )
                      else
                        ...visibleDispatches
                            .where((d) => !d.isActive)
                            .take(20)
                            .map((d) => _DispatchTile(
                                  dispatch: d,
                                  app: app,
                                  role: role,
                                  onUpdateStatus: null, // past — read-only
                                )),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── Emergency vitals needing dispatch ─────────────
                if (role != UserRole.patient &&
                    role != UserRole.relative &&
                    app.emergencyVitals.isNotEmpty)
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CardHeader(title: 'Vitals Requiring Attention'),
                        ...app.emergencyVitals.map((v) => _VitalAlertRow(vital: v)),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // Full-page loading overlay when updating status
          if (_updating)
            const IgnorePointer(
              child: SizedBox.expand(
                child: ColoredBox(color: Colors.black12),
              ),
            ),
        ],
      ),
    );
  }
}

String _availabilityLabel(String status) {
  switch (status) {
    case 'Available':
      return 'Available';
    case 'Busy':
      return 'Busy';
    case 'OutOfService':
      return 'Not Available';
    default:
      return status;
  }
}

// ── Dispatch tile ─────────────────────────────────────────────────

class _DispatchTile extends StatelessWidget {
  final EmergencyDispatchResponse dispatch;
  final AppProvider app;
  final UserRole role;
  final void Function(String status)? onUpdateStatus;

  const _DispatchTile({
    required this.dispatch,
    required this.app,
    required this.role,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final patientName =
        app.patientName(dispatch.patientId) ?? 'Patient #${dispatch.patientId}';

    final dispatchedDate = DateTime.tryParse(dispatch.dispatchedAt)?.toLocal();
    final dispatchedStr = dispatchedDate != null
        ? '${dispatchedDate.day}/${dispatchedDate.month}/${dispatchedDate.year} '
          '${dispatchedDate.hour.toString().padLeft(2, '0')}:'
          '${dispatchedDate.minute.toString().padLeft(2, '0')}'
        : '—';

    final statusColor = _statusColor(dispatch.status, isDark);
    final canUpdate = onUpdateStatus != null &&
        (role == UserRole.ambulance ||
            role == UserRole.admin ||
            role == UserRole.doctor);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgBase : AppColors.bgBase,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: patient + status badge
          Row(
            children: [
              Expanded(
                child: Text(
                  patientName,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkTextPrimary
                        : AppColors.textPrimary,
                  ),
                ),
              ),
              _StatusBadge(status: dispatch.status, color: statusColor),
            ],
          ),
          const SizedBox(height: 6),

          // Metadata
          _MetaRow(Icons.access_time_rounded, 'Dispatched: $dispatchedStr'),
          _MetaRow(Icons.emergency_outlined,
              'Ambulance ID: ${dispatch.ambulanceId}'),
          if (dispatch.notes != null && dispatch.notes!.isNotEmpty)
            _MetaRow(Icons.notes_rounded, dispatch.notes!),

          // Action buttons — only for active dispatches and authorised roles
          if (canUpdate) ...[
            const SizedBox(height: 8),
            _ActionButtons(
              status: dispatch.status,
              onUpdate: onUpdateStatus!,
            ),
          ],
        ],
      ),
    );
  }

  Color _statusColor(String status, bool isDark) {
    switch (status) {
      case 'Pending':
        return isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt;
      case 'OnTheWay':
        return isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt;
      case 'Arrived':
        return isDark ? AppColors.darkBadgePurpleTxt : AppColors.badgePurpleTxt;
      case 'Resolved':
        return isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt;
      case 'Cancelled':
        return isDark ? AppColors.darkTextTertiary : AppColors.textTertiary;
      default:
        return isDark ? AppColors.darkTextSecondary : AppColors.textSecondary;
    }
  }
}

class _AmbulanceTile extends StatelessWidget {
  final AmbulanceResponse ambulance;
  final bool canUpdate;
  final void Function(String status)? onUpdateAvailability;

  const _AmbulanceTile({
    required this.ambulance,
    required this.canUpdate,
    required this.onUpdateAvailability,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isAvailable = ambulance.availabilityStatus == 'Available';
    final badgeType = isAvailable
        ? BadgeType.green
        : ambulance.availabilityStatus == 'Busy'
            ? BadgeType.amber
            : BadgeType.red;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgBase : AppColors.bgBase,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? AppColors.darkBorderColor : AppColors.borderColor,
        ),
      ),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isAvailable
                ? (isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg)
                : (isDark ? AppColors.darkBadgeAmberBg : AppColors.badgeAmberBg),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.emergency_outlined,
              size: 20,
              color: isAvailable
                  ? (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt)
                  : (isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ambulance.stationName,
              style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('${ambulance.licensePlate} · ${ambulance.driverName}',
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Text(ambulance.phone.isNotEmpty ? ambulance.phone : ambulance.driverPhone,
              style: GoogleFonts.dmSans(fontSize: 11.5,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ])),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            BadgeWidget(
              label: _availabilityLabel(ambulance.availabilityStatus),
              type: badgeType,
            ),
            if (canUpdate) ...[
              const SizedBox(height: 6),
              PopupMenuButton<String>(
                tooltip: 'Change availability',
                onSelected: onUpdateAvailability,
                itemBuilder: (_) => const [
                  PopupMenuItem(
                    value: 'Available',
                    child: Text('Available'),
                  ),
                  PopupMenuItem(
                    value: 'Busy',
                    child: Text('Busy'),
                  ),
                  PopupMenuItem(
                    value: 'OutOfService',
                    child: Text('Not Available'),
                  ),
                ],
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isDark
                          ? AppColors.darkBorderColor
                          : AppColors.borderColor,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.tune_rounded,
                          size: 14,
                          color: isDark
                              ? AppColors.darkTextSecondary
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Status',
                          style: GoogleFonts.dmSans(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ]),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;
  final Color color;

  const _StatusBadge({required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: GoogleFonts.dmSans(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaRow(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(children: [
        Icon(icon,
            size: 13,
            color: isDark
                ? AppColors.darkTextTertiary
                : AppColors.textTertiary),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ]),
    );
  }
}

// Status progression: Pending → OnTheWay → Arrived → Resolved | Cancelled
class _ActionButtons extends StatelessWidget {
  final String status;
  final void Function(String) onUpdate;

  const _ActionButtons({required this.status, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    final List<_ActionDef> actions = [];

    switch (status) {
      case 'Pending':
        actions.add(const _ActionDef('On the Way', 'OnTheWay', Icons.directions_car_outlined));
        actions.add(const _ActionDef('Cancel', 'Cancelled', Icons.cancel_outlined, danger: true));
        break;
      case 'OnTheWay':
        actions.add(const _ActionDef('Arrived', 'Arrived', Icons.location_on_outlined));
        actions.add(const _ActionDef('Cancel', 'Cancelled', Icons.cancel_outlined, danger: true));
        break;
      case 'Arrived':
        actions.add(const _ActionDef('Resolve', 'Resolved', Icons.check_circle_outline));
        break;
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: actions.map((a) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final color = a.danger
            ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
            : (isDark ? AppColors.darkAccentMuted : AppColors.accentMuted);
        return OutlinedButton.icon(
          onPressed: () => onUpdate(a.status),
          icon: Icon(a.icon, size: 14, color: color),
          label: Text(a.label,
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w500, color: color)),
          style: OutlinedButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            side: BorderSide(color: color.withOpacity(0.4)),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8)),
          ),
        );
      }).toList(),
    );
  }
}

class _ActionDef {
  final String label;
  final String status;
  final IconData icon;
  final bool danger;

  const _ActionDef(this.label, this.status, this.icon,
      {this.danger = false});
}

// ── Vital alert row ───────────────────────────────────────────────

class _VitalAlertRow extends StatelessWidget {
  final VitalSignsResponse vital;

  const _VitalAlertRow({required this.vital});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg;
    final fg = isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: fg.withOpacity(0.3)),
      ),
      child: Row(children: [
        Icon(Icons.warning_amber_rounded, size: 15, color: fg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${vital.patientName} — HR: ${vital.heartRate} bpm'
            '${vital.oxygenSaturation != null ? ' · SpO₂: ${vital.oxygenSaturation!.toStringAsFixed(1)}%' : ''}',
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: fg,
            ),
          ),
        ),
      ]),
    );
  }
}
