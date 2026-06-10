import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';
import 'package:meditrack/screens/chat_screen.dart';

// ════════════════════════════════════════════════════════════════
// DISPATCH TRACKING PAGE — Doctor & Relative
// Shows live ambulance + patient pins on OpenStreetMap.
// Auto-refreshes every 10 seconds.
// ════════════════════════════════════════════════════════════════

import 'package:meditrack/screens/chat_screen.dart';

class DispatchTrackingPage extends StatefulWidget {
  final EmergencyDispatchResponse dispatch;
  final String patientName;

  const DispatchTrackingPage({
    super.key,
    required this.dispatch,
    required this.patientName,
  });

  @override
  State<DispatchTrackingPage> createState() => _DispatchTrackingPageState();
}

class _DispatchTrackingPageState extends State<DispatchTrackingPage> {
  final MapController _mapCtrl = MapController();
  AmbulanceLocationResponse? _ambLoc;
  Timer? _refreshTimer;
  bool _loading = true;
  String? _error;
  String _currentStatus = '';
  bool   _justArrived   = false;

  @override
  void initState() {
    super.initState();
    _currentStatus = widget.dispatch.status;
    _fetch();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _fetch();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetch() async {
    final res =
        await apiService.getDispatchAmbulanceLocation(widget.dispatch.id);
    if (!mounted) return;
    if (res.ok && res.data != null) {
      setState(() {
        _ambLoc  = res.data;
        _loading = false;
        _error   = null;
      });
      // Auto-Arrived: distance ≤ 0.1 km and still OnTheWay
      final dist = _ambLoc?.distanceFromPatientKm;
      if (dist != null && dist <= 0.1 && _currentStatus == 'OnTheWay') {
        setState(() {
          _currentStatus = 'Arrived';
          _justArrived   = true;
        });
        _refreshTimer?.cancel(); // ambulance is here, stop polling
      }
      // move camera to ambulance if position available
      if (_ambLoc?.latitude != null && _ambLoc?.longitude != null) {
        _mapCtrl.move(
          LatLng(_ambLoc!.latitude!, _ambLoc!.longitude!),
          _mapCtrl.camera.zoom,
        );
      }
    } else {
      setState(() { _loading = false; _error = res.error; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final patLat   = widget.dispatch.patientLatitude;
    final patLng   = widget.dispatch.patientLongitude;
    final ambLat   = _ambLoc?.latitude;
    final ambLng   = _ambLoc?.longitude;
    final distKm   = _ambLoc?.distanceFromPatientKm;

    final markers = <Marker>[
      // Patient — red pin
      Marker(
        point: LatLng(patLat, patLng),
        width: 40, height: 40,
        child: const Icon(Icons.person_pin_circle,
            color: Colors.red, size: 40),
      ),
      // Ambulance — blue pin
      if (ambLat != null && ambLng != null)
        Marker(
          point: LatLng(ambLat, ambLng),
          width: 40, height: 40,
          child: const Icon(Icons.emergency,
              color: Colors.blue, size: 40),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Tracking — ${widget.patientName}',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        actions: const [],
      ),
      body: Column(children: [
        // ── Status bar ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Row 1: status + distance
            Row(children: [
              BadgeWidget(
                label: _justArrived ? 'Arrived ✓' : _currentStatus,
                type: _justArrived
                    ? BadgeType.green
                    : _statusBadge(_currentStatus),
              ),
              const SizedBox(width: 12),
              if (distKm != null) ...[
                Icon(Icons.directions_car_outlined, size: 16,
                    color: isDark ? AppColors.darkAccent : AppColors.accent),
                const SizedBox(width: 4),
                Text('${distKm.toStringAsFixed(1)} km away',
                    style: GoogleFonts.dmSans(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ] else
                Text('Locating ambulance…',
                    style: GoogleFonts.dmSans(fontSize: 13,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary)),
              const Spacer(),
              Text('auto • 10s',
                  style: GoogleFonts.dmSans(fontSize: 11,
                      color: isDark
                          ? AppColors.darkTextTertiary
                          : AppColors.textTertiary)),
            ]),

            // Row 2: ambulance driver info + Chat button
            if (_ambLoc != null && _ambLoc!.driverName.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),
              Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.emergency_outlined, size: 18,
                      color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
                ),
                const SizedBox(width: 10),
                Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_ambLoc!.driverName,
                      style: GoogleFonts.dmSans(
                          fontSize: 13, fontWeight: FontWeight.w700)),
                  Text(
                    _ambLoc!.driverPhone.isNotEmpty
                        ? _ambLoc!.driverPhone
                        : _ambLoc!.phone,
                    style: GoogleFonts.dmSans(fontSize: 12,
                        color: isDark
                            ? AppColors.darkTextSecondary
                            : AppColors.textSecondary),
                  ),
                ])),
                if (_ambLoc!.email.isNotEmpty)
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherEmail: _ambLoc!.email,
                          otherName:  _ambLoc!.driverName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 14),
                    label: Text('Chat', style: GoogleFonts.dmSans(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ]),
            ],
          ]),
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: AlertWidget(message: _error!, isError: true),
          ),

        // ── Arrived banner ────────────────────────────────────
        if (_justArrived)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFFE8F5E9),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text('🚑 Ambulance has arrived at patient location',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF2E7D32))),
              ),
            ]),
          ),

        // ── Map ───────────────────────────────────────────────
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : FlutterMap(
                  mapController: _mapCtrl,
                  options: MapOptions(
                    initialCenter: LatLng(patLat, patLng),
                    initialZoom: 14,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.meditrack',
                    ),
                    MarkerLayer(markers: markers),
                  ],
                ),
        ),

        // ── Legend ────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.person_pin_circle, color: Colors.red, size: 18),
            const SizedBox(width: 4),
            Text('Patient', style: GoogleFonts.dmSans(fontSize: 12)),
            const SizedBox(width: 20),
            const Icon(Icons.emergency, color: Colors.blue, size: 18),
            const SizedBox(width: 4),
            Text('Ambulance', style: GoogleFonts.dmSans(fontSize: 12)),
          ]),
        ),

        // ── Ambulance profile card ─────────────────────────────
        if (_ambLoc != null) ...[
          const Divider(height: 1),
          Container(
            color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header
              Row(children: [
                Container(
                  width: 42, height: 42,
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkBadgeBlueBg : AppColors.badgeBlueBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.emergency_outlined, size: 22,
                      color: isDark ? AppColors.darkBadgeBlueTxt : AppColors.badgeBlueTxt),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(_ambLoc!.driverName,
                      style: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700)),
                  Text('Ambulance Driver',
                      style: GoogleFonts.dmSans(fontSize: 12,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary)),
                ])),
                BadgeWidget(
                  label: _ambLoc!.availabilityStatus,
                  type: _ambLoc!.availabilityStatus == 'Busy'
                      ? BadgeType.red
                      : BadgeType.green,
                ),
              ]),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Info rows
              if (_ambLoc!.driverPhone.isNotEmpty)
                _InfoRow(
                  icon: Icons.phone_outlined,
                  label: 'Driver Phone',
                  value: _ambLoc!.driverPhone,
                  isDark: isDark,
                ),
              if (_ambLoc!.phone.isNotEmpty)
                _InfoRow(
                  icon: Icons.local_phone_outlined,
                  label: 'Unit Phone',
                  value: _ambLoc!.phone,
                  isDark: isDark,
                ),
              if (_ambLoc!.email.isNotEmpty)
                _InfoRow(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: _ambLoc!.email,
                  isDark: isDark,
                ),
              const SizedBox(height: 12),

              // Chat button
              if (_ambLoc!.email.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          otherEmail: _ambLoc!.email,
                          otherName:  _ambLoc!.driverName,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                    label: Text('Chat with Ambulance Driver',
                        style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? AppColors.darkAccent : AppColors.accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ]),
    );
  }

  BadgeType _statusBadge(String status) {
    switch (status) {
      case 'OnTheWay':  return BadgeType.blue;
      case 'Arrived':   return BadgeType.purple;
      case 'Resolved':  return BadgeType.green;
      case 'Cancelled': return BadgeType.red;
      default:          return BadgeType.amber;
    }
  }
}

// ── Info row helper ───────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String   label;
  final String   value;
  final bool     isDark;
  const _InfoRow({required this.icon, required this.label,
      required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 16,
          color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary),
      const SizedBox(width: 10),
      SizedBox(width: 90,
          child: Text(label,
              style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary))),
      Expanded(child: Text(value,
          style: GoogleFonts.dmSans(fontSize: 13,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary))),
    ]),
  );
}
