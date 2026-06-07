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
// DISPATCH TRACKING PAGE — Doctor & Relative
// Shows live ambulance + patient pins on OpenStreetMap.
// Auto-refreshes every 10 seconds.
// ════════════════════════════════════════════════════════════════

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

  @override
  void initState() {
    super.initState();
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetch,
            tooltip: 'Refresh now',
          ),
        ],
      ),
      body: Column(children: [
        // ── Status bar ────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: Row(children: [
            BadgeWidget(
              label: widget.dispatch.status,
              type: _statusBadge(widget.dispatch.status),
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
        ),

        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: AlertWidget(message: _error!, isError: true),
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
