import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/services/app_provider.dart';
import 'package:meditrack/services/auth_provider.dart';
import 'package:meditrack/services/notification_provider.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/widgets/map_location_picker.dart';
import 'package:meditrack/screens/pages/dispatch_tracking_page.dart';
import 'package:meditrack/screens/pages/ambulance_navigation_page.dart';
import 'package:meditrack/screens/chat_screen.dart';

class AmbulancesPage extends StatefulWidget {
  const AmbulancesPage({super.key});
  @override
  State<AmbulancesPage> createState() => _AmbulancesPageState();
}

class _AmbulancesPageState extends State<AmbulancesPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  bool _busy = false;
  String? _msg;
  bool _isError = false;
  Timer? _autoRefresh;

  @override
  void initState() {
    super.initState();
    final role = context.read<AuthProvider>().role;
    _tabs = TabController(length: role == UserRole.ambulance ? 3 : 2, vsync: this);
    // Always do an initial refresh when the page opens
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
    // Auto-refresh for non-ambulance roles so they see status changes
    if (role != UserRole.ambulance) {
      _autoRefresh = Timer.periodic(const Duration(seconds: 10), (_) {
        if (mounted) _refresh();
      });
    } else {
      // Ambulance: also poll every 15s so new Pending dispatches appear without FCM delay
      _autoRefresh = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _autoRefresh?.cancel();
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final app  = context.read<AppProvider>();
    final auth = context.read<AuthProvider>();
    await Future.wait([
      app.refreshDispatches(role: auth.role),
      app.refreshAmbulances(),
      app.refreshPatients(auth.role), // keeps isInEmergency flag fresh
    ]);
    if (mounted) setState(() {});
  }

  // DND toggle — Busy ↔ Available (shown in status bar for ambulance)
  Future<void> _toggleDnd(AmbulanceResponse a) async {
    final newStatus = a.availabilityStatus == 'Busy' ? 'Available' : 'Busy';
    setState(() { _busy = true; _msg = null; });
    final app = context.read<AppProvider>();
    final ok  = await app.updateAmbulanceAvailability(a.id, newStatus);
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !ok;
      _msg = ok
          ? (newStatus == 'Busy'
          ? 'Do Not Disturb enabled — you appear Busy.'
          : 'Do Not Disturb disabled — you appear Available.')
          : 'Failed to update status.';
    });
  }

  Future<void> _accept(EmergencyDispatchResponse d) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.acceptDispatch(d.id);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _msg = res.ok ? 'Accepted. On the way!' : (res.error ?? 'Failed.');
    });
  }

  Future<void> _reject(EmergencyDispatchResponse d) async {
    setState(() { _busy = true; _msg = null; });
    final res = await apiService.rejectDispatch(d.id);
    await _refresh();
    if (!mounted) return;
    setState(() {
      _busy = false; _isError = !res.ok;
      _msg = res.ok ? 'Rejected.' : (res.error ?? 'Failed.');
    });
  }

  Future<void> _updateStatus(int id, String status) async {
    setState(() { _busy = true; _msg = null; });
    final ok = await context.read<AppProvider>().updateDispatchStatus(id, status);
    await _refresh();
    if (!mounted) return;
    setState(() { _busy = false; _isError = !ok; _msg = ok ? 'Updated.' : 'Failed.'; });
  }

  @override
  Widget build(BuildContext context) {
    final app    = context.watch<AppProvider>();
    final auth   = context.watch<AuthProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final role   = auth.role;
    final myEmail = auth.user?.email.toLowerCase() ?? '';

    final myAmbulance = role == UserRole.ambulance
        ? app.ambulances
        .where((a) => a.email.toLowerCase() == myEmail)
        .firstOrNull
        : null;

    return RefreshIndicator(
      onRefresh: _refresh,
      child: Column(children: [
        if (role == UserRole.ambulance)
          myAmbulance != null
              ? _DndBar(
            ambulance: myAmbulance,
            busy: _busy,
            onToggleDnd: () => _toggleDnd(myAmbulance),
          )
              : Padding(
            padding: const EdgeInsets.all(16),
            child: AlertWidget(
                message: 'Ambulance record not found. Contact admin.',
                isError: true),
          ),

        if (_msg != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: AlertWidget(message: _msg!, isError: _isError),
          ),

        // ── Tabs ──────────────────────────────────────────────
        Container(
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: TabBar(
            controller: _tabs,
            labelStyle: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600),
            tabs: [
              Tab(text: role == UserRole.ambulance ? 'My Dispatches' : 'Dispatches'),
              const Tab(text: 'Fleet'),
              if (role == UserRole.ambulance) const Tab(text: 'Messages'),
            ],
          ),
        ),

        Expanded(child: TabBarView(
          controller: _tabs,
          children: [
            _DispatchTab(
              dispatches: role == UserRole.ambulance
                  ? app.dispatches
                  .where((d) => d.ambulanceId == myAmbulance?.id)
                  .toList()
                  : role == UserRole.relative
                  ? app.dispatchesForMyPatients()
                  : app.dispatches,
              role: role,
              myAmbulanceId: myAmbulance?.id,
              busy: _busy,
              onAccept: _accept, onReject: _reject,
              onUpdateStatus: _updateStatus,
              app: app,
            ),
            // Fleet: NotAvailable hidden from non-admins
            _FleetTab(
              ambulances: role == UserRole.admin
                  ? app.ambulances
                  : app.ambulances
                  .where((a) =>
              a.availabilityStatus == 'Available' ||
                  a.availabilityStatus == 'Busy')
                  .toList(),
              role: role,
              myEmail: myEmail,
            ),
            if (role == UserRole.ambulance)
              _MessagesTab(myEmail: myEmail),
          ],
        )),
      ]),
    );
  }
}

// ── DND bar — only shown for Ambulance role ───────────────────
// Sign In / Sign Out buttons REMOVED — those are in Profile page.
// Only DND toggle is here.

class _DndBar extends StatelessWidget {
  final AmbulanceResponse ambulance;
  final bool busy;
  final VoidCallback onToggleDnd;
  const _DndBar(
      {required this.ambulance, required this.busy, required this.onToggleDnd});

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final status  = ambulance.availabilityStatus;
    final isAvail = status == 'Available';
    final isBusy  = status == 'Busy';
    final isOut   = status == 'NotAvailable';

    BadgeType bt;
    if (isAvail)     bt = BadgeType.green;
    else if (isBusy) bt = BadgeType.red;
    else             bt = BadgeType.amber;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isDark ? AppColors.darkBorderColor : AppColors.borderColor),
      ),
      child: Row(children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(ambulance.driverName,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(ambulance.serviceArea ?? ambulance.licensePlate,
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
        ])),
        BadgeWidget(label: status, type: bt),
        const SizedBox(width: 12),
        // DND button — disabled if NotAvailable (signed out)
        Column(children: [
          Text('Do Not Disturb', style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
          Switch(
            value: isBusy,
            onChanged: busy || isOut ? null : (_) => onToggleDnd(),
            activeThumbColor: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt,
            activeTrackColor: isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg,
            inactiveThumbColor: isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt,
            inactiveTrackColor: isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg,
          ),
        ]),
      ]),
    );
  }
}

// ── Dispatch tab ──────────────────────────────────────────────

class _DispatchTab extends StatelessWidget {
  final List<EmergencyDispatchResponse> dispatches;
  final UserRole role; final int? myAmbulanceId; final bool busy;
  final void Function(EmergencyDispatchResponse) onAccept, onReject;
  final void Function(int, String) onUpdateStatus;
  final AppProvider app;

  const _DispatchTab({
    required this.dispatches, required this.role, this.myAmbulanceId,
    required this.busy, required this.onAccept, required this.onReject,
    required this.onUpdateStatus, required this.app,
  });

  @override
  Widget build(BuildContext context) {
    if (dispatches.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const EmptyState(
                message: 'No dispatches', icon: Icons.emergency_outlined),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: dispatches.length,
      itemBuilder: (_, i) {
        final d = dispatches[i];
        return _DispatchCard(
          dispatch: d,
          patientName:
          app.patientName(d.patientId) ?? 'Patient #${d.patientId}',
          showAcceptReject: role == UserRole.ambulance &&
              d.ambulanceId == myAmbulanceId &&
              d.status == 'Pending' &&
              !busy,
          showProgress: role == UserRole.ambulance &&
              d.ambulanceId == myAmbulanceId &&
              d.status != 'Pending',
          showAdminControls:
          role == UserRole.admin || role == UserRole.doctor,
          showTrack: (role == UserRole.doctor || role == UserRole.relative) &&
              (d.status == 'OnTheWay' || d.status == 'Arrived'),
          showNavigate: role == UserRole.ambulance &&
              d.ambulanceId == myAmbulanceId &&
              (d.status == 'OnTheWay' || d.status == 'Arrived'),
          myAmbulanceId: myAmbulanceId,
          onAccept: () => onAccept(d),
          onReject: () => onReject(d),
          onUpdateStatus: (s) => onUpdateStatus(d.id, s),
        );
      },
    );
  }
}

// ── Fleet tab ─────────────────────────────────────────────────

class _FleetTab extends StatelessWidget {
  final List<AmbulanceResponse> ambulances;
  final UserRole role;
  final String myEmail;
  const _FleetTab({required this.ambulances, required this.role, required this.myEmail});

  @override
  Widget build(BuildContext context) {
    if (ambulances.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: const EmptyState(
                message: 'No active ambulances', icon: Icons.emergency_outlined),
          ),
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: ambulances.length,
      itemBuilder: (_, i) {
        final a = ambulances[i];
        final canSet = role == UserRole.admin ||
            a.email.toLowerCase() == myEmail.toLowerCase();
        return _AmbCard(ambulance: a, canSetLocation: canSet);
      },
    );
  }
}

// ── Dispatch card ─────────────────────────────────────────────

class _DispatchCard extends StatelessWidget {
  final EmergencyDispatchResponse dispatch;
  final String patientName;
  final bool showAcceptReject, showProgress, showAdminControls;
  final bool showTrack, showNavigate;
  final int? myAmbulanceId;
  final VoidCallback onAccept, onReject;
  final void Function(String) onUpdateStatus;

  const _DispatchCard({
    required this.dispatch, required this.patientName,
    required this.showAcceptReject, required this.showProgress,
    required this.showAdminControls,
    this.showTrack = false, this.showNavigate = false,
    this.myAmbulanceId,
    required this.onAccept, required this.onReject,
    required this.onUpdateStatus,
  });

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final notifPr = context.watch<NotificationProvider>();
    final appProv = context.watch<AppProvider>();

    // Patient is stable if:
    // 1. NotificationProvider received a normal_vitals FCM, OR
    // 2. Patient's isInEmergency flag is false (backend cleared it when vitals normalized)
    final patient = appProv.patients
        .where((p) => p.id == dispatch.patientId)
        .firstOrNull;
    final isVitalsNormal = patient != null && !patient.isInEmergency;

    final patientStable = showProgress &&
        (dispatch.status == 'OnTheWay' || dispatch.status == 'Arrived') &&
        (notifPr.isPatientStable(dispatch.patientId) || isVitalsNormal);
    final date   = DateTime.tryParse(dispatch.dispatchedAt)?.toLocal();
    final dateStr = date != null
        ? '${date.day}/${date.month} '
        '${date.hour.toString().padLeft(2,'0')}:'
        '${date.minute.toString().padLeft(2,'0')}'
        : '—';

    BadgeType bt;
    switch (dispatch.status) {
      case 'OnTheWay':  bt = BadgeType.blue;   break;
      case 'Arrived':   bt = BadgeType.purple; break;
      case 'Resolved':  bt = BadgeType.green;  break;
      case 'Cancelled': bt = BadgeType.red;    break;
      default:          bt = BadgeType.amber;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(patientName,
              style: GoogleFonts.dmSans(
                  fontSize: 14, fontWeight: FontWeight.w700))),
          BadgeWidget(label: dispatch.status, type: bt),
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
                    ? AppColors.darkBadgeRedTxt
                    : AppColors.badgeRedTxt,
                side: BorderSide(
                    color: isDark
                        ? AppColors.darkBadgeRedTxt
                        : AppColors.badgeRedTxt),
              ),
            )),
          ]),
        ],

        if (showProgress) ...[
          const SizedBox(height: 10),

          // ── Patient Stable banner + Cancel option ─────────────
          if (patientStable) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF66BB6A)),
              ),
              child: Row(children: [
                const Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2E7D32), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('Patient vitals back to normal',
                      style: GoogleFonts.dmSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF2E7D32))),
                ),
              ]),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  context.read<NotificationProvider>()
                      .clearPatientStable(dispatch.patientId);
                  onUpdateStatus('Cancelled');
                },
                icon: const Icon(Icons.cancel_outlined, size: 16),
                label: Text('Cancel Transport — Patient Stable',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2E7D32),
                  side: const BorderSide(color: Color(0xFF66BB6A)),
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],

          if (dispatch.status == 'OnTheWay')
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => onUpdateStatus('Arrived'),
                child: const Text('Mark Arrived'),
              ),
            ),
          if (dispatch.status == 'Arrived')
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => onUpdateStatus('Resolved'),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: Text('Complete Dispatch',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.badgeGreenTxt,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
        ],

        if (showAdminControls &&
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

        // ── Track button (doctor / relative) ─────────────────
        if (showTrack) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DispatchTrackingPage(
                    dispatch: dispatch,
                    patientName: patientName,
                  ),
                ),
              ),
              icon: const Icon(Icons.map_outlined, size: 16),
              label: const Text('Track Ambulance'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.badgeBlueTxt,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],

        // ── Navigate button (ambulance) ───────────────────────
        if (showNavigate) ...[
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AmbulanceNavigationPage(
                    dispatch: dispatch,
                    patientName: patientName,
                    ambulanceId: myAmbulanceId!,
                  ),
                ),
              ),
              icon: const Icon(Icons.navigation_outlined, size: 16),
              label: const Text('Navigate to Patient'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.badgeGreenTxt,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

// ── Messages tab — shows all conversations for the ambulance ──

class _MessagesTab extends StatelessWidget {
  final String myEmail;
  const _MessagesTab({required this.myEmail});

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final notifPr  = context.watch<NotificationProvider>();

    // Get unique senders who sent messages to this ambulance
    final messageNotifs = notifPr.all
        .where((n) => n.type == NotifType.message && n.chatEmail != null)
        .toList();

    // Deduplicate by chatEmail
    final seen = <String>{};
    final conversations = messageNotifs
        .where((n) => seen.add(n.chatEmail!))
        .toList();

    if (conversations.isEmpty) {
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: constraints.maxHeight,
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.chat_bubble_outline_rounded, size: 48,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary),
                const SizedBox(height: 12),
                Text('No messages yet',
                    style: GoogleFonts.dmSans(fontSize: 15,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                const SizedBox(height: 6),
                Text('Relatives and doctors can chat with you\nthrough the tracking screen.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
              ]),
            ),
          ),
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final notif = conversations[i];
        final unread = notifPr.all
            .where((n) => n.chatEmail == notif.chatEmail && !n.isRead)
            .length;
        return AppCard(
          padding: const EdgeInsets.all(14),
          child: InkWell(
            onTap: () {
              notifPr.dismissMessagesFrom(notif.chatEmail!);
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ChatScreen(
                  otherEmail: notif.chatEmail!,
                  otherName:  notif.chatName ?? notif.chatEmail!,
                ),
              ));
            },
            child: Row(children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
                child: Text(
                  (notif.chatName ?? notif.chatEmail!)[0].toUpperCase(),
                  style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700,
                      color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(notif.chatName ?? notif.chatEmail!,
                    style: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600)),
                Text(notif.body, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.dmSans(fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
              ])),
              if (unread > 0)
                Container(
                  width: 22, height: 22,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                    shape: BoxShape.circle,
                  ),
                  child: Center(child: Text('$unread',
                      style: GoogleFonts.dmSans(fontSize: 11,
                          fontWeight: FontWeight.w700, color: Colors.white))),
                ),
            ]),
          ),
        );
      },
    );
  }
}

// ── Ambulance card ────────────────────────────────────────────

class _AmbCard extends StatefulWidget {
  final AmbulanceResponse ambulance;
  final bool canSetLocation;
  const _AmbCard({required this.ambulance, required this.canSetLocation});
  @override
  State<_AmbCard> createState() => _AmbCardState();
}

class _AmbCardState extends State<_AmbCard> {
  bool _saving = false;

  // Returns: 'gps' | 'manual' | 'unknown'
  String get _locationStatus {
    final src = widget.ambulance.locationSource;
    if (widget.ambulance.latitude == null) return 'unknown';
    if (src == 'Manual') return 'manual';
    if (src == 'GPS') {
      final raw = widget.ambulance.lastLocationUpdate;
      if (raw == null) return 'unknown';
      DateTime? last;
      try {
        last = DateTime.parse(raw);
        // Backend returns UTC without 'Z' suffix — force UTC interpretation
        if (!raw.contains('Z') && !raw.contains('+')) {
          last = DateTime.utc(last.year, last.month, last.day,
              last.hour, last.minute, last.second, last.millisecond);
        }
      } catch (_) {
        return 'unknown';
      }
      final ageMinutes = DateTime.now().toUtc().difference(last).inMinutes;
      return ageMinutes < 5 ? 'gps' : 'unknown';
    }
    return 'unknown';
  }

  String _timeSince(String? iso) {
    if (iso == null) return '';
    final dt = DateTime.tryParse(iso)?.toLocal();
    if (dt == null) return '';
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }

  Future<void> _pickLocation() async {
    final result = await showModalBottomSheet<LatLng>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MapLocationPicker(
        title:      'Set ${widget.ambulance.driverName}\'s Location',
        initialLat: widget.ambulance.latitude,
        initialLng: widget.ambulance.longitude,
      ),
    );
    if (result == null || !mounted) return;
    setState(() => _saving = true);
    await apiService.setAmbulanceLocationManual(
        widget.ambulance.id, result.latitude, result.longitude);
    if (mounted) {
      await context.read<AppProvider>().refreshAmbulances();
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final locStatus = _locationStatus;

    BadgeType bt;
    switch (widget.ambulance.availabilityStatus) {
      case 'Available': bt = BadgeType.green; break;
      case 'Busy':      bt = BadgeType.red;   break;
      default:          bt = BadgeType.amber;
    }

    return AppCard(
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

        // ── Main row ──────────────────────────────────────────
        Row(children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
                color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.emergency_outlined, size: 20,
                color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(widget.ambulance.driverName,
                style: GoogleFonts.dmSans(
                    fontSize: 14, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(widget.ambulance.serviceArea ?? widget.ambulance.licensePlate,
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
            Text(widget.ambulance.phone,
                style: GoogleFonts.dmSans(fontSize: 11.5,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary)),
          ])),
          BadgeWidget(label: widget.ambulance.availabilityStatus, type: bt),
        ]),

        const SizedBox(height: 8),

        // ── Location status row ────────────────────────────────
        if (locStatus == 'gps') ...[
          // 🟢 GPS Active
          Row(children: [
            const Icon(Icons.gps_fixed_rounded, size: 14, color: Colors.green),
            const SizedBox(width: 6),
            Text('GPS Active — ${_timeSince(widget.ambulance.lastLocationUpdate)}',
                style: GoogleFonts.dmSans(fontSize: 12, color: Colors.green,
                    fontWeight: FontWeight.w500)),
          ]),
        ] else if (locStatus == 'manual') ...[
          // 🟡 Manual Location
          Row(children: [
            Icon(Icons.edit_location_alt_rounded, size: 14,
                color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt),
            const SizedBox(width: 6),
            Expanded(child: Text(
              'Manual Location — ${_timeSince(widget.ambulance.lastLocationUpdate)}',
              style: GoogleFonts.dmSans(fontSize: 12,
                  color: isDark ? AppColors.darkBadgeAmberTxt : AppColors.badgeAmberTxt,
                  fontWeight: FontWeight.w500),
            )),
            if (widget.canSetLocation)
              GestureDetector(
                onTap: _saving ? null : _pickLocation,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkAccent : AppColors.accent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: _saving
                      ? const SizedBox(width: 10, height: 10,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('Update', style: GoogleFonts.dmSans(
                          fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                ),
              ),
          ]),
        ] else ...[
          // 🔴 Unknown / No GPS
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                    .withValues(alpha: 0.3)),
            ),
            child: Row(children: [
              Icon(Icons.gps_off_rounded, size: 14,
                  color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
              const SizedBox(width: 8),
              Expanded(child: Text(
                widget.ambulance.latitude == null
                    ? 'GPS Disabled / Permission Missing'
                    : 'GPS signal lost — location outdated',
                style: GoogleFonts.dmSans(fontSize: 12,
                    color: isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt),
              )),
              if (widget.canSetLocation) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _saving ? null : _pickLocation,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkAccent : AppColors.accent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: _saving
                        ? const SizedBox(width: 10, height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text('Set on Map', style: GoogleFonts.dmSans(
                            fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
                  ),
                ),
              ],
            ]),
          ),
        ],

      ]),
    );
  }
}