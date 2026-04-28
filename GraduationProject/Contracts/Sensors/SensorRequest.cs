namespace GraduationProject.Contracts.Sensors
{
    public record SensorRequest(
        string Type,
        string Description,
        int PatientId
    );
}