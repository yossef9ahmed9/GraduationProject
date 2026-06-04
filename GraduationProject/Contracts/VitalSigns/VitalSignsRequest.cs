namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsRequest(
        int HeartRate,
        int SensorId,
        int PatientId,
        int? BloodPressureSystolic,
        int? BloodPressureDiastolic,
        double? OxygenSaturation,
        double? Temperature,
        int? RespiratoryRate,
        double? BloodGlucose
    );
}