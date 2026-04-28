namespace GraduationProject.Contracts.Sensors
{
    public record SensorResponse(
        int Id,
        string Type,
        string Description,
        int PatientId
    );
}
