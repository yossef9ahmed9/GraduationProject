import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/location_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:meditrack/widgets/common_widgets.dart';

// ════════════════════════════════════════════════════════════════
// AMBULANCE NAVIGATION PAGE
// Shows patient pin + ambulance's own live pin on OpenStreetMap.
// Ambulance driver uses this to navigate to the patient.
// Pushes location to server every 10 seconds via LocationService.
// ════════════════════════════════════════════════════════════════

class AmbulanceNavigationPage extends StatefulWidget {
  final EmergencyDispatchResponse dispatch;
  final String patientName;
  final int ambulanceId;

  const AmbulanceNavigationPage({
    super.key,
    required this.dispatch,
    required this.patientName,
    required this.ambulanceId,
  });

  @override
  State<AmbulanceNavigationPage> createState() =>
      _AmbulanceNavigationPageState();
}

class _AmbulanceNavigationPageState extends State<AmbulanceNavigationPage> {
  final MapController _mapCtrl = MapController();
  Position? _myPos;
  Timer? _posTimer;
  bool _loading = true;
  bool _autoArrived = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    locationService.startAmbulanceTracking(widget.ambulanceId);
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() { _myPos = pos; _loading = false; });

    _posTimer = Timer.periodic(const Duration(seconds: 5), (_) async {
      final p = await locationService.getCurrentPosition();
      if (!mounted || p == null) return;
      setState(() => _myPos = p);
      _checkArrival(p);
    });
  }

  void _checkArrival(Position pos) {
    if (_autoArrived) return;
    if (widget.dispatch.status != 'OnTheWay') return;
    final metres = Geolocator.distanceBetween(
      pos.latitude, pos.longitude,
      widget.dispatch.patientLatitude,
      widget.dispatch.patientLongitude,
    );
    if (metres <= 100) {
      setState(() => _autoArrived = true);
      // Backend auto-sets Arrived via location push — no extra call needed
    }
  }

  @override
  void dispose() {
    _posTimer?.cancel();
    super.dispose();
  }

  double? get _distanceKm {
    if (_myPos == null) return null;
    final metres = Geolocator.distanceBetween(
      _myPos!.latitude, _myPos!.longitude,
      widget.dispatch.patientLatitude,
      widget.dispatch.patientLongitude,
    );
    return metres / 1000;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final patLat = widget.dispatch.patientLatitude;
    final patLng = widget.dispatch.patientLongitude;

    final markers = <Marker>[
      // Patient — red
      Marker(
        point: LatLng(patLat, patLng),
        width: 40, height: 40,
        child: const Icon(Icons.person_pin_circle,
            color: Colors.red, size: 40),
      ),
      // Me — blue
      if (_myPos != null)
        Marker(
          point: LatLng(_myPos!.latitude, _myPos!.longitude),
          width: 40, height: 40,
          child: const Icon(Icons.emergency,
              color: Colors.blue, size: 40),
        ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Navigate to ${widget.patientName}',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
      ),
      body: Column(children: [
        // ── Arrived banner ────────────────────────────────────
        if (_autoArrived)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: const Color(0xFFE8F5E9),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF2E7D32), size: 18),
              const SizedBox(width: 8),
              Text('You have arrived at the patient',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E7D32))),
            ]),
          ),

        // ── Info bar ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: isDark ? AppColors.darkBgCard : AppColors.bgCard,
          child: Row(children: [
            const Icon(Icons.person_pin_circle_outlined, size: 18,
                color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text(widget.patientName,
                style: GoogleFonts.dmSans(
                    fontSize: 13, fontWeight: FontWeight.w600))),
            if (_distanceKm != null)
              Text('${_distanceKm!.toStringAsFixed(1)} km',
                  style: GoogleFonts.dmSans(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: isDark
                          ? AppColors.darkAccent
                          : AppColors.accent))
            else
              Text('Getting location…',
                  style: GoogleFonts.dmSans(fontSize: 12,
                      color: isDark
                          ? AppColors.darkTextSecondary
                          : AppColors.textSecondary)),
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
            Text('You', style: GoogleFonts.dmSans(fontSize: 12)),
          ]),
        ),
      ]),
    );
  }
}
