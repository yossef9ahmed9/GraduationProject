namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsRequest(
        int HeartRate,
        bool EmergencyStatus,
        int SensorId,

        // NEW: now required so we know which patient this reading belongs to
        int PatientId,

        // optional vitals from the sensor
        int? BloodPressureSystolic,
        int? BloodPressureDiastolic,
        double? OxygenSaturation,
        double? Temperature,
        int? RespiratoryRate,
        double? BloodGlucose
    );
}