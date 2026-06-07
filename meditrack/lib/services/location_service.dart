import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';

// ════════════════════════════════════════════════════════════════
// LOCATION SERVICE
// - Requests GPS permission
// - Provides one-shot & stream position
// - Pushes patient location to server every 30s
// - Pushes ambulance location every 10s when on active dispatch
// ════════════════════════════════════════════════════════════════

class LocationService extends ChangeNotifier {
  Position? _lastPosition;
  Position? get lastPosition => _lastPosition;

  Timer? _patientTimer;
  Timer? _ambulanceTimer;

  // ── Permission ────────────────────────────────────────────────

  Future<bool> requestPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // ── Get current position ──────────────────────────────────────

  Future<Position?> getCurrentPosition() async {
    final granted = await requestPermission();
    if (!granted) return null;
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _lastPosition = pos;
      notifyListeners();
      return pos;
    } catch (_) {
      return null;
    }
  }

  // ── Patient: push location every 30s ─────────────────────────

  void startPatientTracking(int patientId) {
    _patientTimer?.cancel();
    _pushPatientLocation(patientId);
    _patientTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _pushPatientLocation(patientId);
    });
  }

  void stopPatientTracking() => _patientTimer?.cancel();

  Future<void> _pushPatientLocation(int patientId) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    await apiService.updatePatientLocation(
      patientId,
      UpdateLocationRequest(latitude: pos.latitude, longitude: pos.longitude),
    );
  }

  // ── Ambulance: push location every 10s while on dispatch ─────

  void startAmbulanceTracking(int ambulanceId) {
    _ambulanceTimer?.cancel();
    _pushAmbulanceLocation(ambulanceId);
    _ambulanceTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pushAmbulanceLocation(ambulanceId);
    });
  }

  void stopAmbulanceTracking() => _ambulanceTimer?.cancel();

  Future<void> _pushAmbulanceLocation(int ambulanceId) async {
    final pos = await getCurrentPosition();
    if (pos == null) return;
    await apiService.updateAmbulanceLocation(
      ambulanceId,
      UpdateLocationRequest(latitude: pos.latitude, longitude: pos.longitude),
    );
  }

  @override
  void dispose() {
    _patientTimer?.cancel();
    _ambulanceTimer?.cancel();
    super.dispose();
  }
}

// ── Singleton ─────────────────────────────────────────────────
final locationService = LocationService();
