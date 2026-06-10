import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';

// ════════════════════════════════════════════════════════════════
// LOCATION SERVICE
// - Permission requested once, result cached
// - GPS with fallback to last known position
// - Patient: pushes every 10s
// - Ambulance: pushes every 10s with source:'GPS'
// ════════════════════════════════════════════════════════════════

class LocationService extends ChangeNotifier {
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  Timer? _patientTimer;
  Timer? _ambulanceTimer;
  bool   _permissionGranted = false;

  // ── Permission — request once, cache result ───────────────────

  Future<bool> ensurePermission() async {
    if (_permissionGranted) return true;
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    _permissionGranted = perm == LocationPermission.whileInUse ||
        perm == LocationPermission.always;
    return _permissionGranted;
  }

  // ── Get position — high accuracy with fallback ────────────────

  Future<Position?> getCurrentPosition() async {
    final ok = await ensurePermission();
    if (!ok) return _lastPosition; // use cached if no permission

    // Try high accuracy with 5s timeout
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosition = pos;
      notifyListeners();
      return pos;
    } catch (_) {}

    // Fallback 1: last known position from device
    try {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) {
        _lastPosition = last;
        notifyListeners();
        return last;
      }
    } catch (_) {}

    // Fallback 2: cached in memory
    return _lastPosition;
  }

  // ── Patient: push every 10s ───────────────────────────────────

  Future<void> startPatientTracking(int patientId) async {
    _patientTimer?.cancel();
    await _pushPatientLocation(patientId); // immediate
    _patientTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pushPatientLocation(patientId);
    });
  }

  void stopPatientTracking() {
    _patientTimer?.cancel();
    _patientTimer = null;
  }

  Future<void> _pushPatientLocation(int patientId) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    await apiService.updatePatientLocation(
      patientId,
      UpdateLocationRequest(latitude: pos.latitude, longitude: pos.longitude),
    );
  }

  // ── Ambulance: push every 10s with source:'GPS' ───────────────

  Future<void> startAmbulanceTracking(int ambulanceId) async {
    _ambulanceTimer?.cancel();
    await _pushAmbulanceLocation(ambulanceId); // immediate
    _ambulanceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pushAmbulanceLocation(ambulanceId);
    });
  }

  void stopAmbulanceTracking() {
    _ambulanceTimer?.cancel();
    _ambulanceTimer = null;
  }

  Future<void> _pushAmbulanceLocation(int ambulanceId) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    await apiService.updateAmbulanceLocation(
      ambulanceId,
      UpdateLocationRequest(latitude: pos.latitude, longitude: pos.longitude),
      source: 'GPS',
    );
  }

  // ── Auto-detect arrival (within 100m of patient) ──────────────

  Future<void> checkArrivalIfOnDispatch(
      int ambulanceId, List<EmergencyDispatchResponse> dispatches,
      Future<void> Function(int id, String status) updateStatus) async {
    final dispatch = dispatches
        .where((d) => d.ambulanceId == ambulanceId && d.status == 'OnTheWay')
        .firstOrNull;
    if (dispatch == null) return;

    final pos = _lastPosition;
    if (pos == null) return;

    final dist = _distanceMeters(
      pos.latitude, pos.longitude,
      dispatch.patientLatitude, dispatch.patientLongitude,
    );

    if (dist <= 100) {
      await updateStatus(dispatch.id, 'Arrived');
    }
  }

  double _distanceMeters(
      double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) *
            sin(dLng / 2) * sin(dLng / 2);
    return R * 2 * atan2(sqrt(a), sqrt(1 - a));
  }

  double _rad(double deg) => deg * pi / 180;

  @override
  void dispose() {
    _patientTimer?.cancel();
    _ambulanceTimer?.cancel();
    super.dispose();
  }
}

// ── Singleton ─────────────────────────────────────────────────
final locationService = LocationService();
