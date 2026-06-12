import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:meditrack/models/models.dart';

// ════════════════════════════════════════════════════════════════
// API SERVICE — singleton HTTP client
// Fully aligned with all backend controllers.
// Change _base to your backend URL.
// ════════════════════════════════════════════════════════════════

const String _base = 'http://192.168.1.6:5098/api';
// const String _base = 'http://localhost:5000/api'; // iOS simulator / web

/// The root server URL (no /api suffix). Used for building static asset URLs.
String get serverBase => _base.replaceAll('/api', '');

class ApiService {
  static const Duration _requestTimeout = Duration(seconds: 15);

  String? _token;

  void setToken(String? token) => _token = token;

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  // ── Generic helpers ───────────────────────────────────────────

  Future<ApiResult<T>> _get<T>(
    String path,
    T Function(dynamic) parse,
  ) async {
    try {
      final res = await http
          .get(Uri.parse('$_base$path'), headers: _headers)
          .timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(parse(jsonDecode(res.body)), res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<T>> _post<T>(
    String path,
    Map<String, dynamic> body,
    T Function(dynamic) parse,
  ) async {
    try {
      final res = await http.post(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(parse(jsonDecode(res.body)), res.statusCode);
      }
      return ApiResult.failure(
        _errorMsg(res),
        res.statusCode,
        fieldErrors: _fieldErrors(res),
      );
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<bool>> _put(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<T>> _putWithResponse<T>(
    String path,
    Map<String, dynamic> body,
    T Function(dynamic) parse,
  ) async {
    try {
      final res = await http.put(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(
          res.body.isNotEmpty ? parse(jsonDecode(res.body)) : parse({}),
          res.statusCode,
        );
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<bool>> _patch(
    String path,
    Map<String, dynamic> body,
  ) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base$path'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<bool>> _delete(String path) async {
    try {
      final res = await http.delete(
        Uri.parse('$_base$path'),
        headers: _headers,
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  String _errorMsg(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      // FluentValidation / ASP.NET ModelState returns { "errors": { "Field": ["msg"] } }
      if (j is Map<String, dynamic> && j.containsKey('errors')) {
        final errors = j['errors'];
        if (errors is Map) {
          final messages = errors.values
              .expand((v) => v is List ? v.map((e) => e.toString()) : [v.toString()])
              .toList();
          if (messages.isNotEmpty) return messages.join('\n');
        }
      }
      return j['message'] as String? ??
          j['title'] as String? ??
          j['error'] as String? ??
          'Error ${res.statusCode}';
    } catch (_) {
      return 'Error ${res.statusCode}';
    }
  }

  /// Parses FluentValidation field-level errors from a 400 response.
  /// Returns a map of { fieldName (lowercased) → first error message }.
  Map<String, String> _fieldErrors(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map<String, dynamic> && j.containsKey('errors')) {
        final errors = j['errors'];
        if (errors is Map) {
          return {
            for (final entry in errors.entries)
              entry.key.toLowerCase(): entry.value is List
                  ? (entry.value as List).first.toString()
                  : entry.value.toString(),
          };
        }
      }
    } catch (_) {}
    return {};
  }

  // ── Helper: parse backend paginated list ──────────────────────
  // Backend returns a PagedList object: { items, pageNumber, pageSize, totalCount, totalPages }
  // Most existing calls expect a flat List<T>; this helper extracts items from
  // either a paged wrapper or a raw array so both formats are handled gracefully.
  List<T> _parseList<T>(dynamic json, T Function(Map<String, dynamic>) fromJson) {
    if (json is List) {
      return json.map((e) => fromJson(e as Map<String, dynamic>)).toList();
    }
    if (json is Map<String, dynamic> && json.containsKey('items')) {
      return (json['items'] as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  String _queryParams(Map<String, Object> values) => values.entries
      .map((e) => '${Uri.encodeQueryComponent(e.key)}=${Uri.encodeQueryComponent('${e.value}')}')
      .join('&');

  // ════════════════════════════════════════════════════════════════
  // AUTH  — /api/auth
  // ════════════════════════════════════════════════════════════════

  Future<ApiResult<AuthResponse>> login(String email, String password) =>
      _post('/auth/login', {'email': email, 'password': password},
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> refreshToken(String token) =>
      _post('/auth/refresh', {'refreshToken': token},
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> registerPatient(Map<String, dynamic> body) =>
      _post('/auth/register/patient', body,
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> registerDoctor(Map<String, dynamic> body) =>
      _post('/auth/register/doctor', body,
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> registerLab(Map<String, dynamic> body) =>
      _post('/auth/register/lab', body,
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> registerRelative(Map<String, dynamic> body) =>
      _post('/auth/register/relative', body,
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<AuthResponse>> registerAmbulance(Map<String, dynamic> body) =>
      _post('/auth/register/ambulance', body,
          (j) => AuthResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<bool>> forgotPassword(String email) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/auth/forgot-password'),
        headers: _headers,
        body: jsonEncode({'email': email}),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  Future<ApiResult<bool>> resetPassword(Map<String, dynamic> body) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/auth/reset-password'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PATIENTS  — /api/patients
  // ════════════════════════════════════════════════════════════════

  /// GET /api/patients?pageNumber=&pageSize=
  Future<ApiResult<List<PatientResponse>>> getPatients({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/patients?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, PatientResponse.fromJson),
      );

  /// GET /api/patients/doctor?pageNumber=&pageSize=
  /// Returns only the patients linked to the logged-in doctor via follow-ups.
  Future<ApiResult<List<PatientResponse>>> getDoctorPatients({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/patients/doctor?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, PatientResponse.fromJson),
      );

  /// GET /api/patients/relative — patients approved-linked to the logged-in relative
  Future<ApiResult<List<PatientResponse>>> getRelativePatients({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/patients/relative?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, PatientResponse.fromJson),
      );

  /// GET /api/patients/{id}
  Future<ApiResult<PatientResponse>> getPatient(int id) =>
      _get('/patients/$id',
          (j) => PatientResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/patients
  Future<ApiResult<PatientResponse>> createPatient(
          Map<String, dynamic> body) =>
      _post('/patients', body,
          (j) => PatientResponse.fromJson(j as Map<String, dynamic>));

  /// PUT /api/patients/{id}
  Future<ApiResult<bool>> updatePatient(
          int id, Map<String, dynamic> body) =>
      _put('/patients/$id', body);

  /// DELETE /api/patients/{id}
  Future<ApiResult<bool>> deletePatient(int id) =>
      _delete('/patients/$id');

  /// PUT /api/patients/{id}/bloodtype
  Future<ApiResult<bool>> updateBloodType(int id, String bloodType) =>
      _put('/patients/$id/bloodtype', {'bloodType': bloodType});

  // ════════════════════════════════════════════════════════════════
  // DOCTORS  — /api/doctors
  // ════════════════════════════════════════════════════════════════

  /// GET /api/doctors?pageNumber=&pageSize=
  Future<ApiResult<List<DoctorResponse>>> getDoctors({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/doctors?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, DoctorResponse.fromJson),
      );

  /// GET /api/doctors/{id}
  Future<ApiResult<DoctorResponse>> getDoctor(int id) =>
      _get('/doctors/$id',
          (j) => DoctorResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/doctors
  Future<ApiResult<DoctorResponse>> createDoctor(
          Map<String, dynamic> body) =>
      _post('/doctors', body,
          (j) => DoctorResponse.fromJson(j as Map<String, dynamic>));

  /// PUT /api/doctors/{id}
  Future<ApiResult<bool>> updateDoctor(int id, Map<String, dynamic> body) =>
      _put('/doctors/$id', body);

  /// DELETE /api/doctors/{id}
  Future<ApiResult<bool>> deleteDoctor(int id) =>
      _delete('/doctors/$id');

  // ════════════════════════════════════════════════════════════════
  // LABS  — /api/labs
  // ════════════════════════════════════════════════════════════════

  /// GET /api/labs?pageNumber=&pageSize=
  Future<ApiResult<List<LabResponse>>> getLabs({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/labs?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, LabResponse.fromJson),
      );

  /// GET /api/labs/{id}
  Future<ApiResult<LabResponse>> getLab(int id) =>
      _get('/labs/$id',
          (j) => LabResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/labs
  Future<ApiResult<LabResponse>> createLab(Map<String, dynamic> body) =>
      _post('/labs', body,
          (j) => LabResponse.fromJson(j as Map<String, dynamic>));

  /// PUT /api/labs/{id}
  Future<ApiResult<bool>> updateLab(int id, Map<String, dynamic> body) =>
      _put('/labs/$id', body);

  /// DELETE /api/labs/{id}
  Future<ApiResult<bool>> deleteLab(int id) =>
      _delete('/labs/$id');

  // ═══════════════════════════════════════════════════════════════════
  // LAB APPOINTMENTS — /api/labappointments
  // ═══════════════════════════════════════════════════════════════════

  Future<ApiResult<List<LabAppointmentResponse>>> getLabAppointments({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/labappointments?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, LabAppointmentResponse.fromJson),
      );

  Future<ApiResult<List<LabAppointmentResponse>>> getLabAppointmentsByPatient(
    int patientId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/labappointments/patient/$patientId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, LabAppointmentResponse.fromJson),
      );

  Future<ApiResult<List<LabAppointmentResponse>>> getLabAppointmentsByLab(
    int labId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/labappointments/lab/$labId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, LabAppointmentResponse.fromJson),
      );

  Future<ApiResult<LabAppointmentResponse>> createLabAppointment(
          LabAppointmentRequest req) =>
      _post('/labappointments', req.toJson(),
          (j) => LabAppointmentResponse.fromJson(j as Map<String, dynamic>));

  Future<ApiResult<bool>> updateLabAppointmentStatus(
          int id, String status) =>
      _patch('/labappointments/$id/status', {'status': status});

  Future<ApiResult<List<MedicalTestResponse>>> completeLabAppointment(
    int id,
    CompleteLabAppointmentRequest req,
  ) =>
      _post(
        '/labappointments/$id/complete',
        req.toJson(),
        (j) => _parseList(j, MedicalTestResponse.fromJson),
      );

  // ════════════════════════════════════════════════════════════════
  // FOLLOW-UPS  — /api/followups
  // ════════════════════════════════════════════════════════════════

  /// GET /api/followups?pageNumber=&pageSize=
  Future<ApiResult<List<FollowUpResponse>>> getAllFollowUps({
    int pageNumber = 1,
    int pageSize = 100,
    int? patientId,
    int? doctorId,
    String? severity,
    DateTime? from,
    DateTime? to,
  }) =>
      _get(
        '/followups?${_queryParams({
          'pageNumber': pageNumber,
          'pageSize': pageSize,
          if (patientId != null) 'patientId': patientId,
          if (doctorId != null) 'doctorId': doctorId,
          if (severity != null && severity.isNotEmpty) 'severity': severity,
          if (from != null) 'from': from.toIso8601String(),
          if (to != null) 'to': to.toIso8601String(),
        })}',
        (j) => _parseList(j, FollowUpResponse.fromJson),
      );

  /// GET /api/followups/{id}
  Future<ApiResult<FollowUpResponse>> getFollowUp(int id) =>
      _get('/followups/$id',
          (j) => FollowUpResponse.fromJson(j as Map<String, dynamic>));

  /// GET /api/followups/doctor  (uses JWT to find doctor)
  Future<ApiResult<List<FollowUpResponse>>> getDoctorFollowUps({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/followups/doctor?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, FollowUpResponse.fromJson),
      );

  /// GET /api/followups/patient  (uses JWT to find patient)
  Future<ApiResult<List<FollowUpResponse>>> getMyFollowUps({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/followups/patient?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, FollowUpResponse.fromJson),
      );

  /// GET /api/followups/doctor/{doctorId}
  Future<ApiResult<List<FollowUpResponse>>> getFollowUpsByDoctor(
    int doctorId, {
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/followups/doctor/$doctorId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, FollowUpResponse.fromJson),
      );

  /// GET /api/followups/patient/{patientId}
  Future<ApiResult<List<FollowUpResponse>>> getPatientFollowUps(
    int patientId, {
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/followups/patient/$patientId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, FollowUpResponse.fromJson),
      );

  /// POST /api/followups
  Future<ApiResult<FollowUpResponse>> addFollowUp(FollowUpRequest req) =>
      _post('/followups', req.toJson(),
          (j) => FollowUpResponse.fromJson(j as Map<String, dynamic>));

  /// PUT /api/followups/{id}
  Future<ApiResult<bool>> updateFollowUp(
          int id, Map<String, dynamic> body) =>
      _put('/followups/$id', body);

  /// DELETE /api/followups/{id}
  Future<ApiResult<bool>> deleteFollowUp(int id) =>
      _delete('/followups/$id');

  /// PUT /api/followups/{id}/approve  [Doctor]
  Future<ApiResult<bool>> approveFollowUp(int id) =>
      _put('/followups/$id/approve', {});

  /// PUT /api/followups/{id}/reject   [Doctor]
  Future<ApiResult<bool>> rejectFollowUp(int id) =>
      _put('/followups/$id/reject', {});

  /// PUT /api/followups/{id}/cancel   [Patient]
  Future<ApiResult<bool>> cancelFollowUp(int id) =>
      _put('/followups/$id/cancel', {});

  /// PUT /api/followups/{id}/prescription  [Doctor]
  Future<ApiResult<bool>> updatePrescription(
      int id, String treatmentPlan, String notes) =>
      _put('/followups/$id/prescription',
          {'treatmentPlan': treatmentPlan, 'notes': notes});

  // ════════════════════════════════════════════════════════════════
  // VITAL SIGNS  — /api/vitalsigns
  // ════════════════════════════════════════════════════════════════

  /// GET /api/vitalsigns?pageNumber=&pageSize=
  Future<ApiResult<List<VitalSignsResponse>>> getAllVitals({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/vitalsigns?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, VitalSignsResponse.fromJson),
      );

  /// GET /api/vitalsigns/patient/{patientId}?pageNumber=&pageSize=
  Future<ApiResult<List<VitalSignsResponse>>> getVitalsByPatient(
    int patientId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/vitalsigns/patient/$patientId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, VitalSignsResponse.fromJson),
      );

  /// GET /api/vitalsigns/patient/{patientId}/latest
  Future<ApiResult<VitalSignsResponse>> getLatestVitalByPatient(
          int patientId) =>
      _get(
        '/vitalsigns/patient/$patientId/latest',
        (j) => VitalSignsResponse.fromJson(j as Map<String, dynamic>),
      );

  /// POST /api/vitalsigns  [Patient role only]
  Future<ApiResult<VitalSignsResponse>> addVitals(VitalSignsRequest req) =>
      _post('/vitalsigns', req.toJson(),
          (j) => VitalSignsResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/vitalsigns/{id}/check-emergency
  /// Manually re-evaluates a saved reading and triggers dispatch if critical.
  Future<ApiResult<EmergencyDispatchResponse?>> checkEmergency(int vitalId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/vitalsigns/$vitalId/check-emergency'),
        headers: _headers,
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        if (res.body.isEmpty || res.body == 'null') {
          return ApiResult.success(null, res.statusCode);
        }
        return ApiResult.success(
          EmergencyDispatchResponse.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>),
          res.statusCode,
        );
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // PATIENT FILE  — /api/patient-file  &  /api/medical-record
  // ════════════════════════════════════════════════════════════════

  /// GET /api/patient-file/{patientId}
  /// Returns vitals, record history, prescriptions, and lab tests in one call.
  Future<ApiResult<Map<String, dynamic>>> getPatientFile(int patientId) =>
      _get('/patient-file/$patientId', (j) => j as Map<String, dynamic>);

  /// GET /api/medical-record/{patientId}/history
  Future<ApiResult<List<dynamic>>> getMedicalRecordHistory(int patientId) =>
      _get('/medical-record/$patientId/history', (j) => j as List<dynamic>);

  /// PUT /api/medical-record/{patientId}
  /// Doctor / Patient can update the medical record.
  Future<ApiResult<bool>> updateMedicalRecord(
    int patientId, {
    String? medicalRecord,
    String? chronicDiseases,
    String? allergies,
    String? bloodType,
  }) async {
    final body = <String, dynamic>{
      if (medicalRecord   != null) 'medicalRecord':   medicalRecord,
      if (chronicDiseases != null) 'chronicDiseases': chronicDiseases,
      if (allergies       != null) 'allergies':       allergies,
      if (bloodType       != null) 'bloodType':       bloodType,
    };
    try {
      final res = await http.put(
        Uri.parse('$_base/medical-record/$patientId'),
        headers: _headers,
        body: jsonEncode(body),
      ).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // SENSORS  — /api/sensors
  // ════════════════════════════════════════════════════════════════

  /// GET /api/sensors?pageNumber=&pageSize=
  Future<ApiResult<List<SensorResponse>>> getSensors({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/sensors?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, SensorResponse.fromJson),
      );

  /// GET /api/sensors/{id}
  Future<ApiResult<SensorResponse>> getSensor(int id) =>
      _get('/sensors/$id',
          (j) => SensorResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/sensors
  Future<ApiResult<SensorResponse>> createSensor(SensorRequest req) =>
      _post('/sensors', req.toJson(),
          (j) => SensorResponse.fromJson(j as Map<String, dynamic>));

  /// DELETE /api/sensors/{id}
  Future<ApiResult<bool>> deleteSensor(int id) =>
      _delete('/sensors/$id');

  // ════════════════════════════════════════════════════════════════
  // MEDICAL TESTS  — /api/medicaltests
  // ════════════════════════════════════════════════════════════════

  /// GET /api/medicaltests?pageNumber=&pageSize=
  Future<ApiResult<List<MedicalTestResponse>>> getMedicalTests({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/medicaltests?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, MedicalTestResponse.fromJson),
      );

  /// GET /api/medicaltests/{id}
  Future<ApiResult<MedicalTestResponse>> getMedicalTest(int id) =>
      _get('/medicaltests/$id',
          (j) => MedicalTestResponse.fromJson(j as Map<String, dynamic>));

  /// GET /api/medicaltests/patient/{patientId}
  Future<ApiResult<List<MedicalTestResponse>>> getMedicalTestsByPatient(
    int patientId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/medicaltests/patient/$patientId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, MedicalTestResponse.fromJson),
      );

  /// GET /api/medicaltests/lab/{labId}
  Future<ApiResult<List<MedicalTestResponse>>> getMedicalTestsByLab(
    int labId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/medicaltests/lab/$labId?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, MedicalTestResponse.fromJson),
      );

  /// POST /api/medicaltests
  Future<ApiResult<MedicalTestResponse>> addMedicalTest(
          MedicalTestRequest req) =>
      _post('/medicaltests', req.toJson(),
          (j) => MedicalTestResponse.fromJson(j as Map<String, dynamic>));

  /// PUT /api/medicaltests/{id}
  Future<ApiResult<bool>> updateMedicalTest(
          int id, Map<String, dynamic> body) =>
      _put('/medicaltests/$id', body);

  /// DELETE /api/medicaltests/{id}
  Future<ApiResult<bool>> deleteMedicalTest(int id) =>
      _delete('/medicaltests/$id');

  Future<ApiResult<OcrScanResponse>> uploadOcrReport({
    required String fileName,
    required List<int> bytes,
    int? patientId,
    int? labId,
  }) async {
    try {
      final query = <String>[
        if (patientId != null) 'patientId=$patientId',
        if (labId != null) 'labId=$labId',
      ].join('&');
      final uri = Uri.parse('$_base/ocr${query.isNotEmpty ? '?$query' : ''}');
      final request = http.MultipartRequest('POST', uri);
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      final mimeType = lookupMimeType(fileName, headerBytes: bytes) ?? 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes(
        'image',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));

      final streamed = await request.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(
          OcrScanResponse.fromJson(jsonDecode(res.body) as Map<String, dynamic>),
          res.statusCode,
        );
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // AMBULANCES — /api/ambulances
  // ═══════════════════════════════════════════════════════════════════

  Future<ApiResult<List<AmbulanceResponse>>> getAmbulances({
    int pageNumber = 1,
    int pageSize = 100,
  }) =>
      _get(
        '/ambulances?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, AmbulanceResponse.fromJson),
      );

  Future<ApiResult<List<AmbulanceResponse>>> getAvailableAmbulances() =>
      _get('/ambulances/available',
          (j) => _parseList(j, AmbulanceResponse.fromJson));

  Future<ApiResult<bool>> updateAmbulanceAvailability(
          int id, String availabilityStatus) =>
      _put('/ambulances/$id/availability',
          {'availabilityStatus': availabilityStatus});

  // ════════════════════════════════════════════════════════════════
  // EMERGENCY DISPATCHES  — /api/emergencydispatches
  // ════════════════════════════════════════════════════════════════

  /// GET /api/emergencydispatches?pageNumber=&pageSize=
  Future<ApiResult<List<EmergencyDispatchResponse>>> getAllDispatches({
    int pageNumber = 1,
    int pageSize = 50,
  }) =>
      _get(
        '/emergencydispatches?pageNumber=$pageNumber&pageSize=$pageSize',
        (j) => _parseList(j, EmergencyDispatchResponse.fromJson),
      );

  /// GET /api/emergencydispatches/{id}
  Future<ApiResult<EmergencyDispatchResponse>> getDispatch(int id) =>
      _get('/emergencydispatches/$id',
          (j) => EmergencyDispatchResponse.fromJson(
              j as Map<String, dynamic>));

  /// GET /api/emergencydispatches/patient/{patientId}
  Future<ApiResult<List<EmergencyDispatchResponse>>>
      getDispatchesByPatient(
    int patientId, {
    int pageNumber = 1,
    int pageSize = 20,
  }) =>
          _get(
            '/emergencydispatches/patient/$patientId?pageNumber=$pageNumber&pageSize=$pageSize',
            (j) => _parseList(j, EmergencyDispatchResponse.fromJson),
          );

  /// GET /api/emergencydispatches/ambulance/{ambulanceId}
  Future<ApiResult<List<EmergencyDispatchResponse>>>
      getDispatchesByAmbulance(
    int ambulanceId, {
    int pageNumber = 1,
    int pageSize = 20,
  }) =>
          _get(
            '/emergencydispatches/ambulance/$ambulanceId?pageNumber=$pageNumber&pageSize=$pageSize',
            (j) => _parseList(j, EmergencyDispatchResponse.fromJson),
          );

  /// POST /api/emergencydispatches
  Future<ApiResult<EmergencyDispatchResponse>> createDispatch(
          EmergencyDispatchRequest req) =>
      _post('/emergencydispatches', req.toJson(),
          (j) => EmergencyDispatchResponse.fromJson(
              j as Map<String, dynamic>));

  /// PATCH /api/emergencydispatches/{id}/status
  /// status: Pending | OnTheWay | Arrived | Resolved | Cancelled
  Future<ApiResult<bool>> updateDispatchStatus(
          int id, String status) async {
    try {
      final res = await http.patch(
        Uri.parse('$_base/emergencydispatches/$id/status'),
        headers: _headers,
        body: jsonEncode(status), // raw string — backend expects [FromBody] string
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // LOCATION  — /api/location
  // ════════════════════════════════════════════════════════════════

  /// PUT /api/location/patient/{patientId}
  Future<ApiResult<PatientLocationResponse>> updatePatientLocation(
    int patientId,
    UpdateLocationRequest req,
  ) =>
      _putWithResponse(
        '/location/patient/$patientId',
        req.toJson(),
        (j) => PatientLocationResponse.fromJson(j as Map<String, dynamic>),
      );

  /// GET /api/location/patient/{patientId}
  Future<ApiResult<PatientLocationResponse>> getPatientLocation(
          int patientId) =>
      _get('/location/patient/$patientId',
          (j) => PatientLocationResponse.fromJson(
              j as Map<String, dynamic>));

  /// PUT /api/location/ambulance/{ambulanceId}
  Future<ApiResult<AmbulanceLocationResponse>> updateAmbulanceLocation(
    int ambulanceId,
    UpdateLocationRequest req, {
    String source = 'GPS',
  }) =>
      _putWithResponse(
        '/location/ambulance/$ambulanceId',
        {'latitude': req.latitude, 'longitude': req.longitude, 'source': source},
        (j) => AmbulanceLocationResponse.fromJson(
            j as Map<String, dynamic>),
      );

  /// GET /api/location/ambulance/{ambulanceId}
  Future<ApiResult<AmbulanceLocationResponse>> getAmbulanceLocation(
          int ambulanceId) =>
      _get('/location/ambulance/$ambulanceId',
          (j) => AmbulanceLocationResponse.fromJson(
              j as Map<String, dynamic>));

  /// GET /api/location/dispatch/{dispatchId}/ambulance
  /// Track the ambulance assigned to a dispatch.
  Future<ApiResult<AmbulanceLocationResponse>> getDispatchAmbulanceLocation(
          int dispatchId) =>
      _get('/location/dispatch/$dispatchId/ambulance',
          (j) => AmbulanceLocationResponse.fromJson(
              j as Map<String, dynamic>));

  /// PUT /api/location/ambulance/{id} — manual location set (admin / ambulance)
  Future<void> setAmbulanceLocationManual(
      int ambulanceId, double lat, double lng) async {
    try {
      await http.put(
        Uri.parse('$_base/location/ambulance/$ambulanceId'),
        headers: _headers,
        body: jsonEncode({'latitude': lat, 'longitude': lng, 'source': 'Manual'}),
      ).timeout(const Duration(seconds: 8));
    } catch (_) {}
  }

  /// GET /api/location/ambulances/nearest?lat=&lng=
  /// Returns nearest available ambulances sorted by distance.
  Future<ApiResult<List<AmbulanceLocationResponse>>> getNearestAmbulances(
    double lat,
    double lng,
  ) =>
      _get(
        '/location/ambulances/nearest?lat=$lat&lng=$lng',
        (j) => _parseList(j, AmbulanceLocationResponse.fromJson),
      );

  // ════════════════════════════════════════════════════════════════
  // HEART RISK  — /api/heartrisk
  // ════════════════════════════════════════════════════════════════

  /// POST /api/heartrisk/predict
  Future<ApiResult<HeartRiskResponse>> predictHeartRisk(
          HeartRiskRequest req) =>
      _post('/heartrisk/predict', req.toJson(),
          (j) => HeartRiskResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/heartrisk/predict/window
  /// Recommended for real hardware — send averaged 30-s window.
  Future<ApiResult<HeartRiskResponse>> predictHeartRiskWindow(
          Map<String, dynamic> windowData) =>
      _post('/heartrisk/predict/window', windowData,
          (j) => HeartRiskResponse.fromJson(j as Map<String, dynamic>));

  /// POST /api/heartrisk/predict/batch
  Future<ApiResult<Map<String, dynamic>>> predictHeartRiskBatch(
          List<Map<String, dynamic>> readings) =>
      _post('/heartrisk/predict/batch', {'readings': readings},
          (j) => j as Map<String, dynamic>);

  /// POST /api/heartrisk/predict/vitals/{vitalSignsId}
  /// Run AI on an already-saved VitalSigns row.
  Future<ApiResult<HeartRiskResponse>> predictFromVitals(
          int vitalSignsId) async {
    try {
      final res = await http.post(
        Uri.parse('$_base/heartrisk/predict/vitals/$vitalSignsId'),
        headers: _headers,
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(
          HeartRiskResponse.fromJson(
              jsonDecode(res.body) as Map<String, dynamic>),
          res.statusCode,
        );
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  /// GET /api/heartrisk/health
  Future<ApiResult<bool>> checkHeartRiskServiceHealth() async {
    try {
      final res = await http.get(
        Uri.parse('$_base/heartrisk/health'),
        headers: _headers,
      ).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // PATIENT PROGRESS — /api/patient-progress
  // ═══════════════════════════════════════════════════════════════════

  Future<ApiResult<PatientProgressResponse>> getPatientProgress(
    int patientId, {
    DateTime? from,
    DateTime? to,
    int limit = 100,
  }) {
    final params = <String>[
      if (from != null) 'from=${Uri.encodeComponent(from.toIso8601String())}',
      if (to != null) 'to=${Uri.encodeComponent(to.toIso8601String())}',
      'limit=$limit',
    ].join('&');
    return _get('/patient-progress/$patientId?$params',
        (j) => PatientProgressResponse.fromJson(j as Map<String, dynamic>));
  }

  // ═══════════════════════════════════════════════════════════════════
  // FCM — /api/fcm
  // ═══════════════════════════════════════════════════════════════════

  Future<ApiResult<bool>> registerFcmToken(String userEmail, String fcmToken) =>
      _post('/fcm/register', {'userEmail': userEmail, 'fcmToken': fcmToken},
          (_) => true);

  // ═══════════════════════════════════════════════════════════════════
  // CHAT — /api/chat
  // ═══════════════════════════════════════════════════════════════════

  Future<ApiResult<bool>> deleteMessage(int messageId) =>
      _delete('/chat/message/$messageId');

  Future<ApiResult<bool>> deleteMessageForEveryone(int messageId) =>
      _delete('/chat/message/$messageId/all');

  Future<ApiResult<bool>> clearConversation(String otherEmail) =>
      _delete('/chat/conversation/${Uri.encodeComponent(otherEmail)}');

  Future<ApiResult<bool>> clearConversationForEveryone(String otherEmail) =>
      _delete('/chat/conversation/${Uri.encodeComponent(otherEmail)}/all');

  // ── Ambulance sign in/out ─────────────────────────────────────
  Future<ApiResult<bool>> ambulanceSignIn() async {
    try {
      final res = await http.post(Uri.parse('$_base/ambulances/signin'), headers: _headers).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  Future<ApiResult<bool>> ambulanceSignOut() async {
    try {
      final res = await http.post(Uri.parse('$_base/ambulances/signout'), headers: _headers).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  Future<ApiResult<bool>> changePassword(String currentPassword, String newPassword) async {
    try {
      final res = await http.put(Uri.parse('$_base/auth/change-password'),
          headers: _headers,
          body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}))
          .timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  Future<ApiResult<bool>> updateName(String newName) async {
    try {
      final res = await http.put(Uri.parse('$_base/auth/update-name'),
          headers: _headers,
          body: jsonEncode({'newName': newName}))
          .timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  // ── Dispatch requests ─────────────────────────────────────────
  Future<ApiResult<List<dynamic>>> getMyActiveDispatches() =>
      _get('/dispatch-requests/my', (j) => j as List);

  Future<ApiResult<bool>> acceptDispatch(int id) =>
      _put('/dispatch-requests/$id/accept', {});

  Future<ApiResult<bool>> rejectDispatch(int id) =>
      _put('/dispatch-requests/$id/reject', {});

  // ── Relative requests ─────────────────────────────────────────
  Future<ApiResult<Map<String, dynamic>>> sendRelativeRequest(int patientId) =>
      _post('/relative-requests', {'patientId': patientId}, (j) => j as Map<String, dynamic>);

  Future<ApiResult<List<dynamic>>> getRelativeRequestsForPatient() =>
      _get('/relative-requests/patient/me', (j) => j as List);

  Future<ApiResult<List<dynamic>>> getMyRelativeRequestStatus() =>
      _get('/relative-requests/my-status', (j) => j as List);

  Future<ApiResult<bool>> approveRelativeRequest(int requestId) async {
    try {
      final res = await http.put(Uri.parse('$_base/relative-requests/$requestId/approve'), headers: _headers).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  Future<ApiResult<bool>> rejectRelativeRequest(int requestId) async {
    try {
      final res = await http.put(Uri.parse('$_base/relative-requests/$requestId/reject'), headers: _headers).timeout(_requestTimeout);
      return res.statusCode >= 200 && res.statusCode < 300
          ? ApiResult.success(true, res.statusCode)
          : ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) { return ApiResult.failure(e.toString(), null); }
  }

  Future<ApiResult<List<dynamic>>> searchPatients(String query) =>
      _get('/relative-requests/search-patients?q=${Uri.encodeComponent(query)}', (j) => j as List);

  // ── Profile picture ───────────────────────────────────────────
  /// PUT /api/auth/profile-picture — multipart upload, returns the URL string
  Future<ApiResult<String>> uploadProfilePicture(List<int> bytes, String fileName) async {
    try {
      final uri = Uri.parse('$_base/auth/profile-picture');
      final request = http.MultipartRequest('PUT', uri);
      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }
      final mimeType = lookupMimeType(fileName, headerBytes: bytes) ?? 'image/jpeg';
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: fileName,
        contentType: MediaType.parse(mimeType),
      ));
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final j = jsonDecode(res.body);
        return ApiResult.success(j['url'] as String? ?? '', res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  /// DELETE /api/auth/profile-picture — removes profile picture
  Future<ApiResult<bool>> deleteProfilePicture() async {
    try {
      final res = await http.delete(
        Uri.parse('$_base/auth/profile-picture'),
        headers: _headers,
      ).timeout(const Duration(seconds: 15));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(true, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  // ════════════════════════════════════════════════════════════════
  // SENSOR SIMULATOR  — POST /api/vitalsigns/sensor  (AllowAnonymous)
  // Sends one simulated reading for the given patient.
  // scenario: 'normal' | 'high_hr' | 'low_spo2' | 'low_hr'
  // ════════════════════════════════════════════════════════════════

  Future<ApiResult<Map<String, dynamic>>> sendSimulatedReading({
    required int patientId,
    String scenario = 'normal',
  }) async {
    final (hr, spo2) = _generateReading(scenario);
    try {
      final res = await http.post(
        Uri.parse('$_base/vitalsigns/sensor'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'patientId':        patientId,
          'heartRate':        hr,
          'oxygenSaturation': spo2,
        }),
      ).timeout(_requestTimeout);
      if (res.statusCode >= 200 && res.statusCode < 300) {
        return ApiResult.success(
            jsonDecode(res.body) as Map<String, dynamic>, res.statusCode);
      }
      return ApiResult.failure(_errorMsg(res), res.statusCode);
    } catch (e) {
      return ApiResult.failure(e.toString(), null);
    }
  }

  (int hr, double spo2) _generateReading(String scenario) {
    final rng = DateTime.now().millisecondsSinceEpoch;
    switch (scenario) {
      case 'high_hr':
        return (151 + rng % 30, 94.0 + (rng % 30) / 10);
      case 'low_spo2':
        return (70  + rng % 30, 84.0 + (rng % 55) / 10);
      case 'low_hr':
        return (25  + rng % 15, 94.0 + (rng % 30) / 10);
      default: // normal
        return (62  + rng % 34, 96.0 + (rng % 35) / 10);
    }
  }

  // ── Ratings ───────────────────────────────────────────────────

  /// Submit or update a rating for a doctor or lab.
  /// POST /api/ratings  { stars, doctorId? OR labId? }
  Future<ApiResult<RatingResponse>> submitRating(RatingRequest request) =>
      _post('/ratings', request.toJson(),
          (j) => RatingResponse.fromJson(j as Map<String, dynamic>));

  /// Get the current patient's rating for a specific doctor or lab.
  /// GET /api/ratings/my?doctorId=7  OR  ?labId=2
  Future<ApiResult<RatingResponse>> getMyRating({int? doctorId, int? labId}) {
    final params = <String, String>{};
    if (doctorId != null) params['doctorId'] = '$doctorId';
    if (labId    != null) params['labId']    = '$labId';
    final query = params.entries.map((e) => '${e.key}=${e.value}').join('&');
    return _get('/ratings/my?$query',
        (j) => RatingResponse.fromJson(j as Map<String, dynamic>));
  }
}

// Global singleton
final apiService = ApiService();
