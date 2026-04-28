namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsResponse(
        int Id,
        int HeartRate,
        bool EmergencyStatus,
        DateTime TimeStamp,
        int SensorId
    );
}
