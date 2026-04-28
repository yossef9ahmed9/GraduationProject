namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsRequest(
        int HeartRate,
        bool EmergencyStatus,
        int SensorId
    );
}