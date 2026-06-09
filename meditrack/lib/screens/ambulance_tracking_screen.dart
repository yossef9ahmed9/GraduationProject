import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// AmbulanceTrackingScreen
//
// Shows a live map with:
//   • Blue pin  — patient's last known location
//   • Red pin   — ambulance's current location
//   • Polyline  — straight line between them
//
// Refreshes automatically every 10 seconds.
// Pull-to-refresh or the refresh FAB also works.
// ════════════════════════════════════════════════════════════════

class AmbulanceTrackingScreen extends StatefulWidget {
  final int     patientId;
  final String  patientName;
  final int?    dispatchId;   // if opened from an active dispatch
  final int?    ambulanceId;  // fallback if no dispatch

  const AmbulanceTrackingScreen({
    super.key,
    required this.patientId,
    required this.patientName,
    this.dispatchId,
    this.ambulanceId,
  });

  @override
  State<AmbulanceTrackingScreen> createState() =>
      _AmbulanceTrackingScreenState();
}

class _AmbulanceTrackingScreenState
    extends State<AmbulanceTrackingScreen> {
  final MapController _mapCtrl = MapController();
  Timer? _timer;

  PatientLocationResponse?   _patient;
  AmbulanceLocationResponse? _ambulance;
  bool   _loading = false;
  String? _error;

  static const _defaultCenter = LatLng(30.0444, 31.2357); // Cairo

  @override
  void initState() {
    super.initState();
    _refresh();
    // Auto-refresh every 10 seconds
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _refresh());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });

    try {
      // Patient location
      final pRes = await apiService.getPatientLocation(widget.patientId);

      // Ambulance location — prefer dispatch-specific endpoint
      ApiResult<AmbulanceLocationResponse>? aRes;
      if (widget.dispatchId != null) {
        aRes = await apiService.getDispatchAmbulanceLocation(widget.dispatchId!);
      } else if (widget.ambulanceId != null) {
        aRes = await apiService.getAmbulanceLocation(widget.ambulanceId!);
      }

      if (!mounted) return;
      setState(() {
        _loading = false;
        if (pRes.ok)        _patient   = pRes.data;
        if (aRes?.ok == true) _ambulance = aRes!.data;

        // If both have coords, fit the map to show both
        if (_patient?.latitude != null && _ambulance?.latitude != null) {
          _fitBounds();
        } else if (_patient?.latitude != null) {
          _mapCtrl.move(
            LatLng(_patient!.latitude!, _patient!.longitude!), 14);
        } else if (_ambulance?.latitude != null) {
          _mapCtrl.move(
            LatLng(_ambulance!.latitude!, _ambulance!.longitude!), 14);
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  void _fitBounds() {
    if (_patient?.latitude == null || _ambulance?.latitude == null) return;
    final pLat = _patient!.latitude!;
    final pLng = _patient!.longitude!;
    final aLat = _ambulance!.latitude!;
    final aLng = _ambulance!.longitude!;

    final bounds = LatLngBounds(
      LatLng(pLat < aLat ? pLat : aLat, pLng < aLng ? pLng : aLng),
      LatLng(pLat > aLat ? pLat : aLat, pLng > aLng ? pLng : aLng),
    );
    _mapCtrl.fitCamera(
      CameraFit.bounds(bounds: bounds, padding: const EdgeInsets.all(60)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final patientLatLng = _patient?.latitude != null
        ? LatLng(_patient!.latitude!, _patient!.longitude!)
        : null;
    final ambulanceLatLng = _ambulance?.latitude != null
        ? LatLng(_ambulance!.latitude!, _ambulance!.longitude!)
        : null;

    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tracking — ${widget.patientName}',
              style: GoogleFonts.dmSans(
                  fontSize: 15, fontWeight: FontWeight.w700)),
          Text('Auto-refreshes every 10 s',
              style: GoogleFonts.dmSans(fontSize: 11,
                  color: isDark
                      ? AppColors.darkTextSecondary
                      : AppColors.textSecondary)),
        ]),
        actions: [
          if (_loading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(
                  child: SizedBox(width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
      body: Column(children: [
        // Status bar
        if (_error != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: AlertWidget(message: _error!, isError: true),
          ),

        // Legend
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(children: [
            _LegendDot(color: Colors.blue,
                label: _patient?.patientName ?? widget.patientName),
            const SizedBox(width: 20),
            _LegendDot(color: Colors.red,
                label: _ambulance?.driverName ?? 'Ambulance'),
            const Spacer(),
            if (_ambulance?.distanceFromPatientKm != null)
              Text(
                '${_ambulance!.distanceFromPatientKm!.toStringAsFixed(1)} km away',
                style: GoogleFonts.dmSans(fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.darkAccent
                        : AppColors.accent),
              ),
          ]),
        ),

        // Map
        Expanded(
          child: FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: patientLatLng ?? ambulanceLatLng ?? _defaultCenter,
              initialZoom: (patientLatLng != null || ambulanceLatLng != null)
                  ? 13 : 10,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.meditrack',
              ),

              // Polyline between patient and ambulance
              if (patientLatLng != null && ambulanceLatLng != null)
                PolylineLayer<Object>(polylines: [
                  Polyline<Object>(
                    points: [patientLatLng, ambulanceLatLng],
                    color: Colors.blue.withValues(alpha: 0.5),
                    strokeWidth: 3,
                  ),
                ]),

              // Markers
              MarkerLayer(markers: [
                if (patientLatLng != null)
                  Marker(
                    point: patientLatLng,
                    width: 44, height: 54,
                    child: _MapPin(
                      color: Colors.blue,
                      icon: Icons.person_pin_rounded,
                      label: _patient?.patientName
                              ?.split(' ')
                              .first ??
                          '',
                    ),
                  ),
                if (ambulanceLatLng != null)
                  Marker(
                    point: ambulanceLatLng,
                    width: 44, height: 54,
                    child: _MapPin(
                      color: Colors.red,
                      icon: Icons.emergency_rounded,
                      label: '🚑',
                    ),
                  ),
              ]),
            ],
          ),
        ),

        // Info cards
        if (_patient != null || _ambulance != null)
          Container(
            color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(children: [
              if (_patient != null)
                _InfoTile(
                  icon: Icons.person_pin_rounded,
                  color: Colors.blue,
                  title: _patient!.patientName,
                  subtitle: _patient!.latitude != null
                      ? '${_patient!.latitude!.toStringAsFixed(4)}, '
                        '${_patient!.longitude!.toStringAsFixed(4)}'
                      : 'No location data',
                  badge: _patient!.isInEmergency ? '🚨 EMERGENCY' : null,
                ),
              if (_ambulance != null) ...[
                const SizedBox(height: 8),
                _InfoTile(
                  icon: Icons.emergency_rounded,
                  color: Colors.red,
                  title: _ambulance!.driverName,
                  subtitle: _ambulance!.latitude != null
                      ? '${_ambulance!.latitude!.toStringAsFixed(4)}, '
                        '${_ambulance!.longitude!.toStringAsFixed(4)}'
                      : 'No location data',
                  badge: _ambulance!.availabilityStatus,
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}

// ── Map pin widget ─────────────────────────────────────────────

class _MapPin extends StatelessWidget {
  final Color    color;
  final IconData icon;
  final String   label;
  const _MapPin({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (label.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w700)),
        ),
      Icon(icon, color: color, size: 32),
    ],
  );
}

// ── Legend dot ─────────────────────────────────────────────────

class _LegendDot extends StatelessWidget {
  final Color  color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 10, height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 5),
      Text(label,
          style: GoogleFonts.dmSans(fontSize: 12,
              color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary)),
    ]);
  }
}

// ── Info tile ──────────────────────────────────────────────────

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color    color;
  final String   title;
  final String   subtitle;
  final String?  badge;
  const _InfoTile({
    required this.icon, required this.color,
    required this.title, required this.subtitle, this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(children: [
      Icon(icon, color: color, size: 20),
      const SizedBox(width: 10),
      Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600)),
        Text(subtitle,
            style: GoogleFonts.dmMono(fontSize: 11,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.textSecondary)),
      ])),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: badge!.contains('EMERGENCY')
                ? (isDark ? AppColors.darkBadgeRedBg : AppColors.badgeRedBg)
                : (isDark ? AppColors.darkBadgeGreenBg : AppColors.badgeGreenBg),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(badge!,
              style: GoogleFonts.dmSans(fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: badge!.contains('EMERGENCY')
                      ? (isDark ? AppColors.darkBadgeRedTxt : AppColors.badgeRedTxt)
                      : (isDark ? AppColors.darkBadgeGreenTxt : AppColors.badgeGreenTxt))),
        ),
    ]);
  }
}
