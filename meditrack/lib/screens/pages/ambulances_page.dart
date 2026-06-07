import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

class AmbulancesPage extends StatefulWidget {
  const AmbulancesPage({super.key});
  @override
  State<AmbulancesPage> createState() => _AmbulancesPageState();
}

class _AmbulancesPageState extends State<AmbulancesPage> {
  bool _busy    = false;
  String? _msg;
  bool _isError = false;

  Future<void> _refresh() async {
    final app = context.read<AppProvider>();
    await Future.wait([app.refreshDispatches(), app.refreshAmbulances()]);
  }

  // ── DND toggle ────────────────────────────────────────────────
  Future<void> _toggleDnd(AmbulanceResponse amb) async {
    final newStatus = amb.availabilityStatus == 'Busy' ? 'Available' : 'Busy';
    setState(() { _busy = true; _msg = null; });
    final ok = await context.read<AppProvider>()
        .updateAmbulanceAvailability(amb.id, newStatus);
    if (!mounted) return;
    setState(() { _busy = false; _isError = !ok;
      _msg = ok ? 'DND ${newStatus == 'Busy' ? 'ON' : 'OFF'}.' : 'Failed.'; });
  }

  // ── Accept / Reject dispatch ──────────────────────────────────
  Future<void> _accept(EmergencyDispatchResponse d) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.acceptDispatch(d.id);
    await _refresh();
    if (!mounted) return;
    setState(() { _busy = false; _isError = !res.ok;
      _msg = res.ok ? 'Dispatch accepted. On the way!' : (res.error ?? 'Failed.'); });
  }

  Future<void> _reject(EmergencyDispatchResponse d) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.rejectDispatch(d.id);
    await _refresh();
    if (!mounted) return;
    setState(() { _busy = false; _isError = !res.ok;
      _msg = res.ok ? 'Dispatch rejected.' : (res.error ?? 'Failed.'); });
  }

  Future<void> _updateStatus(int dispatchId, String status) async {
    setState(() { _busy = true; _msg = null; });
    final ok = await context.read<AppProvider>().updateDispatchStatus(dispatchId, status);
    if (!mounted) return;
    setState(() { _busy = false; _isError = !ok;
      _msg = ok ? 'Updated.' : 'Failed.'; });
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;

    final myEmail     = auth.user?.email ?? '';
    final myAmbulance = role == UserRole.ambulance
        ? app.ambulances
            .where((a) => a.email.toLowerCase() == myEmail.toLowerCase())
            .firstOrNull
        : null;

    // ── Patient: fleet only ───────────────────────────────────
    if (role == UserRole.patient || role == UserRole.relative) {
      return RefreshIndicator(
        onRefresh: () => app.refreshAmbulances(),
        child: Column(children: [
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AlertWidget(message: _msg!, isError: _isError),
            ),
          Expanded(child: _FleetTab(ambulances: app.ambulances)),
        ]),
      );
    }

    // ── Ambulance role ────────────────────────────────────────
    if (role == UserRole.ambulance) {
      final myDispatches = app.dispatches
          .where((d) => d.ambulanceId == myAmbulance?.id)
          .toList();

      return RefreshIndicator(
        onRefresh: _refresh,
        child: Column(children: [
          // Status card with DND toggle
          if (myAmbulance != null)
            _AmbulanceStatusCard(
              ambulance:  myAmbulance,
              busy:       _busy,
              onToggleDnd: () => _toggleDnd(myAmbulance),
            ),
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AlertWidget(message: _msg!, isError: _isError),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('My Dispatches',
                  style: GoogleFonts.dmSans(
                      fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(
            child: _DispatchesList(
              dispatches:     myDispatches,
              role:           role,
              myAmbulanceId:  myAmbulance?.id,
              busy:           _busy,
              onAccept:       _accept,
              onReject:       _reject,
              onUpdateStatus: _updateStatus,
              app:            app,
            ),
          ),
        ]),
      );
    }

    // ── Admin / Doctor: two tabs ──────────────────────────────
    return DefaultTabController(
      length: 2,
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: Column(children: [
          if (_msg != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: AlertWidget(message: _msg!, isError: _isError),
            ),
          Container(
            color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
            child: TabBar(
              labelStyle: GoogleFonts.dmSans(
                  fontSize: 13, fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Active Dispatches'),
                Tab(text: 'Fleet'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(children: [
              _DispatchesList(
                dispatches:     app.dispatches,
                role:           role,
                myAmbulanceId:  null,
                busy:           _busy,
                onAccept:       _accept,
                onReject:       _reject,
                onUpdateStatus: _updateStatus,
                app:            app,
              ),
              _FleetTab(ambulances: app.ambulances),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ── Ambulance status card with DND toggle ─────────────────────
class _AmbulanceStatusCard extends StatelessWidget {
  final AmbulanceResponse ambulance;
  final bool              busy;
  final VoidCallback      onToggleDnd;

  const _AmbulanceStatusCard({
    required this.ambulance,
    required this.busy,
    required this.onToggleDnd,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final status = ambulance.availabilityStatus;
    final isBusy = status == 'Busy';
    final isAvail = status == 'Available';

    BadgeType badgeType;
    if (isAvail)      badgeType = BadgeType.green;
    else if (isBusy)  badgeType = BadgeType.red;
    else              badgeType = BadgeType.amber;  // NotAvailable

    return Container(
      margin:  const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(ambulance.stationName,
                style: GoogleFonts.dmSans(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(ambulance.driverName,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark
                        ? AppColors.darkTextSecondary
                        : AppColors.textSecondary)),
          ])),
          BadgeWidget(label: status, type: badgeType),
        ]),
        const SizedBox(height: 12),
        // DND toggle — like dark mode switch
        Row(children: [
          Icon(
            isBusy
                ? Icons.do_not_disturb_on_rounded
                : Icons.do_not_disturb_off_outlined,
            size: 18,
            color: isBusy
                ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                : (isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
          ),
          const SizedBox(width: 8),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Do Not Disturb',
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w500)),
            Text(isBusy
                    ? 'You will not receive new dispatches'
                    : 'You can receive new dispatches',
                style: GoogleFonts.dmSans(fontSize: 11,
                    color: isDark
                        ? AppColors.darkTextTertiary
                        : AppColors.textTertiary)),
          ])),
          Switch(
            value: isBusy,
            onChanged: busy ? null : (_) => onToggleDnd(),
            activeColor: isDark
                ? AppColors.darkBadgeRedTxt
                : AppColors.badgeRedTxt,
          ),
        ]),
      ]),
    );
  }
}

// ── Dispatches list ────────────────────────────────────────────
class _DispatchesList extends StatelessWidget {
  final List<EmergencyDispatchResponse>          dispatches;
  final UserRole                                 role;
  final int?                                     myAmbulanceId;
  final bool                                     busy;
  final void Function(EmergencyDispatchResponse) onAccept;
  final void Function(EmergencyDispatchResponse) onReject;
  final void Function(int, String)               onUpdateStatus;
  final AppProvider                              app;

  const _DispatchesList({
    required this.dispatches, required this.role, this.myAmbulanceId,
    required this.busy, required this.onAccept, required this.onReject,
    required this.onUpdateStatus, required this.app,
  });

  @override
  Widget build(BuildContext context) {
    if (dispatches.isEmpty) {
      return const EmptyState(
          message: 'No dispatches', icon: Icons.emergency_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: dispatches.length,
      itemBuilder: (_, i) {
        final d            = dispatches[i];
        final isPending    = d.status == 'Pending';
        final isMyDispatch = d.ambulanceId == myAmbulanceId;
        return _DispatchCard(
          dispatch:         d,
          patientName:      app.patientName(d.patientId) ?? 'Patient #${d.patientId}',
          showAcceptReject: role == UserRole.ambulance && isMyDispatch && isPending && !busy,
          showStatusUpdate: role == UserRole.ambulance && isMyDispatch && !isPending,
          showAdminUpdate:  role == UserRole.admin || role == UserRole.doctor,
          onAccept:         () => onAccept(d),
          onReject:         () => onReject(d),
          onUpdateStatus:   (s) => onUpdateStatus(d.id, s),
        );
      },
    );
  }
}

// ── Fleet tab ──────────────────────────────────────────────────
class _FleetTab extends StatelessWidget {
  final List<AmbulanceResponse> ambulances;
  const _FleetTab({required this.ambulances});

  @override
  Widget build(BuildContext context) {
    if (ambulances.isEmpty) {
      return const EmptyState(
          message: 'No ambulances', icon: Icons.local_taxi_outlined);
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: ambulances.length,
      itemBuilder: (_, i) => _AmbulanceCard(ambulance: ambulances[i]),
    );
  }
}

// ── Dispatch card ──────────────────────────────────────────────
class _DispatchCard extends StatelessWidget {
  final EmergencyDispatchResponse dispatch;
  final String                    patientName;
  final bool                      showAcceptReject;
  final bool                      showStatusUpdate;
  final bool                      showAdminUpdate;
  final VoidCallback              onAccept;
  final VoidCallback              onReject;
  final void Function(String)     onUpdateStatus;

  const _DispatchCard({
    required this.dispatch, required this.patientName,
    required this.showAcceptReject, required this.showStatusUpdate,
    required this.showAdminUpdate,
    required this.onAccept, required this.onReject, required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    DateTime? date;
    try { date = DateTime.parse(dispatch.dispatchedAt).toLocal(); } catch (_) {}
    final dateStr = date != null
        ? '${date.day}/${date.month} '
          '${date.hour.toString().padLeft(2, '0')}:'
          '${date.minute.toString().padLeft(2, '0')}'
        : '—';

    BadgeType badgeType;
    switch (dispatch.status) {
      case 'OnTheWay':  badgeType = BadgeType.blue;   break;
      case 'Arrived':   badgeType = BadgeType.purple; break;
      case 'Resolved':  badgeType = BadgeType.green;  break;
      case 'Cancelled': badgeType = BadgeType.red;    break;
      default:          badgeType = BadgeType.amber;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(patientName,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700))),
          BadgeWidget(label: dispatch.status, type: badgeType),
        ]),
        const SizedBox(height: 6),
        Text('Dispatched: $dateStr',
            style: GoogleFonts.dmSans(fontSize: 12,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary)),
        if (dispatch.notes != null && dispatch.notes!.isNotEmpty)
          Text(dispatch.notes!,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextTertiary
                      : AppColors.textTertiary)),

        if (showAcceptReject) ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: ElevatedButton.icon(
              onPressed: onAccept,
              icon: const Icon(Icons.check_rounded, size: 16),
              label: const Text('Accept'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.badgeGreenTxt,
                  foregroundColor: Colors.white),
            )),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(
              onPressed: onReject,
              icon: const Icon(Icons.close_rounded, size: 16),
              label: const Text('Reject'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
                side: BorderSide(
                    color: isDark
                        ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
              ),
            )),
          ]),
        ],

        if (showStatusUpdate) ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            if (dispatch.status == 'OnTheWay')
              OutlinedButton(
                  onPressed: () => onUpdateStatus('Arrived'),
                  child: const Text('Mark Arrived')),
            if (dispatch.status == 'Arrived')
              ElevatedButton(
                  onPressed: () => onUpdateStatus('Resolved'),
                  child: const Text('Resolve')),
          ]),
        ],

        if (showAdminUpdate &&
            dispatch.status != 'Resolved' &&
            dispatch.status != 'Cancelled') ...[
          const SizedBox(height: 10),
          Wrap(spacing: 8, children: [
            if (dispatch.status == 'Pending')
              OutlinedButton(
                  onPressed: () => onUpdateStatus('Cancelled'),
                  child: const Text('Cancel')),
            if (dispatch.status == 'OnTheWay')
              OutlinedButton(
                  onPressed: () => onUpdateStatus('Arrived'),
                  child: const Text('Mark Arrived')),
            if (dispatch.status == 'Arrived')
              OutlinedButton(
                  onPressed: () => onUpdateStatus('Resolved'),
                  child: const Text('Resolve')),
          ]),
        ],
      ]),
    );
  }
}

// ── Ambulance card ─────────────────────────────────────────────
class _AmbulanceCard extends StatelessWidget {
  final AmbulanceResponse ambulance;
  const _AmbulanceCard({required this.ambulance});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    BadgeType type;
    switch (ambulance.availabilityStatus) {
      case 'Available': type = BadgeType.green;  break;
      case 'Busy':      type = BadgeType.red;    break;
      default:          type = BadgeType.amber;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.emergency_outlined, size: 20,
              color: isDark
                  ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ambulance.stationName,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(ambulance.driverName,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Text(ambulance.phone,
              style: GoogleFonts.dmSans(fontSize: 11.5,
                  color: isDark
                      ? AppColors.darkTextTertiary : AppColors.textTertiary)),
        ])),
        BadgeWidget(label: ambulance.availabilityStatus, type: type),
      ]),
    );
  }
}
