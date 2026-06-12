import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';

// ════════════════════════════════════════════════════════════════
// RATING SERVICE
// Ratings are persisted to the backend (POST /api/ratings).
// SharedPreferences is used as a local cache so UI is instantly
// responsive without waiting for the network on every rebuild.
//
// Cache key format:  ratings_<patientEmail>
//   → JSON map of  "doctor_<id>" / "lab_<id>"  →  double (1–5)
// ════════════════════════════════════════════════════════════════

class RatingService {
  RatingService._();
  static final RatingService instance = RatingService._();

  final Map<String, double> _cache = {};
  String? _loadedFor;

  String _cacheKey(String email)   => 'ratings_$email';
  String _doctorKey(int id)         => 'doctor_$id';
  String _labKey(int id)            => 'lab_$id';

  // ── Load local cache for a patient ───────────────────────────

  Future<void> load(String email) async {
    if (_loadedFor == email) return;
    _cache.clear();
    _loadedFor = email;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw   = prefs.getString(_cacheKey(email));
      if (raw != null) {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        map.forEach((k, v) => _cache[k] = (v as num).toDouble());
      }
    } catch (_) {}
  }

  // ── Getters ───────────────────────────────────────────────────

  double? getDoctorRating(int doctorId) => _cache[_doctorKey(doctorId)];
  double? getLabRating(int labId)       => _cache[_labKey(labId)];

  // ── Submit to backend + update local cache ────────────────────

  Future<void> rateDoctor(String email, int doctorId, double stars) async {
    await _submitToBackend(RatingRequest(stars: stars, doctorId: doctorId));
    await _saveLocal(email, _doctorKey(doctorId), stars);
  }

  Future<void> rateLab(String email, int labId, double stars) async {
    await _submitToBackend(RatingRequest(stars: stars, labId: labId));
    await _saveLocal(email, _labKey(labId), stars);
  }

  Future<void> _submitToBackend(RatingRequest request) async {
    try {
      await apiService.submitRating(request);
    } catch (_) {
      // Fail silently — local cache is still updated so UI stays consistent.
      // Next time the user rates, it will sync again.
    }
  }

  Future<void> _saveLocal(
      String email, String targetKey, double stars) async {
    _cache[targetKey] = stars;
    _loadedFor = email;
    try {
      final prefs = await SharedPreferences.getInstance();
      final map   = Map<String, dynamic>.from(
          jsonDecode(prefs.getString(_cacheKey(email)) ?? '{}') as Map);
      map[targetKey] = stars;
      await prefs.setString(_cacheKey(email), jsonEncode(map));
    } catch (_) {}
  }
}

final ratingService = RatingService.instance;
