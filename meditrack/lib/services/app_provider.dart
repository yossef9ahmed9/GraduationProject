import 'package:flutter/material.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';

// ════════════════════════════════════════════════════════════════
// APP PROVIDER — all loaded data + refresh logic
// ════════════════════════════════════════════════════════════════

class AppProvider extends ChangeNotifier {
  List<PatientResponse> patients = [];
  List<DoctorResponse> doctors = [];
  List<LabResponse> labs = [];
  List<FollowUpResponse> followUps = [];
  List<VitalSignsResponse> vitals = [];
  List<SensorResponse> sensors = [];
  List<MedicalTestResponse> tests = [];
  List<EmergencyDispatchResponse> dispatches = [];
  List<LabAppointmentResponse> labAppointments = [];
  List<AmbulanceResponse> ambulances = [];

  // ── Patient-role own vitals (loaded separately since getAllVitals is admin-only)
  // Kept fresh by HomeScreen polling every 20 s.
  List<VitalSignsResponse> myVitals = [];

  bool isLoading = false;
  bool isOnline = true;
  String? loadError;

  // ── Load all data in parallel ─────────────────────────────────

  /// [patientEmail] — pass the logged-in patient's email when role == patient
  /// so myVitals gets refreshed in the same call (no extra trip needed).
  Future<void> loadAll(UserRole role, {String? patientEmail}) async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      // Patients: Doctor gets only their own patients, Relative gets only linked patients
      final pRes = await (role == UserRole.doctor
          ? apiService.getDoctorPatients()
          : role == UserRole.relative
              ? apiService.getRelativePatients()
              : apiService.getPatients());
      if (pRes.ok) patients = pRes.data ?? [];

      // Build follow-ups call based on role
      Future<ApiResult<List<FollowUpResponse>>> followUpsCall;
      if (role == UserRole.doctor) {
        followUpsCall = apiService.getDoctorFollowUps();
      } else if (role == UserRole.patient) {
        followUpsCall = apiService.getMyFollowUps();
      } else if (role == UserRole.relative) {
        final linked = patients.isNotEmpty ? patients.first : null;
        if (linked != null) {
          followUpsCall = apiService.getPatientFollowUps(linked.id);
        } else {
          followUpsCall = Future.value(ApiResult.success([], 200));
        }
      } else {
        followUpsCall = apiService.getAllFollowUps();
      }

      final emergencyDataCall = (role == UserRole.ambulance ||
              role == UserRole.doctor  ||
              role == UserRole.relative)
          ? apiService.getAllDispatches()
          : Future.value(ApiResult.success(<EmergencyDispatchResponse>[], 200));

      // Patient, Relative, and Ambulance all need the fleet list
      final ambulancesCall = (role == UserRole.ambulance ||
              role == UserRole.patient ||
              role == UserRole.relative)
          ? apiService.getAmbulances()
          : Future.value(ApiResult.success(<AmbulanceResponse>[], 200));

      final results = await Future.wait([
        apiService.getDoctors(),
        apiService.getLabs(),
        followUpsCall,
        apiService.getAllVitals(),
        apiService.getSensors(),
        apiService.getMedicalTests(),
        emergencyDataCall,
        apiService.getLabAppointments(),
        ambulancesCall,
      ]);

      final docsRes  = results[0] as ApiResult<List<DoctorResponse>>;
      final labsRes  = results[1] as ApiResult<List<LabResponse>>;
      final fupRes   = results[2] as ApiResult<List<FollowUpResponse>>;
      final vitRes   = results[3] as ApiResult<List<VitalSignsResponse>>;
      final senRes   = results[4] as ApiResult<List<SensorResponse>>;
      final tstRes   = results[5] as ApiResult<List<MedicalTestResponse>>;
      final dispRes  = results[6] as ApiResult<List<EmergencyDispatchResponse>>;
      final appRes   = results[7] as ApiResult<List<LabAppointmentResponse>>;
      final ambRes   = results[8] as ApiResult<List<AmbulanceResponse>>;

      if (docsRes.ok)  doctors   = docsRes.data  ?? [];
      if (labsRes.ok)  labs      = labsRes.data  ?? [];
      if (fupRes.ok)   followUps = fupRes.data   ?? [];
      if (vitRes.ok)   vitals    = vitRes.data   ?? [];
      if (senRes.ok)   sensors   = senRes.data   ?? [];
      if (tstRes.ok)   tests     = tstRes.data   ?? [];
      if (dispRes.ok)  dispatches = dispRes.data ?? [];
      if (appRes.ok)   labAppointments = appRes.data ?? [];
      if (ambRes.ok)   ambulances = ambRes.data ?? [];

      if (!ambRes.ok) {
        loadError = ambRes.error ?? 'Failed to load ambulances.';
      } else if (!dispRes.ok) {
        loadError = dispRes.error ?? 'Failed to load dispatches.';
      }

      // For patient role: also refresh myVitals so emergency vignette/dialog
      // react immediately on any page refresh — not just in VitalsPage.
      if (role == UserRole.patient && patientEmail != null) {
        final me = patientByEmail(patientEmail);
        if (me != null) {
          final vRes = await apiService.getVitalsByPatient(me.id);
          if (vRes.ok) myVitals = vRes.data ?? [];
        }
      }
    } catch (e) {
      loadError = e.toString();
    }

    isLoading = false;
    notifyListeners();
  }

  // ── Role-scoped refreshes ─────────────────────────────────────

  Future<void> refreshFollowUps(UserRole role, String userEmail) async {
    ApiResult<List<FollowUpResponse>> res;
    if (role == UserRole.doctor) {
      res = await apiService.getDoctorFollowUps();
    } else if (role == UserRole.patient) {
      res = await apiService.getMyFollowUps();
    } else if (role == UserRole.relative) {
      final mine = patients.firstWhere(
        (p) => p.email == userEmail,
        orElse: () => patients.isNotEmpty ? patients.first : PatientResponse(id: 0, name: '', gender: '', phone: '', email: '', address: '', medicalRecord: ''),
      );
      if (mine.id > 0) {
        res = await apiService.getPatientFollowUps(mine.id);
      } else {
        return;
      }
    } else {
      res = await apiService.getAllFollowUps();
    }
    if (res.ok) {
      followUps = res.data ?? [];
      notifyListeners();
    }
  }

  Future<void> refreshTests() async {
    final res = await apiService.getMedicalTests();
    if (res.ok) { tests = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshLabAppointments() async {
    final res = await apiService.getLabAppointments();
    if (res.ok) { labAppointments = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshAmbulances() async {
    final res = await apiService.getAmbulances();
    if (res.ok) {
      ambulances = res.data ?? [];
      loadError = null;
    } else {
      loadError = res.error ?? 'Failed to load ambulances.';
    }
    notifyListeners();
  }

  Future<void> refreshPatients(UserRole role) async {
    final res = role == UserRole.doctor
        ? await apiService.getDoctorPatients()
        : role == UserRole.relative
            ? await apiService.getRelativePatients()
            : await apiService.getPatients();
    if (res.ok) { patients = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshDoctors() async {
    final res = await apiService.getDoctors();
    if (res.ok) { doctors = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshLabs() async {
    final res = await apiService.getLabs();
    if (res.ok) { labs = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshSensors() async {
    final res = await apiService.getSensors();
    if (res.ok) { sensors = res.data ?? []; notifyListeners(); }
  }

  Future<void> refreshVitals(int? patientId) async {
    final res = patientId != null
        ? await apiService.getVitalsByPatient(patientId)
        : await apiService.getAllVitals();
    if (res.ok) { vitals = res.data ?? []; notifyListeners(); }
  }

  /// Refresh this patient's own vitals (used by patient role polling).
  Future<void> refreshMyVitals(int patientId) async {
    final res = await apiService.getVitalsByPatient(patientId);
    if (res.ok) { myVitals = res.data ?? []; notifyListeners(); }
  }

  /// Update myVitals directly from already-fetched data (no extra API call).
  /// Called by VitalsPage after it loads vitals so the HomeScreen reacts instantly.
  void updateMyVitals(List<VitalSignsResponse> data) {
    myVitals = data;
    notifyListeners();
  }

  /// Update shared vitals for a specific patient (used by doctor/admin VitalsPage).
  /// Replaces that patient's entries in the main vitals list so emergencyVitals
  /// reflects the latest readings immediately without waiting for polling.
  void updateVitalsForPatient(int patientId, List<VitalSignsResponse> data) {
    vitals = [
      ...vitals.where((v) => v.patientId != patientId),
      ...data,
    ];
    notifyListeners();
  }

  Future<void> refreshDispatches({UserRole? role, String? myEmail}) async {
    final res = await apiService.getAllDispatches(pageSize: 100);
    if (res.ok) {
      dispatches = res.data ?? [];
      loadError = null;
    } else {
      loadError = res.error ?? 'Failed to load dispatches.';
    }
    notifyListeners();
  }

  // ── Dispatch status update ─────────────────────────────────────

  Future<bool> updateDispatchStatus(int dispatchId, String status) async {
    final res = await apiService.updateDispatchStatus(dispatchId, status);
    if (res.ok) {
      // Optimistically update local state
      dispatches = dispatches.map((d) {
        if (d.id == dispatchId) {
          return EmergencyDispatchResponse(
            id:               d.id,
            dispatchedAt:     d.dispatchedAt,
            arrivedAt:        status == 'Arrived'  ? DateTime.now().toIso8601String() : d.arrivedAt,
            resolvedAt:       (status == 'Resolved' || status == 'Cancelled')
                                  ? DateTime.now().toIso8601String() : d.resolvedAt,
            status:           status,
            patientLatitude:  d.patientLatitude,
            patientLongitude: d.patientLongitude,
            notes:            d.notes,
            patientId:        d.patientId,
            ambulanceId:      d.ambulanceId,
          );
        }
        return d;
      }).toList();
      notifyListeners();
    }
    return res.ok;
  }

  // ── Helper getters ────────────────────────────────────────────

  Future<bool> updateAmbulanceAvailability(int ambulanceId, String status) async {
    final res = await apiService.updateAmbulanceAvailability(ambulanceId, status);
    if (res.ok) {
      ambulances = ambulances.map((a) {
        if (a.id == ambulanceId) {
          return AmbulanceResponse(
            id: a.id,
            email: a.email,
            driverName: a.driverName,
            driverPhone: a.driverPhone,
            licensePlate: a.licensePlate,
            phone: a.phone,
            availabilityStatus: status,
            serviceArea: a.serviceArea,
            latitude: a.latitude,
            longitude: a.longitude,
            lastLocationUpdate: a.lastLocationUpdate,
            activeDispatchCount: a.activeDispatchCount,
          );
        }
        return a;
      }).toList();
      notifyListeners();
    }
    return res.ok;
  }

  PatientResponse? patientByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try { return patients.firstWhere((p) => p.email.trim().toLowerCase() == normalized); }
    catch (_) { return null; }
  }

  DoctorResponse? doctorByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try { return doctors.firstWhere((d) => d.email.trim().toLowerCase() == normalized); }
    catch (_) { return null; }
  }

  LabResponse? labByEmail(String email) {
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;
    try { return labs.firstWhere((l) => l.email.trim().toLowerCase() == normalized); }
    catch (_) { return null; }
  }

  List<VitalSignsResponse> vitalsForPatient(int patientId) =>
      [...vitals, ...myVitals]
          .where((v) => v.patientId == patientId)
          .toList()
        ..sort((a, b) =>
            DateTime.parse(b.timeStamp).compareTo(DateTime.parse(a.timeStamp)));

  VitalSignsResponse? latestVitalForPatient(int patientId) {
    final list = vitalsForPatient(patientId);
    return list.isNotEmpty ? list.first : null;
  }

  bool get hasEmergency =>
      emergencyVitals.isNotEmpty ||
      dispatches.any((d) => d.isActive);

  /// Only the LATEST reading per patient determines emergency state.
  /// Old emergency readings don't count once a normal reading arrives.
  List<VitalSignsResponse> get emergencyVitals {
    final all = [...vitals, ...myVitals];
    if (all.isEmpty) return [];

    // Group by patientId → keep only the most recent reading per patient
    final Map<int, VitalSignsResponse> latestPerPatient = {};
    for (final v in all) {
      final existing = latestPerPatient[v.patientId];
      if (existing == null) {
        latestPerPatient[v.patientId] = v;
      } else {
        // Compare timestamps — keep the newer one
        final existingTs = DateTime.tryParse(existing.timeStamp) ?? DateTime(0);
        final thisTs     = DateTime.tryParse(v.timeStamp) ?? DateTime(0);
        if (thisTs.isAfter(existingTs)) {
          latestPerPatient[v.patientId] = v;
        }
      }
    }

    // Return only patients whose LATEST reading is in emergency
    return latestPerPatient.values
        .where((v) => v.emergencyStatus || v.heartRate > 100)
        .toList();
  }

  List<EmergencyDispatchResponse> get activeDispatches =>
      dispatches.where((d) => d.isActive).toList();

  /// For Relative role — only dispatches where patientId is in their linked patients list
  List<EmergencyDispatchResponse> dispatchesForMyPatients() {
    final myIds = patients.map((p) => p.id).toSet();
    return dispatches.where((d) => myIds.contains(d.patientId)).toList();
  }

  List<EmergencyDispatchResponse> dispatchesForPatient(int patientId) =>
      dispatches.where((d) => d.patientId == patientId).toList();

  List<EmergencyDispatchResponse> dispatchesForAmbulance(int ambulanceId) =>
      dispatches.where((d) => d.ambulanceId == ambulanceId).toList();

  List<MedicalTestResponse> testsForPatient(int patientId) =>
      tests.where((t) => t.patientId == patientId).toList();

  List<LabAppointmentResponse> labAppointmentsForPatient(int patientId) =>
      labAppointments.where((a) => a.patientId == patientId).toList();

  List<FollowUpResponse> followUpsForPatient(int patientId) =>
      followUps.where((f) => f.patientId == patientId).toList();

  List<SensorResponse> sensorsForPatient(int patientId) =>
      sensors.where((s) => s.patientId == patientId).toList();

  String? doctorName(int doctorId) {
    try { return doctors.firstWhere((d) => d.id == doctorId).name; }
    catch (_) { return null; }
  }

  String? patientName(int patientId) {
    try { return patients.firstWhere((p) => p.id == patientId).name; }
    catch (_) { return null; }
  }

  String? labName(int labId) {
    try { return labs.firstWhere((l) => l.id == labId).name; }
    catch (_) { return null; }
  }

  void clear() {
    patients = []; doctors = []; labs = [];
    followUps = []; vitals = []; myVitals = []; sensors = []; tests = [];
    dispatches = []; labAppointments = []; ambulances = [];
    isLoading = false;
    loadError = null;
    notifyListeners();
  }
}
