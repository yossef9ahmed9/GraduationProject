// ════════════════════════════════════════════════════════════════
// MODELS — all data classes for MediTrack
// Fully aligned with backend Contracts as of latest backend revision.
// ════════════════════════════════════════════════════════════════

// ── User Role ─────────────────────────────────────────────────
enum UserRole { patient, doctor, lab, relative, ambulance, admin }

extension UserRoleExt on UserRole {
  String get label {
    switch (this) {
      case UserRole.patient:   return 'Patient';
      case UserRole.doctor:    return 'Doctor';
      case UserRole.lab:       return 'Lab';
      case UserRole.relative:  return 'Relative';
      case UserRole.ambulance: return 'Ambulance';
      default:                 return 'Admin';
    }
  }
}

UserRole userRoleFromString(String s) {
  switch (s.toLowerCase()) {
    case 'patient':   return UserRole.patient;
    case 'doctor':    return UserRole.doctor;
    case 'lab':       return UserRole.lab;
    case 'relative':  return UserRole.relative;
    case 'ambulance': return UserRole.ambulance;
    default:          return UserRole.admin;
  }
}

// ── App User ──────────────────────────────────────────────────
class AppUser {
  final String id;
  final String name;
  final String email;
  final String role;
  final String token;
  final String refreshToken;
  final String? profilePictureUrl;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    required this.token,
    required this.refreshToken,
    this.profilePictureUrl,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'U';
  }
}

// ── Auth Response ─────────────────────────────────────────────
class AuthResponse {
  final String id;
  final String email;
  final String fullName;
  final String token;
  final String refreshToken;
  final String? profilePictureUrl;

  const AuthResponse({
    required this.id,
    required this.email,
    required this.fullName,
    required this.token,
    required this.refreshToken,
    this.profilePictureUrl,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> j) => AuthResponse(
    id:                j['id'] as String? ?? '',
    email:             j['email'] as String? ?? '',
    fullName:          j['fullName'] as String? ?? j['name'] as String? ?? '',
    token:             j['token'] as String? ?? '',
    refreshToken:      j['refreshToken'] as String? ?? '',
    profilePictureUrl: j['profilePictureUrl'] as String?,
  );
}

// ── API Result ────────────────────────────────────────────────
class ApiResult<T> {
  final bool ok;
  final T? data;
  final String? error;
  final int? statusCode;
  /// Per-field validation errors (lowercased field name → first error message).
  /// Populated only on 400 responses with FluentValidation errors.
  final Map<String, String> fieldErrors;

  const ApiResult._({
    required this.ok,
    this.data,
    this.error,
    this.statusCode,
    this.fieldErrors = const {},
  });

  factory ApiResult.success(T data, int code) =>
      ApiResult._(ok: true, data: data, statusCode: code);

  factory ApiResult.failure(String error, int? code, {Map<String, String> fieldErrors = const {}}) =>
      ApiResult._(ok: false, error: error, statusCode: code, fieldErrors: fieldErrors);
}

// ── Paginated Response wrapper ────────────────────────────────
// Backend returns { items: [...], pageNumber, pageSize, totalCount, totalPages }
class PagedList<T> {
  final List<T> items;
  final int pageNumber;
  final int pageSize;
  final int totalCount;
  final int totalPages;

  const PagedList({
    required this.items,
    required this.pageNumber,
    required this.pageSize,
    required this.totalCount,
    required this.totalPages,
  });

  factory PagedList.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) fromJson,
  ) =>
      PagedList(
        items:      (j['items'] as List? ?? [])
            .map((e) => fromJson(e as Map<String, dynamic>))
            .toList(),
        pageNumber: j['pageNumber'] as int? ?? 1,
        pageSize:   j['pageSize']   as int? ?? 10,
        totalCount: j['totalCount'] as int? ?? 0,
        totalPages: j['totalPages'] as int? ?? 1,
      );
}

// ── Patient ───────────────────────────────────────────────────
// Matches GraduationProject.Contracts.Patients.PatientResponse
class PatientResponse {
  final int id;
  final String name;
  final String gender;
  final String phone;
  final String email;
  final String address;
  final String medicalRecord;
  final String? birthDate;
  final String bloodType;
  final String? chronicDiseases;
  final String? allergies;
  final bool isInEmergency;
  final String? profilePictureUrl;

  const PatientResponse({
    required this.id,
    required this.name,
    required this.gender,
    required this.phone,
    required this.email,
    required this.address,
    required this.medicalRecord,
    this.birthDate,
    this.bloodType = '',
    this.chronicDiseases,
    this.allergies,
    this.isInEmergency = false,
    this.profilePictureUrl,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'P';
  }

  factory PatientResponse.fromJson(Map<String, dynamic> j) => PatientResponse(
    id:               j['id'] as int? ?? 0,
    name:             j['name'] as String? ?? j['fullName'] as String? ?? '',
    gender:           j['gender'] as String? ?? '',
    phone:            j['phone'] as String? ?? '',
    email:            j['email'] as String? ?? '',
    address:          j['address'] as String? ?? '',
    medicalRecord:    j['medicalRecord'] as String? ?? '',
    birthDate:        j['birthDate'] as String?,
    bloodType:        j['bloodType'] as String? ?? '',
    chronicDiseases:  j['chronicDiseases'] as String?,
    allergies:        j['allergies'] as String?,
    isInEmergency:    j['isInEmergency'] as bool? ?? false,
    profilePictureUrl: j['profilePictureUrl'] as String?,
  );
}

// ── Doctor ────────────────────────────────────────────────────
class DoctorResponse {
  final int    id;
  final String name;
  final String email;
  final String phone;
  final String specialization;
  final String? hospitalName;
  final String? clinicName;
  final String? clinicAddress;
  final double? clinicLatitude;
  final double? clinicLongitude;
  final String? profilePictureUrl;
  final double  averageRating;
  final int     ratingCount;
  final double? myRating;

  const DoctorResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.specialization,
    this.hospitalName,
    this.clinicName,
    this.clinicAddress,
    this.clinicLatitude,
    this.clinicLongitude,
    this.profilePictureUrl,
    this.averageRating = 0,
    this.ratingCount   = 0,
    this.myRating,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'D';
  }

  factory DoctorResponse.fromJson(Map<String, dynamic> j) => DoctorResponse(
    id:             j['id'] as int? ?? 0,
    name:           j['name'] as String? ?? j['fullName'] as String? ?? '',
    email:          j['email'] as String? ?? '',
    phone:          j['phone'] as String? ?? '',
    specialization: j['specialization'] as String? ?? '',
    hospitalName:   j['hospitalName'] as String?,
    clinicName:     j['clinicName'] as String?,
    clinicAddress:  j['clinicAddress'] as String?,
    clinicLatitude:   (j['clinicLatitude']  as num?)?.toDouble(),
    clinicLongitude:  (j['clinicLongitude'] as num?)?.toDouble(),
    profilePictureUrl: j['profilePictureUrl'] as String?,
    averageRating:  (j['averageRating'] as num?)?.toDouble() ?? 0,
    ratingCount:    j['ratingCount'] as int? ?? 0,
    myRating:       (j['myRating'] as num?)?.toDouble(),
  );
}

// ── Lab ───────────────────────────────────────────────────────

class LabResponse {
  final int    id;
  final String name;
  final String location;
  final String phone;
  final String email;
  final double? latitude;
  final double? longitude;
  final String? profilePictureUrl;
  final double  averageRating;
  final int     ratingCount;
  final double? myRating;

  const LabResponse({
    required this.id,
    required this.name,
    required this.location,
    required this.phone,
    required this.email,
    this.latitude,
    this.longitude,
    this.profilePictureUrl,
    this.averageRating = 0,
    this.ratingCount   = 0,
    this.myRating,
  });

  factory LabResponse.fromJson(Map<String, dynamic> j) => LabResponse(
    id:        j['id']       as int?    ?? 0,
    name:      j['labName']  as String? ?? j['name']  as String? ?? '',
    location:  j['location'] as String? ?? '',
    phone:     j['phone']    as String? ?? '',
    email:     j['email']    as String? ?? '',
    latitude:  (j['latitude']  as num?)?.toDouble(),
    longitude: (j['longitude'] as num?)?.toDouble(),
    profilePictureUrl: j['profilePictureUrl'] as String?,
    averageRating: (j['averageRating'] as num?)?.toDouble() ?? 0,
    ratingCount:   j['ratingCount'] as int? ?? 0,
    myRating:      (j['myRating'] as num?)?.toDouble(),
  );
}


// ── Follow-Up ─────────────────────────────────────────────────
class FollowUpResponse {
  final int     id;
  final int     patientId;
  final int     doctorId;
  final String  diagnosis;
  final String  treatmentPlan;
  final String  notes;
  final String? lastUpdate;
  final String  severity;
  final String  status;
  final String? nextVisitDate;

  const FollowUpResponse({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.diagnosis,
    required this.treatmentPlan,
    required this.notes,
    this.lastUpdate,
    this.severity = 'Low',
    this.status   = 'Pending',
    this.nextVisitDate,
  });

  factory FollowUpResponse.fromJson(Map<String, dynamic> j) => FollowUpResponse(
    id:            j['id']            as int?    ?? 0,
    patientId:     j['patientId']     as int?    ?? 0,
    doctorId:      j['doctorId']      as int?    ?? 0,
    diagnosis:     j['diagnosis']     as String? ?? '',
    treatmentPlan: j['treatmentPlan'] as String? ?? '',
    notes:         j['notes']         as String? ?? '',
    lastUpdate:    j['lastUpdate']    as String? ?? j['updatedAt'] as String?,
    severity:      j['severity']      as String? ?? 'Low',
    status:        j['status']        as String? ?? 'Pending',
    nextVisitDate: j['nextVisitDate'] as String?,
  );
}

class FollowUpRequest {
  final String    diagnosis;
  final String    treatmentPlan;
  final String    notes;
  final int       patientId;
  final int       doctorId;
  final String    severity;
  final DateTime? nextVisitDate;

  const FollowUpRequest({
    required this.diagnosis,
    required this.treatmentPlan,
    required this.notes,
    required this.patientId,
    required this.doctorId,
    this.severity     = 'Low',
    this.nextVisitDate,
  });

  Map<String, dynamic> toJson() => {
    'diagnosis':     diagnosis,
    'treatmentPlan': treatmentPlan,
    'notes':         notes,
    'patientId':     patientId,
    'doctorId':      doctorId,
    'severity':      severity,
    if (nextVisitDate != null) 'nextVisitDate': nextVisitDate!.toIso8601String(),
  };
}

// ── Emergency Dispatch ────────────────────────────────────────
// Matches GraduationProject.Contracts.EmergencyDispatches.EmergencyDispatchResponse
class EmergencyDispatchResponse {
  final int id;
  final String dispatchedAt;
  final String? arrivedAt;
  final String? resolvedAt;
  final String status; // Pending / OnTheWay / Arrived / Resolved / Cancelled
  final double patientLatitude;
  final double patientLongitude;
  final String? notes;
  final int patientId;
  final int ambulanceId;

  const EmergencyDispatchResponse({
    required this.id,
    required this.dispatchedAt,
    this.arrivedAt,
    this.resolvedAt,
    required this.status,
    required this.patientLatitude,
    required this.patientLongitude,
    this.notes,
    required this.patientId,
    required this.ambulanceId,
  });

  factory EmergencyDispatchResponse.fromJson(Map<String, dynamic> j) =>
      EmergencyDispatchResponse(
        id:               j['id'] as int? ?? 0,
        dispatchedAt:     j['dispatchedAt'] as String? ?? '',
        arrivedAt:        j['arrivedAt'] as String?,
        resolvedAt:       j['resolvedAt'] as String?,
        status:           j['status'] as String? ?? '',
        patientLatitude:  (j['patientLatitude'] as num?)?.toDouble() ?? 0.0,
        patientLongitude: (j['patientLongitude'] as num?)?.toDouble() ?? 0.0,
        notes:            j['notes'] as String?,
        patientId:        j['patientId'] as int? ?? 0,
        ambulanceId:      j['ambulanceId'] as int? ?? 0,
      );

  Map<String, dynamic> toJson() => {
    'id':               id,
    'dispatchedAt':     dispatchedAt,
    'arrivedAt':        arrivedAt,
    'resolvedAt':       resolvedAt,
    'status':           status,
    'patientLatitude':  patientLatitude,
    'patientLongitude': patientLongitude,
    'notes':            notes,
    'patientId':        patientId,
    'ambulanceId':      ambulanceId,
  };

  bool get isActive =>
      status == 'Pending' || status == 'OnTheWay' || status == 'Arrived';
}

class EmergencyDispatchRequest {
  final int patientId;
  final int ambulanceId;
  final double patientLatitude;
  final double patientLongitude;
  final String? notes;

  const EmergencyDispatchRequest({
    required this.patientId,
    required this.ambulanceId,
    required this.patientLatitude,
    required this.patientLongitude,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'patientId':        patientId,
    'ambulanceId':      ambulanceId,
    'patientLatitude':  patientLatitude,
    'patientLongitude': patientLongitude,
    if (notes != null) 'notes': notes,
  };
}

// ── Vital Signs ───────────────────────────────────────────────
// Matches GraduationProject.Contracts.VitalSigns.VitalSignsResponse
class VitalSignsResponse {
  final int id;
  final int heartRate;
  final bool emergencyStatus;
  final String timeStamp;
  final int sensorId;
  final int patientId;
  final String patientName;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? oxygenSaturation;
  final double? temperature;
  final int? respiratoryRate;
  final double? bloodGlucose;
  // Inline auto-dispatch result — non-null when this reading triggered a dispatch
  final EmergencyDispatchResponse? autoDispatch;

  // Aliases kept for backward compat with existing UI code
  int get systolicBP  => bloodPressureSystolic  ?? 0;
  int get diastolicBP => bloodPressureDiastolic ?? 0;

  const VitalSignsResponse({
    required this.id,
    required this.heartRate,
    required this.emergencyStatus,
    required this.timeStamp,
    required this.sensorId,
    required this.patientId,
    required this.patientName,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.oxygenSaturation,
    this.temperature,
    this.respiratoryRate,
    this.bloodGlucose,
    this.autoDispatch,
  });

  String get bpDisplay {
    if (bloodPressureSystolic != null && bloodPressureDiastolic != null) {
      return '$bloodPressureSystolic/$bloodPressureDiastolic';
    }
    return '—';
  }

  bool get isAlert => emergencyStatus; // الباك يقرر — Warning بتكون SnackBar بس

  factory VitalSignsResponse.fromJson(Map<String, dynamic> j) =>
      VitalSignsResponse(
        id:                      j['id'] as int? ?? 0,
        heartRate:               j['heartRate'] as int? ?? 0,
        emergencyStatus:         j['emergencyStatus'] as bool? ?? false,
        timeStamp:               j['timeStamp'] as String? ??
                                 j['timestamp'] as String? ??
                                 DateTime.now().toIso8601String(),
        sensorId:                j['sensorId'] as int? ?? 0,
        patientId:               j['patientId'] as int? ?? 0,
        patientName:             j['patientName'] as String? ?? '',
        bloodPressureSystolic:   j['bloodPressureSystolic'] as int?,
        bloodPressureDiastolic:  j['bloodPressureDiastolic'] as int?,
        oxygenSaturation:        (j['oxygenSaturation'] as num?)?.toDouble(),
        temperature:             (j['temperature'] as num?)?.toDouble(),
        respiratoryRate:         j['respiratoryRate'] as int?,
        bloodGlucose:            (j['bloodGlucose'] as num?)?.toDouble(),
        autoDispatch:            j['autoDispatch'] != null
            ? EmergencyDispatchResponse.fromJson(
                j['autoDispatch'] as Map<String, dynamic>)
            : null,
      );
}

class VitalSignsRequest {
  final int heartRate;
  final int patientId;
  final int sensorId;
  final int? bloodPressureSystolic;
  final int? bloodPressureDiastolic;
  final double? oxygenSaturation;
  final double? temperature;
  final int? respiratoryRate;
  final double? bloodGlucose;

  const VitalSignsRequest({
    required this.heartRate,
    required this.patientId,
    required this.sensorId,
    this.bloodPressureSystolic,
    this.bloodPressureDiastolic,
    this.oxygenSaturation,
    this.temperature,
    this.respiratoryRate,
    this.bloodGlucose,
  });

  Map<String, dynamic> toJson() => {
    'heartRate':              heartRate,
    'patientId':              patientId,
    'sensorId':               sensorId,
    if (bloodPressureSystolic  != null) 'bloodPressureSystolic':  bloodPressureSystolic,
    if (bloodPressureDiastolic != null) 'bloodPressureDiastolic': bloodPressureDiastolic,
    if (oxygenSaturation       != null) 'oxygenSaturation':       oxygenSaturation,
    if (temperature            != null) 'temperature':            temperature,
    if (respiratoryRate        != null) 'respiratoryRate':        respiratoryRate,
    if (bloodGlucose           != null) 'bloodGlucose':           bloodGlucose,
  };
}

// ── Sensor ────────────────────────────────────────────────────
// Matches GraduationProject.Contracts.Sensors.SensorResponse
class SensorResponse {
  final int id;
  final String type;
  final String description;
  final int patientId;
  final bool isActive;
  final String? lastPing;

  const SensorResponse({
    required this.id,
    required this.type,
    required this.description,
    required this.patientId,
    required this.isActive,
    this.lastPing,
  });

  factory SensorResponse.fromJson(Map<String, dynamic> j) => SensorResponse(
    id:          j['id'] as int? ?? 0,
    type:        j['type'] as String? ?? '',
    description: j['description'] as String? ?? '',
    patientId:   j['patientId'] as int? ?? 0,
    isActive:    j['isActive'] as bool? ?? false,
    lastPing:    j['lastPing'] as String?,
  );
}

class SensorRequest {
  final String type;
  final String description;
  final int patientId;

  const SensorRequest({
    required this.type,
    required this.description,
    required this.patientId,
  });

  Map<String, dynamic> toJson() => {
    'type':        type,
    'description': description,
    'patientId':   patientId,
  };
}

// ── Medical Test ──────────────────────────────────────────────
class MedicalTestResponse {
  final int id;
  final int patientId;
  final int labId;
  final String name;
  final String result;
  final String? date;

  const MedicalTestResponse({
    required this.id,
    required this.patientId,
    required this.labId,
    required this.name,
    required this.result,
    this.date,
  });

  factory MedicalTestResponse.fromJson(Map<String, dynamic> j) =>
      MedicalTestResponse(
        id:        j['id'] as int? ?? 0,
        patientId: j['patientId'] as int? ?? 0,
        labId:     j['labId'] as int? ?? 0,
        name:      j['name'] as String? ?? j['testName'] as String? ?? '',
        result:    j['result'] as String? ?? '',
        date:      j['date'] as String? ?? j['createdAt'] as String?,
      );
}

class MedicalTestRequest {
  final String name;
  final String result;
  final int patientId;
  final int labId;

  const MedicalTestRequest({
    required this.name,
    required this.result,
    required this.patientId,
    required this.labId,
  });

  Map<String, dynamic> toJson() => {
    'name':      name,
    'result':    result,
    'patientId': patientId,
    'labId':     labId,
  };
}

class LabAppointmentResponse {
  final int id;
  final int patientId;
  final String patientName;
  final int labId;
  final String labName;
  final List<String> testNames;
  final String appointmentDate;
  final String notes;
  final String status;
  final String createdAt;

  const LabAppointmentResponse({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.labId,
    required this.labName,
    required this.testNames,
    required this.appointmentDate,
    required this.notes,
    required this.status,
    required this.createdAt,
  });

  factory LabAppointmentResponse.fromJson(Map<String, dynamic> j) =>
      LabAppointmentResponse(
        id: j['id'] as int? ?? 0,
        patientId: j['patientId'] as int? ?? 0,
        patientName: j['patientName'] as String? ?? '',
        labId: j['labId'] as int? ?? 0,
        labName: j['labName'] as String? ?? '',
        testNames: (j['testNames'] as List? ?? []).map((e) => '$e').toList(),
        appointmentDate: j['appointmentDate'] as String? ?? '',
        notes: j['notes'] as String? ?? '',
        status: j['status'] as String? ?? '',
        createdAt: j['createdAt'] as String? ?? '',
      );
}

class LabAppointmentRequest {
  final int patientId;
  final int labId;
  final List<String> testNames;
  final DateTime appointmentDate;
  final String? notes;

  const LabAppointmentRequest({
    required this.patientId,
    required this.labId,
    required this.testNames,
    required this.appointmentDate,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'patientId': patientId,
    'labId': labId,
    'testNames': testNames,
    'appointmentDate': appointmentDate.toIso8601String(),
    if (notes != null) 'notes': notes,
  };
}

class LabTestResultRequest {
  final String name;
  final String result;

  const LabTestResultRequest({required this.name, required this.result});

  Map<String, dynamic> toJson() => {
    'name': name,
    'result': result,
  };
}

class CompleteLabAppointmentRequest {
  final List<LabTestResultRequest> results;

  const CompleteLabAppointmentRequest({required this.results});

  Map<String, dynamic> toJson() => {
    'results': results.map((r) => r.toJson()).toList(),
  };
}

class OcrScanResponse {
  final String extractedText;
  final Map<String, dynamic> analysis;
  final MedicalTestResponse? medicalTest;
  final String? patientSummary;

  const OcrScanResponse({
    required this.extractedText,
    required this.analysis,
    this.medicalTest,
    this.patientSummary,
  });

  bool get isValidScan => analysis['isValidScan'] as bool? ?? false;

  /// The test type auto-detected by the backend (e.g. "CBC", "Lipid Panel")
  String get testType => analysis['testType'] as String? ?? 'CBC';

  factory OcrScanResponse.fromJson(Map<String, dynamic> j) =>
      OcrScanResponse(
        extractedText:  j['extractedText'] as String? ?? '',
        analysis:       j['analysis'] as Map<String, dynamic>? ?? {},
        patientSummary: j['patientSummary'] as String?,
        medicalTest:    j['medicalTest'] is Map<String, dynamic>
            ? MedicalTestResponse.fromJson(j['medicalTest'] as Map<String, dynamic>)
            : null,
      );
}

class AmbulanceResponse {
  final int id;
  final String email;
  final String driverName;
  final String driverPhone;
  final String licensePlate;
  final String phone;
  final String availabilityStatus;
  final String? serviceArea;
  final double? latitude;
  final double? longitude;
  final String? lastLocationUpdate;
  final int activeDispatchCount;
  final String locationSource; // "GPS" | "Manual" | "Unknown"

  const AmbulanceResponse({
    required this.id,
    required this.email,
    required this.driverName,
    required this.driverPhone,
    required this.licensePlate,
    required this.phone,
    required this.availabilityStatus,
    this.serviceArea,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    required this.activeDispatchCount,
    this.locationSource = 'Unknown',
  });

  factory AmbulanceResponse.fromJson(Map<String, dynamic> j) => AmbulanceResponse(
    id:                  j['id']                  as int?    ?? 0,
    email:               j['email']               as String? ?? '',
    driverName:          j['driverName']          as String? ?? '',
    driverPhone:         j['driverPhone']         as String? ?? '',
    licensePlate:        j['licensePlate']        as String? ?? '',
    phone:               j['phone']               as String? ?? '',
    availabilityStatus:  j['availabilityStatus']  as String? ?? '',
    serviceArea:         j['serviceArea']         as String?,
    latitude:            (j['latitude']  as num?)?.toDouble(),
    longitude:           (j['longitude'] as num?)?.toDouble(),
    lastLocationUpdate:  j['lastLocationUpdate']  as String?,
    activeDispatchCount: j['activeDispatchCount'] as int?    ?? 0,
    locationSource:      j['locationSource']      as String? ?? 'Unknown',
  );
}

// ── Patient Progress ──────────────────────────────────────────
class PatientProgressResponse {
  final int patientId;
  final String patientName;
  final List<VitalPoint> vitals;
  final List<TestPoint> tests;

  const PatientProgressResponse({
    required this.patientId,
    required this.patientName,
    required this.vitals,
    required this.tests,
  });

  factory PatientProgressResponse.fromJson(Map<String, dynamic> j) =>
      PatientProgressResponse(
        patientId:   j['patientId']   as int?    ?? 0,
        patientName: j['patientName'] as String? ?? '',
        vitals: (j['points'] as List? ?? [])
            .map((e) => VitalPoint.fromJson(e as Map<String, dynamic>)).toList(),
        tests: (j['tests'] as List? ?? [])
            .map((e) => TestPoint.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

class VitalPoint {
  final DateTime timestamp;
  final int      heartRate;
  final double   oxygenSaturation;
  final bool     isEmergency;

  const VitalPoint({
    required this.timestamp,
    required this.heartRate,
    required this.oxygenSaturation,
    required this.isEmergency,
  });

  factory VitalPoint.fromJson(Map<String, dynamic> j) => VitalPoint(
    timestamp:        DateTime.tryParse(j['timestamp'] as String? ?? '')?.toLocal() ?? DateTime.now(),
    heartRate:        j['heartRate']        as int?    ?? 0,
    oxygenSaturation: (j['oxygenSaturation'] as num?)?.toDouble() ?? 0,
    isEmergency:      j['emergencyStatus']  as bool?   ?? false,
  );
}

class TestPoint {
  final DateTime date;
  final String   name;
  final String   result;
  final int      labId;
  final String   labName;

  const TestPoint({
    required this.date,
    required this.name,
    required this.result,
    required this.labId,
    required this.labName,
  });

  factory TestPoint.fromJson(Map<String, dynamic> j) => TestPoint(
    date:    DateTime.tryParse(j['date']    as String? ?? '')?.toLocal() ?? DateTime.now(),
    name:    j['name']    as String? ?? '',
    result:  j['result']  as String? ?? '',
    labId:   j['labId']   as int?    ?? 0,
    labName: j['labName'] as String? ?? '',
  );
}

// ── Relative Request ──────────────────────────────────────────
class RelativeRequest {
  final int      id;
  final int      relativeId;
  final String   relativeName;
  final String   relativePhone;
  final String   relationType;
  final int      patientId;
  final String   status;
  final DateTime createdAt;

  const RelativeRequest({
    required this.id,
    required this.relativeId,
    required this.relativeName,
    required this.relativePhone,
    required this.relationType,
    required this.patientId,
    required this.status,
    required this.createdAt,
  });

  factory RelativeRequest.fromJson(Map<String, dynamic> j) => RelativeRequest(
    id:            j['id']            as int?    ?? 0,
    relativeId:    j['relativeId']    as int?    ?? 0,
    relativeName:  j['relativeName']  as String? ?? '',
    relativePhone: j['relativePhone'] as String? ?? '',
    relationType:  j['relationType']  as String? ?? '',
    patientId:     j['patientId']     as int?    ?? 0,
    status:        j['status']        as String? ?? '',
    createdAt:     DateTime.tryParse(j['createdAt'] as String? ?? '')?.toLocal() ?? DateTime.now(),
  );
}

// ── Patient search result ─────────────────────────────────────
class PatientSearchResult {
  final int    id;
  final String name;
  final String email;
  final String phone;
  final String gender;

  const PatientSearchResult({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.gender,
  });

  factory PatientSearchResult.fromJson(Map<String, dynamic> j) =>
      PatientSearchResult(
        id:     j['id']     as int?    ?? 0,
        name:   j['name']   as String? ?? '',
        email:  j['email']  as String? ?? '',
        phone:  j['phone']  as String? ?? '',
        gender: j['gender'] as String? ?? '',
      );

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts[0].isNotEmpty) return parts[0][0].toUpperCase();
    return 'P';
  }
}

// ── Heart Risk ────────────────────────────────────────────────
// Matches GraduationProject.Contracts.HeartRisk.*
class HeartRiskResponse {
  final String tier; // NORMAL / WARNING / CRITICAL
  final double score;
  final double confidence;
  final String action;
  final String message;
  final bool alert;
  final String? overrideReason;
  final HeartRiskProbabilities probabilities;

  const HeartRiskResponse({
    required this.tier,
    required this.score,
    required this.confidence,
    required this.action,
    required this.message,
    required this.alert,
    this.overrideReason,
    required this.probabilities,
  });

  factory HeartRiskResponse.fromJson(Map<String, dynamic> j) =>
      HeartRiskResponse(
        tier:           j['tier'] as String? ?? '',
        score:          (j['score'] as num?)?.toDouble() ?? 0.0,
        confidence:     (j['confidence'] as num?)?.toDouble() ?? 0.0,
        action:         j['action'] as String? ?? '',
        message:        j['message'] as String? ?? '',
        alert:          j['alert'] as bool? ?? false,
        overrideReason: j['overrideReason'] as String?,
        probabilities:  j['probabilities'] != null
            ? HeartRiskProbabilities.fromJson(
                j['probabilities'] as Map<String, dynamic>)
            : const HeartRiskProbabilities(normal: 0, warning: 0, critical: 0),
      );
}

class HeartRiskProbabilities {
  final double normal;
  final double warning;
  final double critical;

  const HeartRiskProbabilities({
    required this.normal,
    required this.warning,
    required this.critical,
  });

  factory HeartRiskProbabilities.fromJson(Map<String, dynamic> j) =>
      HeartRiskProbabilities(
        normal:   (j['normal'] as num?)?.toDouble() ?? 0.0,
        warning:  (j['warning'] as num?)?.toDouble() ?? 0.0,
        critical: (j['critical'] as num?)?.toDouble() ?? 0.0,
      );
}

class HeartRiskRequest {
  final double bpm;
  final double spo2;
  final double hrvMs;
  final int age;
  final int sex; // 0 = female, 1 = male

  const HeartRiskRequest({
    required this.bpm,
    required this.spo2,
    required this.hrvMs,
    required this.age,
    required this.sex,
  });

  Map<String, dynamic> toJson() => {
    'bpm':    bpm,
    'spo2':   spo2,
    'hrv_ms': hrvMs,
    'age':    age,
    'sex':    sex,
  };
}

// ── Location ──────────────────────────────────────────────────
// Matches GraduationProject.Contracts.Location.LocationResponses
class PatientLocationResponse {
  final int patientId;
  final String patientName;
  final double? latitude;
  final double? longitude;
  final String? lastLocationUpdate;
  final bool isInEmergency;

  const PatientLocationResponse({
    required this.patientId,
    required this.patientName,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    required this.isInEmergency,
  });

  factory PatientLocationResponse.fromJson(Map<String, dynamic> j) =>
      PatientLocationResponse(
        patientId:          j['patientId'] as int? ?? 0,
        patientName:        j['patientName'] as String? ?? '',
        latitude:           (j['latitude'] as num?)?.toDouble(),
        longitude:          (j['longitude'] as num?)?.toDouble(),
        lastLocationUpdate: j['lastLocationUpdate'] as String?,
        isInEmergency:      j['isInEmergency'] as bool? ?? false,
      );
}

class AmbulanceLocationResponse {
  final int ambulanceId;
  final String driverName;
  final String email;
  final String driverPhone;
  final String phone;
  final String availabilityStatus;
  final double? latitude;
  final double? longitude;
  final String? lastLocationUpdate;
  final double? distanceFromPatientKm;

  const AmbulanceLocationResponse({
    required this.ambulanceId,
    required this.driverName,
    this.email = '',
    this.driverPhone = '',
    this.phone = '',
    required this.availabilityStatus,
    this.latitude,
    this.longitude,
    this.lastLocationUpdate,
    this.distanceFromPatientKm,
  });

  factory AmbulanceLocationResponse.fromJson(Map<String, dynamic> j) =>
      AmbulanceLocationResponse(
        ambulanceId:           j['ambulanceId']           as int?    ?? 0,
        driverName:            j['driverName']            as String? ?? '',
        email:                 j['email']                 as String? ?? '',
        driverPhone:           j['driverPhone']           as String? ?? '',
        phone:                 j['phone']                 as String? ?? '',
        availabilityStatus:    j['availabilityStatus']    as String? ?? '',
        latitude:              (j['latitude']  as num?)?.toDouble(),
        longitude:             (j['longitude'] as num?)?.toDouble(),
        lastLocationUpdate:    j['lastLocationUpdate']    as String?,
        distanceFromPatientKm: (j['distanceFromPatientKm'] as num?)?.toDouble(),
      );
}

class UpdateLocationRequest {
  final double latitude;
  final double longitude;

  const UpdateLocationRequest({required this.latitude, required this.longitude});

  Map<String, dynamic> toJson() => {
    'latitude':  latitude,
    'longitude': longitude,
  };
}

// ── Rating ────────────────────────────────────────────────────
class RatingRequest {
  final double stars;
  final int?   doctorId;
  final int?   labId;

  const RatingRequest({required this.stars, this.doctorId, this.labId});

  Map<String, dynamic> toJson() => {
    'stars': stars,
    if (doctorId != null) 'doctorId': doctorId,
    if (labId    != null) 'labId':    labId,
  };
}

class RatingResponse {
  final int    id;
  final int    patientId;
  final int?   doctorId;
  final int?   labId;
  final double stars;
  final String updatedAtUtc;

  const RatingResponse({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.labId,
    required this.stars,
    required this.updatedAtUtc,
  });

  factory RatingResponse.fromJson(Map<String, dynamic> j) => RatingResponse(
    id:           j['id']        as int?    ?? 0,
    patientId:    j['patientId'] as int?    ?? 0,
    doctorId:     j['doctorId']  as int?,
    labId:        j['labId']     as int?,
    stars:        (j['stars'] as num?)?.toDouble() ?? 0,
    updatedAtUtc: j['updatedAtUtc'] as String? ?? '',
  );
}
