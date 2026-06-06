namespace GraduationProject.Contracts.VitalSigns
{
    public record VitalSignsRequest(
        int HeartRate,
        double OxygenSaturation,
        int SensorId,
        int PatientId
    );

}