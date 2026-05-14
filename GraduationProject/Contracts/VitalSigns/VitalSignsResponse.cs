using GraduationProject.Contracts.EmergencyDispatches;

namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsResponse(
        int Id,
        int HeartRate,
        bool EmergencyStatus,
        DateTime TimeStamp,
        int SensorId,

        // NEW: patient info directly in the response
        int PatientId,
        string PatientName,   // NEW: so caller knows whose reading this is without extra call

        // NEW: all the extra vitals
        int? BloodPressureSystolic,
        int? BloodPressureDiastolic,
        double? OxygenSaturation,
        double? Temperature,
        int? RespiratoryRate,
        double? BloodGlucose,

        // NEW: if this reading triggered an automatic emergency dispatch,
        // the dispatch summary is included here so the frontend can
        // immediately show the ambulance details without a second API call.
        // Null when the reading was within safe thresholds.
        EmergencyDispatchResponse? AutoDispatch
    );
}
